#!groovy
//
// Jenkins-image.groovy - Jenkins script for building a single Zenoss product image.
//
// The Jenkins job parameters for this script are:
//
//    GIT_SHA              - the GIT SHA of product-assembly to checkout for this build
//    GIT_CREDENTIAL_ID    - the UUID of the Jenkins GIT credentials used to checkout stuff from github
//    MATURITY             - the image maturity level (e.g. 'unstable', 'testing', 'stable')
//    PRODUCT_BUIlD_NUMBER - the build number for any given execution of this build pipeline; set by the begin job.
//    TARGET_PRODUCT       - identifies the target product (e.g. 'core', 'resmgr', 'ucspm', etc)
//    DEPLOY_BRANCH        - The zenoss-deploy branch to forward to the appliance build job.
//    IGNORE_TEST_IMAGE_FAILURE - Ignores any failure of the Test Image stage when true.
//
node('build-zenoss-product') {
    def pipelineBuildName = env.JOB_NAME
    def pipelineBuildNumber = env.BUILD_NUMBER
    currentBuild.displayName = "product build #${PRODUCT_BUILD_NUMBER} (pipeline job #${pipelineBuildNumber} @${env.NODE_NAME})"

    def SVCDEF_GIT_REF=""
    def ZENOSS_VERSION=""
    def SERVICED_BRANCH=""
    def SERVICED_MATURITY=""
    def SERVICED_VERSION=""
    def SERVICED_BUILD_NUMBER=""

    stage('Checkout product-assembly') {
        // Make sure we start in a clean directory to ensure a fresh git clone
        deleteDir()
        // NOTE: The 'master' branch name here is only used to clone the github repo.
        //       The next checkout command will align the build with the correct target revision.
        git(
            branch: 'master',
            credentialsId: '${GIT_CREDENTIAL_ID}',
            url: 'https://github.com/zenoss/product-assembly',
        )
        sh("git checkout ${GIT_SHA}")

        // Get the values of various versions out of the versions.mk file for use in later stages
        def versionProps = readProperties file: 'versions.mk'

        SVCDEF_GIT_REF = versionProps['SVCDEF_GIT_REF']
        ZENOSS_VERSION = versionProps['VERSION']
        SERVICED_BRANCH = versionProps['SERVICED_BRANCH']
        SERVICED_MATURITY = versionProps['SERVICED_MATURITY']
        SERVICED_VERSION = versionProps['SERVICED_VERSION']
        SERVICED_BUILD_NUMBER = versionProps['SERVICED_BUILD_NUMBER']

        echo "SVCDEF_GIT_REF=${SVCDEF_GIT_REF}"
        echo "ZENOSS_VERSION=${ZENOSS_VERSION}"
        echo "SERVICED_BRANCH=${SERVICED_BRANCH}"
        echo "SERVICED_MATURITY=${SERVICED_MATURITY}"
        echo "SERVICED_VERSION=${SERVICED_VERSION}"
        echo "SERVICED_BUILD_NUMBER=${SERVICED_BUILD_NUMBER}"
    }

    stage('Build Images') {
        dir("${TARGET_PRODUCT}") {
            withEnv(["MATURITY=${MATURITY}", "BUILD_NUMBER=${PRODUCT_BUILD_NUMBER}"]) {
                productImageTag = sh(returnStdout: true, script: "make product-image-tag").trim()
                productImageID = sh(returnStdout: true, script: "make product-image-id").trim()
                mariadbImageTag = sh(returnStdout: true, script: "make mariadb-image-tag").trim()
                mariadbImageID = sh(returnStdout: true, script: "make mariadb-image-id").trim()
                echo "Building images ${productImageID} and ${mariadbImageID}"

                sh("make clean build")
                sh("make getDownloadLogs")
            }
        }

        def includePattern = TARGET_PRODUCT + '/*artifact.log'
        archiveArtifacts artifacts: includePattern
    }

    stage('Test Images') {
        dir("${TARGET_PRODUCT}") {
            withEnv(["MATURITY=${MATURITY}", "BUILD_NUMBER=${PRODUCT_BUILD_NUMBER}"]) {
                sh(
                    script: "make run-tests",
                    returnStatus: IGNORE_TEST_IMAGE_FAILURE.toBoolean()
                )
            }
        }
    }

    stage('Push Images') {
        dir("${TARGET_PRODUCT}") {
            withEnv(["MATURITY=${MATURITY}", "BUILD_NUMBER=${PRODUCT_BUILD_NUMBER}"]) {
                sh("make push clean")
            }
        }
    }

    stage('Build Service Template RPM') {
        dir("svcdefs") {
            // Run the checkout in a separate directory.
            // We have to clean it ourselves, because Jenkins doesn't (apparently)
            sh("make clean")
            def repo_dir = sh(returnStdout: true, script: "make repo_dir").trim()
            dir("${repo_dir}") {
                echo "Cloning zenoss-service - ${SVCDEF_GIT_REF} with credentialsId=${GIT_CREDENTIAL_ID}"
                // NOTE: The 'master' branch name here is only used to clone the github repo.
                //       The next checkout command will align the build with the correct target revision.
                git(
                    branch: 'master',
                    credentialsId: '${GIT_CREDENTIAL_ID}',
                    url: 'https://github.com/zenoss/zenoss-service.git',
                )
                sh("git checkout ${SVCDEF_GIT_REF}")

                // Log the current SHA of zenoss-service so, when building from a branch,
                // we know exactly which commit went into a particular build
                def HEAD_SHA = sh(returnStdout: true, script: "git rev-parse HEAD")
                echo "zenoss/zenoss-service git SHA = ${HEAD_SHA}"
            }

            def makeArgs = [
                "BUILD_NUMBER=${PRODUCT_BUILD_NUMBER}",
                "IMAGE_NUMBER=${PRODUCT_BUILD_NUMBER}",
                "MATURITY=${MATURITY}",
                "TARGET_PRODUCT=${TARGET_PRODUCT}",
            ].join(' ')
            sh("make build ${makeArgs}")

            archiveArtifacts artifacts: "${repo_dir}/output/**"
        }
    }

    stage('Push Service Template RPM') {
        // FIXME - if we never use the pipeline to build/publish artifacts directly to the stable or
        //         testing repos, then maybe we should remove MATURITY as an argument for this job?
        def s3Subdirectory = "/yum/zenoss/" + MATURITY + "/centos/el7/os/x86_64"
        def rpmJobLabel = TARGET_PRODUCT + " product build #" + PRODUCT_BUILD_NUMBER
        build job: 'rpm_repo_push', parameters: [
            [$class: 'StringParameterValue', name: 'JOB_LABEL', value: rpmJobLabel],
            [$class: 'StringParameterValue', name: 'UPSTREAM_JOB_NAME', value: pipelineBuildName],
            [$class: 'StringParameterValue', name: 'S3_BUCKET', value: 'get.zenoss.io'],
            [$class: 'StringParameterValue', name: 'S3_SUBDIR', value: s3Subdirectory]
        ]
    }

    stage('Build Appliances') {

        def branches = [:]

        if (TARGET_PRODUCT == "resmgr") {
            // After building RM, we build two sets of appliances; one for ZSD and another for POC

            // We have to use this version of the for-loop and _not_ the for(String s: strings)
            // as per https://jenkins.io/doc/pipeline/examples/#parallel-from-list
            def appliances = ["zsd", "poc"]
            for (int i = 0; i < appliances.size(); i++) {
                def applianceTarget = appliances.get(i);
                def jobLabel = applianceTarget + " appliance for " + TARGET_PRODUCT + " product build #" + PRODUCT_BUILD_NUMBER
                def branch = {
                    build job: 'appliance-build', parameters: [
                        [$class: 'StringParameterValue', name: 'JOB_LABEL', value: jobLabel],
                        [$class: 'StringParameterValue', name: 'TARGET_PRODUCT', value: applianceTarget],
                        [$class: 'StringParameterValue', name: 'BRANCH', value: DEPLOY_BRANCH],
                        [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: PRODUCT_BUILD_NUMBER],
                        [$class: 'StringParameterValue', name: 'ZENOSS_MATURITY', value: MATURITY],
                        [$class: 'StringParameterValue', name: 'ZENOSS_VERSION', value: ZENOSS_VERSION],
                        [$class: 'StringParameterValue', name: 'SERVICED_BRANCH', value: SERVICED_BRANCH],
                        [$class: 'StringParameterValue', name: 'SERVICED_MATURITY', value: SERVICED_MATURITY],
                        [$class: 'StringParameterValue', name: 'SERVICED_VERSION', value: SERVICED_VERSION],
                        [$class: 'StringParameterValue', name: 'SERVICED_BUILD_NUMBER', value: SERVICED_BUILD_NUMBER],
                        [$class: 'BooleanParameterValue', name: 'BUILD_APPLIANCES', value: BUILD_APPLIANCES.toBoolean()],
                    ]
                }

                branches[applianceTarget] = branch
            }
        } else {
            def jobLabel = TARGET_PRODUCT + " appliance for product build #" + PRODUCT_BUILD_NUMBER
            branches[TARGET_PRODUCT] = {
                build job: 'appliance-build', parameters: [
                    [$class: 'StringParameterValue', name: 'JOB_LABEL', value: jobLabel],
                    [$class: 'StringParameterValue', name: 'TARGET_PRODUCT', value: TARGET_PRODUCT],
                    [$class: 'StringParameterValue', name: 'BRANCH', value: DEPLOY_BRANCH],
                    [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: PRODUCT_BUILD_NUMBER],
                    [$class: 'StringParameterValue', name: 'ZENOSS_MATURITY', value: MATURITY],
                    [$class: 'StringParameterValue', name: 'ZENOSS_VERSION', value: ZENOSS_VERSION],
                    [$class: 'StringParameterValue', name: 'SERVICED_BRANCH', value: SERVICED_BRANCH],
                    [$class: 'StringParameterValue', name: 'SERVICED_MATURITY', value: SERVICED_MATURITY],
                    [$class: 'StringParameterValue', name: 'SERVICED_VERSION', value: SERVICED_VERSION],
                    [$class: 'StringParameterValue', name: 'SERVICED_BUILD_NUMBER', value: SERVICED_BUILD_NUMBER],
                    [$class: 'BooleanParameterValue', name: 'BUILD_APPLIANCES', value: BUILD_APPLIANCES.toBoolean()],
                ]
            }
        }

        parallel branches
    }
}

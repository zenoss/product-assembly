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
//
node ('build-zenoss-product') {
    def pipelineBuildName = env.JOB_NAME
    def pipelineBuildNumber = env.BUILD_NUMBER
    currentBuild.displayName = "product build #${PRODUCT_BUILD_NUMBER} (pipeline job #${pipelineBuildNumber})"

    def childJobLabel = TARGET_PRODUCT + " product build #" + PRODUCT_BUILD_NUMBER

    stage 'Build image'
        // Make sure we start in a clean directory to ensure a fresh git clone
        deleteDir()
        // NOTE: The 'master' branch name here is only used to clone the github repo.
        //       The next checkout command will align the build with the correct target revision.
        git branch: 'master', credentialsId: '${GIT_CREDENTIAL_ID}', url: 'https://github.com/zenoss/product-assembly'
        sh("git checkout ${GIT_SHA}")

        // Get the values of various versions out of the versions.mk file for use in later stages
        def versionProps = readProperties file: 'versions.mk'
        def SVCDEF_GIT_REF=versionProps['SVCDEF_GIT_REF']
        def ZENOSS_VERSION=versionProps['VERSION']
        def SERVICED_BRANCH=versionProps['SERVICED_BRANCH']
        def SERVICED_MATURITY=versionProps['SERVICED_MATURITY']
        def SERVICED_VERSION=versionProps['SERVICED_VERSION']
        def SERVICED_BUILD_NBR=versionProps['SERVICED_BUILD_NBR']
        echo "SVCDEF_GIT_REF=${SVCDEF_GIT_REF}"
        echo "ZENOSS_VERSION=${ZENOSS_VERSION}"
        echo "SERVICED_BRANCH=${SERVICED_BRANCH}"
        echo "SERVICED_MATURITY=${SERVICED_MATURITY}"
        echo "SERVICED_VERSION=${SERVICED_VERSION}"
        echo "SERVICED_BUILD_NBR=${SERVICED_BUILD_NBR}"

        // Make the target product
//        sh("cd ${TARGET_PRODUCT};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make clean build getDownloadLogs")

        def includePattern = TARGET_PRODUCT + '/*artifact.log'
//        archive includes: includePattern

    stage 'Test image'
//        sh("cd ${TARGET_PRODUCT};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make run-tests")

    stage 'Push image'
//        sh("cd ${TARGET_PRODUCT};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make push clean")

    stage 'Compile service definitions and build RPM'
        // Run the checkout in a separate directory. We have to clean it ourselves, because Jenkins doesn't (apparently)
        sh("rm -rf svcdefs/build;mkdir -p svcdefs/build/zenoss-service")
        dir('svcdefs/build/zenoss-service') {
            // NOTE: The 'master' branch name here is only used to clone the github repo.
            //       The next checkout command will align the build with the correct target revision.
            echo "Cloning zenoss-service - ${SVCDEF_GIT_REF} with credentialsId=${GIT_CREDENTIAL_ID}"
            git branch: 'master', credentialsId: '${GIT_CREDENTIAL_ID}', url: 'https://github.com/zenoss/zenoss-service.git'
            sh("git checkout ${SVCDEF_GIT_REF}")
        }

        // Note that SVDEF_GIT_READY=true tells the make to NOT attempt a git operation on its own because we need to use
        //     Jenkins credentials instead
        def makeArgs = "BUILD_NUMBER=${PRODUCT_BUILD_NUMBER}\
            IMAGE_NUMBER=${PRODUCT_BUILD_NUMBER}\
            MATURITY=${MATURITY}\
            SVCDEF_GIT_READY=true\
            TARGET_PRODUCT=${TARGET_PRODUCT}"
//        sh("cd svcdefs;make build ${makeArgs}")
//        archive includes: 'svcdefs/build/zenoss-service/output/**'

    stage 'Push RPM'
        // FIXME - if we never use the pipeline to build/publish artifacts directly to the stable or
        //         testing repos, then maybe we should remove MATURITY as an argument for this job?
        def s3Subdirectory = "/yum/zenoss/" + MATURITY + "/centos/el7/os/x86_64"
//        build job: 'rpm_repo_push', parameters: [
//            [$class: 'StringParameterValue', name: 'JOB_LABEL', value: childJobLabel],
//            [$class: 'StringParameterValue', name: 'UPSTREAM_JOB_NAME', value: pipelineBuildName],
//            [$class: 'StringParameterValue', name: 'S3_BUCKET', value: 'get.zenoss.io'],
//            [$class: 'StringParameterValue', name: 'S3_SUBDIR', value: s3Subdirectory]
//        ]

    stage 'Build Appliances'
        def branches = [:]

        if (TARGET_PRODUCT == "resmgr") {
            def appliances = ["zsd", "zsd_alderaan", "poc"]
            // After building RM, we build two sets of appliances; one for ZSD and another for POC

            // We have to use this version of the for-loop and _not_ the for(String s: strings)
            // as per https://jenkins.io/doc/pipeline/examples/#parallel-from-list
            for (int i = 0; i < appliances.size(); i++) {
                def applianceTarget = appliances.get(i);

                // specific build for zsd alderaan which includes rm5.2 and cc1.3.
                // this is only temporary.  See BLD-15 in jira
                def jobLabel = applianceTarget + " appliance for " + TARGET_PRODUCT + " product build #" + PRODUCT_BUILD_NUMBER
                def serviced_branch = SERVICED_BRANCH
                def serviced_maturity = SERVICED_MATURITY
                def serviced_version = SERVICED_VERSION
                def serviced_build_nbr = SERVICED_BUILD_NBR

                if (applianceTarget == "zsd_alderaan") {
                    serviced_branch = "develop"
                    serviced_maturity = "unstable"
                    serviced_version = ""
                    serviced_build_nbr = ""
                }

                def branch = {
                    build job: 'jb-appliance-build', parameters: [
                            [$class: 'StringParameterValue', name: 'JOB_LABEL', value: jobLabel],
                            [$class: 'StringParameterValue', name: 'TARGET_PRODUCT', value: applianceTarget],
                            [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: PRODUCT_BUILD_NUMBER],
                            [$class: 'StringParameterValue', name: 'ZENOSS_MATURITY', value: MATURITY],
                            [$class: 'StringParameterValue', name: 'ZENOSS_VERSION', value: ZENOSS_VERSION],
                            [$class: 'StringParameterValue', name: 'SERVICED_BRANCH', value: serviced_branch],
                            [$class: 'StringParameterValue', name: 'SERVICED_MATURITY', value: serviced_maturity],
                            [$class: 'StringParameterValue', name: 'SERVICED_VERSION', value: serviced_version],
                            [$class: 'StringParameterValue', name: 'SERVICED_BUILD_NBR', value: serviced_build_nbr],
                    ]
                }

                branches[applianceTarget] = branch

            }
        } else {
            branches["core"] = {
                build job: 'jb-appliance-build', parameters: [
                        [$class: 'StringParameterValue', name: 'JOB_LABEL', value: childJobLabel],
                        [$class: 'StringParameterValue', name: 'TARGET_PRODUCT', value: TARGET_PRODUCT],
                        [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: PRODUCT_BUILD_NUMBER],
                        [$class: 'StringParameterValue', name: 'ZENOSS_MATURITY', value: MATURITY],
                        [$class: 'StringParameterValue', name: 'ZENOSS_VERSION', value: ZENOSS_VERSION],
                        [$class: 'StringParameterValue', name: 'SERVICED_BRANCH', value: SERVICED_BRANCH],
                        [$class: 'StringParameterValue', name: 'SERVICED_MATURITY', value: SERVICED_MATURITY],
                        [$class: 'StringParameterValue', name: 'SERVICED_VERSION', value: SERVICED_VERSION],
                        [$class: 'StringParameterValue', name: 'SERVICED_BUILD_NBR', value: SERVICED_BUILD_NBR],
                ]
            }
        }

    parallel branches
}

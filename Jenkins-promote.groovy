#!groovy
//
// Jenkins-promote.groovy - Jenkins script for promoting a single Zenoss product image.
//
// This script has 4 phases:
// 1. Pull the specified docker image from docker hub, retag it per the
//    "to" parameters, and push the result back to docker hub.
// 2. Recompile the service definitions to use the new image and build the
//    svcdef RPM.
// 3. Push the RPM to the designated YUM repo (e.g. testing or stable).
// 4. Build appliances and offline resources based on the new image and RPM.
//
// The Jenkins job parameters for this script are:
//
// GIT_SHA              - the GIT SHA of product-assembly to checkout for this build
// GIT_CREDENTIAL_ID    - the UUID of the Jenkins GIT credentials used to checkout stuff from github
// PRODUCT_BUIlD_NUMBER - the build number for any given execution of this build pipeline
// TARGET_PRODUCT       - identifies the target product (e.g. 'core', 'resmgr', 'ucspm', etc)
// FROM_MATURITY        - required; the maturity level of the build that is
//                        being promoted. Must be one of unstable, testing, stable
// FROM_RELEASEPHASE    - The release phase of the from build (e.g. "RC1", "BETA", etc)
//                        Only applies when FROM_MATURITY is testing
// TO_MATURITY          - required; the maturity level of the build that will
//                        be created. Must be one of testing, or stable
// TO_RELEASEPHASE      - The release phase of the promoted build.
//                        If TO_MATURITY is testing, then this value is typically something "BETA" or "RC1".
//                        If TO_MATURITY is stable, then this value must be a single digit such as 1.
//
node('build-zenoss-product') {
    def pipelineBuildName = env.JOB_NAME
    def pipelineBuildNumber = env.BUILD_NUMBER
    currentBuild.displayName = "promote ${TARGET_PRODUCT} from ${FROM_MATURITY} to ${TO_MATURITY}"
    def childJobLabel = TARGET_PRODUCT + " promote to " + TO_MATURITY

    def SVCDEF_GIT_REF=""
    def ZENOSS_VERSION=""
    def ZENOSS_SHORT_VERSION=""
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

        sh("pwd; git status")

        // Get the values of various versions out of the versions.mk file for use in later stages
        def versionProps = readProperties file: 'versions.mk'

        SVCDEF_GIT_REF=versionProps['SVCDEF_GIT_REF']
        ZENOSS_VERSION=versionProps['VERSION']
        ZENOSS_SHORT_VERSION=versionProps['SHORT_VERSION']
        SERVICED_BRANCH=versionProps['SERVICED_BRANCH']
        SERVICED_MATURITY=versionProps['SERVICED_MATURITY']
        SERVICED_VERSION=versionProps['SERVICED_VERSION']
        SERVICED_BUILD_NUMBER=versionProps['SERVICED_BUILD_NUMBER']

        echo "SVCDEF_GIT_REF=${SVCDEF_GIT_REF}"
        echo "ZENOSS_VERSION=${ZENOSS_VERSION}"
        echo "ZENOSS_SHORT_VERSION=${ZENOSS_SHORT_VERSION}"
        echo "SERVICED_BRANCH=${SERVICED_BRANCH}"
        echo "SERVICED_MATURITY=${SERVICED_MATURITY}"
        echo "SERVICED_VERSION=${SERVICED_VERSION}"
        echo "SERVICED_BUILD_NUMBER=${SERVICED_BUILD_NUMBER}"
    }

    stage('Promote Product Image') {
        dir("svcdefs") {
            withEnv([
                "TARGET_PRODUCT=${TARGET_PRODUCT}",
                "PRODUCT_BUILD_NUMBER=${PRODUCT_BUILD_NUMBER}",
                "ZENOSS_VERSION=${ZENOSS_VERSION}",
                "ZENOSS_SHORT_VERSION=${ZENOSS_SHORT_VERSION}",
                "FROM_MATURITY=${FROM_MATURITY}",
                "FROM_RELEASEPHASE=${FROM_RELEASEPHASE}",
                "TO_MATURITY=${TO_MATURITY}",
                "TO_RELEASEPHASE=${TO_RELEASEPHASE}",
            ]) {
                sh("./image_promote.sh")
            }
        }
    }

    stage('Promote MariaDB Image') {
        dir("svcdefs") {
            withEnv([
                "TARGET_PRODUCT=mariadb-${TARGET_PRODUCT}",
                "PRODUCT_BUILD_NUMBER=${PRODUCT_BUILD_NUMBER}",
                "ZENOSS_VERSION=${ZENOSS_VERSION}",
                "ZENOSS_SHORT_VERSION=${ZENOSS_SHORT_VERSION}",
                "FROM_MATURITY=${FROM_MATURITY}",
                "FROM_RELEASEPHASE=${FROM_RELEASEPHASE}",
                "TO_MATURITY=${TO_MATURITY}",
                "TO_RELEASEPHASE=${TO_RELEASEPHASE}",
            ]) {
                sh("./image_promote.sh")
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
                "MATURITY=${TO_MATURITY}",
                "RELEASE_PHASE=${TO_RELEASEPHASE}",
                "TARGET_PRODUCT=${TARGET_PRODUCT}",
            ].join(' ')
            sh("make build ${makeArgs}")

            archiveArtifacts artifacts: "${repo_dir}/output/**"
        }
    }

    stage('Push Service Template RPM') {
        // FIXME - if we never use the pipeline to build/publish artifacts directly to the stable or
        //         testing repos, then maybe we should remove MATURITY as an argument for this job?
        def s3Subdirectory = "/yum/zenoss/" + TO_MATURITY + "/centos/el7/os/x86_64"
        build job: 'rpm_repo_push', parameters: [
            [$class: 'StringParameterValue', name: 'JOB_LABEL', value: childJobLabel],
            [$class: 'StringParameterValue', name: 'UPSTREAM_JOB_NAME', value: pipelineBuildName],
            [$class: 'StringParameterValue', name: 'S3_BUCKET', value: 'get.zenoss.io'],
            [$class: 'StringParameterValue', name: 'S3_SUBDIR', value: s3Subdirectory]
        ]
    }

    stage('Build Appliances') {
        if (BUILD_APPLIANCES != "true") {
            echo "Skipped Build Appliances"
            return
        }

        // NOTE: The appliance build parameter PRODUCT_BUILD_NUMBER is used for retrieving RPMs
        //       and labeling appliance artifacts. However, for promotion builds where MATURITY is
        //       testing or stable, we do not use the product build number to label the artifacts -
        //       we use the value of TO_RELEASEPHASE instead.
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
                        [$class: 'StringParameterValue', name: 'BRANCH', value: BRANCH],
                        [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: TO_RELEASEPHASE],
                        [$class: 'StringParameterValue', name: 'ZENOSS_MATURITY', value: TO_MATURITY],
                        [$class: 'StringParameterValue', name: 'ZENOSS_VERSION', value: ZENOSS_VERSION],
                        [$class: 'StringParameterValue', name: 'SERVICED_BRANCH', value: SERVICED_BRANCH],
                        [$class: 'StringParameterValue', name: 'SERVICED_MATURITY', value: SERVICED_MATURITY],
                        [$class: 'StringParameterValue', name: 'SERVICED_VERSION', value: SERVICED_VERSION],
                        [$class: 'StringParameterValue', name: 'SERVICED_BUILD_NUMBER', value: SERVICED_BUILD_NUMBER],
                    ]
                }

                branches[applianceTarget] = branch
            }
        } else {
            def jobLabel = TARGET_PRODUCT + " product build #" + PRODUCT_BUILD_NUMBER
            branches[TARGET_PRODUCT] = {
                build job: 'appliance-build', parameters: [
                        [$class: 'StringParameterValue', name: 'JOB_LABEL', value: jobLabel],
                        [$class: 'StringParameterValue', name: 'TARGET_PRODUCT', value: TARGET_PRODUCT],
                        [$class: 'StringParameterValue', name: 'BRANCH', value: BRANCH],
                        [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: TO_RELEASEPHASE],
                        [$class: 'StringParameterValue', name: 'ZENOSS_MATURITY', value: TO_MATURITY],
                        [$class: 'StringParameterValue', name: 'ZENOSS_VERSION', value: ZENOSS_VERSION],
                        [$class: 'StringParameterValue', name: 'SERVICED_BRANCH', value: SERVICED_BRANCH],
                        [$class: 'StringParameterValue', name: 'SERVICED_MATURITY', value: SERVICED_MATURITY],
                        [$class: 'StringParameterValue', name: 'SERVICED_VERSION', value: SERVICED_VERSION],
                        [$class: 'StringParameterValue', name: 'SERVICED_BUILD_NUMBER', value: SERVICED_BUILD_NUMBER],
                ]
            }
        }

        parallel branches
    }
}

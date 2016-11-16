#!groovy
//
// Jenkins-promote.groovy - Jenkins script for promoting a single Zenoss product image.
//
// This script has 4 phases:
// 1. Pull the specified docker image from docker hub, retag it per the
//    "to" parameters, push the result back to docker hub.
// 2. Recompile the service definitions to use the new image and build the
//    svcdef RPM.
// 3. Push the RPM to the designated YUM repo (e.g. testing or stable).
// 4. Build appliances and offline resources based on the new image.
//
// The Jenkins job parameters for this script are:
//
// GIT_SHA              - the GIT SHA of product-assembly to checkout for this build
// GIT_CREDENTIAL_ID    - the UUID of the Jenkins GIT credentials used to checkout stuff from github
// PRODUCT_BUIlD_NUMBER - the build number for any given execution of this build pipeline; set by the begin job.
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
node ('build-zenoss-product') {
    def pipelineBuildName = env.JOB_NAME
    def pipelineBuildNumber = env.BUILD_NUMBER
    currentBuild.displayName = "promote ${TARGET_PRODUCT} from ${FROM_MATURITY} to ${TO_MATURITY}"
    def childJobLabel = TARGET_PRODUCT + " promote to " + TO_MATURITY

    stage 'Promote image'
        // NOTE: The 'master' branch name here is only used to clone the github repo.
        //       The next checkout command will align the build with the correct target revision.
        git branch: 'master', credentialsId: '${GIT_CREDENTIAL_ID}', url: 'https://github.com/zenoss/product-assembly'
        sh("git checkout ${GIT_SHA}")

        // Get the values of various versions out of the versions.mk file for use in later stages
        def versionProps = readProperties file: 'versions.mk'
        def SVCDEF_GIT_REF=versionProps['SVCDEF_GIT_REF']
        def ZENOSS_VERSION=versionProps['VERSION']
        def ZENOSS_SHORT_VERSION=versionProps['SHORT_VERSION']
        echo "SVCDEF_GIT_REF=${SVCDEF_GIT_REF}"
        echo "ZENOSS_VERSION=${ZENOSS_VERSION}"
        echo "ZENOSS_SHORT_VERSION=${ZENOSS_SHORT_VERSION}"

        // Promote the docker images
        def promoteArgs = "TARGET_PRODUCT=${TARGET_PRODUCT}\
            PRODUCT_BUILD_NUMBER=${PRODUCT_BUILD_NUMBER}\
            ZENOSS_VERSION=${ZENOSS_VERSION}\
            ZENOSS_SHORT_VERSION=${ZENOSS_SHORT_VERSION}\
            FROM_MATURITY=${FROM_MATURITY}\
            FROM_RELEASEPHASE=${FROM_RELEASEPHASE}\
            TO_MATURITY=${TO_MATURITY}\
            TO_RELEASEPHASE=${TO_RELEASEPHASE}"
        sh("cd svcdefs;${promoteArgs} ./image_promote.sh")

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
            MATURITY=${TO_MATURITY}\
            SVCDEF_GIT_READY=true\
            TARGET_PRODUCT=${TARGET_PRODUCT}"
        sh("cd svcdefs;make build ${makeArgs}")
        archive includes: 'svcdefs/build/zenoss-service/output/**'

    stage 'Push RPM'
        echo "FIXME - call rpm_repo_push"
/************************
        // FIXME - if we never use the pipeline to build/publish artifacts directly to the stable or
        //         testing repos, then maybe we should remove MATURITY as an argument for this job?
        def s3Subdirectory = "/yum/zenoss/" + TO_MATURITY + "/centos/el7/os/x86_64"
        build job: 'rpm_repo_push', parameters: [
            [$class: 'StringParameterValue', name: 'JOB_LABEL', value: childJobLabel],
            [$class: 'StringParameterValue', name: 'UPSTREAM_JOB_NAME', value: pipelineBuildName],
            [$class: 'StringParameterValue', name: 'S3_BUCKET', value: 'get.zenoss.io'],
            [$class: 'StringParameterValue', name: 'S3_SUBDIR', value: s3Subdirectory]
        ]
********/

    stage 'Build Appliances'
        if (BUILD_APPLIANCE == true) {
            echo "FIXME - Build Appliances"
/************************
            build job: 'appliance-build', parameters: [
                [$class: 'StringParameterValue', name: 'JOB_LABEL', value: childJobLabel],
                [$class: 'StringParameterValue', name: 'TARGET_PRODUCT', value: TARGET_PRODUCT],
                [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: PRODUCT_BUILD_NUMBER],
                [$class: 'StringParameterValue', name: 'MATURITY', value: TO_MATURITY],
                [$class: 'StringParameterValue', name: 'ZENOSS_VERSION', value: ZENOSS_VERSION],
                [$class: 'StringParameterValue', name: 'SERVICED_BRANCH', value: SERVICED_BRANCH],
                [$class: 'StringParameterValue', name: 'SERVICED_VERSION', value: SERVICED_VERSION],
                [$class: 'StringParameterValue', name: 'SERVICED_BUILD_NBR', value: SERVICED_BUILD_NBR],
            ]
********/
        } else {
            echo "Skipped Build Appliances"
        }
}

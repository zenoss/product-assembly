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

    stage 'Build image'
        // NOTE: The 'master' branch name here is only used to clone the github repo.
        //       The next checkout command will align the build with the correct target revision.
        git branch: 'master', credentialsId: '${GIT_CREDENTIAL_ID}', url: 'https://github.com/zenoss/product-assembly'
        sh("git checkout ${GIT_SHA}")

        // Get the values of various versions out of the versions.mk file for use in later stages
        def versionProps = readProperties file: 'versions.mk'
        def SVCDEF_GIT_REF=versionProps['SVCDEF_GIT_REF']
        def ZENOSS_VERSION=versionProps['VERSION']
        def SERVICED_BRANCH=versionProps['SERVICED_BRANCH']
        def SERVICED_VERSION=versionProps['SERVICED_VERSION']
        def SERVICED_BUILD_NBR=versionProps['SERVICED_BUILD_NBR']
        echo "SVCDEF_GIT_REF=${SVCDEF_GIT_REF}"
        echo "ZENOSS_VERSION=${ZENOSS_VERSION}"
        echo "SERVICED_BRANCH=${SERVICED_BRANCH}"
        echo "SERVICED_VERSION=${SERVICED_VERSION}"
        echo "SERVICED_BUILD_NBR=${SERVICED_BUILD_NBR}"

        // Make the target product
        sh("cd ${TARGET_PRODUCT};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make clean build getDownloadLogs")

        // This is a hack, but I couldn't figure out another way to read the job parameter
        sh("echo ${TARGET_PRODUCT} >target_product")
        target=readFile('target_product').trim()
        def includePattern = target + '/*artifact.log'
        archive includes: includePattern

    stage 'Test image'
        sh("cd ${TARGET_PRODUCT};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make run-tests")

    stage 'Push image'
        sh("cd ${TARGET_PRODUCT};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make push")

    stage 'Compile service definitions and build RPM'
        // Run the checkout in a separate directory. We have to clean it ourselves, because Jenkins doesn't (apparently)
        sh("rm -rf svcdefs/build;mkdir -p svcdefs/build/zenoss-service")
        dir('svcdefs/build/zenoss-service') {
            echo "Cloning zenoss-service - ${SVCDEF_GIT_REF} with credentialsId=${GIT_CREDENTIAL_ID}"
            // NOTE: The 'master' branch name here is only used to clone the github repo.
            //       The next checkout command will align the build with the correct target revision.
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
        sh("cd svcdefs;make build ${makeArgs}")
        archive includes: 'svcdefs/build/zenoss-service/output/**'

    stage 'Push RPM'
        // This is a hack, but I couldn't figure out another way to read the job parameter
       sh("echo '${TARGET_PRODUCT} product build #${PRODUCT_BUILD_NUMBER}' >rpmJobLabel.txt")
       jobLabel=readFile('rpmJobLabel.txt').trim()

       // FIXME - in the arguments below, "unstable" needs to be replaced with ${MATURITY}, but there has to be a better
       //         way than the writing/reading file hack. Alternatively, if we never use the pipeline to build/publish
       //         artifacts directly to the stable or testing repos, then maybe we leave it hard-coded and remove
       //         MATURITY as an argument for this job.
       build job: 'rpm_repo_push', parameters: [
            [$class: 'StringParameterValue', name: 'JOB_LABEL', value: jobLabel],
            [$class: 'StringParameterValue', name: 'UPSTREAM_JOB_NAME', value: pipelineBuildName],
            [$class: 'StringParameterValue', name: 'S3_BUCKET', value: 'get.zenoss.io'],
            [$class: 'StringParameterValue', name: 'S3_SUBDIR', value: '/yum/zenoss/unstable/centos/el7/os/x86_64']
        ]

    stage 'Build Appliances'
        sh("echo '${TARGET_PRODUCT} product build #${PRODUCT_BUILD_NUMBER}' >applianceJobLabel.txt")
        jobLabel=readFile('applianceJobLabel.txt').trim()
        build job: 'appliance-build', parameters: [
            [$class: 'StringParameterValue', name: 'JOB_LABEL', value: jobLabel],
            [$class: 'StringParameterValue', name: 'TARGET_PRODUCT', value: TARGET_PRODUCT],
            [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: PRODUCT_BUILD_NUMBER],
            [$class: 'StringParameterValue', name: 'MATURITY', value: MATURITY],
            [$class: 'StringParameterValue', name: 'ZENOSS_VERSION', value: ZENOSS_VERSION],
            [$class: 'StringParameterValue', name: 'SERVICED_BRANCH', value: SERVICED_BRANCH],
            [$class: 'StringParameterValue', name: 'SERVICED_VERSION', value: SERVICED_VERSION],
            [$class: 'StringParameterValue', name: 'SERVICED_BUILD_NBR', value: SERVICED_BUILD_NBR],
        ]
}

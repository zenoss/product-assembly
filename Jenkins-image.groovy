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
node('build-zenoss-product') {
    def pipelineBuildName = env.JOB_NAME
    def pipelineBuildNumber = env.BUILD_NUMBER
    currentBuild.displayName = "product build #${PRODUCT_BUILD_NUMBER} (pipeline job #${pipelineBuildNumber} @${env.NODE_NAME})"

    def SVCDEF_GIT_REF = ""
    def ZENOSS_VERSION = ""
    def SERVICED_BRANCH = ""
    def SERVICED_MATURITY = ""
    def SERVICED_VERSION = ""
    def SERVICED_BUILD_NUMBER = ""
    def IMAGE_PROJECT = ""
    def customImage = ""
    stage('Checkout Product Assembly') {
        // Make sure we start in a clean directory to ensure a fresh git clone
        deleteDir()
        // NOTE: The 'master' branch name here is only used to clone the github repo.
        //       The next checkout command will align the build with the correct target revision.
        git branch: 'master', credentialsId: '${GIT_CREDENTIAL_ID}', url: 'https://github.com/zenoss/product-assembly'
        sh("git checkout ${GIT_SHA}")
    }
    stage('Download zenpacks') {
        // Get the values of various versions out of the versions.mk file for use in later stages
        def versionProps = readProperties file: 'versions.mk'
        SVCDEF_GIT_REF = versionProps['SVCDEF_GIT_REF']
        ZENOSS_VERSION = versionProps['VERSION']
        SERVICED_BRANCH = versionProps['SERVICED_BRANCH']
        SERVICED_MATURITY = versionProps['SERVICED_MATURITY']
        SERVICED_VERSION = versionProps['SERVICED_VERSION']
        SERVICED_BUILD_NUMBER = versionProps['SERVICED_BUILD_NUMBER']
        SHORT_VERSION = versionProps['SHORT_VERSION']
        DEPLOY_BRANCH = versionProps['DEPLOY_BRANCH']
        IMAGE_PROJECT = versionProps['IMAGE_PROJECT']
        echo "SVCDEF_GIT_REF=${SVCDEF_GIT_REF}"
        echo "ZENOSS_VERSION=${ZENOSS_VERSION}"
        echo "SERVICED_BRANCH=${SERVICED_BRANCH}"
        echo "SERVICED_MATURITY=${SERVICED_MATURITY}"
        echo "SERVICED_VERSION=${SERVICED_VERSION}"
        echo "SERVICED_BUILD_NUMBER=${SERVICED_BUILD_NUMBER}"

        if (DEPLOY_BRANCH == null || DEPLOY_BRANCH == "") {
            DEPLOY_BRANCH = BRANCH
        }
        echo "DEPLOY_BRANCH=${DEPLOY_BRANCH}"

        // Make the target product
        sh("cd ${TARGET_PRODUCT};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make clean build-deps")
    }

    stage('Build image') {
        imageName = "${IMAGE_PROJECT}/${TARGET_PRODUCT}_${SHORT_VERSION}:${ZENOSS_VERSION}_${PRODUCT_BUILD_NUMBER}_${MATURITY}"
        echo "imageName=${imageName}"
        customImage = docker.build(imageName, "-f ${TARGET_PRODUCT}/Dockerfile ${TARGET_PRODUCT}")

        sh("cd ${TARGET_PRODUCT};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make getDownloadLogs")
        def includePattern = TARGET_PRODUCT + '/*artifact.log'
        archive includes: includePattern
    }

    stage('Test image') {
        echo "skipping tests..."
        //sh("cd ${TARGET_PRODUCT};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make run-tests")
    }

    stage('Push image') {
        docker.withRegistry('https://gcr.io', 'gcr:zing-registry-188222') {
            customImage.push()
        }
        sh("cd ${TARGET_PRODUCT};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make clean")
    }
    stage('Compile service definitions and build RPM') {
        // Run the checkout in a separate directory. We have to clean it ourselves, because Jenkins doesn't (apparently)
        sh("rm -rf svcdefs/build;mkdir -p svcdefs/build/zenoss-service")
        dir('svcdefs/build/zenoss-service') {
            // NOTE: The 'master' branch name here is only used to clone the github repo.
            //       The next checkout command will align the build with the correct target revision.
            echo "Cloning zenoss-service - ${SVCDEF_GIT_REF} with credentialsId=${GIT_CREDENTIAL_ID}"
            git branch: 'master', credentialsId: '${GIT_CREDENTIAL_ID}', url: 'https://github.com/zenoss/zenoss-service.git'
            sh("git checkout ${SVCDEF_GIT_REF}")

            // Log the current SHA of zenoss-service so, when building from a branch,
            // we know exactly which commit went into a particular build
            sh("echo zenoss/zenoss-service git SHA = \$(git rev-parse HEAD)")
        }

        // Note that SVDEF_GIT_READY=true tells the make to NOT attempt a git operation on its own because we need to use
        //     Jenkins credentials instead
        def makeArgs = "BUILD_NUMBER=${PRODUCT_BUILD_NUMBER}\
            IMAGE_NUMBER=${PRODUCT_BUILD_NUMBER}\
            MATURITY=${MATURITY}\
            SVCDEF_GIT_READY=true\
            TARGET_PRODUCT=${TARGET_PRODUCT}"
        sh("cd svcdefs;make build ${makeArgs}")
        sh("mkdir -p artifacts")
        sh("cp svcdefs/build/zenoss-service/output/*.json artifacts/.")
        sh("cd artifacts; for file in *json; do tar -cvzf \$file.tgz \$file; done")
        archive includes: 'artifacts/*.json*'
    }

    stage('Upload service definitions') {
//        def archiveEnv = "SHORT_VERSION=${SHORT_VERSION}\
//            ZENOSS_VERSION=${ZENOSS_VERSION}\
//            TARGET_PRODUCT=${TARGET_PRODUCT} \
//            MATURITY=${MATURITY}\
//            BUILD_NUMBER=${PRODUCT_BUILD_NUMBER}"
//        sh("${archiveEnv} python archive.py --service-def")
    }

}

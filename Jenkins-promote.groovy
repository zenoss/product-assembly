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
// FROM_MATURITY        - required; the maturity level of the build that is
//                        being promoted. Must be one of unstable, testing, stable
// FROM_RELEASEPHASE    - The release phase of the from build (e.g. "RC1", "BETA", etc)
//                        Only applies when FROM_MATURITY is testing
// TO_MATURITY          - required; the maturity level of the build that will
//                        be created. Must be one of testing, or stable
//                        If TO_MATURITY is testing, then this value is typically something "BETA" or "RC1".
//                        If TO_MATURITY is stable, then this value must be a single digit such as 1.
//
node ('build-zenoss-product') {
    def TARGET_PRODUCT = "cse"

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

    stage ('Pull cz image') {
        // Make sure we start in a clean directory to ensure a fresh git clone
        deleteDir()
        // NOTE: The 'master' branch name here is only used to clone the github repo.
        //       The next checkout command will align the build with the correct target revision.
        git branch: 'master', credentialsId: '${GIT_CREDENTIAL_ID}', url: 'https://github.com/zenoss/product-assembly'
        sh("git checkout ${GIT_SHA}")
        sh("pwd;git status")

        // Get the values of various versions out of the versions.mk file for use in later stages
        def versionProps = readProperties file: 'versions.mk'
        SVCDEF_GIT_REF = versionProps['SVCDEF_GIT_REF']
        ZENOSS_VERSION = versionProps['VERSION']
        ZENOSS_SHORT_VERSION = versionProps['SHORT_VERSION']
        SERVICED_BRANCH = versionProps['SERVICED_BRANCH']
        SERVICED_MATURITY = versionProps['SERVICED_MATURITY']
        SERVICED_VERSION = versionProps['SERVICED_VERSION']
        SERVICED_BUILD_NUMBER = versionProps['SERVICED_BUILD_NUMBER']
        echo "SVCDEF_GIT_REF=${SVCDEF_GIT_REF}"
        echo "ZENOSS_VERSION=${ZENOSS_VERSION}"
        echo "ZENOSS_SHORT_VERSION=${ZENOSS_SHORT_VERSION}"
        echo "SERVICED_BRANCH=${SERVICED_BRANCH}"
        echo "SERVICED_MATURITY=${SERVICED_MATURITY}"
        echo "SERVICED_VERSION=${SERVICED_VERSION}"
        echo "SERVICED_BUILD_NUMBER=${SERVICED_BUILD_NUMBER}"

        if (!TARGET_PRODUCT.trim()) {
            error "ERROR: Missing required argument - TARGET_PRODUCT"
        }
        if (!ZENOSS_VERSION.trim()) {
            error "ERROR: Missing required argument - ZENOSS_VERSION"
        }
        if (!ZENOSS_SHORT_VERSION.trim()) {
            error "ERROR: Missing required argument - ZENOSS_SHORT_VERSION"
        }
        if (!FROM_MATURITY.trim()) {
            error "ERROR: Missing required argument - FROM_MATURITY"
        }
        if (!TO_MATURITY.trim()) {
            error "ERROR: Missing required argument - TO_MATURITY"
        }
        if (FROM_MATURITY != "unstable" && FROM_MATURITY != "testing" && FROM_MATURITY != "stable") {
            error "ERROR: FROM_MATURITY=$FROM_MATURITY is invalid; must be one of unstable, testing or stable"
        }
        if (FROM_MATURITY == "unstable" && !PRODUCT_BUILD_NUMBER.trim()) {
            error "ERROR: Missing required argument - PRODUCT_BUILD_NUMBER\n When FROM_MATURITY=unstable, PRODUCT_BUILD_NUMBER is required."
        }
        if (FROM_MATURITY == "testing" && !FROM_RELEASEPHASE.trim()) {
            error "ERROR: Missing required argument - FROM_RELEASEPHASE\n When FROM_MATURITY=testing, FROM_RELEASEPHASE is required."
        }
        if (TO_MATURITY != "testing" && TO_MATURITY != "stable") {
            error "ERROR: TO_MATURITY=${TO_MATURITY} is invalid; must be one of testing or stable"
        }

        repo = "gcr.io/zing-registry-188222/${TARGET_PRODUCT}_${ZENOSS_SHORT_VERSION}"
        tag = ""
        if (FROM_MATURITY == "unstable") {
            // only accept images where all sub-components were pinned at build time
            tag = "${ZENOSS_VERSION}_${PRODUCT_BUILD_NUMBER}_unstable-pinned"
        } else if (FROM_MATURITY == "stable" || FROM_MATURITY == "testing") {
            tag = "${ZENOSS_VERSION}_${FROM_RELEASEPHASE}"
        } else {
            error "Invalid maturity value ${FROM_MATURITY}"
        }
        from_image = "${repo}:${tag}"
        echo "pulling ${from_image}"
        CZ_IMAGE=null
        docker.withRegistry('https://gcr.io', 'gcr:zing-registry-188222') {
            CZ_IMAGE=docker.image("${from_image}")
            CZ_IMAGE.pull()
        }

    }
    stage ('Promote cz image') {
        if  (TO_MATURITY == "stable" || TO_MATURITY == "testing"){
            promote_tag="${ZENOSS_VERSION}_${BUILD_NUMBER}"
        }else{
            error "Invalid maturity value ${TO_MATURITY}"
        }
        docker.withRegistry('https://gcr.io', 'gcr:zing-registry-188222') {
            CZ_IMAGE.tag("${promote_tag}")
            CZ_IMAGE.push("${promote_tag}")
        }
    }
    stage ('Pull mariadb image'){
        repo = "gcr.io/zing-registry-188222/mariadb"
        tag = ""
        if (FROM_MATURITY == "unstable") {
            // only accept images where all sub-components were pinned at build time
            tag = tag + "${ZENOSS_VERSION}_${PRODUCT_BUILD_NUMBER}_unstable-pinned"
        } else if (FROM_MATURITY == "stable" || FROM_MATURITY == "testing") {
            tag = tag + "${ZENOSS_VERSION}_${FROM_RELEASEPHASE}"
        } else {
            error "Invalid maturity value ${FROM_MATURITY}"
        }
        from_image = "${repo}:${tag}"
        echo "pulling ${from_image}"
        CZ_IMAGE=null
        docker.withRegistry('https://gcr.io', 'gcr:zing-registry-188222') {
            CZ_IMAGE=docker.image("${from_image}")
            CZ_IMAGE.pull()
        }
    }
    stage ('Promote mariadb image'){
        
        if  (TO_MATURITY == "stable" || TO_MATURITY == "testing"){
            promote_tag="${ZENOSS_VERSION}_${BUILD_NUMBER}"
        }else{
            error "Invalid maturity value ${TO_MATURITY}"
        }
        docker.withRegistry('https://gcr.io', 'gcr:zing-registry-188222') {
            CZ_IMAGE.tag("${promote_tag}")
            CZ_IMAGE.push("${promote_tag}")
        }
    }   
    stage ('Compile service definitions') {
        // Run the checkout in a separate directory. We have to clean it ourselves, because Jenkins doesn't (apparently)
        sh("rm -rf svcdefs/build;mkdir -p svcdefs/build/zenoss-service")
        dir('svcdefs/build/zenoss-service') {
            // NOTE: The 'master' branch name here is only used to clone the github repo.
            //       The next checkout command will align the build with the correct target revision.
            echo "Cloning zenoss-service - ${SVCDEF_GIT_REF} with credentialsId=${GIT_CREDENTIAL_ID}"
            git branch: 'master', credentialsId: '${GIT_CREDENTIAL_ID}', url: 'https://github.com/zenoss/zenoss-service.git'
            sh("pwd;git checkout ${SVCDEF_GIT_REF}")
        }

        // Note that SVDEF_GIT_READY=true tells the make to NOT attempt a git operation on its own because we need to use
        //     Jenkins credentials instead
        def makeArgs = "BUILD_NUMBER=${PRODUCT_BUILD_NUMBER}\
        IMAGE_NUMBER=${PRODUCT_BUILD_NUMBER}\
            MATURITY=${TO_MATURITY}\
            SVCDEF_GIT_READY=true\
            RELEASE_PHASE=${BUILD_NUMBER}\
            TARGET_PRODUCT=${TARGET_PRODUCT}"
        sh("cd svcdefs;make build ${makeArgs}")
        sh("mkdir -p artifacts")
        sh("cp svcdefs/build/zenoss-service/output/*.json artifacts/.")
        sh("cd artifacts; for file in *json; do tar -cvzf \$file.tgz \$file; done")
        archive includes: 'artifacts/*.json*'
    }

    stage('Upload service definitions') {
        echo "upload..."
        googleStorageUpload bucket: "gs://cz-${TO_MATURITY}/${TARGET_PRODUCT}/${ZENOSS_VERSION}", \
         credentialsId: 'zing-registry-188222', pathPrefix: 'artifacts/', pattern: 'artifacts/*tgz'
    }
}

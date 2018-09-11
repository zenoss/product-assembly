#!groovy
//
// Jenkins-begin.groovy - Jenkins script for initiating the Zenoss product build process.
//
// The Jenkins job parameters for this script are:
//
//    BRANCH            - the name of the GIT branch to build from.
//    GIT_CREDENTIAL_ID - the UUID of the Jenkins GIT credentials used to checkout stuff from github
//    MATURITY          - the image maturity level (e.g. 'unstable', 'testing', 'stable')
//
node('build-zenoss-product') {
    // To avoid naming confusion with downstream jobs that have their own BUILD_NUMBER variables,
    // define 'PRODUCT_BUILD_NUMBER' as the parameter name that will be used by all downstream
    // jobs to identify a particular execution of the build pipeline.
    def TARGET_PRODUCT = "cse"
    def PRODUCT_BUILD_NUMBER = env.BUILD_NUMBER
    def JENKINS_URL = env.JENKINS_URL  // e.g. http://<server>/
    def JOB_NAME = env.JOB_NAME        // e.g. product-assembly/support-6.0.x/begin
    def JOB_URL = env.JOB_URL          // e.g. ${JENKINS_URL}job/${JOB_NAME}/
    def BUILD_URL = env.BUILD_URL      // e.g. ${JOB_URL}${PRODUCT_BUILD_NUMBER}
    currentBuild.displayName = "product build #${PRODUCT_BUILD_NUMBER} @${env.NODE_NAME}"

    try {
        stage('Checkout product-assembly repo') {
            // Make sure we start in a clean directory to ensure a fresh git clone
            deleteDir()
            git branch: BRANCH, credentialsId: GIT_CREDENTIAL_ID, url: 'https://github.com/zenoss/product-assembly'

            // Record the current git commit sha in the variable 'GIT_SHA'
            sh("git rev-parse HEAD >git_sha.id")
            GIT_SHA = readFile('git_sha.id').trim()
            println("Building from git commit='${GIT_SHA}' on branch ${BRANCH} for MATURITY='${MATURITY}'")
        }

        stage('Build product-base') {
            if (PINNED == "true") {
                // make sure SVCDEF_GIT_REF and IMPACT_VERSION have the form x.x.x, where x is an integer
                println "Checking for pinned versions in versions.mk"
                sh("grep '^SVCDEF_GIT_REF=[0-9]\\{1,\\}\\.[0-9]\\{1,\\}\\.[0-9]\\{1,\\}' versions.mk")
                sh("grep '^IMPACT_VERSION=[0-9]\\{1,\\}\\.[0-9]\\{1,\\}\\.[0-9]\\{1,\\}' versions.mk")

                // make sure ZING_API_PROXY_VERSION and ZING_CONNECTOR_VERSION have the form YYYY-MM-DD-N
                sh("grep '^ZING_API_PROXY_VERSION=20[1-4][0-9]\\-[0-1][0-9]\\-[0-3][0-9]\\-[0-9]' versions.mk")
                sh("grep '^ZING_CONNECTOR_VERSION=20[1-4][0-9]\\-[0-1][0-9]\\-[0-3][0-9]\\-[0-9]' versions.mk")

                // Verify that everything in the component and ZP manifests are pinned
                println "Checking for pinned versions in component_versions.json"
                sh("./artifact_download.py component_versions.json --pinned")

                println "Checking for pinned versions in zenpack_versions.json"
                sh("./artifact_download.py zenpack_versions.json --pinned")
            }
            sh("cd product-base;MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make clean build")
        }

        def SVCDEF_GIT_REF = ""
        def IMAGE_PROJECT = ""
        def customImage = ""
        stage('Download zenpacks') {
            // Get the values of various versions out of the versions.mk file for use in later stages
            def versionProps = readProperties file: 'versions.mk'
            SVCDEF_GIT_REF = versionProps['SVCDEF_GIT_REF']
            IMAGE_PROJECT = versionProps['IMAGE_PROJECT']
            echo "SVCDEF_GIT_REF=${SVCDEF_GIT_REF}"

            // Make the target product
            sh("cd ${TARGET_PRODUCT};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make clean build-deps")
        }

        stage('Build image') {

            imageTag = "${PRODUCT_BUILD_NUMBER}_${MATURITY}"
            imageName = "${IMAGE_PROJECT}/${TARGET_PRODUCT}_${PRODUCT_BUILD_NUMBER}:${imageTag}"
            echo "imageName=${imageName}"
            customImage = docker.build(imageName, "-f ${TARGET_PRODUCT}/Dockerfile ${TARGET_PRODUCT}")

            sh("cd ${TARGET_PRODUCT};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make getDownloadLogs")
            def includePattern = TARGET_PRODUCT + '/*artifact.log'
            archive includes: includePattern
        }

        stage('Test image') {
            sh("cd ${TARGET_PRODUCT};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make run-tests")
        }

        stage('Push image') {
            docker.withRegistry('https://gcr.io', 'gcr:zing-registry-188222') {
                customImage.push()
                if (PINNED == "true") {
                    //add a pinned tag so we know if this image is viable for promotion
                    customImage.push("${imageTag}-pinned")
                }
            }
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
            def makeArgs = "BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} \
             IMAGE_NUMBER=${PRODUCT_BUILD_NUMBER} \
             MATURITY=${MATURITY} \
             SVCDEF_GIT_READY=true \
             TARGET_PRODUCT=${TARGET_PRODUCT} "
            sh("cd svcdefs;make build ${makeArgs}")
            sh("mkdir -p artifacts")
            sh("cp svcdefs/build/zenoss-service/output/*.json artifacts/.")
            sh("cd artifacts; for file in *json; do tar -cvzf \$file.tgz \$file; done")
            archive includes: 'artifacts/*.json*'
        }

        stage('Upload service definitions') {
            googleStorageUpload bucket: "gs://cse_artifacts/${TARGET_PRODUCT}/${MATURITY}/${PRODUCT_BUILD_NUMBER}", \
         credentialsId: 'zing-registry-188222', pathPrefix: 'artifacts/', pattern: 'artifacts/*tgz'
        }

    } catch (err) {
        echo "Job failed with the following error: ${err}"
        if (err.toString().contains("completed with status ABORTED") ||
                err.toString().contains("hudson.AbortException: script returned exit code 2")) {
            currentBuild.result = 'ABORTED'
        } else {
            currentBuild.result = 'FAILED'
        }

        slackSend color: 'warning',
                channel: '#zing-dev',
                message: "CSE Build Failed: ${env.JOB_NAME} Build #${env.BUILD_NUMBER} ${env.BUILD_URL}"
        error "Job failed with the following error: ${err}"
    } finally {
        sh("cd ${TARGET_PRODUCT};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make clean")
        sh("cd product-base;MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make clean")
    }
}

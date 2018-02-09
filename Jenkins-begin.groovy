#!groovy
//
// Jenkins-begin.groovy - Jenkins script for initiating the Zenoss product build process.
//
// The Jenkins job parameters for this script are:
//
//    BRANCH            - the name of the GIT branch to build from.
//    GIT_CREDENTIAL_ID - the UUID of the Jenkins GIT credentials used to checkout stuff from github
//    MATURITY          - the image maturity level (e.g. 'unstable', 'testing', 'stable')
//    BUILD_APPLIANCES  - true/false whether appliances should be built.
//
node('build-zenoss-product') {
    // To avoid naming confusion with downstream jobs that have their own BUILD_NUMBER variables,
    // define 'PRODUCT_BUILD_NUMBER' as the parameter name that will be used by all downstream
    // jobs to identify a particular execution of the build pipeline.
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
                // make sure SVCDEF_GIT_REF has is of the form x.x.x, where x is an integer
                sh("grep '^SVCDEF_GIT_REF=[0-9]\\{1,\\}\\.[0-9]\\{1,\\}\\.[0-9]\\{1,\\}' versions.mk")
                sh("./artifact_download.py component_versions.json --pinned")
                sh("./artifact_download.py zenpack_versions.json --pinned")
            }
            sh("cd product-base;MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make clean build")
        }

        stage('Push product-base') {
            sh("cd product-base;MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make push clean")
        }

        stage ('Run all product pipelines') {
            def branches = [
                'cse-pipeline': {
                    build job: 'cse-pipeline', parameters: [
                            [$class: 'StringParameterValue', name: 'GIT_CREDENTIAL_ID', value: GIT_CREDENTIAL_ID],
                            [$class: 'StringParameterValue', name: 'GIT_SHA', value: GIT_SHA],
                            [$class: 'StringParameterValue', name: 'MATURITY', value: MATURITY],
                            [$class: 'StringParameterValue', name: 'BRANCH', value: BRANCH],
                            [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: PRODUCT_BUILD_NUMBER],
                            [$class: 'StringParameterValue', name: 'TARGET_PRODUCT', value: "cse"],
                            [$class: 'BooleanParameterValue', name: 'BUILD_APPLIANCES', value: false],
                    ]
                },
            ]

            parallel branches
            // Set the status to success because the finally block is about to execute
            //      and we don't want the final report status to be "IN-PROGRESS"
            currentBuild.result = 'SUCCESS'
        }
    } catch (err) {
        echo "Job failed with the following error: ${err}"
        if (err.toString().contains("completed with status ABORTED") ||
                err.toString().contains("hudson.AbortException: script returned exit code 2")) {
            currentBuild.result = 'ABORTED'
        } else {
            currentBuild.result = 'FAILED'
        }
    } finally {
        sh("./build_status.py --server \"${JENKINS_URL}\" --job-name ${JOB_NAME} --build ${PRODUCT_BUILD_NUMBER} -b ${BRANCH} --job-status ${currentBuild.result} -html buildReport.html")
        archive includes: 'buildReport.*'
        publishHTML([allowMissing         : true,
                     alwaysLinkToLastBuild: true,
                     keepAll              : true,
                     reportDir            : './',
                     reportFiles          : 'buildReport.html',
                     reportName           : 'Build Summary Report'])
    }
}

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
node ('build-zenoss-product') {
    // To avoid naming confusion with downstream jobs that have their own BUILD_NUMBER variables,
    // define 'PRODUCT_BUILD_NUMBER' as the parameter name that will be used by all downstream
    // jobs to identify a particular execution of the build pipeline.
    PRODUCT_BUILD_NUMBER=env.BUILD_NUMBER
    currentBuild.displayName = "product build #${PRODUCT_BUILD_NUMBER}"

    try {
        stage 'Checkout product-assembly repo'
            // Make sure we start in a clean directory to ensure a fresh git clone
            deleteDir()
            git branch: BRANCH, credentialsId: GIT_CREDENTIAL_ID, url: 'https://github.com/zenoss/product-assembly'

            // Record the current git commit sha in the variable 'GIT_SHA'
            sh("git rev-parse HEAD >git_sha.id")
            GIT_SHA=readFile('git_sha.id').trim()
            println("Building from git commit='${GIT_SHA}' on branch ${BRANCH} for MATURITY='${MATURITY}'")

        stage 'Build product-base'
            if (PINNED == "true") {
                // make sure SVCDEF_GIT_REF has is of the form x.x.x, where x is an integer
                sh("grep '^SVCDEF_GIT_REF=[0-9]\\{1,\\}\\.[0-9]\\{1,\\}\\.[0-9]\\{1,\\}' versions.mk")
                sh("./artifact_download.py component_versions.json --pinned")
                sh("./artifact_download.py zenpack_versions.json --pinned")
            }
            sh("cd product-base;MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make clean build")

        stage 'Push product-base'
            sh("cd product-base;MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make push clean")

        stage 'Run all product pipelines'
            def branches = [
                'core-pipeline': {
                    build job: 'core-pipeline', parameters: [
                        [$class: 'StringParameterValue', name: 'GIT_CREDENTIAL_ID', value: GIT_CREDENTIAL_ID],
                        [$class: 'StringParameterValue', name: 'GIT_SHA', value: GIT_SHA],
                        [$class: 'StringParameterValue', name: 'MATURITY', value: MATURITY],
                        [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: PRODUCT_BUILD_NUMBER],
                    ]
                },
                'resmgr-pipeline': {
                    build job: 'resmgr-pipeline', parameters: [
                        [$class: 'StringParameterValue', name: 'GIT_CREDENTIAL_ID', value: GIT_CREDENTIAL_ID],
                        [$class: 'StringParameterValue', name: 'GIT_SHA', value: GIT_SHA],
                        [$class: 'StringParameterValue', name: 'MATURITY', value: MATURITY],
                        [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: PRODUCT_BUILD_NUMBER],
                    ]
                },
            ]

            parallel branches
    } catch (err) {
        echo "Job failed with the following error: ${err}"
        if (err.toString().contains("completed with status ABORTED") ||
            err.toString().contains("hudson.AbortException: script returned exit code 2")) {
            currentBuild.result = 'ABORTED'
        } else {
            currentBuild.result = 'FAILED'
        }
    } finally {
        sh("./build_status.py -b ${BRANCH} -p ${PRODUCT_BUILD_NUMBER} --job-name ${env.JOB_BASE_NAME} --job-status ${currentBuild.result} -html buildReport.html")
        archive includes: 'buildReport.*'
        publishHTML([allowMissing: true,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: './',
            reportFiles: 'buildReport.html',
            reportName: 'Build Summary Report'])
    }
}

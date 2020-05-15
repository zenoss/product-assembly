#!groovy
//
// Jenkins-begin.groovy - Jenkins script for initiating the Zenoss product build process.
//
// The Jenkins job parameters for this script are:
//
//    BRANCH            - the name of the product-assembly GIT branch to build from.
//    GIT_CREDENTIAL_ID - the UUID of the Jenkins GIT credentials used to checkout stuff from github
//    MATURITY          - the image maturity level (e.g. 'unstable', 'testing', 'stable')
//    BUILD_APPLIANCES  - true/false whether appliances should be built.
//    DEPLOY_BRANCH     - The name of the zenoss-deploy GIT branch to use for building appliances.
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
    def SVCDEF_GIT_REF = ''

    currentBuild.displayName = "product build #${PRODUCT_BUILD_NUMBER} @${env.NODE_NAME}"

    try {
        stage('Checkout product-assembly') {
            // Make sure we start in a clean directory to ensure a fresh git clone
            deleteDir()
            git branch: BRANCH, credentialsId: GIT_CREDENTIAL_ID, url: 'https://github.com/zenoss/product-assembly'

            // Record the current git commit sha in the variable 'GIT_SHA'
            sh("git rev-parse HEAD >git_sha.id")
            GIT_SHA = readFile('git_sha.id').trim()
            println("Building from git commit='${GIT_SHA}' on branch ${BRANCH} for MATURITY='${MATURITY}'")

            if (PINNED == "true") {
                // make sure SVCDEF_GIT_REF has is of the form x.x.x, where x is an integer
                sh("grep '^SVCDEF_GIT_REF=[0-9]\\{1,\\}\\.[0-9]\\{1,\\}\\.[0-9]\\{1,\\}' versions.mk")
                sh("./artifact_download.py component_versions.json --pinned")
                sh("./artifact_download.py zenpack_versions.json --pinned")
            }
            
            def versionProps = readProperties file: 'versions.mk'
            SVCDEF_GIT_REF = versionProps['SVCDEF_GIT_REF']
        }

        stage('Build Service Migrations') {
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
                ].join(' ')
                sh("make migrations ${makeArgs}")

                archiveArtifacts artifacts: "*.whl"
            }
        }

        stage('Build product-base') {
            dir("product-base") {
                withEnv(["MATURITY=${MATURITY}", "BUILD_NUMBER=${PRODUCT_BUILD_NUMBER}"]) {
                    sh("make clean build")
                }
            }
        }

        stage('Build mariadb-base') {
            dir("mariadb-base") {
                withEnv(["MATURITY=${MATURITY}", "BUILD_NUMBER=${PRODUCT_BUILD_NUMBER}"]) {
                    sh("make clean build")
                }
            }
        }

        stage('Push Base Images') {
            withEnv(["MATURITY=${MATURITY}", "BUILD_NUMBER=${PRODUCT_BUILD_NUMBER}"]) {
                dir("product-base") {
                    sh("make push clean")
                }
                dir("mariadb-base") {
                    sh("make push clean")
                }
            }
        }

        stage('Run Product Pipelines') {
            def branches = [
                // 'core-pipeline': {
                //     build job: 'core-pipeline', parameters: [
                //         [$class: 'StringParameterValue', name: 'GIT_CREDENTIAL_ID', value: GIT_CREDENTIAL_ID],
                //         [$class: 'StringParameterValue', name: 'GIT_SHA', value: GIT_SHA],
                //         [$class: 'StringParameterValue', name: 'MATURITY', value: MATURITY],
                //         [$class: 'StringParameterValue', name: 'DEPLOY_BRANCH', value: DEPLOY_BRANCH],
                //         [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: PRODUCT_BUILD_NUMBER],
                //         [$class: 'BooleanParameterValue', name: 'BUILD_APPLIANCES', value: BUILD_APPLIANCES.toBoolean()],
                //         [$class: 'BooleanParameterValue', name: 'IGNORE_TEST_IMAGE_FAILURE', value: IGNORE_TEST_IMAGE_FAILURE.toBoolean()],
                //     ]
                // },
                'resmgr-pipeline': {
                    build job: 'resmgr-pipeline', parameters: [
                        [$class: 'StringParameterValue', name: 'GIT_CREDENTIAL_ID', value: GIT_CREDENTIAL_ID],
                        [$class: 'StringParameterValue', name: 'GIT_SHA', value: GIT_SHA],
                        [$class: 'StringParameterValue', name: 'MATURITY', value: MATURITY],
                        [$class: 'StringParameterValue', name: 'DEPLOY_BRANCH', value: DEPLOY_BRANCH],
                        [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: PRODUCT_BUILD_NUMBER],
                        [$class: 'BooleanParameterValue', name: 'BUILD_APPLIANCES', value: BUILD_APPLIANCES.toBoolean()],
                        [$class: 'BooleanParameterValue', name: 'IGNORE_TEST_IMAGE_FAILURE', value: IGNORE_TEST_IMAGE_FAILURE.toBoolean()],
                    ]
                },
            ]

            parallel branches
            // Set the status to success because the finally block is about to execute
            // and the final report status should not be "IN-PROGRESS"
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
        archiveArtifacts artifacts: 'buildReport.*'
        publishHTML([
            allowMissing: true,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: './',
            reportFiles: 'buildReport.html',
            reportName: 'Build Summary Report',
        ])
    }
}

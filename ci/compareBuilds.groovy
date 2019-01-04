pipeline {
    agent {
        label 'docker-based-build'
    }

    options {
        buildDiscarder logRotator(artifactDaysToKeepStr: '', artifactNumToKeepStr: '', daysToKeepStr: '', numToKeepStr: '70')
        disableConcurrentBuilds()
    }

    parameters {
        choice(name: 'BUILD1_NAME',
            choices: 'core-pipeline\nresmgr-pipeline\nucspm-pipeline\nbegin',
            description: '')
        string(name: 'BUILD1_JOB_NBR',
            defaultValue: '',
            description: '<p>The jenkins job number of the job selected for BUILD1_NAME.</p>\n'
                       + '<p>Note that you can use <b>lastSuccessfulBuild</b> for this field.</p>')
        choice(name: 'BUILD2_NAME',
            choices: 'core-pipeline\nresmgr-pipeline\nucspm-pipeline\nbegin',
            description: '')
        string(name: 'BUILD2_JOB_NBR',
            defaultValue: '',
            description: '<p>The jenkins job number of the job selected for BUILD2_NAME.</p>\n'
                       + '<p>Note that you can use <b>lastSuccessfulBuild</b> for this field.</p>')
        string(name: 'BRANCH',
            defaultValue: 'develop',
            description: 'The name of the GIT branch to build from. This value is used for both product-assembly and zenoss-deploy.')
        booleanParam(name: 'CHANGELOG_REPORT',
            defaultValue: false,
            description: '<p>Generate <code>changelog</code> report.</p>')
    }

    stages {
        stage('Generate builds difference report') {
            steps {
                script {
                    sh """
                        python compare_builds.py \
                            -b1 ${params.BRANCH}/${params.BUILD1_NAME}/${params.BUILD1_JOB_NBR} \
                            -b2 ${params.BRANCH}/${params.BUILD2_NAME}/${params.BUILD2_JOB_NBR} > buildReport.log
                    """
                    archiveArtifacts artifacts: 'buildReport.log'
                }
            }
        }

        stage('Generate changelog report') {
            when {
                expression {
                    return params.CHANGELOG_REPORT 
                }
            }
            steps {
                script {
                    sh "mkdir -p ${WORKSPACE}/output"

                    sh """
                        python compare_builds.py \
                            -b1 ${params.BRANCH}/${params.BUILD1_NAME}/${params.BUILD1_JOB_NBR} \
                            -b2 ${params.BRANCH}/${params.BUILD2_NAME}/${params.BUILD2_JOB_NBR} \
                            --output-format json > output/zingChanges.json
                    """

                    withCredentials([
                        string(credentialsId: env.GLOBAL_GIT_TOKEN_ID, variable: 'GITHUB_TOKEN'),
                        usernamePassword(credentialsId: env.GLOBAL_JIRA_CREDS_ID, usernameVariable: 'JIRA_USER', passwordVariable: 'JIRA_PASSWD'),
                    ]) {
                        docker.withRegistry('https://gcr.io', "gcr:${env.GLOBAL_GCR_CREDS_ID}") {
                            docker.image(env.GLOBAL_CHANGELOG_IMAGE).inside("-v ${WORKSPACE}/output:/mnt/pwd -w /mnt/pwd") {
                                sh "ls -l"
                                sh "pwd"
                                sh """
                                    changelog \
                                        --manifest zingChanges.json \
                                        --github-token ${env.GITHUB_TOKEN} \
                                        --jira-user ${env.JIRA_USER} \
                                        --jira-passwd ${env.JIRA_PASSWD} \
                                        --format html \
                                        --output changelog.html \
                                        --json-report changelog.json
                                """
                            }
                        }

                        archiveArtifacts artifacts: 'output/*'

                        publishHTML([
                            allowMissing: true,
                            alwaysLinkToLastBuild: true,
                            keepAll: true,
                            reportDir: 'output',
                            reportFiles: 'changelog.html',
                            reportName: 'Change Log',
                            reportTitles: ''
                        ])
                    }
                }
            }
        }
    }
}

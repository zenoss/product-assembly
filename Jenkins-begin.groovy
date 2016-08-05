#!groovy
//
// Jenkins-begin.groovy - Jenkins script for initiating the Zenoss product build process.
//
// The Jenkins job parameters for this script are:
//
//    BRANCH            - the name of the GIT branch to build from. Note - do not use "BRANCH_NAME" becuase that term is reserved
//                        for use by the workflow-scm-step plugin
//    GIT_CREDENTIAL_ID - the UUID of the Jenkins GIT credentials used to checkout stuff from github
//    MATURITY          - the image maturity level (e.g. 'unstable', 'testing', 'stable')
//
node ('build-zenoss-product') {
    // To avoid naming confusion with downstream jobs that have their own BUILD_NUMBER variables,
    // define 'PRODUCT_BUILD_NUMBER' as the parameter name that will be used by all downstream
    // jobs to identify a particular execution of the build pipeline.
    PRODUCT_BUILD_NUMBER=env.BUILD_NUMBER
    currentBuild.displayName = "product build #${PRODUCT_BUILD_NUMBER}"

    stage 'Checkout product-assembly repo'
        // Checkout the tip of the target branch
        git branch: '${BRANCH}', credentialsId: '${GIT_CREDENTIAL_ID}', url: 'https://github.com/zenoss/product-assembly'

        // Record the current git commit sha in the variable 'GIT_SHA'
        sh("git rev-parse HEAD >git_sha.id")
        GIT_SHA=readFile('git_sha.id').trim()
        println("Building from git commit='${GIT_SHA}' on branch ${BRANCH} for MATURITY='${MATURITY}'")

    stage 'Build product-base'
        sh("cd product-base;MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make clean build")

    stage 'Push product-base'
        sh("cd product-base;MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make push")

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
}

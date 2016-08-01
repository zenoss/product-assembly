node ('build-ubuntu') {
    PRODUCT_BUILD_NUMBER=env.BUILD_NUMBER
    currentBuild.displayName = "product bld #${PRODUCT_BUILD_NUMBER}"

    stage 'Checkout product-assembly repo'
        // FIXME: parameterize the git credentialsID
        git branch: 'develop', credentialsId: '796808e0-a2b9-4b66-88d6-1ce283234ad1', url: 'https://github.com/zenoss/product-assembly'

        // Record the current git commit id in the variable 'git_sha'
        sh("git rev-parse HEAD >git_sha.id")
        git_sha=readFile('git_sha.id').trim()
        println("Building from git commit='${git_sha}' for MATURITY='${MATURITY}'")

    stage 'Build product-base'
        sh("cd $WORKSPACE/product-base;MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make clean build")

    stage 'Build all products'
        def branches = [
            'core': {
                println "Starting core-pipeline"
                build job: 'core-pipeline', parameters: [
                    [$class: 'ChoiceParameterValue', name: 'MATURITY', value: MATURITY],
                    [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: PRODUCT_BUILD_NUMBER],
                    [$class: 'StringParameterValue', name: 'GIT_SHA', value: GIT_SHA],
                ]
            },
            'resmgr': {
                println "Starting resmgr-pipeline"
                build job: 'resmgr-pipeline', parameters: [
                    [$class: 'ChoiceParameterValue', name: 'MATURITY', value: MATURITY],
                    [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: PRODUCT_BUILD_NUMBER],
                    [$class: 'StringParameterValue', name: 'GIT_SHA', value: GIT_SHA],
                ]
            },
        ]

        parallel branches
}

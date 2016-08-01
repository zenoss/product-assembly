node ('build-ubuntu') {
    PRODUCT_BUILD_NUMBER=env.BUILD_NUMBER

    currentBuild.displayName = "product bld #${PRODUCT_BUILD_NUMBER}"
    echo env.GIT_COMMIT

    stage 'Checkout product-assembly repo'
        // FIXME: parameterize the git credentialsID
        //sshagent(['796808e0-a2b9-4b66-88d6-1ce283234ad1']) {
        git branch: 'develop', credentialsId: '796808e0-a2b9-4b66-88d6-1ce283234ad1', url: 'https://github.com/zenoss/product-assembly'
        sh("git rev-parse HEAD >git_sha.id")
        git_sha=readFile('git_sha.id').trim()
        println("Building from git commit='${git_sha}'")
        //}

    stage 'Build product-base'
        sh("MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make clean build")

    stage 'Build All Products'
        def branches = [
            'core': {
                println "Starting core-pipeline with parameters #${MATURITY} #${PRODUCT_BUILD_NUMBER}"
                build job: 'core-pipeline', parameters: [
                    [$class: 'ChoiceParameterValue', name: 'MATURITY', value: MATURITY],
                    [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: PRODUCT_BUILD_NUMBER],
                ]
            },
            'resmgr': {
                println "Starting resmgr-pipeline with parameters #${MATURITY} #${PRODUCT_BUILD_NUMBER}"
                build job: 'resmgr-pipeline', parameters: [
                    [$class: 'ChoiceParameterValue', name: 'MATURITY', value: MATURITY],
                    [$class: 'StringParameterValue', name: 'PRODUCT_BUILD_NUMBER', value: PRODUCT_BUILD_NUMBER],
                ]
            },
        ]

        parallel branches
}

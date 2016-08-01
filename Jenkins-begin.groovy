node{
    PRODUCT_BUILD_NUMBER=env.BUILD_NUMBER
    currentBuild.displayName = "product bld #${PRODUCT_BUILD_NUMBER}"

    stage 'Checkout product-assembly repo'
        //git branch: 'develop', credentialsId: '6ece10bd-11c1-4e23-8f36-6848f6c4c704', url: 'https://github.com/zenoss/product-assembly'
        println("Got commit=#${GIT_COMMIT}")

        //sshagent(['6ece10bd-11c1-4e23-8f36-6848f6c4c704']) {
        //    GIT_SHA=sh("git rev-parse HEAD")
        //    println("Got sha=#${GIT_SHA}")
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

#!groovy
node ('build-ubuntu') {
    targetProduct = env.TARGET_PRODUCT
    currentBuild.displayName = "product build #${PRODUCT_BUILD_NUMBER}"

    stage 'Build image'
        git branch: 'develop', credentialsId: '${GIT_CREDENTIAL_ID}', url: 'https://github.com/zenoss/product-assembly'
        sh("git checkout ${GIT_SHA}")
        sh("cd ${targetProduct};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make clean build")

    stage 'Push image'
        sh("cd ${targetProduct};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make push")

    // compile svc defs
    // build svc def rpm
    // push svc-dev rpm
    stage 'Compile service definitions'
       echo 'Hello World 2'
}

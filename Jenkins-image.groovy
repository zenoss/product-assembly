#!groovy
//
// Jenkins-image.groovy - Jenkins script for building a single Zenoss product image.
//
// The Jenkins job parameters for this script are:
//
//    GIT_SHA              - the GIT SHA of product-assembly to checkout for this build
//    GIT_CREDENTIAL_ID    - the UUID of the Jenkins GIT credentials used to checkout stuff from github
//    MATURITY             - the image maturity level (e.g. 'unstable', 'testing', 'stable')
//    PRODUCT_BUIlD_NUMBER - the build number for any given execution of this build pipeline; set by the begin job.
//    TARGET_PRODUCT       - identifies the target product (e.g. 'core', 'resmgr', 'ucspm', etc)
//
node ('build-zenoss-product') {
    pipelineBuildNumber = env.BUILD_NUMBER
    currentBuild.displayName = "product build #${PRODUCT_BUILD_NUMBER}"

    stage 'Build image'
        // NOTE: The 'master' branch name here is only used to clone the github repo.
        //       The next checkout command will align the build with the correct target revision.
        git branch: 'master', credentialsId: '${GIT_CREDENTIAL_ID}', url: 'https://github.com/zenoss/product-assembly'
        sh("git checkout ${GIT_SHA}")
        sh("cd ${TARGET_PRODUCT};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make clean build")

    stage 'Push image'
        sh("cd ${TARGET_PRODUCT};MATURITY=${MATURITY} BUILD_NUMBER=${PRODUCT_BUILD_NUMBER} make push")

    //
    // FIXME:
    // 1. Parameterize HBASE, HDFS, OPENTSDB image versions
    // 2. Parameterize SVCDEF_GIT_SHA
    // 3. Remove duplication of SHORT_VERSION and VERSION here vs things like IMAGENAME and VERSION in
    //    core/makefile, resmgr/makefile, etc
    //
    stage 'Compile service definitions and build RPM'
        sh("mkdir -p svcdefs/build/zenoss-service")
        dir('svcdefs/build/zenoss-service') {
            def SVCDEF_GIT_SHA = 'develop'
            echo "Cloning zenoss-service - ${SVCDEF_GIT_SHA} with credentialsId=${GIT_CREDENTIAL_ID}"
            git branch: 'master', credentialsId: '${GIT_CREDENTIAL_ID}', url: 'https://github.com/zenoss/zenoss-service.git'
            sh("git checkout ${SVCDEF_GIT_SHA}")
        }
        
        def makeArgs = "BUILD_NUMBER=${pipelineBuildNumber}\
            HBASE_VERSION=24.0.0\
            HDFS_VERSION=24.0.0\
            IMAGE_NUMBER=${PRODUCT_BUILD_NUMBER}\
            MATURITY=${MATURITY}\
            OPENTSDB_VERSION=24.0.0\
            SHORT_VERSION=5.2\
            SVCDEF_GIT_SHA=develop\
            TARGET_PRODUCT=${TARGET_PRODUCT}\
            VERSION=5.2.0"
       sh("cd svcdefs;make build ${makeArgs}")
       archiveArtifacts artifacts: 'svcdefs/build/zenoss-service/output/*', fingerprint: true

    stage 'Push RPM'
        echo "TODO - implement rpm repo push"

}

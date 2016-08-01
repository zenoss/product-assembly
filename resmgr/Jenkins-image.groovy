#!groovy
node ('build-ubuntu') {
  withEnv(['TARGET_PRODUCT=\'resmgr\'']) {
    load '../Jenkins-common.groovy'
  }
}

#!groovy
node ('build-ubuntu') {
  withEnv(['TARGET_PRODUCT=\'resmgr\'']) {
    load '../Jenkins-image-common.groovy'
  }
}

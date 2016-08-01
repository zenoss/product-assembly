#!groovy
node ('build-ubuntu') {
  withEnv(['TARGET_PRODUCT=\'core\'']) {
    load '../Jenkins-image-common.groovy'
  }
}

#!groovy
node ('build-ubuntu') {
  withEnv(['TARGET_PRODUCT=\'core\'']) {
    load '../workspace@script/Jenkins-image-common.groovy'
  }
}

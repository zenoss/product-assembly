#!/bin/bash
#
# build-devbase.sh - build the image that will serve as the basis for zendev/devimg.
#
# Required Arguments (specified as environment variables):
# BASE_TAG - the full docker tag of image to build
#
# Any other environment variables will be inherited by the make which is invoked
# by this script. For instance, if you want to build devimg with a custom version
# zenoss-centos-base, you could run something like:
#
# FROM_IMAGE=zenoss-centos-base:1.3.9-dev BASE_TAG=zendev/devimg:metis ./build-devbase.sh
#
# And the value of FROM_IMAGE will be inherited by the make execution
#
if [ -z "${BASE_TAG}" ]
then
	echo "ERROR: Missing required argument - BASE_TAG"
	exit 1
fi

#
# if the target image exists, don't rebuild it.
#
# Normally, native makefile syntax is used for these kinds of checks, but
# in the case of docker images, it's more straightfoward to implement here.
#
IMAGE_EXISTS=`docker images | awk '{print $1":"$2}' | grep ${BASE_TAG} 2>/dev/null`
if [ ! -z "${IMAGE_EXISTS}" ]
then
	echo "Skipping build-devimg because ${BASE_TAG} exists already"
	exit 0
fi

# Get the uid/gid of the current user so that we can change the zenoss user in the
# the container to match the UID/GID of the current user.
CURRENT_UID=`id -u`
CURRENT_GID=`id -g`

set -e
set -x

cd ../product-base
TAG=${BASE_TAG} INSTALL_OPTIONS="--change-uid ${CURRENT_UID}:${CURRENT_GID}" make build-devimg

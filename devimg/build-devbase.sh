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
# BASE_TAG=zendev/devimg:metis ./build-devbase.sh
#
if [ -z "${PRODUCT_BASE_IMAGE_ID}" ]; then
	echo "ERROR: Missing required argument - PRODUCT_BASE_IMAGE_ID"
	exit 1
fi

#
# if the target image exists, don't rebuild it.
#
# Normally, native makefile syntax is used for these kinds of checks, but
# in the case of docker images, it's more straightfoward to implement here.
#
IMAGE_EXISTS=$(docker image ls -q ${PRODUCT_BASE_IMAGE_ID} 2>/dev/null)
if [ ! -z "${IMAGE_EXISTS}" ]; then
	echo "Image ${PRODUCT_BASE_IMAGE_ID} exists already, moving on."
	exit 0
fi

# Get the uid/gid of the current user so that we can change the zenoss user in the
# the container to match the UID/GID of the current user.
CURRENT_UID=$(id -u)
CURRENT_GID=$(id -g)

INSTALL_OPTIONS="--change-uid ${CURRENT_UID}:${CURRENT_GID}"
export INSTALL_OPTIONS

make -C ../product-base build-devimg

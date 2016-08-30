#!/bin/bash
#
# build.sh - build zendev/devimg.
#
# This script assumes that zendev/devimg-base already exists; see build-devbase.sh.
# This script runs create_devimg.sh in zendev/devimg-base with several key
# directories in the image bind-mounted to source directories in the developer's
# local sandbox.  The create_devimg.sh script creates zenoss, optionally link
# installs zenpacks and setups some other component links. After
# create_devimg.sh completes, this script commits the resultant container as a
# new zendev/devimg image.
#
# Required Arguments (specified as environment variables):
# BASE_TAG    - the tag of image to start from (e.g. zendev/devimg-base:<envName>)
# TAG         - the full docker tag of image to build (e.g. zendev/devimg:<envName>)
# ZENDEV_ROOT - see the description in makefile
# SRCROOT     - see the description in makefile
# PRODBIN_SRC - see the description in makefile
# ZENPACK_SRC - see the description in makefile

if [ -z "${BASE_TAG}" ]
then
	echo "ERROR: Missing required argument - BASE_TAG"
	exit 1
elif [ -z "${TAG}" ]
then
	echo "ERROR: Missing required argument - TAG"
	exit 1
elif [ -z "${ZENDEV_ROOT}" ]
then
	echo "ERROR: Missing required argument - ZENDEV_ROOT"
	exit 1
elif [ -z "${SRCROOT}" ]
then
	echo "ERROR: Missing required argument - SRCROOT"
elif [ -z "${PRODBIN_SRC}" ]
then
	echo "ERROR: Missing required argument - PRODBIN_SRC"
	exit 1
elif [ -z "${ZENPACK_SRC}" ]
then
	echo "ERROR: Missing required argument - ZENPACK_SRC"
	exit 1
fi

# Always try to remove the docker container, even on a failed exit.
cleanup() {
	if [ ! -z "${CONTAINER_ID}" ]
	then
		docker ps -qa --no-trunc | grep ${CONTAINER_ID} | xargs --no-run-if-empty docker rm -f
	fi
	rm -f ${CONTAINER_ID_FILE}
}
trap cleanup EXIT

echo "Initializing Zenoss and installing Zenpacks ..."
echo "   ZENHOME=${ZENDEV_ROOT}/zenhome"
echo "   VAR_ZENOSS=${ZENDEV_ROOT}/var_zenoss"
echo "   SRCROOT=${SRCROOT}"
echo "   PRODBIN_SRC=${PRODBIN_SRC}"
echo "   ZENPACK_SRC=${ZENPACK_SRC}"

CONTAINER_ID_FILE=containerID.txt
rm -f ${CONTAINER_ID_FILE}

set -e
set -x

# Run create_zenoss, record the container id and CONTAINER_ID_FILE and leave
# the image running so that we can commit the changes
#
docker run \
	--cidfile ${CONTAINER_ID_FILE} \
	-v ${ZENDEV_ROOT}/zenhome:/opt/zenoss \
	-v ${ZENDEV_ROOT}/var_zenoss:/var/zenoss \
	-v ${SRCROOT}:/mnt/src \
	-t ${BASE_TAG} \
	/opt/zenoss/install_scripts/create_devimg.sh

echo "Committing all of the changes to ${TAG}"
CONTAINER_ID=`cat ${CONTAINER_ID_FILE}`
docker commit ${CONTAINER_ID} ${TAG}

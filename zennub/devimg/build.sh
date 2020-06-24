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
# ZENHOME - see the description in makefile
# SRCROOT     - see the description in makefile

if [ -z "${BASE_TAG}" ]
then
	echo "ERROR: Missing required argument - BASE_TAG"
	exit 1
elif [ -z "${TAG}" ]
then
	echo "ERROR: Missing required argument - TAG"
	exit 1
elif [ -z "${ZENHOME}" ]
then
	echo "ERROR: Missing required argument - ZENHOME"
	exit 1
elif [ -z "${SRCROOT}" ]
then
	echo "ERROR: Missing required argument - SRCROOT"
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
echo "   ZENHOME=${ZENHOME}/zenhome"
echo "   VAR_ZENOSS=${ZENHOME}/var_zenoss"
echo "   SRCROOT=${SRCROOT}"

CONTAINER_ID_FILE=containerID.txt
rm -f ${CONTAINER_ID_FILE}

set -e
set -x

# Run create_zenoss, record the container id and CONTAINER_ID_FILE and leave
# the image running so that we can commit the changes
#
PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
DEVIMG_WD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && cd ../../devimg && pwd )"

if ! [ -d ${SRCROOT}/github.com/zenoss/zenoss-prodbin ]; then
	echo "SRCROOT seems to be incorrect (should be set to the directory that contains github.com subdirectory)"
	exit 1
fi

docker run \
	--cidfile ${CONTAINER_ID_FILE} \
	-v ${ZENHOME}/zenhome:/opt/zenoss \
	-v ${ZENHOME}/var_zenoss:/var/zenoss \
	-v ${SRCROOT}/github.com/zenoss:/mnt/src \
	-v ${PWD}:/mnt/zennub \
	-v ${DEVIMG_WD}:/mnt/devimg \
        -v ${HOME}/.m2:/home/zenoss/.m2 \
        -t ${BASE_TAG} \
	/mnt/zennub/create_devimg.sh

echo "Committing all of the changes to ${TAG}"
CONTAINER_ID=`cat ${CONTAINER_ID_FILE}`
docker commit ${CONTAINER_ID} ${TAG}

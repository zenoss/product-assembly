#!/bin/bash
#
# dump_db.sh - build zendev/devimg.
#
# This script assumes that zendev/devimg already exists; see build.sh.
# This script runs dump_zodb.sh in zendev/devimg with several key
# directories in the image bind-mounted to source directories in the developer's
# local sandbox.  The dump_zodb.sh script creates a clean base zodb from the XML files or gz file
# on the developer's local sandbox (zenoss-prodbin/Products/ZenModel/data).  It then migrates
# the database to the latest version based on the migrate scripts found in ZenModel/migrate.
# Finally, it dumps an updated set of xml files and an updated .gz file back out to 
# zenoss-prodbin/Products/ZenModel/data
#
# Required Arguments (specified as environment variables):
# TAG         - the full docker tag of the devimage to use (e.g. zendev/devimg:<envName>)
# ZENDEV_ROOT - see the description in makefile
# SRCROOT     - see the description in makefile
#
# Optional Argument
# ZENWIPE_ARGS - set to '--xml' to load DB from XML files, or leave empty to use .gz file

if [ -z "${TAG}" ]
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

echo "Preparing to clean, migrate and dump zodb ..."
echo "   ZENHOME=${ZENDEV_ROOT}/zenhome"
echo "   VAR_ZENOSS=${ZENDEV_ROOT}/var_zenoss"
echo "   SRCROOT=${SRCROOT}"
echo "   ZENWIPE_ARGS=${ZENWIPE_ARGS}"

CONTAINER_ID_FILE=containerID.txt
rm -f ${CONTAINER_ID_FILE}

set -e
set -x

# Run dump_zodb.sh, record the container id and CONTAINER_ID_FILE so we can
# be sure the container gets cleaned up on exit
#
PWD="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
echo "docker run \
	--rm \
	--cidfile ${CONTAINER_ID_FILE} \
	-v ${ZENDEV_ROOT}/zenhome:/opt/zenoss \
	-v ${ZENDEV_ROOT}/var_zenoss:/var/zenoss \
	-v ${SRCROOT}:/mnt/src \
	-v ${PWD}:/mnt/devimg \
        -v ${HOME}/.m2:/home/zenoss/.m2 \
        -t ${TAG} \
	/mnt/devimg/dump_zodb.sh ${ZENWIPE_ARGS}
"
docker run \
	--rm \
	--cidfile ${CONTAINER_ID_FILE} \
	-v ${ZENDEV_ROOT}/zenhome:/opt/zenoss \
	-v ${ZENDEV_ROOT}/var_zenoss:/var/zenoss \
	-v ${SRCROOT}:/mnt/src \
	-v ${PWD}:/mnt/devimg \
        -v ${HOME}/.m2:/home/zenoss/.m2 \
        -t ${TAG} \
	/mnt/devimg/dump_zodb.sh ${ZENWIPE_ARGS}


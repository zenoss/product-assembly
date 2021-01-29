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
# PRODUCT_BASE_IMAGE_ID - the tag of image to start from (e.g. zendev/devimg-base:<envName>)
# PRODUCT_IMAGE_ID      - the full docker tag of image to build (e.g. zendev/devimg:<envName>)
# ZENDEV_ROOT           - see the description in makefile
# SRCROOT               - see the description in makefile

env_vars_are_missing=0

if [ -z "${PRODUCT_BASE_IMAGE_ID}" ]; then
	echo "ERROR: Missing required argument - PRODUCT_BASE_IMAGE_ID"
	env_vars_are_missing=1
fi
if [ -z "${PRODUCT_IMAGE_ID}" ]; then
	echo "ERROR: Missing required argument - PRODUCT_IMAGE_ID"
	env_vars_are_missing=1
fi
if [ -z "${MARIADB_BASE_IMAGE_ID}" ]; then
	echo "ERROR: Missing required argument - MARIADB_BASE_IMAGE_ID"
	env_vars_are_missing=1
fi
if [ -z "${MARIADB_IMAGE_ID}" ]; then
	echo "ERROR: Missing required argument - MARIADB_IMAGE_ID"
	env_vars_are_missing=1
fi
if [ -z "${ZENDEV_ROOT}" ]; then
	echo "ERROR: Missing required argument - ZENDEV_ROOT"
	env_vars_are_missing=1
fi
if [ -z "${SRCROOT}" ]; then
	echo "ERROR: Missing required argument - SRCROOT"
	env_vars_are_missing=1
fi
if [ ${env_vars_are_missing} -eq 1 ]; then
	exit 1
fi

# Create the names to use for the various containers
name_suffix=$(dd bs=16 count=1 status=none if=/dev/urandom | base64 | tr -cd "[:alnum:]" | cut -c1-16)
network_name=network-${name_suffix}
product_name=product-${name_suffix}
mariadb_name=mariadb-${name_suffix}

PWD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

fail() {
	echo "ERROR: ${*}" >&2
	exit 1;
}

# Always remove the docker containers, even on a failed exit.
cleanup() {
	docker container stop -t 2 ${product_name} ${mariadb_name} >/dev/null 2>&1
	docker container wait ${product_name} ${mariadb_name} >/dev/null 2>&1
	test $? -eq 0 && echo Containers ${product_name} ${mariadb_name} stopped

	docker rm -f ${product_name} ${mariadb_name} >/dev/null 2>&1
	test $? -eq 0 && echo Removed containers ${product_name} ${mariadb_name}

	docker network rm ${network_name} >/dev/null 2>&1
	test $? -eq 0 && echo Removed network ${network_name}
}
trap cleanup EXIT

echo
echo "Initializing Zenoss and installing Zenpacks ..."
echo "   ZENHOME=${ZENDEV_ROOT}/zenhome"
echo "   VAR_ZENOSS=${ZENDEV_ROOT}/var_zenoss"
echo "   SRCROOT=${SRCROOT}"
echo

docker network create ${network_name} || fail "Could not create docker network"

docker container create \
	-it \
	--name ${mariadb_name} \
	--network ${network_name} \
	${MARIADB_BASE_IMAGE_ID} \
	/usr/bin/mysqld_safe --skip-syslog --log-error=/var/log/mysql/load.log --bind-address=0.0.0.0 \
	|| fail "Could not create ${MARIADB_BASE_IMAGE_ID} container"

docker container start ${mariadb_name} || fail "Could not start ${MARIADB_BASE_IMAGE_ID} container"

DEVIMG_MOUNT=/mnt/devimg

docker container create \
	-it \
	--name ${product_name} \
	--network ${network_name} \
	-v ${ZENDEV_ROOT}/zenhome:/opt/zenoss \
	-v ${ZENDEV_ROOT}/var_zenoss:/var/zenoss \
	-v ${SRCROOT}:/mnt/src \
	-v ${PWD}:${DEVIMG_MOUNT} \
	-v ${HOME}/.m2:/home/zenoss/.m2 \
	${PRODUCT_BASE_IMAGE_ID} \
	/bin/bash \
	|| fail "Could not create ${PRODUCT_BASE_IMAGE_ID} container"

docker container start ${product_name} || fail "Could not start ${PRODUCT_BASE_IMAGE_ID} container"

docker container exec \
	-e "DBHOST=${mariadb_name}" \
	${product_name} \
	${DEVIMG_MOUNT}/create_devimg.sh \
	|| fail "Could not execute create_devimg.sh script"

docker container exec \
	-e "MOUNTPATH=${DEVIMG_MOUNT}" \
	${product_name} \
	${DEVIMG_MOUNT}/install-activepython.sh \
	|| fail "Could not execute install-activepython.sh script"

echo "Stopping the ${PRODUCT_BASE_IMAGE_ID} container."
docker container stop ${product_name}
echo "Stopping the ${MARIADB_BASE_IMAGE_ID} container."
docker container exec ${mariadb_name} mysqladmin shutdown
docker container wait ${product_name} ${mariadb_name}
echo "The ${PRODUCT_BASE_IMAGE_ID} and ${MARIADB_BASE_IMAGE_ID} containers have stopped."

echo "Committing changes and creating the ${MARIADB_IMAGE_ID} image."
docker container commit -m "ZODB loaded" ${mariadb_name} ${MARIADB_IMAGE_ID}
echo "done"
echo "Committing changes and creating the ${PRODUCT_IMAGE_ID} image."
docker container commit -m "devimg created" ${product_name} ${PRODUCT_IMAGE_ID}
echo "done"

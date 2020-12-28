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

env_vars_are_missing=0

if [ -z "${PRODUCT_IMAGE_ID}" ]; then
	echo "ERROR: Missing required environment variable - PRODUCT_IMAGE_ID" >&2
	env_vars_are_missing=1
fi
if [ -z "${MARIADB_IMAGE_ID}" ]; then
	echo "ERROR: Missing required environment variable - MARIADB_IMAGE_ID" >&2
	env_vars_are_missing=1
fi
if [ -z "${ZENDEV_ROOT}" ]; then
	echo "ERROR: Missing required environment variable - ZENDEV_ROOT" >&2
	env_vars_are_missing=1
fi
if [ -z "${SRCROOT}" ]; then
	echo "ERROR: Missing required environment variable - SRCROOT" >&2
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

# Always try to remove the docker container, even on a failed exit.
cleanup() {
	set +x
	set +e
	docker container stop -t 2 ${product_name} >/dev/null 2>&1
	docker container exec ${mariadb_name} mysqladmin shutdown >/dev/null 2>&1
	docker container wait ${product_name} ${mariadb_name} >/dev/null 2>&1
	test $? -eq 0 && echo Containers ${product_name} ${mariadb_name} stopped

	docker rm -f ${product_name} ${mariadb_name} >/dev/null 2>&1
	test $? -eq 0 && echo Removed containers ${product_name} ${mariadb_name}

	docker network rm ${network_name} >/dev/null 2>&1
	test $? -eq 0 && echo Removed network ${network_name}
}
trap cleanup EXIT

fail() {
	echo "ERROR: ${*}" >&2
	exit 1;
}

echo "Preparing to clean, migrate and dump zodb ..."
echo "   PRODUCT_IMAGE_ID=${PRODUCT_IMAGE_ID}"
echo "   MARIADB_IMAGE_ID=${MARIADB_IMAGE_ID}"
echo "   ZENHOME=${ZENDEV_ROOT}/zenhome"
echo "   VAR_ZENOSS=${ZENDEV_ROOT}/var_zenoss"
echo "   SRCROOT=${SRCROOT}"
echo "   ZENWIPE_ARGS=${ZENWIPE_ARGS}"

set -e

docker network create ${network_name} || fail "Could not create docker network"

docker container create \
	-it \
	--name ${mariadb_name} \
	--network ${network_name} \
	${MARIADB_IMAGE_ID} \
	/usr/bin/mysqld_safe --skip-syslog --log-error=/var/log/mysql/load.log --bind-address=0.0.0.0 \
	|| fail "Could not create ${MARIADB_IMAGE_ID} container"

docker container start ${mariadb_name} || fail "Could not start ${MARIADB_IMAGE_ID} container"

docker container create \
	-it \
	--name ${product_name} \
	--network ${network_name} \
	-v ${ZENDEV_ROOT}/zenhome:/opt/zenoss \
	-v ${SRCROOT}:/mnt/src \
	-v ${PWD}:/mnt/devimg \
	-v ${HOME}/.m2:/home/zenoss/.m2 \
	${PRODUCT_IMAGE_ID} \
	/bin/bash \
	|| fail "Could not create ${PRODUCT_IMAGE_ID} container"

docker container start ${product_name} || fail "Could not start ${PRODUCT_IMAGE_ID} container"

docker container exec \
	-t \
	-e "DBHOST=${mariadb_name}" \
	-e "SRCROOT=/mnt/src" \
	${product_name} \
	/mnt/devimg/dump_zodb.sh ${ZENWIPE_ARGS} \
	|| fail "Could not execute dump_zodb.sh script"

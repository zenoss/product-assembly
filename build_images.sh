#!/bin/bash

# Expected variables
#
# PRODUCT_BASE_IMAGE_ID - product-base image
# MARIADB_BASE_IMAGE_ID - mariadb-base image
# PRODUCT_IMAGE_ID - final product image
# MARIADB_IMAGE_ID - final mariadb image

missing_env_vars=0

if [ -z "${PRODUCT_BASE_IMAGE_ID}" ]; then
	echo PRODUCT_BASE_IMAGE_ID is not defined >&2
	missing_env_vars=1
fi
if [ -z "${PRODUCT_IMAGE_ID}" ]; then
	echo PRODUCT_IMAGE_ID is not defined >&2
	missing_env_vars=1
fi
if [ -z "${MARIADB_BASE_IMAGE_ID}" ]; then
	echo MARIADB_BASE_IMAGE_ID is not defined >&2
	missing_env_vars=1
fi
if [ -z "${MARIADB_IMAGE_ID}" ]; then
	echo MARIADB_IMAGE_ID is not defined >&2
	missing_env_vars=1
fi
if [ ${missing_env_vars} -eq 1 ]; then
	exit 1
fi

name_suffix=$(dd bs=16 count=1 status=none if=/dev/urandom | base64 | tr -cd "[:alnum:]" | cut -c1-16)
network_name=network-${name_suffix}
product_name=product-${name_suffix}
mariadb_name=mariadb-${name_suffix}

fail() {
	echo "ERROR: ${*}" >&2
	exit 1;
}

stop_containers() {
	echo "Stopping the containers"
	docker container stop -t 2 ${product_name} >/dev/null 2>&1
	docker container exec ${mariadb_name} mysqladmin shutdown >/dev/null 2>&1
	docker container wait ${product_name} ${mariadb_name} >/dev/null 2>&1
	test $? -eq 0 && echo Containers ${product_name} ${mariadb_name} stopped
}

# Upon exit, remove containers and networks
cleanup() {
	stop_containers

	docker container rm -f ${product_name} ${mariadb_name} >/dev/null 2>&1
	test $? -eq 0 && echo Removed containers ${product_name} ${mariadb_name}

	docker network rm ${network_name} >/dev/null 2>&1
	test $? -eq 0 && echo Removed network ${network_name}
}
trap cleanup EXIT

# Create the mariadb-net network
echo
echo "Creating docker network for building the mariadb and product images"
docker network create ${network_name} || fail "Could not create docker network"

# Create and start the mariadb-build container
echo
echo "Creating mariadb container for building the mariadb image"
docker container create \
	-it \
	--name ${mariadb_name} \
	--network ${network_name} \
	${MARIADB_BASE_IMAGE_ID} \
	/usr/bin/mysqld_safe --skip-syslog --log-error=/var/log/mysql/load.log --bind-address=0.0.0.0 \
	|| fail "Could not create mariadb container"

echo
echo "Starting mariadb image build container"
docker container start ${mariadb_name} || fail "Could not start mariadb container"

# Create the product-build container
echo
echo "Creating product container for building the product image"
docker container create \
	-it \
	--name ${product_name} \
	--network ${network_name} \
	-v $(pwd):/src \
	${PRODUCT_BASE_IMAGE_ID} \
	/bin/bash \
	|| fail "Count not create product container"

echo
echo "Starting the product image build container"
docker container start ${product_name} || fail "Could not start product container"

echo
echo "Copying license files, manifests, and zenpacks to build container"
docker container exec \
	${product_name} \
	/bin/bash -l -c "/src/copy_files.sh" \
	|| fail "Could not execute copy_files.sh script"

echo
echo "Creating Zenoss"
docker container exec \
	-w /opt/zenoss/install_scripts \
	-e "DBHOST=${mariadb_name}" \
	${product_name} \
	/bin/bash -l -c "./create_zenoss.sh" \
	|| fail "Could not execute create_zenoss.sh script"

echo
echo "Copying upgrade scripts to build container"
docker container exec \
	${product_name} \
	/bin/bash -l -c "/src/copy_upgrade_scripts.sh" \
	|| fail "Could not execute copy_files.sh script"

# =============================================================================================

echo
stop_containers

echo
echo "Committing changes to MariaDB image"
docker container commit -m "ZODB loaded" ${mariadb_name} ${MARIADB_IMAGE_ID}

echo
echo "Committing changes to product image"
docker container commit -m "Zenoss created" ${product_name} ${PRODUCT_IMAGE_ID}

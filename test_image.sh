#!/bin/bash

TEST_PARAMS=""
MOUNTS=""
ENV_VARS=""

while (( "$#" )); do
	case "$1" in
		--no-zenpacks)
			TEST_PARAMS="$TEST_PARAMS $1"
			shift
			;;
		--mount)
			MOUNTS="${MOUNTS} -v $2"
			shift 2
			;;
		--env)
			ENV_VARS="${ENV_VARS} -e $2"
			shift 2
			;;
		-*) # unsupported options
			echo "Error: unknown option $1" >&2
			exit 1
	esac
done

# Expected variables
#
# PRODUCT_IMAGE_ID - final product image
# MARIADB_IMAGE_ID - final mariadb image

missing_env_vars=0

if [ -z "${PRODUCT_IMAGE_ID}" ]; then
	echo PRODUCT_IMAGE_ID is not defined >&2
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

# Upon exit, remove containers and networks
cleanup() {
	docker container stop -t 2 ${product_name} >/dev/null 2>&1
	docker container exec ${mariadb_name} mysqladmin shutdown >/dev/null 2>&1
	docker container wait ${product_name} ${mariadb_name} >/dev/null 2>&1
	test $? -eq 0 && echo Containers ${product_name} ${mariadb_name} stopped

	docker container rm -f ${product_name} ${mariadb_name} >/dev/null 2>&1
	test $? -eq 0 && echo Removed containers ${product_name} ${mariadb_name}

	docker network rm ${network_name} >/dev/null 2>&1
	test $? -eq 0 && echo Removed network ${network_name}
}
trap cleanup EXIT

# Create the mariadb-net network
echo
echo "Creating docker network for testing the product image"
docker network create ${network_name} || fail "Could not create docker network"

# Create and start the mariadb-build container
echo
echo "Creating mariadb container to run tests"
docker container create \
	-it \
	--name ${mariadb_name} \
	--network ${network_name} \
	${MARIADB_IMAGE_ID} \
	/usr/bin/mysqld_safe --skip-syslog --log-error=/var/log/mysql/load.log --bind-address=0.0.0.0 \
	|| fail "Could not create mariadb container"

echo
echo "Starting mariadb container for testing"
docker container start ${mariadb_name} || fail "Could not start mariadb container"

# Create the product-build container
echo
echo "Creating product container for testing the product image"
docker container create \
	-it \
	--name ${product_name} \
	--network ${network_name} \
	${MOUNTS} \
	${PRODUCT_IMAGE_ID} \
	/bin/bash \
	|| fail "Count not create product container"

echo
echo "Starting the product container for testing"
docker container start ${product_name} || fail "Could not start product container"

echo
echo "Testing Zenoss"
ENV_VARS="-e DBHOST=${mariadb_name} ${ENV_VARS}"
docker container exec \
	-w /opt/zenoss/install_scripts \
	${ENV_VARS} \
	${product_name} \
	/bin/bash -l -c "./starttests.sh ${TEST_PARAMS}" \
	|| fail "Could not execute starttests.sh script"

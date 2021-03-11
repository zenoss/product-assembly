#!/bin/bash

if [ -z "${MARIADB_BASE_IMAGE_ID}" ] ; then
	echo Environment variable MARIADB_BASE_IMAGE_ID is not set.
	exit 1
fi

uuid=$(dd bs=16 count=1 status=none if=/dev/urandom | base64 | tr -cd "[:alnum:]" | cut -c1-16)
container=mariadb_container_${uuid}
unsquashed=mariadb:${uuid}

cleanup() {
	echo Removing container ${container}
	docker container rm -f ${container} >/dev/null 2>&1
	docker image rm -f ${unsquashed} >/dev/null 2>&1
}
trap cleanup EXIT

echo Building image ${MARIADB_BASE_IMAGE_ID} ...
docker build --pull -t ${unsquashed} .

path=$(docker run -t --rm ${unsquashed} /bin/bash --login -c "printf \${PATH}")
instruction="ENV TERM=xterm ZENHOME=/opt/zenoss PATH=\"${path}\""

echo Squashing image ${MARIADB_BASE_IMAGE_ID} ...
docker run --name ${container} -d ${unsquashed} echo
docker export ${container} | docker import -m "Base mariadb image for Zenoss applications" -c "${instruction}" - ${MARIADB_BASE_IMAGE_ID}

echo Created image ${MARIADB_BASE_IMAGE_ID}

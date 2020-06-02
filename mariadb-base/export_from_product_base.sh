#!/bin/bash

if [ $# -ne 3 ]; then
	echo "usage: $0 product-image-name source-files-file output-directory"
	exit 1
fi
PRODUCT_BASE_IMAGE="$1"
SOURCE_FILES="$2"
OUTPUT_DIR="$3"

suffix=$(base64 /dev/urandom | tr -cd "[:alnum:]" | dd bs=16 count=1 status=none)
container=product_base_export_${suffix}

cmd="docker container"

migrate_scripts_to_pymysql() {
	local scripts=$(find ${OUTPUT_DIR} -type f -exec grep -l MySQLdb {} \+)
	echo "Updating scripts to use pymysql: "${scripts}
	for script in ${scripts}; do
		sed -i -e "s/MySQLdb/pymysql/g" ${script}
	done
}

cleanup() {
	echo
	echo "Stopping and removing the ${PRODUCT_BASE_IMAGE} container"
	${cmd} stop ${container}
	${cmd} rm -f ${container}
}

trap cleanup EXIT

echo
echo "Creating ${PRODUCT_BASE_IMAGE} container to export necessary files"
${cmd} create -it --name ${container} ${PRODUCT_BASE_IMAGE} /bin/bash

echo
echo "Starting ${PRODUCT_BASE_IMAGE} container"
${cmd} start ${container}

echo
echo "Export the files"
mkdir -p exported_files
${cmd} cp "${SOURCE_FILES}" ${container}:/home/zenoss/files_to_copy.txt
${cmd} exec ${container} tar cv -T /home/zenoss/files_to_copy.txt | tar xv -C "${OUTPUT_DIR}"
echo
migrate_scripts_to_pymysql

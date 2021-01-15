#!/bin/bash

source ../build_lib.sh

check_image_variables
create_build_containers
start_build_containers
copy_files
create_zenoss

echo
echo "Installing ActiveState Python"
docker container exec \
	-w /src \
	${product_name} \
	/bin/bash -l -c "./install-activepython.sh" \
	|| fail "Could not execute install-activepython.sh script"

copy_upgrade_scripts
stop_containers
commit_images

#!/bin/bash

source ../build_lib.sh

check_image_variables
create_build_containers
start_build_containers
copy_files
create_zenoss
copy_upgrade_scripts
stop_containers
commit_images

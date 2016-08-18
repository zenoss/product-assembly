#!/bin/sh

# load the installation functions
. ${ZENHOME}/install_scripts/install_lib.sh

set -e
set -x 


start_requirements

echo "Starting zeneventserver..."
su - zenoss  -c "${ZENHOME}/bin/zeneventserver start"

su - zenoss  -c "${ZENHOME}/bin/runtests"



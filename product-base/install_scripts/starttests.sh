#!/bin/sh

# load the installation functions
. ${ZENHOME}/install_scripts/install_lib.sh

set -e
set -x 


start_requirements

if [ -f "${ZENHOME}/bin/zencatalogservice" ]; then
    echo "Starting zencatalogservice..."
    su - zenoss  -c "${ZENHOME}/bin/zencatalogservice start"

fi

echo "Starting zeneventserver..."
su - zenoss  -c "${ZENHOME}/bin/zeneventserver start"

su - zenoss  -c "${ZENHOME}/bin/runtests"



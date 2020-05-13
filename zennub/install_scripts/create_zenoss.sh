#!/bin/sh

set -e
set -x

echo "Running zenoss_init"
${ZENHOME}/install_scripts/zenoss_init.sh

echo "Cleaning up after install..."
find ${ZENHOME} -name \*.py[co] -delete
rm -f ${ZENHOME}/log/\*.log
# rm -rf /opt/solr/logs/*
/sbin/scrub.sh

echo "Component Artifact Report"
cat ${ZENHOME}/log/zenoss_component_artifact.log

echo "ZenPack Artifact Report"
cat ${ZENHOME}/log/zenpacks_artifact.log


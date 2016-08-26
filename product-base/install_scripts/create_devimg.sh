#!/bin/bash

if [ -z "${SRCROOT}" ]
then
    SRCROOT=/mnt/src
fi

if [ ! -d "${SRCROOT}" ]
then
    echo "ERROR: SRCROOT=${SRCROOT} does not exist"
    exit 1
fi

set -e
set -x

echo "Starting create_devimg ..."
export BUILD_DEVIMG=1
/opt/zenoss/install_scripts/create_zenoss.sh
echo "Finished create_zenoss.sh"

echo "Link in Java apps"
rm -rf ${ZENHOME}/lib/central-query
ln -s ${SRCROOT}/query ${ZENHOME}/lib/central-query
chown zenoss:zenoss ${ZENHOME}/lib/central-query

rm -rf ${ZENHOME}/lib/metric-consumer-app
ln -s ${SRCROOT}/zenoss.metric.consumer/metric-consumer-app ${ZENHOME}/lib/metric-consumer-app
chown zenoss:zenoss ${ZENHOME}/lib/metric-consumer-app

echo "Install zenoss-protocols in development mode"
su - zenoss -c "pip uninstall -y zenoss.protocols"
su - zenoss -c "pip install -e ${SRCROOT}/zenoss-protocols/python"

echo "Install zenwipe"
cp /opt/zenoss/devimg/zenwipe.sh /opt/zenoss/bin/zenwipe.sh
chown zenoss:zenoss /opt/zenoss/bin/zenwipe.sh
chmod 754 /opt/zenoss/bin/zenwipe.sh

# TODO
# include zep

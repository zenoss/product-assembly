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

# link source code for zenoss initialization
echo "Linking in prodbin Products ..."
rm -rf ${ZENHOME}/Products
su - zenoss -c "ln -s ${SRCROOT}/zenoss-prodbin/Products ${ZENHOME}/Products"
echo "Linking in zenpacks directory ..."
su - zenoss -c "ln -s ${SRCROOT} ${ZENHOME}/packs"

echo "Linking in modelindex..."
su - zenoss -c "pip uninstall -y zenoss.modelindex"
su - zenoss -c "ln -s ${SRCROOT}/modelindex ${ZENHOME}/modelindex"
ls -l ${ZENHOME}/modelindex
ls -l /mnt/src

su - zenoss -c "pip install -e ${ZENHOME}/modelindex"

echo "Configuring maven..."
cat /home/zenoss/.bashrc
rm /opt/maven/conf/settings.xml
cp /mnt/devimg/settings.xml /opt/maven/conf/settings.xml
cat <<EOF >> /home/zenoss/.bashrc
export PATH=/opt/maven/bin:\$PATH
EOF

cat /home/zenoss/.bashrc
echo "Starting create_devimg ..."
export BUILD_DEVIMG=1
${ZENHOME}/install_scripts/create_zenoss.sh --no-quickstart
echo "Finished create_zenoss.sh"



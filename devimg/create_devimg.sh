#!/bin/bash

if [ -z "${SRCROOT}" ]; then
    SRCROOT=/mnt/src
fi
if [ ! -d "${SRCROOT}" ]; then
	echo "ERROR: Path ${SRCROOT} does not exist"
	exit 1
fi

# link source code for zenoss initialization
echo "Linking in prodbin Products ..."
rm -rf ${ZENHOME}/Products
su - zenoss -c "ln -s ${SRCROOT}/zenoss-prodbin/Products ${ZENHOME}/Products"

echo "Linking in zenpacks directory ..."
su - zenoss -c "ln -s ${SRCROOT} ${ZENHOME}/packs"

echo "Linking in zep sql directory ..."
rm -rf ${ZENHOME}/share/zeneventserver/sql
su - zenoss -c "ln -s ${SRCROOT}/zenoss-zep/core/src/main/sql ${ZENHOME}/share/zeneventserver/sql"

echo "Linking in zep webapp..."
rm -rf ${ZENHOME}/webapps/zeneventserver
su - zenoss -c "ln -s ${SRCROOT}/zenoss-zep ${ZENHOME}/webapps/zeneventserver"

echo "Linking in modelindex..."
su - zenoss -c "pip uninstall -y zenoss.modelindex"
su - zenoss -c "ln -s ${SRCROOT}/modelindex ${ZENHOME}/modelindex"
su - zenoss -c "pip install -e ${ZENHOME}/modelindex"

echo "Linking in solr configsets..."
rm -rf /opt/solr/server/solr/configsets
ln -s ${SRCROOT}/modelindex/zenoss/modelindex/solr/configsets /opt/solr/server/solr/configsets

echo "Linking in metrics dir"
rm -rf ${ZENHOME}/bin/metrics
su - zenoss -c "ln -s ${SRCROOT}/zenoss-prodbin/bin/metrics ${ZENHOME}/bin/metrics"

#TODO: do we want to do this for prodbin bin files as well?
if [ -d ${SRCROOT}/zenoss-zep/dist/src/assembly/bin ]; then
    for srcfile in ${SRCROOT}/zenoss-zep/dist/src/assembly/bin/*; do
        filename=$(basename "$srcfile")
        rm -f ${ZENHOME}/bin/${filename}
        su - zenoss -c "ln -s ${srcfile} ${ZENHOME}/bin/${filename}"
    done
else
    echo "${SRCROOT}/zenoss-zep/dist/src/assembly/bin does not exist"
    exit 1
fi

echo "Configuring maven..."
cat /home/zenoss/.bashrc
rm /opt/maven/conf/settings.xml
cp /mnt/devimg/settings.xml /opt/maven/conf/settings.xml
cat <<EOF >> /home/zenoss/.bashrc
export PATH=/opt/maven/bin:\$PATH
EOF

# Copy the devimg version of prepare.sh into the install_scripts directory.
cp ${SRCROOT}/product-assembly/devimg/prepare.sh ${ZENHOME}/install_scripts/prepare.sh

cat /home/zenoss/.bashrc
echo "Install Zenoss ..."
export BUILD_DEVIMG=1
export SRCROOT
${ZENHOME}/install_scripts/create_zenoss.sh --no-quickstart
echo "Finished create_zenoss.sh"

echo "Link in Java apps"
rm -rf ${ZENHOME}/lib/central-query
su - zenoss -c "ln -s ${SRCROOT}/query ${ZENHOME}/lib/central-query"

rm -rf ${ZENHOME}/lib/metric-consumer-app
su - zenoss -c "ln -s ${SRCROOT}/zenoss.metric.consumer ${ZENHOME}/lib/metric-consumer-app"

#TODO figure out how to install protocols in develop mode. The setup.py doesn't buld protobus.
#echo "Install zenoss-protocols in development mode"
#su - zenoss -c "pip uninstall -y zenoss.protocols"
#su - zenoss -c "pip install -e ${SRCROOT}/zenoss-protocols/python"

echo "Install zenwipe"
cp ${SRCROOT}/product-assembly/devimg/zenwipe.sh ${ZENHOME}/bin/zenwipe.sh
chown zenoss:zenoss ${ZENHOME}/bin/zenwipe.sh
chmod 754 ${ZENHOME}/bin/zenwipe.sh
echo "zenwipe has been installed."

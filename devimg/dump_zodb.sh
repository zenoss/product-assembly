#!/bin/bash

# prepare the environment
source ${ZENHOME}/install_scripts/prepare.sh
prepare

# load the installation functions
source ${ZENHOME}/install_scripts/install_lib.sh

cleanup() {
	set +x
	set +e
	if [ -f $ZENHOME/zensocket ]; then
		mv $ZENHOME/zensocket $ZENHOME/bin/zensocket
		chmod 04750 $ZENHOME/bin/zensocket
	fi
	stop_solr
	stop_rabbitmq
	stop_redis
}
trap cleanup EXIT

sync_zope_conf || die "Failed to sync globals.conf to zope config files"

start_redis
start_rabbitmq
start_solr

mv $ZENHOME/bin/zensocket $ZENHOME/zensocket

set -e
set -x

echo "Running zenwipe.sh $@"
su - zenoss -l -c "/opt/zenoss/bin/zenwipe.sh $@" \
	|| die "Failed to run zenwipe.sh"

echo "Running exportXml"
su - zenoss -l -c "cd /opt/zenoss/Products/ZenModel/data && ./exportXml.sh" \
	|| die "Failed to export XML and SQL dump file"

echo "Finished dumping zodb"

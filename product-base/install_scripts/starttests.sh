#!/bin/bash
#
# Start Zenoss and run all platform and ZenPack tests
#

set -e
# set -x

# prepare the environment
source ${ZENHOME}/install_scripts/prepare.sh
prepare

. ${ZENHOME}/install_scripts/install_lib.sh

cleanup() {
	stop_zep
	stop_solr
	stop_rabbitmq
	stop_redis
}
trap cleanup EXIT

sync_zope_conf

start_redis
start_rabbitmq
start_solr
start_zep

su - zenoss -c "${ZENHOME}/bin/runtests $*"

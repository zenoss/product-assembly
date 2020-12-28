#!/bin/bash

set -e
# set -x

# prepare the environment
source ${ZENHOME}/install_scripts/prepare.sh
prepare

# load the installation functions
source ${ZENHOME}/install_scripts/install_lib.sh

rabbitmq_configure

# Initialize and load the zodb database
initialize_relstorage
load_zodb
pack_zodb

# Initialize the zenoss_zep database
initialize_zep

# Start services to finish initialization
start_redis
start_rabbitmq
start_solr

# Update Zope conf files from globals.conf
sync_zope_conf

# # set up the zope instance
run_mkzopeinstance

# Register zproxy scripts and conf
init_zproxy

# Remediate file ownership under $ZENHOME.
fix_zenhome_owner_and_group

# Copy missing files from $ZENHOME/etc into /etc
copy_missing_etc_files

# Remediate file permissions on /etc/sudoers.d and /etc/logrotate.d
fix_etc_permissions

init_modelcatalog

echo "Add default system user..."
su - zenoss -c "${ZENHOME}/bin/zendmd --script ${ZENHOME}/bin/addSystemUser.py"

# These directories need to be setup prior to zenpack install to facilitate
# link installs for zendev/devimg
ensure_dfs_dirs

# Migrate ZODB
migrate_zodb

install_zenpacks

# Pass along arguments to this function (e.g. --no-quickstart)
reset_zenoss_uuid $*

cleanup_zep_database

# shut down servers
stop_redis
stop_rabbitmq
stop_solr

echo "Cleaning up after install..."
set -x
find ${ZENHOME} -name \*.py[co] -delete
rm -f ${ZENHOME}/log/\*.log
rm -rf /opt/solr/logs/*
set +x

echo "Component Artifact Report"
cat ${ZENHOME}/log/zenoss_component_artifact.log

echo "ZenPack Artifact Report"
cat ${ZENHOME}/log/zenpacks_artifact.log

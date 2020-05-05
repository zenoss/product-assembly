#!/bin/bash
##############################################################################
# 
# Copyright (C) Zenoss, Inc. 2007, all rights reserved.
# 
# This content is made available according to terms specified in
# License.zenoss under the directory where your Zenoss product is installed.
# 
##############################################################################

# THIS SCRIPT WILL BLOW AWAY YOUR DATABASE
# Use --xml option to this script to rebuild using DmdBuilder and the XML files
# Default is simply to reload from SQL dump

if [ -z "${ZENHOME}" ]; then
    if [ -d /opt/zenoss ] ; then
        ZENHOME=/opt/zenoss
    else
        echo "Please define the ZENHOME environment variable"
        exit 1
    fi
fi

source ${ZENHOME}/install_scripts/install_lib.sh


# Drop and recreate the ZODB relstorage database
echo "Recreating zodb and zodb_session databases"
mysql \
	--user=${ZODB_USER} --password=${ZODB_PASSWORD} \
	--host=${ZODB_HOST} --port=${ZODB_PORT} \
	-e "DROP DATABASE zodb; DROP DATABASE zodb_session; CREATE DATABASE zodb; CREATE DATABASE zodb_session;"

initialize_relstorage

# Drop and recreate the ZEP event database
echo "Recreating zenoss_zep database"
mysql \
	--user=${ZEP_USER} --password=${ZEP_PASSWORD} \
	--host=${ZEP_HOST} --port=${ZEP_PORT} \
	-e "DROP DATABASE zenoss_zep; CREATE DATABASE zenoss_zep;"

initialize_zep

echo "Deleting Zenpacks"
rm -rf $ZENHOME/ZenPacks/* /var/zenoss/ZenPacks/* /var/zenoss/ZenPackSource/*

# Creates the initial user file for zenbuild
echo "Initializing zope with default admin/zenoss user..."
python $ZENHOME/zopehome/mkzopeinstance --dir="$ZENHOME" --user="admin:zenoss" || die "Unable to create Zope instance."

echo "Building zenoss"
zenbuild "$@"

# truncate daemons.txt file
cp /dev/null $ZENHOME/etc/daemons.txt

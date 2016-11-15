#!/bin/bash

# load the installation functions
#   so we can use start_requirements
. ${ZENHOME}/install_scripts/install_lib.sh


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

echo "Starting required applications ..."

start_requirements

/usr/lib/rabbitmq/bin/rabbitmq-plugins enable rabbitmq_management
/sbin/rabbitmqctl stop
sleep 5
rm -r /var/lib/rabbitmq/mnesia/rabbit@rbt0.pid
/usr/sbin/rabbitmq-server 2>&1 > ${ZENHOME}/log/rabbitmq.log &
rabbitmqctl wait /var/lib/rabbitmq/mnesia/rabbit@rbt0.pid

echo "Running zenwipe.sh $@"
su - zenoss -c "/opt/zenoss/bin/zenwipe.sh $@"
echo "Running exportXml"
su - zenoss -c "cd /opt/zenoss/Products/ZenModel/data && ./exportXml.sh"

echo "Stopping mysql..."
mysqladmin shutdown

echo "Stopping redis..."
pkill redis

echo "Stopping rabbit..."
/sbin/rabbitmqctl stop

sleep 10
echo "Cleaning up mysql data..."
rm /var/lib/mysql/ib_logfile0
rm /var/lib/mysql/ib_logfile1

echo "Cleaning up after install..."
find ${ZENHOME} -name \*.py[co] -delete
rm -f ${ZENHOME}/log/\*.log
/sbin/scrub.sh

echo "Finished dumping zodb"




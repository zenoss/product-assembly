#!/bin/sh


# load the installation functions
. ${ZENHOME}/install_scripts/install_lib.sh

set -e
set -x

# ZEN-28791: Set mysqld.log initial permissions
fix_mysqld_log

start_requirements

/usr/lib/rabbitmq/bin/rabbitmq-plugins enable rabbitmq_management
/sbin/rabbitmqctl stop
sleep 5
rm -r /var/lib/rabbitmq/mnesia/rabbit@rbt0.pid
/usr/sbin/rabbitmq-server 2>&1 > ${ZENHOME}/log/rabbitmq.log &
rabbitmqctl wait /var/lib/rabbitmq/mnesia/rabbit@rbt0.pid

echo "Running zenoss_init"
${ZENHOME}/install_scripts/zenoss_init.sh

echo "Cleaning up dmd.uuid"
echo "dmd.uuid = None" > /tmp/cleanuuid.zendmd
su - zenoss -c "zendmd --commit --script=/tmp/cleanuuid.zendmd"

echo "Truncating heartbeats"
mysql -u root zenoss_zep -e "truncate daemon_heartbeat;"

echo "Stopping mysql..."
mysqladmin shutdown

#TODO stop and clean content of rabbit queues
echo "Stopping redis..."
pkill redis

echo "Stopping rabbit..."
/sbin/rabbitmqctl stop

echo "Stopping solr..."
kill $SOLR_PID

sleep 10
echo "Cleaning up mysql data..."
rm /var/lib/mysql/ib_logfile0
rm /var/lib/mysql/ib_logfile1

echo "Cleaning up after install..."
find ${ZENHOME} -name \*.py[co] -delete
rm -f ${ZENHOME}/log/\*.log
rm -rf /opt/solr/logs/*
/sbin/scrub.sh

echo "Component Artifact Report"
cat ${ZENHOME}/log/zenoss_component_artifact.log

echo "ZenPack Artifact Report"
cat ${ZENHOME}/log/zenpacks_artifact.log


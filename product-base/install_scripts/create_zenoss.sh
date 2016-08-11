#!/bin/sh

set -e
set -x 

echo "Starting mysql..."
/usr/bin/mysql_install_db --user=mysql
/usr/bin/mysqld_safe &

echo "Starting redis..."
/usr/bin/redis-server /etc/redis.conf &

echo "Starting rabbit..."
echo "127.0.0.1 rbt0" >> /etc/hosts
/usr/sbin/rabbitmq-server &
sleep 5
/usr/lib/rabbitmq/bin/rabbitmq-plugins enable rabbitmq_management
/sbin/rabbitmqctl stop
sleep 5
/usr/sbin/rabbitmq-server 2>&1 > ${ZENHOME}/log/rabbitmq.log &
sleep 5

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

sleep 10
echo "Cleaning up mysql data..."
rm /var/lib/mysql/ib_logfile0
rm /var/lib/mysql/ib_logfile1

echo "TODO REMOVE THIS AFTER PRODBIN IS UPDATED TO FILTER OUT MIGRATE TESTS"
rm -rf ${ZENHOME}/Products/ZenModel/migrate/tests

echo "Cleaning up after install..."
find ${ZENHOME} -name \*.py[co] -delete
rm -f ${ZENHOME}/log/\*.log
/sbin/scrub.sh

echo "Component Artifact Report"
cat ${ZENHOME}/log/zenoss_component_artifact.log

echo "ZenPack Artifact Report"
cat ${ZENHOME}/log/zenpack_artifact.log


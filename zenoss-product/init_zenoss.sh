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
/usr/sbin/rabbitmq-server &
sleep 5

echo "Running zenoss_init"
/opt/zenoss/bin/zenoss_init


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

echo "Deleting pyc and pyo files..."
find /opt/zenoss -name \*.py[co] -delete
/sbin/scrub.sh


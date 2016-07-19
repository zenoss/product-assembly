#!/bin/sh

set -e
set -x 

#Files added via docker will be owned by root, set to zenoss
chown -Rf zenoss:zenoss /opt/zenoss/*

# Install Prodbin
su - zenoss -c "wget -qO- http://zenpip.zendev.org/packages/prodbin-${PRODBIN_VERSION}.tar.gz | tar -C ${ZENHOME} -xzv"

# Install MetricConsumer
su - zenoss -c "wget -qO- http://zenpip.zendev.org/packages/metric-consumer-app-${METRICCONSUMER_VERSION}-zapp.tar.gz | tar -C ${ZENHOME} -xzv"

# Install CentralQuery
su - zenoss -c "wget -qO- http://zenpip.zendev.org/packages/central-query-${CENTRALQUERY_VERSION}-zapp.tar.gz | tar -C ${ZENHOME} -xzv"

# Install zep
su - zenoss -c "wget -qO- http://nexus.zendev.org:8081/nexus/service/local/repositories/releases/content/org/zenoss/zep/zep-dist/${ZEP_VERSION}/zep-dist-${ZEP_VERSION}.tar.gz | tar -C ${ZENHOME} -xzv"

# Install metricshipper
su - zenoss -c "wget -qO- http://zenpip.zendev.org/packages/metricshipper-${METRICSHIPPER_VERSION}.tgz | tar -C ${ZENHOME} -xzv"

# Install zminion
su - zenoss -c "wget -qO- http://zenpip.zendev.org/packages/zminion-${ZMINION_VERSION}.tgz | tar -C ${ZENHOME} -xzv"

# Install redis-mon
su - zenoss -c "wget -qO- http://zenpip.zendev.org/packages/redis-mon-${REDISMON_VERSION}.tgz | tar -C ${ZENHOME} -xzv"

# Install zproxy
su - zenoss -c "wget -qO- http://zenpip.zendev.org/packages/zproxy-1.0.0.tar.gz | tar --strip-components=2 -C ${ZENHOME} -xzv"

# TODO add upgrade templates to /root  - probably done in core/rm image builds

su - zenoss -c "source /opt/zenoss/bin/activate; pip install -i http://zenpip.zendev.org/simple/ --trusted-host zenpip.zendev.org  servicemigration"





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

sleep 10
echo "Cleaning up mysql data..."
rm /var/lib/mysql/ib_logfile0
rm /var/lib/mysql/ib_logfile1

echo "TODO REMOVE THIS AFTER PRODBIN IS UPDATED TO FILTER OUT MIGRATE TESTS"
rm -rf /opt/zenoss/Products/ZenModel/migrate/tests

echo "Cleaning up after install..."
find /opt/zenoss -name \*.py[co] -delete
rm -f /opt/zenoss/log/*
/sbin/scrub.sh


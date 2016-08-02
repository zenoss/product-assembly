#!/bin/sh

set -e
set -x

#Files added via docker will be owned by root, set to zenoss
chown -Rf zenoss:zenoss ${ZENHOME}/*

# Install Prodbin
su - zenoss -c "wget -qO- http://zenpip.zendev.org/packages/prodbin-${PRODBIN_VERSION}.tar.gz | tar -C ${ZENHOME} -xzv"
su - zenoss -c "source ${ZENHOME}/bin/activate; pip install ${ZENHOME}/dist/*.whl"
su - zenoss -c "rm -rf ${ZENHOME}/dist"


# Install MetricConsumer
su - zenoss -c "wget -qO- http://zenpip.zendev.org/packages/metric-consumer-app-${METRICCONSUMER_VERSION}-zapp.tar.gz | tar -C ${ZENHOME} -xzv"

# Install CentralQuery
su - zenoss -c "wget -qO- http://zenpip.zendev.org/packages/central-query-${CENTRALQUERY_VERSION}-zapp.tar.gz | tar -C ${ZENHOME} -xzv"

# Install icmpecho
su - zenoss -c "wget -qO- http://zenpip.zendev.org/packages/icmpecho-${ICMPECHO_VERSION}.tar.gz | tar -C /tmp -xzv"
su - zenoss -c "mv /tmp/pyraw ${ZENHOME}/bin"
su - zenoss -c "source ${ZENHOME}/bin/activate; pip install /tmp/icmpecho*.whl"

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

su - zenoss -c "source ${ZENHOME}/bin/activate; pip install -i http://zenpip.zendev.org/simple/ --trusted-host zenpip.zendev.org  servicemigration==${SERVICEMIGRATION_VERSION}"

# TODO add upgrade templates to /root  - probably done in core/rm image builds

echo "TODO REMOVE THIS AFTER PRODBIN IS UPDATED TO FILTER OUT MIGRATE TESTS"
rm -rf ${ZENHOME}/Products/ZenModel/migrate/tests

echo "Cleaning up after install..."
find ${ZENHOME} -name \*.py[co] -delete
/sbin/scrub.sh

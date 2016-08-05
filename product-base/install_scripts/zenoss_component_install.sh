#!/bin/sh

set -e
set -x

#Files added via docker will be owned by root, set to zenoss
chown -Rf zenoss:zenoss ${ZENHOME}/*

# Install Prodbin
su - zenoss -c "wget -qO- http://zenpip.zendev.org/packages/prodbin-${PRODBIN_VERSION}.tar.gz | tar -C ${ZENHOME} -xzv"
su - zenoss -c "source ${ZENHOME}/bin/activate; pip install ${ZENHOME}/dist/*.whl"
su - zenoss -c "mv ${ZENHOME}/legacy/sitecustomize.py ${ZENHOME}/lib/python2.7/"
su - zenoss -c "rm -rf ${ZENHOME}/dist ${ZENHOME}/legacy"



# Install MetricConsumer
su - zenoss -c "wget -qO- http://zenpip.zendev.org/packages/metric-consumer-app-${METRICCONSUMER_VERSION}-zapp.tar.gz | tar -C ${ZENHOME} -xzv"
# TODO: remove this and make sure files marked as executable in tar file
su - zenoss -c "chmod +x ${ZENHOME}/bin/metric-consumer-app.sh"
# TODO: remove this and make sure the tar file contains the proper links
su - zenoss -c "ln -s ${ZENHOME}/etc/metric-consumer-app/metric-consumer-app_supervisor.conf ${ZENHOME}/etc/supervisor/metric-consumer-app_supervisor.conf"

# Install CentralQuery
su - zenoss -c "wget -qO- http://zenpip.zendev.org/packages/central-query-${CENTRALQUERY_VERSION}-zapp.tar.gz | tar -C ${ZENHOME} -xzv"
# TODO: remove this and make sure files marked as executable in tar file
su - zenoss -c "chmod +x ${ZENHOME}/bin/central-query.sh"
# TODO: remove this and make sure the tar file contains the proper links
su - zenoss -c "ln -s ${ZENHOME}/etc/central-query/central-query_supervisor.conf ${ZENHOME}/etc/supervisor/central-query_supervisor.conf"

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

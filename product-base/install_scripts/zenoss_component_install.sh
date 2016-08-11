#!/bin/sh

set -e
set -x

mkdir -p ${ZENHOME}/log/

#Files added via docker will be owned by root, set to zenoss
chown -Rf zenoss:zenoss ${ZENHOME}/*


function artifactDownload
{
    local artifact="$@"
    su - zenoss -c "${ZENHOME}/install_scripts/artifact_download.py --out_dir /tmp ${ZENHOME}/install_scripts/component_versions.json ${artifact} --reportFile ${ZENHOME}/log/zenoss_component_artifact.log"
}

# Install Prodbin
artifactDownload "zenoss-prodbin"
su - zenoss -c "tar -C ${ZENHOME} -xzvf /tmp/prodbin*"
# TODO: remove this and make sure the tar file contains the proper links
su - zenoss -c "mkdir -p ${ZENHOME}/etc/supervisor"
su - zenoss -c "mkdir -p ${ZENHOME}/var/zauth"
su - zenoss -c "mkdir -p ${ZENHOME}/libexec"
su - zenoss -c "ln -s ${ZENHOME}/etc/zauth/zauth_supervisor.conf ${ZENHOME}/etc/supervisor/zauth_supervisor.conf"

su - zenoss -c "pip install  --use-wheel --no-index  ${ZENHOME}/dist/*.whl"
su - zenoss -c "mv ${ZENHOME}/legacy/sitecustomize.py ${ZENHOME}/lib/python2.7/"
su - zenoss -c "rm -rf ${ZENHOME}/dist ${ZENHOME}/legacy"


# Install MetricConsumer
artifactDownload "metric-consumer"
su - zenoss -c "tar -C ${ZENHOME} -xzvf /tmp/metric-consumer*"
# TODO: remove this and make sure files marked as executable in tar file
su - zenoss -c "chmod +x ${ZENHOME}/bin/metric-consumer-app.sh"
# TODO: remove this and make sure the tar file contains the proper links
su - zenoss -c "ln -s ${ZENHOME}/etc/metric-consumer-app/metric-consumer-app_supervisor.conf ${ZENHOME}/etc/supervisor/metric-consumer-app_supervisor.conf"

# Install CentralQuery
artifactDownload "central-query"
su - zenoss -c "tar -C ${ZENHOME} -xzvf /tmp/central-query*"
# TODO: remove this and make sure files marked as executable in tar file
su - zenoss -c "chmod +x ${ZENHOME}/bin/central-query.sh"
# TODO: remove this and make sure the tar file contains the proper links
su - zenoss -c "ln -s ${ZENHOME}/etc/central-query/central-query_supervisor.conf ${ZENHOME}/etc/supervisor/central-query_supervisor.conf"

# Install icmpecho
artifactDownload "icmpecho"
su - zenoss -c "tar -C /tmp -xzvf /tmp/icmpecho*"
su - zenoss -c "mv /tmp/pyraw ${ZENHOME}/bin"
su - zenoss -c "pip install  --use-wheel --no-index  /tmp/icmpecho*.whl"

# Install zenoss-protocols
artifactDownload "zenoss-protocols"
su - zenoss -c "pip install  --use-wheel --no-index  /tmp/zenoss.protocols*.whl"

# Install pynetsnmp
artifactDownload "pynetsnmp"
su - zenoss -c "pip install  --use-wheel --no-index  /tmp/pynetsnmp*.whl"

# Install zenoss-extjs
artifactDownload "zenoss-extjs"
su - zenoss -c "pip install  --no-index  /tmp/zenoss.extjs*"

# Install zep
artifactDownload "zep"
su - zenoss -c "tar -C ${ZENHOME} -xzvf /tmp/zep-dist*"

# Install metricshipper
artifactDownload "metricshipper"
su - zenoss -c "tar -C ${ZENHOME} -xzvf /tmp/metricshipper*"

# Install zminion
artifactDownload "zminion"
su - zenoss -c "tar -C ${ZENHOME} -xzvf /tmp/zminion*"

# Install redis-mon
artifactDownload "redis-mon"
su - zenoss -c "tar -C ${ZENHOME} -xzvf /tmp/redis-mon*"

# Install zproxy
artifactDownload "zproxy"
su - zenoss -c "tar --strip-components=2 -C ${ZENHOME} -xzvf /tmp/zproxy*"


artifactDownload "servicemigration"
su - zenoss -c "pip install  --use-wheel --no-index  /tmp/servicemigration*"

# TODO add upgrade templates to /root  - probably done in core/rm image builds

echo "TODO REMOVE THIS AFTER PRODBIN IS UPDATED TO FILTER OUT MIGRATE TESTS"
rm -rf ${ZENHOME}/Products/ZenModel/migrate/tests

echo "Cleaning up after install..."
find ${ZENHOME} -name \*.py[co] -delete
/sbin/scrub.sh

echo "Component Artifact Report"
cat ${ZENHOME}/log/zenoss_component_artifact.log


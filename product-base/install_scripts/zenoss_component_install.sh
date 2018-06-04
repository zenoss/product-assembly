#!/bin/sh

set -e
set -x

if [ $# -ne 0 -a $# -ne 2 ]
then
	echo "ERROR: $# is an invalid number of arguments; only 0 or 2 arguments are allowed"
	exit 1
elif [ $# -eq 2 ]
then
	if [ "$1" != "--change-uid" ]
	then
		echo "ERROR: invalid option '$1'; only --change-uid allowed"
		exit 1
	fi

	# This section is typically used for devimg's to apply the uid/gid of the
	# current user to the zenoss user/group in the image.
	NEW_UID=`echo $2 | cut -d: -f1`
	NEW_GID=`echo $2 | cut -d: -f1`
	echo "Changing zenoss user/group ids to ${NEW_UID}:${NEW_GID}"

	groupmod --gid ${NEW_GID} zenoss
	usermod --uid ${NEW_UID} --gid ${NEW_GID} zenoss

	# Fix up ownership for zenoss-owned files outside of ZENHOME
	chown zenoss:zenoss /var/spool/mail/zenoss
	chown -Rf zenoss:zenoss /home/zenoss
fi

mkdir -p ${ZENHOME}/log/

# Files added via docker will be owned by root, set to zenoss to start to avoid conflicts
# as we unpack components into ZENHOME
chown -Rf zenoss:zenoss ${ZENHOME}


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

su - zenoss -c "pip install --no-index  ${ZENHOME}/dist/*.whl"
su - zenoss -c "mv ${ZENHOME}/legacy/sitecustomize.py ${ZENHOME}/lib/python2.7/"
su - zenoss -c "rm -rf ${ZENHOME}/dist ${ZENHOME}/legacy"
source ${ZENHOME}/install_scripts/versions.sh 
su - zenoss -c "sed -e 's/%VERSION_STRING%/${VERSION}/g; s/%BUILD_NUMBER%/${BUILD_NUMBER}/g' ${ZENHOME}/Products/ZenModel/ZVersion.py.in > ${ZENHOME}/Products/ZenModel/ZVersion.py"

# Install MetricConsumer
artifactDownload "zenoss.metric.consumer"
su - zenoss -c "tar -C ${ZENHOME} -xzvf /tmp/metric-consumer*"
# TODO: remove this and make sure files marked as executable in tar file
su - zenoss -c "chmod +x ${ZENHOME}/bin/metric-consumer-app.sh"
# TODO: remove this and make sure the tar file contains the proper links
su - zenoss -c "ln -s ${ZENHOME}/etc/metric-consumer-app/metric-consumer-app_supervisor.conf ${ZENHOME}/etc/supervisor/metric-consumer-app_supervisor.conf"

# Install CentralQuery
artifactDownload "query"
su - zenoss -c "tar -C ${ZENHOME} -xzvf /tmp/central-query*"
# TODO: remove this and make sure files marked as executable in tar file
su - zenoss -c "chmod +x ${ZENHOME}/bin/central-query.sh"
# TODO: remove this and make sure the tar file contains the proper links
su - zenoss -c "ln -s ${ZENHOME}/etc/central-query/central-query_supervisor.conf ${ZENHOME}/etc/supervisor/central-query_supervisor.conf"

# Install icmpecho
artifactDownload "icmpecho"
su - zenoss -c "tar -C /tmp -xzvf /tmp/icmpecho*"
su - zenoss -c "mv /tmp/pyraw ${ZENHOME}/bin"
su - zenoss -c "pip install --no-index  /tmp/icmpecho*.whl"

# Install zenoss-protocols
artifactDownload "zenoss-protocols"
su - zenoss -c "pip install --no-index  /tmp/zenoss.protocols*.whl"

# Install pynetsnmp
artifactDownload "pynetsnmp"
su - zenoss -c "pip install --no-index  /tmp/pynetsnmp*.whl"

# Install zenoss-extjs
artifactDownload "zenoss-extjs"
su - zenoss -c "pip install  --no-index  /tmp/zenoss.extjs*"

# Install zep
artifactDownload "zenoss-zep"
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

# Install zenoss.toolobx
artifactDownload "zenoss.toolbox"
su - zenoss -c "pip install --no-index  /tmp/zenoss.toolbox*.whl"

# Install the service migration SDK
artifactDownload "service-migration"
su - zenoss -c "pip install --no-index  /tmp/servicemigration*"

# Install zenoss-solr
# TODO:  Don't do this.  Either componentize our solr startup scripts, do this in zenoss-centos-base,
#  move solr to its own image, or some combination of these.
#  But for now, go ahead and do this.
wget -q http://zenpip.zenoss.eng/packages/zenoss-solr-1.0dev.tgz -O /tmp/zenoss-solr.tgz
tar -C "/" -xzvf /tmp/zenoss-solr.tgz
chown -R zenoss:zenoss /var/solr

# Install Modelindex
artifactDownload "modelindex"
su - zenoss -c "mkdir /tmp/modelindex"
su - zenoss -c "tar -C /tmp/modelindex -xzvf /tmp/modelindex-*"
su - zenoss -c "pip install /tmp/modelindex/dist/zenoss.modelindex*"
# Copy the modelindex configsets into solr for bootstrapping.
#  TODO:  when we move to external zookeeper for solr, do something else
rm -rf /opt/solr/server/solr/configsets
cp -R /tmp/modelindex/zenoss/modelindex/solr/configsets /opt/solr/server/solr/

# Some components have files which are read-only by zenoss, so we need to
# open up the permissions to allow read/write for the group and read for
# all others.  We need to make this minimal setting here to facilitate
# creation of a devimg.
#
# Note that the final arbitration of permissions will be done by zenoss_init.sh
# when the actual product image is created.
chmod -R g+rw,o+r,+X ${ZENHOME}/*

# TODO add upgrade templates to /root  - probably done in core/rm image builds

echo "TODO REMOVE THIS AFTER PRODBIN IS UPDATED TO FILTER OUT MIGRATE TESTS"
rm -rf ${ZENHOME}/Products/ZenModel/migrate/tests

echo "TODO REMOVE THIS AFTER PRODBIN IS UPDATED TO FILTER OUT ZenUITests-based TESTS"
rm -rf ${ZENHOME}/Products/ZenUITests

echo "Cleaning up after install..."
find ${ZENHOME} -name \*.py[co] -delete
/sbin/scrub.sh

echo "Component Artifact Report"
cat ${ZENHOME}/log/zenoss_component_artifact.log


#!/bin/bash

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
	NEW_UID=$(echo $2 | cut -d: -f1)
	NEW_GID=$(echo $2 | cut -d: -f1)
	echo "Changing zenoss user/group ids to ${NEW_UID}:${NEW_GID}"

	groupmod --gid ${NEW_GID} zenoss
	usermod --uid ${NEW_UID} --gid ${NEW_GID} zenoss

	# Fix BLD-215
	mkdir -p /home/zenoss/.cache/pip/wheels
	# End BLD-215

	# Fix up ownership for zenoss-owned files outside of ZENHOME
	chown zenoss:zenoss /var/spool/mail/zenoss
	chown -Rf zenoss:zenoss /home/zenoss
fi

# Ensure ZENHOME has a log directory
mkdir -p ${ZENHOME}/log/

# Files added via docker will be owned by root, set to zenoss to start to avoid conflicts
# as we unpack components into ZENHOME
chown -Rf zenoss:zenoss ${ZENHOME}


function run
{
	su - zenoss -c "$@"
}

function download_artifact
{
    local artifact="$@"
    run "${ZENHOME}/install_scripts/artifact_download.py --out_dir /tmp --reportFile ${ZENHOME}/log/zenoss_component_artifact.log ${ZENHOME}/install_scripts/component_versions.json ${artifact}"
}

# Install Prodbin
download_artifact "zenoss-prodbin"
run "tar -C ${ZENHOME} -xzvf /tmp/prodbin* --exclude=Products/ZenModel/migrate/tests --exclude=Products/ZenUITests"

# TODO: remove this and make sure the tar file contains the proper links
run "mkdir -p ${ZENHOME}/etc/supervisor ${ZENHOME}/var/zauth ${ZENHOME}/libexec"
run "ln -s ${ZENHOME}/etc/zauth/zauth_supervisor.conf ${ZENHOME}/etc/supervisor/zauth_supervisor.conf"

run "pip install --no-index ${ZENHOME}/dist/*.whl"
run "mv ${ZENHOME}/legacy/sitecustomize.py ${ZENHOME}/lib/python2.7/"
run "rm -rf ${ZENHOME}/dist ${ZENHOME}/legacy"
source ${ZENHOME}/install_scripts/versions.sh 
run "sed -e 's/%VERSION_STRING%/${VERSION}/g; s/%BUILD_NUMBER%/${BUILD_NUMBER}/g' ${ZENHOME}/Products/ZenModel/ZVersion.py.in > ${ZENHOME}/Products/ZenModel/ZVersion.py"

# Install zensocket
download_artifact "zensocket"
run "tar -C ${ZENHOME} -xzvf /tmp/zensocket*"

# Install MetricConsumer
download_artifact "zenoss.metric.consumer"
run "tar -C ${ZENHOME} -xzvf /tmp/metric-consumer*"
# TODO: remove this and make sure files marked as executable in tar file
run "chmod +x ${ZENHOME}/bin/metric-consumer-app.sh"
# TODO: remove this and make sure the tar file contains the proper links
run "ln -s ${ZENHOME}/etc/metric-consumer-app/metric-consumer-app_supervisor.conf ${ZENHOME}/etc/supervisor/metric-consumer-app_supervisor.conf"

# Install CentralQuery
download_artifact "query"
run "tar -C ${ZENHOME} -xzvf /tmp/central-query*"
# TODO: remove this and make sure files marked as executable in tar file
run "chmod +x ${ZENHOME}/bin/central-query.sh"
# TODO: remove this and make sure the tar file contains the proper links
run "ln -s ${ZENHOME}/etc/central-query/central-query_supervisor.conf ${ZENHOME}/etc/supervisor/central-query_supervisor.conf"

# Install zenoss-protocols
download_artifact "zenoss-protocols"
run "pip install --no-index  /tmp/zenoss.protocols*.whl"

# Install pynetsnmp
download_artifact "pynetsnmp"
run "pip install --no-index  /tmp/pynetsnmp*.whl"

# Install zenoss-extjs
download_artifact "zenoss-extjs"
run "pip install  --no-index  /tmp/zenoss.extjs*"

# Install zep
download_artifact "zenoss-zep"
run "tar -C ${ZENHOME} -xzvf /tmp/zep-dist*"

# Install metricshipper
download_artifact "metricshipper"
run "tar -C ${ZENHOME} -xzvf /tmp/metricshipper*"

# Install zminion
download_artifact "zminion"
run "tar -C ${ZENHOME} -xzvf /tmp/zminion*"

# Install redis-mon
download_artifact "redis-mon"
run "tar -C ${ZENHOME} -xzvf /tmp/redis-mon*"

# Install zproxy
download_artifact "zproxy"
run "tar --strip-components=2 -C ${ZENHOME} -xzvf /tmp/zproxy*"

# Install zenoss.toolobx
download_artifact "zenoss.toolbox"
run "pip install --no-index  /tmp/zenoss.toolbox*.whl"

# Install the service migration SDK
download_artifact "service-migration"
run "pip install --no-index  /tmp/servicemigration*"

# Install zenoss-solr
download_artifact "solr-image"
tar -C / -xzvf /tmp/zenoss-solr*
chown -R zenoss:zenoss /var/solr

# Install Modelindex
download_artifact "modelindex"
run "mkdir /tmp/modelindex"
run "tar -C /tmp/modelindex -xzvf /tmp/modelindex-*"
run "pip install --no-index /tmp/modelindex/dist/zenoss.modelindex*"
# Copy the modelindex configsets into solr for bootstrapping.
#  TODO:  when we move to external zookeeper for solr, do something else
cp -R /tmp/modelindex/zenoss/modelindex/solr/configsets/zenoss_model /opt/solr/server/solr/configsets

# Some components have files which are read-only by zenoss, so we need to
# open up the permissions to allow read/write for the group and read for
# all others.  We need to make this minimal setting here to facilitate
# creation of a devimg.
#
# Note that the final arbitration of permissions will be done by zenoss_init.sh
# when the actual product image is created.
chmod -R g+rw,o+r,+X ${ZENHOME}/*

# Install the service migration package
run "pip install --no-index ${ZENHOME}/install_scripts/zenservicemigration*.whl"

echo "Cleaning up after install..."
find ${ZENHOME} -name \*.py[co] -delete
/sbin/scrub.sh

echo "Component Artifact Report"
cat ${ZENHOME}/log/zenoss_component_artifact.log

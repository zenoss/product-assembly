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

	# Fix BLD-215
	mkdir -p /home/zenoss/.cache/pip/wheels
        # End BLD-215

	# Fix up ownership for zenoss-owned files outside of ZENHOME
	chown zenoss:zenoss /var/spool/mail/zenoss
	# Fix up ownership in ZENHOME
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

# Install zenoss-protocols
artifactDownload "zenoss-protocols"
su - zenoss -c "pip install --no-index  /tmp/zenoss.protocols*.whl"

# Install pynetsnmp
artifactDownload "pynetsnmp"
su - zenoss -c "pip install --no-index  /tmp/pynetsnmp*.whl"

# Install the service migration SDK
artifactDownload "service-migration"
su - zenoss -c "pip install --no-index  /tmp/servicemigration*"

# Install Modelindex
artifactDownload "modelindex"
su - zenoss -c "mkdir /tmp/modelindex"
su - zenoss -c "tar -C /tmp/modelindex -xzvf /tmp/modelindex-*"
su - zenoss -c "pip install /tmp/modelindex/dist/zenoss.modelindex*"


# Some components have files which are read-only by zenoss, so we need to
# open up the permissions to allow read/write for the group and read for
# all others.  We need to make this minimal setting here to facilitate
# creation of a devimg.
#
# Note that the final arbitration of permissions will be done by zenoss_init.sh
# when the actual product image is created.
chmod -R g+rw,o+r,+X ${ZENHOME}/*

# TODO add upgrade templates to /root  - probably done in core/rm image builds

#echo "TODO REMOVE THIS AFTER PRODBIN IS UPDATED TO FILTER OUT MIGRATE TESTS"
rm -rf ${ZENHOME}/Products/ZenModel/migrate/tests

#echo "TODO REMOVE THIS AFTER PRODBIN IS UPDATED TO FILTER OUT ZenUITests-based TESTS"
rm -rf ${ZENHOME}/Products/ZenUITests

echo "Cleaning up after install..."
find ${ZENHOME} -name \*.py[co] -delete
/sbin/scrub.sh

echo "Component Artifact Report"
cat ${ZENHOME}/log/zenoss_component_artifact.log


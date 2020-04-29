#!/bin/bash

if [ -z "${DBHOST}" ]; then
	echo "DBHOST environment variable not specified. Aborting."
	exit 1
fi
if [ -z "${SRCROOT}" ]; then
	echo "SRCROOT environment variable not specified. Aborting."
	exit 1
fi

zodbpack_config=${ZENHOME}/install_scripts/zodbpack.conf
global_config=${ZENHOME}/etc/global.conf
zep_config=${SRCROOT}/zenoss-zep/core/src/main/resources/zep-config-cfg.xml

prepare() {
	sed \
		-e "s/%DBHOST%/${DBHOST}/" \
		${ZENHOME}/install_scripts/zodbpack.conf.in > ${zodbpack_config}

	# Set config for zodb connection
	cp -f ${global_config} ${global_config}.bak
	sed \
		-e "s/zodb-host .\+/zodb-host ${DBHOST}/" \
		-e "s/zep-host .\+/zep-host ${DBHOST}/" \
		-i \
		${global_config}

	# Set config for zeneventserver
	cp -f ${zep_config} ${zep_config}.bak
	sed -e "s/file:etc\//file:\/opt\/zenoss\/etc\//" -i ${zep_config}
}

cleanup_prepare() {
	rm -f "${zodbpack_config}"
	if [ -f "${global_config}.bak" ]; then
		mv -f ${global_config}.bak ${global_config}
	fi
	if [ -f "${zep_config}.bak" ]; then
		mv -f ${zep_config}.bak ${zep_config}
	fi
}
trap cleanup_prepare EXIT

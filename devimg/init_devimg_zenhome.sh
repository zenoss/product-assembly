#!/bin/bash
#
# Initialize zenhome for devimg by copying the container's ZENHOME contents
#   to a mount point outside of the container which points to the current
#   user's ZENHOME on the host OS.
#
if [ -z "${1}" ]
then
	echo "ERROR: missing required argument for target mount point"
	exit 1
elif [ ! -d "${1}" ]
then
	echo "ERROR: target mount point '${1}' not found"
	exit 1
fi

if [ -z "${ZENHOME}" ]
then
	echo "ERROR: ZENHOME not defined"
	exit 1
fi

TARGET_MOUNT=${1}

# Delete anything that's already in the mounted volume. This step executes
# in the container as root so we can remove any root-owned files that get
# created in the developer's local ZENHOME.
rm -rf ${TARGET_MOUNT}/*

# Copy out everything in ZENHOME except Products, devimg and packs.
# These directories will be soft-linked in host OS.
find ${ZENHOME} -maxdepth 1 |\
	egrep -v '/Products|/devimg|/packs' |\
	xargs --no-run-if-empty cp -rp -t ${TARGET_MOUNT}

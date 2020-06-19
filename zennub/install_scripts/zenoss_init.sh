#! /usr/bin/env bash
#
# zenoss_init_pre
#
# This script is intended to be run before the zenoss processes have

#
# Note: it is run by root
#
##############################################################################
#
# Copyright (C) Zenoss, Inc. 2007, all rights reserved.
#
# This content is made available according to terms specified in
# License.zenoss under the directory where your Zenoss product is installed.
#
##############################################################################

set -e
set +x

. ${ZENHOME}/install_scripts/install_lib.sh


# set the python shebang line
shebang

# Remediate file ownership under $ZENHOME.
fix_zenhome_owner_and_group

# Copy missing files from $ZENHOME/etc into /etc
copy_missing_etc_files

# Remediate file permissions on /etc/sudoers.d and /etc/logrotate.d
fix_etc_permissions

# These directories need to be setup prior to zenpack install to facilitate
# link installs for zendev/devimg
ensure_dfs_dirs
ensure_dir /opt/zenoss/ZenPacks

# These need to exist, and be owned by the zenoss user, so that when
# the docker volumes are mounted over them, they will also be writable
# by the zenoss user as well.
ensure_dir /data
ensure_dir /cfg

echo "Upgrading yaml parser ..."
yum -y install libyaml-devel
su - zenoss -c "pip uninstall --yes pyyaml; pip install pyyaml --global-option='--with-libyaml'"

echo "Checking for zenpack file ${ZENHOME}/install_scripts/zenpacks.json ..."
if [ -f "${ZENHOME}/install_scripts/zenpacks.json" ]; then

    # run zp install
    #TODO the output from zp_install.py and the zenpack install subprocesses it creates comes out of order, need to fix
    echo "Installing zenpacks..."
    if [ -z "${BUILD_DEVIMG}" ]
    then
       LINK_INSTALL=""
       ZENPACK_BLACKLIST=""
    else
       LINK_INSTALL="--link"
       ZENPACK_BLACKLIST="${ZENHOME}/install_scripts/zp_blacklist.json"
    fi
    su - zenoss  -c "${ZENHOME}/install_scripts/zp_install.py ${ZENHOME}/install_scripts/zenpacks.json ${ZENHOME}/packs ${ZENPACK_BLACKLIST} ${LINK_INSTALL}"

    su - zenoss  -c "mkdir -p /opt/zenoss/etc/nub/system; /opt/zenoss/Products/ZenNub/update_zenpacks.py"

fi

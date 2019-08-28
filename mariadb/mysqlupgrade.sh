#/bin/bash

GLOBAL_CFG="/opt/zenoss/etc/global.conf"
ADMIN_USER=$(grep -r "zodb-admin-user" $GLOBAL_CFG | awk '{print $2}')
PASSWD=$(grep -r "zodb-admin-password" $GLOBAL_CFG | awk '{print $2}')
mysql_upgrade -u $ADMIN_USER -p$PASSWD

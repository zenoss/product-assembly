#/bin/bash

SERVICE=$1
GLOBAL_CFG="/opt/zenoss/etc/global.conf"

if [ $SERVICE == "mariadb-model" ]; then

  ADMIN_USER=$(grep -r "zodb-admin-user" $GLOBAL_CFG | awk '{print $2}')
  PASSWD=$(grep -r "zodb-admin-password" $GLOBAL_CFG | awk '{print $2}')
  mysql_upgrade -u $ADMIN_USER -p$PASSWD

elif [ $SERVICE == "mariadb-events" ]; then

  ADMIN_USER=$(grep -r "zep-admin-user" $GLOBAL_CFG | awk '{print $2}')
  PASSWD=$(grep -r "zep-admin-password" $GLOBAL_CFG | awk '{print $2}')
  mysql_upgrade -u $ADMIN_USER -p$PASSWD

else

  echo "Unknown $SERVICE service, mysqlupdate failed"

fi



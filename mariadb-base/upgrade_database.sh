#/bin/bash

SERVICE=$1
GLOBAL_CFG="/opt/zenoss/etc/global.conf"
ADMIN_USER="root"
PASSWD=""


case $SERVICE in
	mariadb-model)
		ADMIN_USER=$(grep -r "zodb-admin-user" $GLOBAL_CFG | awk '{print $2}')
		PASSWD=$(grep -r "zodb-admin-password" $GLOBAL_CFG | awk '{print $2}')
		;;
	mariadb-events)
		ADMIN_USER=$(grep -r "zep-admin-user" $GLOBAL_CFG | awk '{print $2}')
		PASSWD=$(grep -r "zep-admin-password" $GLOBAL_CFG | awk '{print $2}')
		;;
esac

start_db() {
	mysqld_safe --skip-syslog --log-error=/var/log/mysql/upgrade.log &
	until mysqladmin ping 2>/dev/null; do
		echo "Waiting for mysqld..."
		sleep 1
	done
}

cleanup() {
	mysqladmin ping 2>/dev/null
	if [ $? -eq 0 ]; then
		echo "Shutting down mysqld..."
		mysqladmin shutdown
	fi
}

trap cleanup EXIT

set -e

start_db
chown -R mysql:mysql /var/lib/mysql
mysql_upgrade -u $USERNAME -p $PASSWD

#/bin/bash

SERVICE=$1
GLOBAL_CFG="/opt/zenoss/etc/global.conf"
ADMIN_USER="root"
export MYSQL_PWD=""

case $SERVICE in
	mariadb-model|mariadb)
		ADMIN_USER=$(grep -r "zodb-admin-user" $GLOBAL_CFG | awk '{print $2}')
		MYSQL_PWD=$(grep -r "zodb-admin-password" $GLOBAL_CFG | awk '{print $2}')
		;;
	mariadb-events)
		ADMIN_USER=$(grep -r "zep-admin-user" $GLOBAL_CFG | awk '{print $2}')
		MYSQL_PWD=$(grep -r "zep-admin-password" $GLOBAL_CFG | awk '{print $2}')
		;;
esac

ZODB_USER=$(grep -r "zodb-user" $GLOBAL_CFG | awk '{print $2}')
ZEP_USER=$(grep -r "zep-user" $GLOBAL_CFG | awk '{print $2}')

start_db() {
	chown -R mysql:mysql /var/lib/mysql
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
		mysqladmin shutdown -u $ADMIN_USER
	fi
}

trap cleanup EXIT

set -e

start_db
mysql_upgrade -u $ADMIN_USER
sed -e "s/!ZU!/${ZODB_USER}/g" -e "s/!EU!/${ZEP_USER}/g" /opt/zenoss/bin/fix_permissions.sql.in | mysql -u $ADMIN_USER

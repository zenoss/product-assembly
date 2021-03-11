#!/bin/bash

SQL_PERMS=/home/zenoss/permissions.sql

install_toolbox() {
	pip --no-python-version-warning --no-cache-dir install --no-index /home/zenoss/zends.toolbox*whl
}

start_db() {
	mysqld_safe --skip-syslog --log-error=/var/log/mysql/build.log &
	until mysqladmin ping 2>/dev/null; do
		echo "Waiting for mysql..."
		sleep 1
	done
}

stop_db() {
	mysqladmin shutdown
}

fix_root_permissions() {
	mysql \
		-u root \
		-D mysql \
		-e "UPDATE user SET plugin='mysql_native_password' WHERE user='root'; FLUSH PRIVILEGES;"
}

apply_permissions() {
	cat ${SQL_PERMS} | mysql -u root
}

create_databases() {
	# Create the databases zodb, zodb_session, zenoss_zep
	mysql -u root -e "CREATE DATABASE IF NOT EXISTS zodb;"
	mysql -u root -e "CREATE DATABASE IF NOT EXISTS zodb_session;"
	mysql -u root -e "CREATE DATABASE IF NOT EXISTS zenoss_zep;"
}

cleanup() {
	rm -f ${SQL_PERMS} /home/zenoss/initialize_db.sh /home/zenoss/zends.toolbox*whl
	stop_db
}

trap cleanup EXIT

install_toolbox

start_db

mysql_upgrade
fix_root_permissions
create_databases
apply_permissions

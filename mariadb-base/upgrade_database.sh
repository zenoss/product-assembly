#/bin/bash

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
mysql_upgrade

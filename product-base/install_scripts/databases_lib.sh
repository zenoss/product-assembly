# Setup /var/log/mysqld.log and give permissions to mysqld to write to it.

export ZEP_DB_TYPE="`get_var zep-db-type`"
export ZEP_HOST="`get_var zep-host`"
export ZEP_DB="`get_var zep-db`"
export ZEP_PORT="`get_var zep-port`"
export ZEP_ADMIN_USER="`get_var zep-admin-user`"
export ZEP_ADMIN_PASSWORD="`get_var zep-admin-password`"
export ZEP_USER="`get_var zep-user`"
export ZEP_PASSWORD="`get_var zep-password`"

export ZODB_DB_TYPE=`get_var zodb-db-type`
export ZODB_HOST="`get_var zodb-host`"
export ZODB_DB="`get_var zodb-db`"
export ZODB_PORT="`get_var zodb-port`"
export ZODB_ADMIN_USER="`get_var zodb-admin-user`"
export ZODB_ADMIN_PASSWORD="`get_var zodb-admin-password`"
export ZODB_USER="`get_var zodb-user`"
export ZODB_PASSWORD="`get_var zodb-password`"


initialize_relstorage() {
	echo "Initialize relstorage (zodb database)..."

	su - zenoss -l -c "${ZENHOME}/install_scripts/zodb_relstorage_init.py" \
		|| die "Unable to initialize relstorage"

	local schemadir=${ZENHOME}/Products/ZenUtils/relstorage/mysql
	for patch_file in $(find ${schemadir} -name \*.sql | sort); do
		cat ${patch_file} >> patch.sql
	done
	cat patch.sql | mysql \
		--batch \
		--user=${ZODB_USER} --password=${ZODB_PASSWORD} \
		--host=${ZODB_HOST} \
		--database=${ZODB_DB} \
		|| die "Unable to patch relstorage tables"
	rm -f patch.sql
}


load_zodb()
{
	echo "Load ZODB dump file..."
	ZODB_SQL_GZ=${ZENHOME}/Products/ZenModel/data/zodb.sql.gz
	gunzip -c $ZODB_SQL_GZ | mysql \
		--batch \
		--skip-column-names \
		--user=${ZODB_USER} --password=${ZODB_PASSWORD} \
		--host=${ZODB_HOST} \
		--database=${ZODB_DB} \
		|| die "Unable to load Zenoss ZODB SQL dump"
}

pack_zodb() {
	echo "Packing the ZODB database..."
	su - zenoss -l -c "zodbpack ${ZENHOME}/install_scripts/zodbpack.conf" || die "Unable to pack ZODB"
}

initialize_zep() {
	echo "Initialize zeneventserver (zenoss_zep) database..."

	local schemadir=${ZENHOME}/share/zeneventserver/sql/mysql
	for patch_file in $(find ${schemadir} -name \*.sql | sort); do
		cat ${patch_file} >> patch.sql
	done
	cat patch.sql | mysql \
		--batch \
		--user=${ZEP_USER} --password=${ZEP_PASSWORD} \
		--host=${ZEP_HOST} \
		--database=${ZEP_DB} \
		|| die "Unable to patch relstorage tables"
	rm -f patch.sql
}

# initialize the model catalog in solr
init_modelcatalog()
{
	echo "Initialize model catalog..."
	if [ -f $ZENHOME/Products/Zuul/catalog/model_catalog_init.py ]; then
		su - zenoss -c "python $ZENHOME/Products/Zuul/catalog/model_catalog_init.py --hard"
	fi
}

edit_root_permissions()
{
  mysql --user="root" --database="mysql" --execute="SELECT user, host, plugin FROM mysql.user;"
  mysql --user="root" --database="mysql" --execute="UPDATE user SET plugin='mysql_native_password' WHERE user='root'; FLUSH PRIVILEGES;"
  mysql --user="root" --database="mysql" --execute="SELECT user, host, plugin FROM mysql.user;"
}

# create a zope instance
run_mkzopeinstance()
{
	echo "Set up zope instance..."
	# If these are present mkzopeinstance won't put the shell scripts in place
	mkdir -p /opt/zenoss/zopehome
	for script in addzope2user mkzopeinstance runzope zopectl zpasswd; do
		mv /opt/zenoss/bin/${script} /opt/zenoss/zopehome/
	done
	# sed -i -e's/^import os.*activate_this$$//g' /opt/zenoss/zopehome/*
	cp /opt/zenoss/bin/activate_this.py /opt/zenoss/zopehome/

	echo "Initializing zope with default admin/zenoss user..."
	# Initializes zope with default admin/zenoss user
	su zenoss -l -c 'python $ZENHOME/zopehome/mkzopeinstance --dir="$ZENHOME" --user="admin:zenoss"' || die "Unable to create Zope instance."
}

reset_zenoss_uuid() {
	echo "Cleaning up dmd.uuid"
	echo "dmd.uuid = None" > /tmp/cleanuuid.zendmd
	if [  "$1" == '--no-quickstart' ]; then
		 echo "dmd._rq = True " >> /tmp/cleanuuid.zendmd
		 echo "dmd.ZenUsers.getUserSettings('admin') " >> /tmp/cleanuuid.zendmd
	fi
	su - zenoss -c "zendmd --commit --script=/tmp/cleanuuid.zendmd"
}

cleanup_zep_database() {
	echo "Truncating heartbeats"
	mysql -u ${ZEP_USER} -p${ZEP_PASSWORD} -h ${ZEP_HOST} ${ZEP_DB} -e "truncate daemon_heartbeat;"
}

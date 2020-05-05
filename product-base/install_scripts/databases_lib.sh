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

	local cmd="${ZENHOME}/install_scripts/zodb_relstorage_init.py"
	if [[ $EUID -eq 0 ]]; then
		cmd="su - zenoss -c \"${cmd}\""
	fi
	eval ${cmd} || die "Unable to initialize relstorage"

	local schemadir=${ZENHOME}/Products/ZenUtils/relstorage/mysql
	local sqlscript=/tmp/patch_$(get_random_key).sql
	for patch_file in $(find ${schemadir} -name \*.sql | sort); do
		cat ${patch_file} >> ${sqlscript}
	done
	cat ${sqlscript} | mysql \
		--batch \
		--user=${ZODB_USER} --password=${ZODB_PASSWORD} \
		--host=${ZODB_HOST} \
		--database=${ZODB_DB} \
		|| die "Unable to patch relstorage tables"
	rm -f ${sqlscript}
}


load_zodb() {
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
	local cmd="zodbpack ${ZENHOME}/install_scripts/zodbpack.conf"
	if [[ $EUID -eq 0 ]]; then
		cmd="su - zenoss -c \"${cmd}\""
	fi
	eval ${cmd} || die "Unable to pack ZODB"
}

initialize_zep() {
	echo "Initialize zeneventserver (zenoss_zep) database..."

	local schemadir=${ZENHOME}/share/zeneventserver/sql/mysql
	local sqlscript=/tmp/patch_$(get_random_key).sql
	for patch_file in $(find ${schemadir} -name \*.sql | sort); do
		cat ${patch_file} >> ${sqlscript}
	done
	cat ${sqlscript} | mysql \
		--batch \
		--user=${ZEP_USER} --password=${ZEP_PASSWORD} \
		--host=${ZEP_HOST} \
		--database=${ZEP_DB} \
		|| die "Unable to patch zenoss_zep tables"
	rm -f ${sqlscript}
}

# initialize the model catalog in solr
init_modelcatalog() {
	echo "Initialize model catalog..."
	local cmd="python $ZENHOME/Products/Zuul/catalog/model_catalog_init.py --hard"
	if [ -f $ZENHOME/Products/Zuul/catalog/model_catalog_init.py ]; then
		if [[ $EUID -eq 0 ]]; then
			cmd="su - zenoss -c \"${cmd}\""
		fi
		eval ${cmd} || die "Unable to initialize model catalog"
	fi
}

edit_root_permissions() {
  mysql \
	  --user="root" \
	  --database="mysql" \
	  --execute="SELECT user, host, plugin FROM mysql.user;"

  mysql \
	  --user="root" \
	  --database="mysql" \
	  --execute="UPDATE user SET plugin='mysql_native_password' WHERE user='root'; FLUSH PRIVILEGES;"

  mysql \
	  --user="root" \
	  --database="mysql" \
	  --execute="SELECT user, host, plugin FROM mysql.user;"
}

# create a zope instance
run_mkzopeinstance() {
	echo "Create Zope instance..."
	mkdir -p ${ZENHOME}/zopehome
	for script in addzope2user mkzopeinstance runzope zopectl zpasswd; do
		mv ${ZENHOME}/bin/${script} ${ZENHOME}/zopehome/
	done
	if [[ $EUID -eq 0 ]]; then
		chown zenoss:zenoss ${ZENHOME}/zopehome/*
	fi

	cp --preserve ${ZENHOME}/bin/activate_this.py ${ZENHOME}/zopehome/

	# Initializes zope with default admin/zenoss user
	local cmd="python $ZENHOME/zopehome/mkzopeinstance --dir=\"$ZENHOME\" --user=\"admin:zenoss\""
	if [[ $EUID -eq 0 ]]; then
		cmd="su - zenoss -c \"${cmd}\""
	fi
	eval ${cmd} || die "Unable to create Zope instance."
}

reset_zenoss_uuid() {
	echo "Cleaning up dmd.uuid..."
	local script=/tmp/cleanuuid_$(get_random_key).zendmd
	echo "dmd.uuid = None" > ${script}
	if [  "$1" == '--no-quickstart' ]; then
		 echo "dmd._rq = True " >> ${script}
		 echo "dmd.ZenUsers.getUserSettings('admin') " >> ${script}
	fi
	local cmd="zendmd --commit --script=${script}"
	if [[ $EUID -eq 0 ]]; then
		cmd="su - zenoss -c \"${cmd}\""
	fi
	eval ${cmd} || die "Unable to clean up dmd.uuid"
	rm -f ${script}
}

cleanup_zep_database() {
	echo "Truncating heartbeats"
	mysql \
		--user=${ZEP_USER} --password=${ZEP_PASSWORD} \
		--host=${ZEP_HOST} --port=${ZEP_PORT} \
		${ZEP_DB} \
		-e "TRUNCATE daemon_heartbeat;"
}

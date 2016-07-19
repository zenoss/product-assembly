function get_var {
    VAR_NAME=$1

    OUTPUT=`su zenoss  -c "$ZENHOME/bin/zenglobalconf -p $VAR_NAME"`
    if [ $? != 0 ]; then
       exit 1
    fi
    echo $OUTPUT
}

export ZENHOME=/opt/zenoss

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

export RABBITMQ_HOST="`get_var amqphost`"
export RABBITMQ_SSL="`get_var amqpusessl`"
export RABBITMQ_PORT="`get_var amqpport`"
export RABBITMQ_VHOST="`get_var amqpvhost`"
export RABBITMQ_USER="`get_var amqpuser`"
export RABBITMQ_PASS="`get_var amqppassword`"


fail()
{
    echo $*
    exit 1
}

shebang() {
   # replace the first line of any python sh-bang script with
   # #!$ZENHOME/bin/python
   find $ZENHOME/bin \( -type f -o -type l \) -exec readlink -e '{}' \; | \
      egrep -v "zensocket|pyraw" | \
      xargs sed -i '1,1 s%#!.*python$%#!'"$ZENHOME/bin/python"'%'
}

configure_amqp() {
    RABBITMQ_ADMIN="`which rabbitmqadmin`"
    if [ ! -z "$RABBITMQ_ADMIN" ]; then
        local user_exists=`"$RABBITMQ_ADMIN" list users | tail -n +4 | egrep -v "^\+" | awk '{ print $2 }' | grep '^'"$RABBITMQ_USER"'$'`
        if [ -z "$user_exists" ]; then
            echo "Adding RabbitMQ user: $RABBITMQ_USER"
            "$RABBITMQ_ADMIN" declare user name="$RABBITMQ_USER" password="$RABBITMQ_PASS" tags=
        fi
        local vhost_exists=`"$RABBITMQ_ADMIN" list vhosts | tail -n +4 | egrep -v "^\+" | awk '{ print $2 }' | grep '^'"$RABBITMQ_VHOST"'$'`
        if [ -z "$vhost_exists" ]; then
            echo "Adding RabbitMQ vhost: $RABBITMQ_VHOST"
            "$RABBITMQ_ADMIN" declare vhost name="$RABBITMQ_VHOST"
        fi
        local perm_exists=`"$RABBITMQ_ADMIN" list permissions user | tail -n +4 | egrep -v "^\+" | awk '{ print $2 }' | grep '^'"$RABBITMQ_USER"'$'`
        if [ -z "$perm_exists" ]; then
            echo "Setting RabbitMQ permissions for user: $RABBITMQ_USER"
            "$RABBITMQ_ADMIN" declare permission vhost="$RABBITMQ_VHOST" user="$RABBITMQ_USER" configure='.*' write='.*' read='.*' 
        fi
    else
        echo "Unable to find rabbitmqadmin. Please refer to the installation"
        echo "guide for instructions on configuring RabbitMQ."
    fi
}

# create the zodb database
create_zodb_db()
{
    $ZENHOME/bin/zeneventserver-create-db --dbhost "$ZODB_HOST" --dbport "$ZODB_PORT" --dbname "$ZODB_DB" \
        --dbadminuser "$ZODB_ADMIN_USER" --dbadminpass "$ZODB_ADMIN_PASSWORD" \
        --dbtype "$ZODB_DB_TYPE" \
        --dbuser "$ZODB_USER" --dbpass "$ZODB_PASSWORD" --schemadir "$ZENHOME/Products/ZenUtils/relstorage" \
        || fail "Failed to create ZODB database"

}

create_zodb_session_db()
{
    $ZENHOME/bin/zeneventserver-create-db --dbhost "$ZODB_HOST" --dbport "$ZODB_PORT" --dbname "$ZODB_DB"_session \
        --dbadminuser "$ZODB_ADMIN_USER" --dbadminpass "$ZODB_ADMIN_PASSWORD" \
        --dbtype "$ZODB_DB_TYPE" --force \
        --dbuser "$ZODB_USER" --dbpass "$ZODB_PASSWORD" --schemadir "$ZENHOME/Products/ZenUtils/relstorage" \
        || fail "Failed to create ZODB session database"
}

create_zep_db()
{
    $ZENHOME/bin/zeneventserver-create-db --dbhost "$ZEP_HOST" --dbport "$ZEP_PORT" --dbname "$ZEP_DB" \
        --dbadminuser "$ZEP_ADMIN_USER" --dbadminpass "$ZEP_ADMIN_PASSWORD" \
        --dbtype "$ZEP_DB_TYPE" \
        --dbuser "$ZEP_USER" --dbpass "$ZEP_PASSWORD" || fail "Failed to create ZEP database"
}

# create a zope instance
run_mkzopeinstance()
{
    set +x
    set -e
    echo "Syncing zenglobal conf, whatver that means."
    su zenoss -l -c "$ZENHOME/bin/zenglobalconf -s"

    echo "Moving zope scripts around..."
    # If these are present mkzopeinstance won't put the shell scripts in place
    mkdir -p /opt/zenoss/zopehome
    mv /opt/zenoss/bin/addzope2user   /opt/zenoss/zopehome
    mv /opt/zenoss/bin/mkzopeinstance /opt/zenoss/zopehome
    mv /opt/zenoss/bin/runzope        /opt/zenoss/zopehome
    mv /opt/zenoss/bin/zopectl        /opt/zenoss/zopehome
    mv /opt/zenoss/bin/zpasswd        /opt/zenoss/zopehome
    sed -i -e's/^import os.*activate_this$$//g' /opt/zenoss/zopehome/*

    echo "Initializing zope with default admin/zenoss user..."
    #initializes zope with default admin/zenoss user
    su zenoss -l -c 'python $ZENHOME/zopehome/mkzopeinstance --dir="$ZENHOME" --user="admin:zenoss" || fail Unable to create Zope instance.'

#    cp /opt/zenoss/lib/python2.7/site-packages/Zope2/utilities/skel/bin/runzope.in /opt/zenoss/bin/runzope
#    cp /opt/zenoss/lib/python2.7/site-packages/Zope2/utilities/skel/bin/zopectl.in /opt/zenoss/bin/zopectl
}

init_zproxy() 
{
    set -e
    echo "Validating redis is running"
    msg=`redis-cli FLUSHALL`
    if [ "$?" -ne 0 ]; then
        fail "Failed to connect to redis: ${msg}"
    else
	echo "Linking zproxy files..."
	su - zenoss -l -c 'mkdir -p /opt/zenoss/etc/supervisor'
	su - zenoss -l -c 'ln -sf /opt/zenoss/zproxy/conf/zproxy_supervisor.conf /opt/zenoss/etc/supervisor/zproxy_supervisor.conf'
	su - zenoss -l -c 'ln -sf /opt/zenoss/zproxy/sbin/zproxy /opt/zenoss/bin/zproxy'

	echo "Regiser zproxy scripts..."
        msg=`su - zenoss -c "zproxy register load-scripts"`
	if [ "$?" -ne 0 ]; then
            fail "Failed to load proxy scripts: ${msg}"
        fi
	echo "Regiser zproxy conf..."
        msg=`su - zenoss -c "zproxy register from-file ${ZENHOME}/etc/zproxy_registration.conf"`
        if [ "$?" -ne 0 ]; then
            fail "Failed to load proxy registrations: ${msg}"
        fi
    fi
}

# load objects into the zodb
run_zenbuild()
{
    echo Loading initial Zenoss objects into the Zeo database
    echo   '(this can take a few minutes)'
    su zenoss -l -c "$ZENHOME/bin/zenbuild $ZENBUILD_ARGS"  || fail "Unable to create the initial Zenoss object database"

}


# Set permission and ownership under zenhome
fix_zenhome_owner_and_group()
{
    echo "Setting zenoss owner in /opt/zenoss..."
    set -e
    chown -Rf zenoss:zenoss /opt/zenoss/*
    echo "TODO: Setting permissions on pyraw and zensocket."
    chown root:zenoss /opt/zenoss/bin/zensocket
    chmod 04750 /opt/zenoss/bin/zensocket
#    chown root:zenoss /opt/zenoss/bin/{zensocket,pyraw}
#    chmod 04750 /opt/zenoss/bin/{zensocket,pyraw}
}

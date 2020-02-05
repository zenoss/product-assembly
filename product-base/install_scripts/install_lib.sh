if [ -z "${ZENHOME}" ]; then
	export ZENHOME=/opt/zenoss
fi

CONFIG_FILE=${ZENHOME}/etc/global.conf

die() { echo "ERROR: ${*}" >&2; exit 1; }

get_var() {
	local key=$1
	[ -n "${key}" ] || die "No global config option name given to get_var"
	grep -q "${key}" $CONFIG_FILE || die "No option '${key}' found in global.conf"
	awk -v k="${key}" 'BEGIN{f=0} $1==k {v=$2;f=1} END{if (f==1) print v}' $CONFIG_FILE
}

source ${ZENHOME}/install_scripts/rabbitmq_lib.sh
source ${ZENHOME}/install_scripts/databases_lib.sh

export SOLR_PORT="8983"

start_redis() {
    printf "Starting redis..."
    /usr/bin/redis-server /etc/redis.conf &
	echo "OK"
}

stop_redis() {
	printf "Stopping redis..."
	pkill redis
	echo "OK"
}

start_solr() {
	echo "SOLR_PORT=$SOLR_PORT"
	printf "Starting solr..."
	setuser zenoss /opt/solr/zenoss/bin/start-solr -cloud -Dbootstrap_confdir=/opt/solr/server/solr/configsets/zenoss_model/conf -Dcollection.configName=zenoss_model -Dsolr.jetty.request.header.size=1000000 &
	export SOLR_PID=$!
	printf "waiting for solr to start..."
	until $(curl -A 'Solr answering healthcheck' -sI http://localhost:$SOLR_PORT/solr/admin/cores | grep -q 200); do
	  sleep 5
	done
	echo "OK"
}

stop_solr() {
	printf "Stopping solr..."
	kill $SOLR_PID
	until [[ ! $(ps h -q $SOLR_PID) ]]; do
		sleep 1
	done
	echo "OK"
}

start_zep() {
	printf "Starting zeneventserver..."
	su - zenoss -c "${ZENHOME}/bin/zeneventserver start"
	echo "OK"
}

stop_zep() {
	printf "Stopping zeneventserver..."
	su - zenoss -c "${ZENHOME}/bin/zeneventserver stop"
	echo "OK"
}

sync_zope_conf() {
	echo "Update Zope config file from globals.conf"
	su - zenoss -l -c "$ZENHOME/bin/zenglobalconf -s"
}

init_zproxy() {
	echo "Initializing zproxy..."

	printf "..validating redis is running .. "
	local msg=$(redis-cli FLUSHALL 2>&1)
	[ $? -eq 0 ] || die "Failed to connect to redis: ${msg}"
	echo ${msg}

	echo "..linking zproxy files"
	su - zenoss -l -c 'mkdir -p ${ZENHOME}/etc/supervisor'
	su - zenoss -l -c 'ln -sf ${ZENHOME}/zproxy/conf/zproxy_supervisor.conf ${ZENHOME}/etc/supervisor/zproxy_supervisor.conf'
	su - zenoss -l -c 'ln -sf ${ZENHOME}/zproxy/sbin/zproxy ${ZENHOME}/bin/zproxy'

	echo "..register zproxy scripts"
	su - zenoss -c "zproxy register load-scripts" || die "Failed to load proxy scripts"

	echo "..register zproxy conf"
	su - zenoss -c "zproxy register from-file ${ZENHOME}/etc/zproxy_registration.conf" \
		|| die "Failed to load proxy registrations"
}

# Set permission and ownership under zenhome
fix_zenhome_owner_and_group() {
	echo "Setting zenoss owner in /opt/zenoss..."
	chown -Rf zenoss:zenoss /opt/zenoss/*
	echo "Setting permissions on zensocket."
	chown root:zenoss /opt/zenoss/bin/zensocket
	chmod 04750 /opt/zenoss/bin/zensocket
}

# Set permissions under /etc
copy_missing_etc_files() {
	echo "Copying missing files from $ZENHOME/etc to /etc"
	sudoersd_files=("zenoss_dmidecode" "zenoss_nmap" "zenoss_ping" "zenoss_rabbitmq_stats")
	for f in "${sudoersd_files[@]}"
	do
		if [ -f /etc/sudoers.d/"$f" ]; then
			echo "/etc/sudoers.d/$f already exists"
		else
			if [ -f $ZENHOME/etc/sudoers.d/$f ]; then
				echo "Copying from $ZENHOME/etc/sudoers.d/$f to /etc/sudoers.d/$f"
				cp -p $ZENHOME/etc/sudoers.d/$f /etc/sudoers.d/$f
			else
				echo "$ZENHOME/etc/sudoers.d/$f not found, skipping"
			fi
		fi
	done
}

# Set permissions under /etc
fix_etc_permissions() {
	echo "Setting correct permissions on files under /etc/"
	local sudoersd_files=("zenoss_dmidecode" "zenoss_nmap" "zenoss_ping" "zenoss_rabbitmq_stats")
	for f in "${sudoersd_files[@]}"; do
		if [ -f /etc/sudoers.d/"$f" ]; then
		    echo "Setting permissions on /etc/sudoers.d/$f"
		    chmod 440 /etc/sudoers.d/"$f"
		    echo "Changing owner of /etc/sudoers.d/$f to root:root"
		    chown root:root /etc/sudoers.d/$f
		else
		    echo "/etc/sudoers.d/$f not found"
		fi
	done
	echo "Setting permissions on /etc/sudoers.d/"
	chmod 750 /etc/sudoers.d
}

install_zenpacks() {
	if [ -f "${ZENHOME}/install_scripts/zenpacks.json" ]; then
		start_zep

		# run zp install
		#TODO the output from zp_install.py and the zenpack install subprocesses
		# it creates comes out of order, need to fix
		echo "Installing zenpacks..."
		if [ -z "${BUILD_DEVIMG}" ]; then
		   LINK_INSTALL=""
		   ZENPACK_BLACKLIST=""
		else
		   LINK_INSTALL="--link"
		   ZENPACK_BLACKLIST="${ZENHOME}/install_scripts/zp_blacklist.json"
		fi
		su - zenoss -c "${ZENHOME}/install_scripts/zp_install.py ${ZENHOME}/install_scripts/zenpacks.json ${ZENHOME}/packs ${ZENPACK_BLACKLIST} ${LINK_INSTALL}"

		stop_zep
	fi
}

DESIRED_OWNERSHIP=${DESIRED_OWNERSHIP:-"zenoss:zenoss"}

ensure_dir() {

	local dirs="$@"
	for dirpath in "$@"; do
		# ensure directory exists
		if [[ ! -d "$dirpath" ]]; then
			mkdir -p "$dirpath" || die "unable to create dir: $dirpath"
		fi

		# ensure at least one file in the directory for dfs
		if [[ $(ls -a1 "$dirpath"|wc -l) -le 2 ]]; then   # an empty dir will always have '.' and '..'
			touch "$dirpath/README.txt" || die "unable to create file: $dirpath/README.txt"
		fi

		# ensure ownership
		if [[ -n "$DESIRED_OWNERSHIP" ]]; then
			chown -R "$DESIRED_OWNERSHIP" "$dirpath" \
				|| die "unable to chown to $DESIRED_OWNERSHIP for $dirpath"
		fi
	done
}

ensure_dfs_dirs() {
	echo "Ensuring some directories exist"
	# assuming ImageID comes before ContainerPath in each service.json
	# the paths listed below are generated from a subset of:
	#   egrep -r 'ImageID|ContainerPath' ~/src/europa/build/services/ |
	#       awk '/ImageID/{img=$NF} /ContainerPath/ {print img, $NF}' | sort -u
	ensure_dir \
		"/opt/zenoss/log/jobs" \
		"/opt/zenoss/log" \
		"/opt/zenoss/var/ext" \
		"/home/zenoss/.ssh" \
		"/opt/zenoss/export" \
		"/opt/zenoss/patches" \
		"/opt/zenoss/.ZenPacks" \
		"/opt/zenoss/.pc" \
		"/var/zenoss/ZenPacks" \
		"/var/zenoss/ZenPackSource"
}

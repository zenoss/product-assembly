if [ -z "${ZENHOME}" ]; then
	export ZENHOME=/opt/zenoss
fi

CONFIG_FILE=${ZENHOME}/etc/global.conf

get_random_key() {
	dd bs=16 count=1 status=none if=/dev/urandom | base64 | tr -cd "[:alnum:]" | cut -c1-16
}

die() { echo "ERROR: ${*}" >&2; exit 1; }

get_var() {
	local key=$1
	[ -n "${key}" ] || die "No global config option name given to get_var"
	grep -q "${key}" $CONFIG_FILE || die "No option '${key}' found in global.conf"
	awk -v k="${key}" 'BEGIN{f=0} $1==k {v=$2;f=1} END{if (f==1) print v}' $CONFIG_FILE
}

source ${ZENHOME}/install_scripts/rabbitmq_lib.sh
source ${ZENHOME}/install_scripts/databases_lib.sh

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

export SOLR_PORT="8983"

start_solr() {
	echo "Starting solr on port ${SOLR_PORT}..."
	local solr_cmd="/opt/solr/zenoss/bin/start-solr -cloud -Dbootstrap_confdir=/opt/solr/server/solr/configsets/zenoss_model/conf -Dcollection.configName=zenoss_model -Dsolr.jetty.request.header.size=1000000"
	if [[ $EUID -eq 0 ]]; then
		solr_cmd="setuser zenoss ${solr_cmd}"
	fi
	eval ${solr_cmd} &
	export SOLR_PID=$!
	until $(curl -A 'Solr answering healthcheck' -sI http://localhost:$SOLR_PORT/solr/admin/cores | grep -q 200); do
		sleep 5
	done
	echo "Solr has started"
}

stop_solr() {
	echo "Stopping solr..."
	kill $SOLR_PID
	until [[ ! $(ps h -q $SOLR_PID) ]]; do
		sleep 1
	done
	echo "Solr has stopped"
}

start_zep() {
	printf "Starting zeneventserver..."
	local zep_cmd="${ZENHOME}/bin/zeneventserver start"
	if [[ $EUID -eq 0 ]]; then
		zep_cmd="su - zenoss -c \"${zep_cmd}\""
	fi
	eval ${zep_cmd}
	echo "zeneventserver has started"
}

stop_zep() {
	echo "Stopping zeneventserver..."
	local zep_cmd="${ZENHOME}/bin/zeneventserver stop"
	if [[ $EUID -eq 0 ]]; then
		zep_cmd="su - zenoss -c \"${zep_cmd}\""
	fi
	eval ${zep_cmd}
	echo "zeneventserver has stopped"
}

sync_zope_conf() {
	echo "Update Zope config file from globals.conf"
	local cmd="$ZENHOME/bin/zenglobalconf -s"
	if [[ $EUID -eq 0 ]]; then
		cmd="su - zenoss -c \"${cmd}\""
	fi
	eval ${cmd}
}

init_zproxy() {
	echo "Initializing zproxy..."

	printf "...validating redis is running..."
	local msg=$(redis-cli FLUSHALL 2>&1)
	[ $? -eq 0 ] || die "Failed to connect to redis: ${msg}"
	echo ${msg}

	echo "...linking zproxy files"
	mkdir -p ${ZENHOME}/etc/supervisor
	if [[ $EUID -eq 0 ]]; then
		chown zenoss:zenoss ${ZENHOME}/etc/supervisor
	fi

	local cmd1="ln -sf ${ZENHOME}/zproxy/conf/zproxy_supervisor.conf ${ZENHOME}/etc/supervisor/zproxy_supervisor.conf"
	local cmd2="ln -sf ${ZENHOME}/zproxy/sbin/zproxy ${ZENHOME}/bin/zproxy"
	local cmd3="zproxy register load-scripts"
	local cmd4="zproxy register from-file ${ZENHOME}/etc/zproxy_registration.conf"
	if [[ $EUID -eq 0 ]]; then
		cmd1="su - zenoss -c \"${cmd1}\""
		cmd2="su - zenoss -c \"${cmd2}\""
		cmd3="su - zenoss -c \"${cmd3}\""
		cmd4="su - zenoss -c \"${cmd4}\""
	fi

	eval ${cmd1}
	eval ${cmd2}

	echo "...register zproxy scripts"
	eval ${cmd3} || die "Failed to load proxy scripts"

	echo "...register zproxy conf"
	eval ${cmd4} || die "Failed to load proxy registrations"
}

# Set permission and ownership under zenhome
fix_zenhome_owner_and_group() {
	if [[ $EUID -ne 0 ]]; then
		echo "fix_zenhome_owner_and_group must run as root"
		exit 1
	fi
	echo "Setting zenoss owner in /opt/zenoss..."
	chown -Rf zenoss:zenoss /opt/zenoss/*
	echo "Setting permissions on zensocket."
	chown root:zenoss /opt/zenoss/bin/zensocket
	chmod 04750 /opt/zenoss/bin/zensocket
}

# Set permissions under /etc
copy_missing_etc_files() {
	if [[ $EUID -ne 0 ]]; then
		echo "copy_missing_etc_files must run as root"
		exit 1
	fi
	echo "Copying missing files from $ZENHOME/etc to /etc"
	local sudoersd_files=("zenoss_dmidecode" "zenoss_nmap" "zenoss_ping" "zenoss_rabbitmq_stats" "zenoss_var_chown")
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
	if [[ $EUID -ne 0 ]]; then
		echo "fix_etc_permissions must run as root"
		exit 1
	fi
	echo "Setting correct permissions on files under /etc/"
	local sudoersd_files=("zenoss_dmidecode" "zenoss_nmap" "zenoss_ping" "zenoss_rabbitmq_stats" "zenoss_var_chown")
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
		local cmd="${ZENHOME}/install_scripts/zp_install.py ${ZENHOME}/install_scripts/zenpacks.json ${ZENHOME}/packs ${ZENPACK_BLACKLIST} ${LINK_INSTALL}"
		if [[ $EUID -eq 0 ]]; then
			cmd="su - zenoss -c \"${cmd}\""
		fi
		eval ${cmd}

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

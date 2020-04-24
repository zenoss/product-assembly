RABBITMQ_PID_FILE=/var/lib/rabbitmq/mnesia/rabbit@rbt0.pid

rabbitmq_add_host() {
	# Make sure the 'rbt0' name is found in /etc/hosts
	# rabbitmq will not run without this change.
	if grep -q "rbt0" /etc/hosts; then
		return
	fi
	local HOSTS=/etc/hosts
	local HOSTS_TMP=/tmp/hosts.edit
	yes | cp -f ${HOSTS} ${HOSTS_TMP} >/dev/null 2>&1
	if grep -q "127.0.0.1" ${HOSTS_TMP}; then
		local names=$(sed -n "s/127.0.0.1\s\+\(.\+\)/\1/p" ${HOSTS_TMP})
		names="${names} rbt0"
		sed -i "/127.0.0.1\s\+/s/.*/127.0.0.1 ${names}/" ${HOSTS_TMP}
	else
		sed -i "1i127.0.0.1 localhost rbt0" ${HOSTS_TMP}
	fi
	yes | cp -f ${HOSTS_TMP} ${HOSTS} >/dev/null 2>&1
	rm -f ${HOSTS_TMP}
}

rabbitmq_enable_management_plugins() {
	echo "Enabling RabbitMQ management plugins..."
	# Enable the management plugins
	# rabbitmq requires a restart if running while this change is made.
	local plugins="$(which rabbitmq-plugins 2>/dev/null)"
	test -z "${plugins}" && die "rabbitmq-plugins not found. Is RabbitMQ installed?"
	"${plugins}" enable rabbitmq_management
}

rabbitmq_install_admin_script() {
	echo "Installing rabbitmqadmin script..."
	# This installation requires rabbitmq to be running
	# with the management plugins enabled.

	local admin="$(which rabbitmqadmin 2>/dev/null)"
	if [ -z "${admin}" ]; then
		admin="/usr/local/bin/rabbitmqadmin"
	fi
	if [ ! -x "${admin}" ]; then
		if curl -s -o "${admin}" http://localhost:15672/cli/rabbitmqadmin; then
			chmod +x "${admin}"
		else
			die "Could not download rabbitmqadmin script for RabbitMQ server"
		fi
	fi
}

rabbitmq_list() {
	local cmd="$(which rabbitmqadmin 2>/dev/null)"
	test -z "${cmd}" && die "File not found: rabbitmqadmin"
	${cmd} list $@ --format raw_json
}

rabbitmq_declarations() {
	# This configuration requires the rabbitmqadmin script and a
	# running rabbitmq server.

	local amqp_host="$(get_var amqphost)"
	local amqp_ssl="$(get_var amqpusessl)"
	local amqp_port="$(get_var amqpport)"
	local amqp_vhost="$(get_var amqpvhost)"
	local amqp_user="$(get_var amqpuser)"
	local amqp_pass="$(get_var amqppassword)"
	local admin="$(which rabbitmqadmin 2>/dev/null)"

	local user=$(rabbitmq_list users | jq -r ".[].name" | grep "^${amqp_user}$")
	if [ -z "$user" ]; then
		echo "Adding RabbitMQ user: ${amqp_user}"
		"${admin}" declare user name="${amqp_user}" password="${amqp_pass}" tags=
	else
		echo "RabbitMQ user already added: ${amqp_user}"
	fi

	local vhost=$(rabbitmq_list vhosts | jq -r ".[].name" | grep "^${amqp_vhost}$")
	if [ -z "$vhost" ]; then
		echo "Adding RabbitMQ vhost: ${amqp_vhost}"
		"${admin}" declare vhost name="${amqp_vhost}"
	else
		echo "RabbitMQ vhost already added: ${amqp_vhost}"
	fi

	local perms=$(rabbitmq_list permissions user | jq -r ".[].user" | grep "^${amqp_user}$")
	if [ -z "$perms" ]; then
		echo "Setting RabbitMQ permissions for user: ${amqp_user}"
		"${admin}" declare permission vhost="${amqp_vhost}" user="${amqp_user}" configure='.*' write='.*' read='.*'
	else
		echo "RabbitMQ permissions for user already set: ${amqp_user}"
	fi
}

start_rabbitmq()
{
	echo "Starting RabbitMQ..."

	local cmd=$(which rabbitmqctl 2>/dev/null)
	test -z "${cmd}" && die "'rabbitmqctl' command not found.  Is RabbitMQ installed?"

	local server=$(which rabbitmq-server 2>/dev/null)
	test -z "${server}" && die "'rabbitmq-server' command not found.  Is RabbitMQ installed?"

	# make sure there's no previous pid file
	rm -f ${RABBITMQ_PID_FILE}

	# Add the "rbt0" hostname for localhost
	rabbitmq_add_host

	# Use 'rabbitmqctl status' to make sure that the erlang cookie for rabbitmq
	# is created first so there is no race btwn starting rabbitmq-server and
	# calling 'rabbitmqctl wait'
	# Reference - https://bugzilla.redhat.com/show_bug.cgi?id=1059913
	local ERLANG_COOKIE_FILE=/var/lib/rabbitmq/.erlang.cookie

	if [ ! -f ${ERLANG_COOKIE_FILE} ]; then
		${cmd} status >/dev/null 2>&1 || true  # noop; suppress error code

		# Wait for the erlang cookie file to exist
		until [ -f ${ERLANG_COOKIE_FILE} ]; do sleep 1; done
	fi

	# Start the rabbitmq server
	${server} &

	# Wait for the server to be ready
	if ${cmd} wait ${RABBITMQ_PID_FILE}; then
		echo "RabbitMQ is running"
	else
		echo "RabbitMQ failed to start"
		return 1
	fi
}

stop_rabbitmq()
{
	if [ ! -f ${RABBITMQ_PID_FILE} ]; then
		return
	fi

	local cmd=$(which rabbitmqctl 2>/dev/null)
	[ -n "${cmd}" ] || die "'rabbitmqctl' command not found.  Is RabbitMQ installed?"

	local pid=$(${cmd} status | sed -ne "s/^.*{pid,\([0-9]\+\)}.*$/\1/p")

	echo "Stopping RabbitMQ..."

	# Stop the rabbitmq server
	${cmd} stop

	# Wait for the server to exit
	until [ ! $(ps -p ${pid} >/dev/null 2>&1) ]; do sleep 1; done

	rm -f ${RABBITMQ_PID_FILE}
	echo "RabbitMQ has stopped."
}

rabbitmq_configure() {
	echo "Configuring RabbitMQ..."

	# Ensure rabbitmq is not running
	stop_rabbitmq

	rabbitmq_enable_management_plugins

	# Start rabbitmq to finish configuration
	start_rabbitmq

	rabbitmq_install_admin_script
	rabbitmq_declarations

	stop_rabbitmq

	echo "RabbitMQ configuration complete."
}

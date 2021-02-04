#!/bin/bash

if [ -z "${MOUNTPATH}" ]; then
	echo "MOUNTPATH environment variable is unset."
	exit 1
fi

# Install ActiveState Python into /opt/activepython
mkdir -p /opt/activepython
${MOUNTPATH}/activepython/install.sh -I /opt/activepython

# Update default zenoss shell variables.
echo "export OPENSSLDIR=/etc/pki/tls" >> /etc/profile.d/zenoss.sh
echo "export SSL_CERT_DIR=/etc/pki/tls/certs" >> /etc/profile.d/zenoss.sh
echo "export SSL_CERT_FILE=/etc/pki/tls/cert.pem" >> /etc/profile.d/zenoss.sh

# Remove artifacts of previous virtual environment (virtualenv)
find /opt/zenoss/lib/python2.7 -maxdepth 1 -type l -delete
find /opt/zenoss/include -maxdepth 1 -type l -delete

# (re) Install virtual environment with ActiveState Python
su - zenoss -c "virtualenv --python=/opt/activepython/bin/python /opt/zenoss"

# Delete the existing .pyc files
find /opt/zenoss -name \*.py[co] -delete

# Create new .pyc files (using ActiveState Python)
# Note: the '-x' argument excludes .py files that aren't Python 2 compatible.
su - zenoss -c "python -m compileall -fq -x \"(/tests/|/skins/zenmodel|pexpect/_async.py|zodbpickle/.*_3.py|attr/_next_gen.py|jinja2/async(filters|support).py)\" /opt/zenoss"

# Fix zenoss' PATH variable
su - zenoss -c "${MOUNTPATH}/fixup_path.sh"

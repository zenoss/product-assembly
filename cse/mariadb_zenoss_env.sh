#!/bin/bash
apt-get install -y gcc python-dev openjdk-8-jdk libpython2.7 libxml2-dev libxslt1-dev snmp redis-server rabbitmq-server jq
echo "127.0.0.1 rbt0" >> /etc/hosts
echo -e "NODENAME=rabbit@rbt0\nNODE_IP_ADDRESS=0.0.0.0" > /etc/rabbitmq/rabbitmq-env.conf
wget -qO- https://bootstrap.pypa.io/pip/2.7/get-pip.py | python;
chown -R zenoss:zenoss $ZENHOME
chown -R zenoss:zenoss /opt/solr/
chmod +x $ZENHOME/install_scripts/artifact_download.py
pip install virtualenv==16.7.9
find $ZENHOME/lib/python2.7/ -type l -delete
su - zenoss -c 'virtualenv $ZENHOME && virtualenv --relocatable $ZENHOME'
su - zenoss -c 'mkdir $ZENHOME/zenpacks'
su - zenoss -c 'cd $ZENHOME/install_scripts; ./artifact_download.py --zp_manifest zenpacks.json --out_dir ../zenpacks --reportFile zenpacks_artifact.log zenpack_versions.json'
rm -rf $ZENHOME/local

source ${ZENHOME}/install_scripts/rabbitmq_lib.sh
rabbitmq_start
rabbitmqctl stop

FROM zenoss/zenoss-centos-base:1.2.1
MAINTAINER Zenoss <dev@zenoss.com>


ENV ZENHOME /opt/zenoss
ENV PRODBIN_VERSION 5.2.0-develop
ENV METRICCONSUMER_VERSION 0.1.3
ENV CENTRALQUERY_VERSION 0.1.11
ENV ZEP_VERSION 2.0.3
ENV METRICSHIPPER_VERSION 1.1.2
ENV ZMINION_VERSION 1.3.2
ENV REDISMON_VERSION 231e8c4cd6dc61e1ab5f224917458721372fc423
ENV ZPROXY_VERSION 1.0.0 


# TODO add license file for core? License.zenoss and license.core.html - these will be overwritten by non-core installs as needed

ADD zope.conf global.conf zproxy_registration.conf /opt/zenoss/etc/

ADD zenoss_init install_lib.sh /opt/zenoss/bin/

# Initialize zenoss
ADD create_zenoss.sh /usr/bin/create_zenoss.sh

RUN chmod +x /usr/bin/create_zenoss.sh /opt/zenoss/bin/zenoss_init; /usr/bin/create_zenoss.sh



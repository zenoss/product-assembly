FROM zenoss/zenoss-centos-base:1.2.2

# maintener is redundant since base image is ours as well
#MAINTAINER Zenoss <dev@zenoss.com>


ENV ZENHOME=/opt/zenoss            \
    CENTRALQUERY_VERSION=0.1.12    \
    ICMPECHO_VERSION=1.0.1         \
    METRICCONSUMER_VERSION=0.1.4   \
    METRICSHIPPER_VERSION=1.1.2    \
    PRODBIN_VERSION=5.2.0-develop  \
    REDISMON_VERSION=0.1.2         \
    SERVICEMIGRATION_VERSION=1.0.0 \
    ZEP_VERSION=2.2.1              \
    ZMINION_VERSION=1.3.2          \
    ZPROXY_VERSION=1.0.0


ADD install_scripts /opt/zenoss/install_scripts/

# Split these 2 commands into separate RUN statements because of problems building w/Docker 1.11.1
RUN chmod +x /opt/zenoss/install_scripts/*
RUN /opt/zenoss/install_scripts/zenoss_component_install.sh

# TODO: fix this. The hubpasswd file should be in the service definition
ADD hubpasswd /opt/zenoss/etc/

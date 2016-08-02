FROM zenoss/zenoss-centos-base:1.2.1

# maintener is redundant since base image is ours as well
#MAINTAINER Zenoss <dev@zenoss.com>


ENV ZENHOME=/opt/zenoss            \
    CENTRALQUERY_VERSION=0.1.11    \
    ICMPECHO_VERSION=1.0.1         \
    METRICCONSUMER_VERSION=0.1.3   \
    METRICSHIPPER_VERSION=1.1.2    \
    PRODBIN_VERSION=5.2.0-develop  \
    REDISMON_VERSION=0.1.2         \
    SERVICEMIGRATION_VERSION=1.0.0 \
    ZEP_VERSION=2.2.1              \
    ZMINION_VERSION=1.3.2          \
    ZPROXY_VERSION=1.0.0


#TODO: These files belong in prodbin
ADD zope.conf global.conf zproxy_registration.conf /opt/zenoss/etc/

#TODO: this may belong in prodbin as well
ADD sitecustomize.py /opt/zenoss/lib/python/

ADD install_scripts /opt/zenoss/install_scripts/

# Split these 2 commands into separate RUN statements because of problems building w/Docker 1.11.1
RUN chmod +x /opt/zenoss/install_scripts/*
RUN /opt/zenoss/install_scripts/zenoss_component_install.sh

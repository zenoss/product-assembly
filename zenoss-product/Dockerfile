FROM zenoss/zenoss-centos-base:1.2.1

# maintener is redundant since base image is ours as well
#MAINTAINER Zenoss <dev@zenoss.com>


ENV ZENHOME=/opt/zenoss            \
    PRODBIN_VERSION=5.2.0-develop  \
    METRICCONSUMER_VERSION=0.1.3   \
    CENTRALQUERY_VERSION=0.1.11    \
    ZEP_VERSION=2.2.1              \
    METRICSHIPPER_VERSION=1.1.2    \
    ZMINION_VERSION=1.3.2          \
    REDISMON_VERSION=0.1.2         \
    ZPROXY_VERSION=1.0.0           \
    SERVICEMIGRATION_VERSION=1.0.0


# TODO add license file for core? License.zenoss and license.core.html - these will be overwritten by non-core installs as needed

ADD zope.conf global.conf zproxy_registration.conf /opt/zenoss/etc/

ADD sitecustomize.py /opt/zenoss/lib/python/

ADD install_scripts /opt/zenoss/install_scripts/

RUN chmod +x /opt/zenoss/install_scripts/* && /opt/zenoss/install_scripts/zenoss_component_install.sh



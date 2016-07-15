FROM zenoss/zenoss-centos-base:1.2.1-dev
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


# set the user for the container and so files from commands will be owned by zenoss user
USER zenoss

# TODO add license file for core? License.zenoss and license.core.html - these will be overwritten by non-core installs as needed

# Install Prodbin
RUN wget -qO- http://zenpip.zendev.org/packages/prodbin-${PRODBIN_VERSION}.tar.gz | tar -C ${ZENHOME} -xzv 

# TODO modify any conf files here or should they be pre modified in the prodbin tar.gz?  zope.conf

# Install MetricConsumer
RUN wget -qO- http://zenpip.zendev.org/packages/metric-consumer-app-${METRICCONSUMER_VERSION}-zapp.tar.gz | tar -C ${ZENHOME} -xzv

# Install CentralQuery
RUN wget -qO- http://zenpip.zendev.org/packages/central-query-${CENTRALQUERY_VERSION}-zapp.tar.gz | tar -C ${ZENHOME} -xzv

# Install zep
RUN wget -qO- http://nexus.zendev.org:8081/nexus/service/local/repositories/releases/content/org/zenoss/zep/zep-dist/${ZEP_VERSION}/zep-dist-${ZEP_VERSION}.tar.gz | tar -C ${ZENHOME} -xzv

# Install metricshipper
RUN wget -qO- http://zenpip.zendev.org/packages/metricshipper-${METRICSHIPPER_VERSION}.tgz | tar -C ${ZENHOME} -xzv

# Install zminion
RUN wget -qO- http://zenpip.zendev.org/packages/zminion-${ZMINION_VERSION}.tgz | tar -C ${ZENHOME} -xzv

# Install redis-mon
RUN wget -qO- http://zenpip.zendev.org/packages/redis-mon-${REDISMON_VERSION}.tgz | tar -C ${ZENHOME} -xzv

# Install zproxy
RUN wget -qO- http://zenpip.zendev.org/packages/zproxy-1.0.0.tar.gz | tar --strip-components=2 -C ${ZENHOME} -xzv

# TODO add upgrade templates to /root  - probably done in core/rm image builds

RUN source /opt/zenoss/bin/activate; pip install -i http://zenpip.zendev.org/simple/ --trusted-host zenpip.zendev.org  servicemigration

ADD zope.conf global.conf zproxy_registration.conf /opt/zenoss/etc/

ADD zenoss_init shared-functions.sh install-functions.sh zenoss_install_config /opt/zenoss/bin/

USER root
# Initialize zenoss
ADD init_zenoss.sh /usr/bin/init_zenoss.sh


RUN chmod +x /usr/bin/init_zenoss.sh /opt/zenoss/bin/zenoss_init; /usr/bin/init_zenoss.sh
FROM zenoss/zenoss-centos-base:1.2.2

# maintener is redundant since base image is ours as well
#MAINTAINER Zenoss <dev@zenoss.com>

ENV ZENHOME=/opt/zenoss

ADD install_scripts component_info /opt/zenoss/install_scripts/

# Split these 2 commands into separate RUN statements because of problems building w/Docker 1.11.1
RUN chmod +x /opt/zenoss/install_scripts/*
RUN /opt/zenoss/install_scripts/zenoss_component_install.sh

# TODO: fix this. The hubpasswd file should be in the service definition
ADD hubpasswd /opt/zenoss/etc/

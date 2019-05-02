FROM zendev/devimg:zenoss6


FROM ubuntu:bionic
MAINTAINER Zenoss <dev@zenoss.com>

ENV TERM xterm

#make sure we don't use multiverse repo
RUN RUN sed -i '/^deb.*multiverse/s/^/#\ /' /etc/apt/sources.list \
    && apt-get update -y \
    && apt-get install -y \
    vim-tiny           \
    file               \
    dnsutils           \
    telnet             \
    htop               \
    bash-completion    \
    netcat             \
    openssh-client     \
    zip                \
    traceroute         \
    wget               \
    lsof               \
    curl               \
    nano               \
    tree               \
    strace             \
    tcpdump            \
    net-tools          \
    unzip              \
    sysstat            \
    tmux               \
    iproute2           \
    iputils-ping       \
    less               \
    mariadb-server     \
    python2.7          \
    && apt-get clean

 
RUN ln -s /usr/bin/vi /usr/bin/vim && ln -s /usr/bin/python2.7 /usr/bin/python

RUN wget -qO- https://bootstrap.pypa.io/get-pip.py | python; \
    pip install --no-cache-dir supervisor && \
    ln -s /usr/local/bin/supervisord /bin/supervisord

RUN mkdir -p /opt/zenoss/log; rm /etc/mysql/mariadb.conf.d/50-server.cnf; rm -rf /var/lib/mysql/*
    
ADD my.cnf /etc/my.cnf

COPY --from=0 /var/lib/mysql /var/lib/mysql    

RUN chown -R mysql:mysql /var/lib/mysql

RUN mysqld_safe & until mysqladmin ping; do sleep 1; done && mysql_upgrade

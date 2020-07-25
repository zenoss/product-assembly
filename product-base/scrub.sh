#!/usr/bin/env bash

set -e

[ -f /usr/share/cracklib/pw_dict.pwd ] && gzip -9 /usr/share/cracklib/pw_dict.pwd
localedef --list-archive | grep -v en_US | xargs localedef --delete-from-archive
mv /usr/lib/locale/locale-archive /usr/lib/locale/locale-archive.tmpl
/usr/sbin/build-locale-archive
[ -d /usr/share/locale/en ] && mv /usr/share/locale/en /tmp
[ -d /usr/share/locale/en_US ] && mv /usr/share/locale/en_US /tmp
[ -f /usr/share/locale/locale.alias ] && mv /usr/share/locale/locale.alias /tmp
rm -rf /usr/share/locale/*
[ -d /tmp/en ] && mv /tmp/en /usr/share/locale
[ -d /tmp/en_US ] && mv /tmp/en_US /usr/share/locale
[ -f /tmp/locale.alias ] && mv /tmp/locale.alias /usr/share/locale
mv /usr/share/i18n/locales/en_US /tmp
rm -rf /usr/share/i18n/locales/*
mv /tmp/en_US /usr/share/i18n/locales/
rm -vf /etc/yum/protected.d/*
rm -rf /boot/*
echo "yum clean"
yum clean all
truncate -c -s 0 /var/log/yum.log
rm -rf /var/lib/yum/yumdb/*
rm -rf /var/lib/yum/history/*
rm -rf /var/cache/*
rm -rf /var/tmp/*
rm -rf /tmp/*
find /usr/lib/python2.7/site-packages -name '*.pyc' -delete


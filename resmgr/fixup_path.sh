#!/bin/bash

PATH=$(getconf PATH)

# Copied from /etc/profile
pathmunge() {
	case ":${PATH}:" in
		*:"$1":*)
			;;
		*)
			if [ "$2" = "after" ] ; then
				PATH=$PATH:$1
			else
				PATH=$1:$PATH
			fi
	esac
}

pathmunge /usr/local/bin after
pathmunge /bin after
pathmunge /usr/local/sbin after
pathmunge /usr/sbin after

pathmunge /opt/activepython/bin
pathmunge /opt/zenoss/var/ext/bin
pathmunge /opt/zenoss/bin

sed -i -e "0,/export PATH=.*/ s~export PATH=.*~export PATH=${PATH}~" /home/zenoss/.bashrc

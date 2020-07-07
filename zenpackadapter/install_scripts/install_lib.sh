function get_var {
    VAR_NAME=$1

    OUTPUT=`su - zenoss  -c "$ZENHOME/bin/zenglobalconf -p $VAR_NAME"`
    if [ $? != 0 ]; then
       exit 1
    fi
    echo $OUTPUT
}

export ZENHOME=/opt/zenoss

shebang() {
   # replace the first line of any python sh-bang script with
   # #!$ZENHOME/bin/python
   find $ZENHOME/bin \( -type f -o -type l \) -exec readlink -e '{}' \; | \
      egrep -v "zensocket|metrics" | \
      xargs sed -i '1,1 s%#!.*python$%#!'"$ZENHOME/bin/python"'%'
}


# Set permission and ownership under zenhome
fix_zenhome_owner_and_group()
{
    echo "Setting zenoss owner in /opt/zenoss..."
    set -e
    chown -Rf zenoss:zenoss /opt/zenoss/*
    echo "Setting permissions on zensocket."
    chown root:zenoss /opt/zenoss/bin/zensocket
    chmod 04750 /opt/zenoss/bin/zensocket
}

# Set permissions under /etc
copy_missing_etc_files()
{
    echo "Copying missing files from $ZENHOME/etc to /etc"
    set -e
    sudoersd_files=("zenoss_dmidecode" "zenoss_nmap" "zenoss_ping" "zenoss_rabbitmq_stats")
    for f in "${sudoersd_files[@]}"
    do
        if [ -f /etc/sudoers.d/"$f" ]
        then
            echo "/etc/sudoers.d/$f already exists"
        else
            if [ -f $ZENHOME/etc/sudoers.d/$f ]
            then
                echo "Copying from $ZENHOME/etc/sudoers.d/$f to /etc/sudoers.d/$f"
                cp -p $ZENHOME/etc/sudoers.d/$f /etc/sudoers.d/$f
            else
                echo "$ZENHOME/etc/sudoers.d/$f not found, skipping"
            fi
        fi
    done
}

# Set permissions under /etc
fix_etc_permissions()
{
    echo "Setting correct permissions on files under /etc/"
    set -e
    sudoersd_files=("zenoss_dmidecode" "zenoss_nmap" "zenoss_ping" "zenoss_rabbitmq_stats")
    for f in "${sudoersd_files[@]}"
    do
        if [ -f /etc/sudoers.d/"$f" ]
        then
            echo "Setting permissions on /etc/sudoers.d/$f"
            chmod 440 /etc/sudoers.d/"$f"
            echo "Changing owner of /etc/sudoers.d/$f to root:root"
            chown root:root /etc/sudoers.d/$f
        else
            echo "/etc/sudoers.d/$f not found"
        fi
    done
    echo "Setting permissions on /etc/sudoers.d/"
    chmod 750 /etc/sudoers.d
}


DESIRED_OWNERSHIP=${DESIRED_OWNERSHIP:-"zenoss:zenoss"}

function die { echo "ERROR: ${*}" >&2; exit 1; }

function ensure_dir
{
    local dirs="$@"
    for dirpath in "$@"; do
        # ensure directory exists
        if [[ ! -d "$dirpath" ]]; then
            \mkdir -p "$dirpath" || die "unable to create dir: $dirpath"
        fi

        # ensure at least one file in the directory for dfs
        if [[ $(\ls -a1 "$dirpath"|\wc -l) -le 2 ]]; then   # an empty dir will always have '.' and '..'
            \touch "$dirpath/README.txt" || die "unable to create file: $dirpath/README.txt"
        fi

        # ensure ownership
        if [[ -n "$DESIRED_OWNERSHIP" ]]; then
            \chown -R "$DESIRED_OWNERSHIP" "$dirpath" || die "unable to chown to $DESIRED_OWNERSHIP for $dirpath"
        fi
    done
}

function ensure_dfs_dirs
{
    # assuming ImageID comes before ContainerPath in each service.json
    # the paths listed below are generated from a subset of:
    #   egrep -r 'ImageID|ContainerPath' ~/src/europa/build/services/ |
    #       awk '/ImageID/{img=$NF} /ContainerPath/ {print img, $NF}' | sort -u
    ensure_dir \
        "/opt/zenoss/log/jobs" \
        "/opt/zenoss/log" \
        "/opt/zenoss/var/ext" \
        "/home/zenoss/.ssh" \
        "/opt/zenoss/export" \
        "/opt/zenoss/patches" \
        "/opt/zenoss/.ZenPacks" \
        "/opt/zenoss/.pc" \
        "/var/zenoss/ZenPacks" \
        "/var/zenoss/ZenPackSource"
}

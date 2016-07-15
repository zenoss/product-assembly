##############################################################################
# 
# Copyright (C) Zenoss, Inc. 2006, all rights reserved.
# 
# This content is made available according to terms specified in
# License.zenoss under the directory where your Zenoss product is installed.
# 
##############################################################################


#
# functions that are shared (referenced) by both the build-functions
# and install-functions.  this is logic that we don't want to link to
# installation or building because it is actually common to both of them
#

#TOPDIR=`dirname "$0"`
#TOPDIR=`cd "$TOPDIR" && pwd`
#export LD_LIBRARY_PATH=$ZENHOME/lib:$LD_LIBRARY_PATH

# reset our stty to be sane
#cleanup()
#{
#    stty sane 2>/dev/null
#}

# print the error message provided and then exit with a 1 return code
fail()
{
    echo $*
    exit 1
}

# disable echo
#noecho()
#{
#    stty -echo 2>/dev/null
#}

# enable echo
#echook()
#{
#    echo
#    stty echo 2>/dev/null
#}

# replace SEARCH with REPLACE in $FILE using sed
#replace() {
#    SEARCH=$1
#    REPLACE=$2
#    FILE=$3
#    TEMP=/tmp/`basename $FILE`

#    sed -e "s%${SEARCH}%${REPLACE}%g" < ${FILE} > ${TEMP}
#    mv ${TEMP} ${FILE}
#}

# tests to see if VARIABLE is set in FILE.  if it is set don't do
# anything.  if it is not set then set it to the VALUE provided.
#append() {
#    VARIABLE=$1
#    VALUE=$2
#    FILE=$3

#    TESTVALUE=`grep ${VARIABLE} ${FILE}`
#    if [ -z "${TESTVALUE}" ]; then
#        echo "export $VARIABLE=\"${VALUE}\"" >> ${FILE}
#    fi
#}

shebang() {
   # replace the first line of any python sh-bang script with
   # #!$ZENHOME/bin/python
   find $ZENHOME/bin \( -type f -o -type l \) -exec readlink -e '{}' \; | \
      egrep -v "zensocket|pyraw" | \
      xargs sed -i '1,1 s%#!.*python$%#!'"$ZENHOME/bin/python"'%'
}

# convert #.#.#.# into integer for numerical comparison
#get_version() { 
#    dottedVersion=$1
#    echo "${dottedVersion}" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
#}

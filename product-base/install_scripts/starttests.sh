#!/bin/sh
#
# Start Zenoss and run all platform and ZenPack tests
#
set -e
set -x

${ZENHOME}/install_scripts/startZenossForTests.sh

su - zenoss  -c "${ZENHOME}/bin/runtests $*"



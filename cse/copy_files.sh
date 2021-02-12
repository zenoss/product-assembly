#!/bin/bash

cp /src/zphistory.json /src/licenses.cse.html /src/License.zenoss /opt/zenoss/
cp /src/licenses.cse.html /opt/zenoss/Products/ZenUI3/docs/licenses.html

cp /src/zenpacks.json /opt/zenoss/install_scripts/
cp /src/zenpacks_artifact.log /opt/zenoss/log/

mkdir -p /opt/zenoss/bin/healthchecks
cp /src/zing_connector_answering /opt/zenoss/bin/healthchecks/

mkdir -p /opt/zenoss/packs
cp /src/zenpacks/* /opt/zenoss/packs/

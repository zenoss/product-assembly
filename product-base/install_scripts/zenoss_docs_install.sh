#!/bin/sh

set -e
set -x

if [ $# -ne 1 ]
then
   echo "ERROR: $# is an invalid number of arguments; only 1 argument allowed"
   exit 1
else
   if [ "$1" = "core" ]
   then
      ARTIFACT_NAME="docs-core"
   elif [ "$1" = "enterprise" ] 
   then
      ARTIFACT_NAME="docs-enterprise"
   else
      echo "$1 not a valid argument value; use 'core' or 'enterprise'"
      exit 1
   fi
fi

function artifactDownload
{
   local artifact="$@"
   su - zenoss -c "${ZENHOME}/install_scripts/artifact_download.py --out_dir ${ZENHOME}/docs ${ZENHOME}/install_scripts/doc_versions.json ${artifact} --reportFile ${ZENHOME}/log/zenoss_doc_artifact.log"
}

artifactDownload ${ARTIFACT_NAME}

echo "Doc Artifact Report"
cat ${ZENHOME}/log/zenoss_doc_artifact.log

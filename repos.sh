#!/bin/bash

if [ -z "$1" ]; then
    FILE=".repos.json"
else
    FILE=$1
fi

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

set -e

cat ${DIR}/supplementary.json > ${FILE}
${DIR}/artifact_download.py ${DIR}/component_versions.json --git_output ${FILE} --append
${DIR}/artifact_download.py ${DIR}/zenpack_versions.json --git_output ${FILE} --append

#!/usr/bin/env bash
#
# http://platform-jenkins.zenoss.eng/job/product-assembly/job/<branch>/image-promote/configure
#

#
# Environment Variables required by this script:
#
# TARGET_PRODUCT       - required; identifies the target product
#                        (e.g. 'core', 'resmgr', 'ucspm', etc)
# PRODUCT_BUILD_NUMBER - the product build to be promoted.
#                        Only required if FROM_MATURITY is unstable
# ZENOSS_VERSION       - required; the 3-digit Zenoss product version number
#                        (e.g. 5.2.0)
# ZENOSS_SHORT_VERSION - required; the 2-digit Zenoss product number
#                        (e.g. 5.2)
# FROM_MATURITY        - required; the maturity level of the build that is
#                        being promoted. Must be one of unstable, testing, stable
# FROM_RELEASEPHASE    - The release phase of the from build (e.g. "RC1", "BETA", etc)
#                        Only applies when FROM_MATURITY is testing
# TO_MATURITY          - required; the maturity level of the build that will
#                        be created. Must be one of testing, or stable
# TO_RELEASEPHASE      - The release phase of the promoted build.
#                        If TO_MATURITY is testing, then this value is typically something "BETA" or "RC1".
#                        If TO_MATURITY is stable, then this value must be a single digit such as 1.
#

if [ -z "${TARGET_PRODUCT}" ]
then
    echo "ERROR: Missing required argument - TARGET_PRODUCT"
    exit 1
elif [ -z "${ZENOSS_VERSION}" ]
then
    echo "ERROR: Missing required argument - ZENOSS_VERSION"
    exit 1
elif [ -z "${ZENOSS_SHORT_VERSION}" ]
then
    echo "ERROR: Missing required argument - ZENOSS_SHORT_VERSION"
    exit 1
elif [ -z "${FROM_MATURITY}" ]
then
    echo "ERROR: Missing required argument - FROM_MATURITY"
    exit 1
elif [ -z "${TO_MATURITY}" ]
then
    echo "ERROR: Missing required argument - TO_MATURITY"
    exit 1
elif [ -z "${TO_RELEASEPHASE}" ]
then
    echo "ERROR: Missing required argument - TO_RELEASEPHASE"
    exit 1
elif [[ "$TARGET_PRODUCT" == "ucspm" && "$TO_MATURITY" == "stable" && -z "${PRODUCT_BUILD_NUMBER}" ]]
then
    echo "ERROR: Missing required argument - PRODUCT_BUILD_NUMBER"
    echo "       When TARGET_PRODUCT=ucspm and TO_MATURITY=stable, PRODUCT_BUILD_NUMBER is required."
    exit 1
elif [[ "$FROM_MATURITY" != "unstable" && "$FROM_MATURITY" != "testing" && "$FROM_MATURITY" != "stable" ]]
then
    echo "ERROR: FROM_MATURITY=$FROM_MATURITY is invalid; must be one of unstable, testing or stable"
    exit 1
elif [[ "$FROM_MATURITY" == "unstable" && -z "${PRODUCT_BUILD_NUMBER}" ]]
then
    echo "ERROR: Missing required argument - PRODUCT_BUILD_NUMBER"
    echo "       When FROM_MATURITY=unstable, PRODUCT_BUILD_NUMBER is required."
    exit 1
elif [[ "$FROM_MATURITY" == "testing" && -z "${FROM_RELEASEPHASE}" ]]
then
    echo "ERROR: Missing required argument - FROM_RELEASEPHASE"
    echo "       When FROM_MATURITY=testing, FROM_RELEASEPHASE is required."
    exit 1
elif [[ "$TO_MATURITY" != "testing" && "$TO_MATURITY" != "stable" ]]
then
    echo "ERROR: TO_MATURITY=$TO_MATURITY is invalid; must be one of testing or stable"
    exit 1
fi

echo "TARGET_PRODUCT=${TARGET_PRODUCT}"
echo "PRODUCT_BUILD_NUMBER=${PRODUCT_BUILD_NUMBER}"
echo "ZENOSS_VERSION=${ZENOSS_VERSION}"
echo "ZENOSS_SHORT_VERSION=${ZENOSS_SHORT_VERSION}"
echo "FROM_MATURITY=${FROM_MATURITY}"
echo "FROM_RELEASEPHASE=${FROM_RELEASEPHASE}"
echo "TO_MATURITY=${TO_MATURITY}"
echo "TO_RELEASEPHASE=${TO_RELEASEPHASE}"

set -e
set -x

repo_tag() {
    target_product="$1"        # examples: core, resmgr
    maturity="$2"      # examples: stable, testing, unstable
    phase="$3"         # examples for testing: BETA1, CR13, GA
                       # examples for stable: 1, 2, 3
    # repo name: e.g., zenoss/resmgr_5.0
    repo="zenoss/${target_product}_${ZENOSS_SHORT_VERSION}"
    case $maturity in
        unstable )
            # e.g., 5.0.0_1234_unstable
            tag="${ZENOSS_VERSION}_${PRODUCT_BUILD_NUMBER}_unstable"
            ;;
        testing )
            # e.g., 5.0.0_CR13
            tag="${ZENOSS_VERSION}_${phase}"
            ;;
        stable )            
            if [ "$TARGET_PRODUCT" == "ucspm" ]
            then
                # BLD-127 UCS-PM Released Artifacts contain build number in the file name
                tag="${ZENOSS_VERSION}_${PRODUCT_BUILD_NUMBER}"
            else
                # e.g., 5.0.0_2
                tag="${ZENOSS_VERSION}_${phase}"
            fi
            ;;
        * )
            echo "maturity value '$maturity' is invalid"
            exit 1
            ;;
    esac

    echo ${repo}:${tag}
}

retry() {
    local maxtries=$1; shift
    local sleeptime=$1; shift
    local command="$@"
    local tries=0
    until [ ${tries} -ge ${maxtries} ]; do
        set +e
        ${command};
        local result=$?;
        set -e
        [ ${result} = 0 ] && break
        tries=$[$tries+1]
        echo sleeping $sleeptime before retry
        sleep $sleeptime
    done
    return ${result}
}

rm -rf output
mkdir output
# No quoting TARGET_PRODUCTS below in order to split the string on spaces
FROM_STRING=$(repo_tag "$TARGET_PRODUCT" "$FROM_MATURITY" "$FROM_RELEASEPHASE")
echo "Pulling 'from' docker image $FROM_STRING"
retry 4 5s docker pull "$FROM_STRING"

# make sure there isn't already an image with this tag on docker hub
TO_STRING=$(repo_tag "$TARGET_PRODUCT" "$TO_MATURITY" "$TO_RELEASEPHASE")
echo "Verifying there is no existing 'to' docker image $TO_STRING"
docker pull "$TO_STRING" &> /dev/null && echo "Image with tag $TO_STRING already exists on docker hub" && exit 1

# tag the image with the new tag and push
docker tag "$FROM_STRING" "$TO_STRING"
retry 10 30s docker push "$TO_STRING"
if [[ "$TO_MATURITY" = "stable" ]]; then
    echo "Pulling image to ensure it is available ..."
    retry 4 5s docker pull "$TO_STRING"    # ensure new tag is available
    retry 4 5s docker pull "$FROM_STRING"  # allow a little time for dockerhub
    LATEST_STRING="$(echo $TO_STRING | cut -f1 -d:):${ZENOSS_VERSION}"
    docker pull "$LATEST_STRING" &> /dev/null && echo "Image with tag $LATEST_STRING already exists on docker hub" && exit 1

    docker tag "$FROM_STRING" "$LATEST_STRING"
    retry 10 30s docker push "$LATEST_STRING"
fi

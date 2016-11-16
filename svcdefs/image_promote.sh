#!/usr/bin/env bash
#
# http://platform-jenkins.zenoss.eng/job/product-assembly/job/support-5.2.x/image-promote/configure
#

# FIXME: Add doc for variables

# Always required:
# TARGET_PRODUCT
# PRODUCT_BUILD_NUMBER - required if FROM_MATURITY == unstable
# ZENOSS_VERSION
# ZENOSS_SHORT_VERSION
# FROM_MATURITY - must be one of unstable, testing, stable
# FROM_RELEASEPHASE - required if FROM_MATURITY != unstable
# TO_MATURITY - must be one of testing, or stable
# TO_RELEASEPHASE - for stable, should be single digit matching the RPM


# FIXME: Add checks for required variables

# FIXME: Log all variables
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
            # e.g., 5.0.0_2
            tag="${ZENOSS_VERSION}_${phase}"
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
#retry 4 5s docker pull "$FROM_STRING"

# make sure there isn't already an image with this tag on docker hub
TO_STRING=$(repo_tag "$TARGET_PRODUCT" "$TO_MATURITY" "$TO_RELEASEPHASE")
echo "Verifying there is no existing 'to' docker image $TO_STRING"
#docker pull "$TO_STRING" &> /dev/null && echo "Image with tag $TO_STRING already exists on docker hub" && exit 1

exit 0

# tag the image with the new tag and push
docker tag -f "$FROM_STRING" "$TO_STRING"
retry 10 30s docker push "$TO_STRING"
if [[ "$TO_MATURITY" = "stable" ]]; then
    echo "Pulling image to ensure it is available ..."
    retry 4 5s docker pull "$TO_STRING"    # ensure new tag is available
    retry 4 5s docker pull "$FROM_STRING"  # allow a little time for dockerhub
    LATEST_STRING="$(echo $TO_STRING | cut -f1 -d:):${ZENOSS_VERSION}"
    docker tag -f "$FROM_STRING" "$LATEST_STRING"
    retry 10 30s docker push "$LATEST_STRING"
fi



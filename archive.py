# upload_step() {
#     # $1: source pattern
#     # $2: target path
#     # copying a quoted source pattern to the directory relative to $ARTIFACTS_PATH
#     # also list its md5sum to MD5SUMS.txt
#     # the function ignores and skips thru all errors
#     scp $1 "${ARTIFACTS_SERVER}:${ARTIFACTS_PATH}/$2" || :
# md5sum $1 | ssh ${ARTIFACTS_SERVER} "(flock -w 300 9 || exit 23; cat >> ${ARTIFACTS_PATH}/$2/MD5SUMS.txt; ) 9>${ARTIFACTS_PATH}/$2/md5.lock" || :
# }

import argparse
import os
import sys

def main(options):
    if not options.service_def and not options.offline_images:
        sys.exit("no options provided")

    ARTIFACTS_SERVER="artifacts.zenoss.eng"
    print os.environ
    ARTIFACTS_PATH = "builds/{SHORT_VERSION}.x/{MATURITY}/{ZENOSS_VERSION}/{BUILD_NUMBER}/{TARGET_PRODUCT}/build/"
    ARTIFACTS_PATH = ARTIFACTS_PATH.format(**os.environ)
    if options.service_def:
        print "Archive artifact to %s" % ARTIFACTS_PATH
    if options.offline_images:
        pass

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Copy artifacts to artifacts server')

    parser.add_argument('--service-def', action="store_true",
                        help='push service definition')

    parser.add_argument('--offline-images', action="store_true",
                        help='push offline docker images')

    options = parser.parse_args()
    main(options)

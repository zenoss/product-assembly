#!/usr/bin/env python
import argparse
import json

def main(args):
    versions = json.load(args.zp_versions)
    args.zp_versions.close()
    def zpName(versionInfo):
        return versionInfo["name"]
    print json.dumps(sorted(versions, key=zpName), indent=4, sort_keys=True, separators=(',', ': '))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Sort zenpack version json')
    parser.add_argument('zp_versions', type=file, nargs="?", default="zenpack_versions.json",
                        help='json file with list of zenpacks')
    args = parser.parse_args()
    main(args)

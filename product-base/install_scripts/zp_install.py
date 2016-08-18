#!/usr/bin/env python
import argparse
import fnmatch
import json
import os
import subprocess
import sys

def main(args):
    manifest = json.load(args.zp_manifest)
    for zpName in manifest['install_order']:
        zpGlob = '%s*' % zpName
        dirList = os.listdir(args.zpDir)
        zpFileName = fnmatch.filter(dirList, zpGlob)
        if not zpFileName or len(zpFileName) != 1:
            # TODO: this needs to raise if zenpack was not found
            # raise Exception("zenpack file not found for zenpack: %s" % zpName)
            print "zenpack file not found for zenpack: %s" % zpName
        else:
            zpFile = os.path.join(args.zpDir, zpFileName[0])
            print "Installing zenpack: %s %s" % (zpName, zpFile)
            sys.stdout.flush()
            subprocess.check_call(['zenpack', '--install', zpFile])


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Install zenpacks from the manifest ')
    parser.add_argument('zp_manifest', type=file,
                        help='json file with list of zenpacks to be installed')
    parser.add_argument('zpDir', type=str, nargs="?", default=".",
                        help='directory where zenpacks are, defaults to pwd')
    args = parser.parse_args()
    main(args)

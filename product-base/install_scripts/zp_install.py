#!/usr/bin/env python
import argparse
import fnmatch
import json
import os
import subprocess
import sys

def main(args):
    manifest = json.load(args.zp_manifest)
    blacklist = []
    if args.zp_blacklist:
        print "ZenPack blacklist='%s'" % args.zp_blacklist
        with open(args.zp_blacklist) as blacklistFile:
            blacklist = json.load(blacklistFile)

    for zpName in manifest['install_order']:
        if zpName in blacklist:
            print "Skipping blacklisted ZenPack %s" % zpName
            continue

        zpGlob = '%s-*' % zpName
        if args.link:
            #exact match for link install
            zpGlob = zpName
        dirList = os.listdir(args.zpDir)
        zpFileName = fnmatch.filter(dirList, zpGlob)
        if not zpFileName:
            raise Exception("zenpack file not found for zenpack: %s" % zpName)
        elif len(zpFileName) != 1:
            raise Exception("Found multiple files for zenpack: %s" % zpName)
        else:
            zpFile = os.path.join(args.zpDir, zpFileName[0])
            cmd = ['zenpack', '--install', zpFile]
            if args.link:
                print "Installing zenpack in link mode: %s %s" % (zpName, zpFile)
                cmd.append('--link')
            else:
                print "Installing zenpack: %s %s" % (zpName, zpFile)
            sys.stdout.flush()
            subprocess.check_call(cmd)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Install zenpacks from the manifest ')
    parser.add_argument('zp_manifest', type=file,
                        help='json file with list of zenpacks to be installed')
    parser.add_argument('zpDir', type=str, nargs="?", default=".",
                        help='directory where zenpacks are, defaults to pwd')
    parser.add_argument('--link', action="store_true",
                        help='link-install the zenpacks')
    parser.add_argument('zp_blacklist', type=str, nargs="?",
                        help='json file with list of zenpacks to be blacklisted from the install')
    args = parser.parse_args()
    main(args)

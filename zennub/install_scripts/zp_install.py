#!/usr/bin/env python
import argparse
import fileinput
import fnmatch
import json
import os
import pkg_resources
import subprocess
import sys

ignore_dependencies = [
    "ZenPacks.zenoss.EnterpriseReports",
    "ZenPacks.zenoss.EnterpriseCollector",
    "ZenPacks.zenoss.DistributedCollector"
]


def main(args):
    os.environ["PRODUCT_ASSEMBLY"] = "1"
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

            if args.link:
                fix_dependencies_setup(zpName, zpFile)
                cmd = ['/opt/zenoss/bin/python', 'setup.py', 'develop', '--site-dirs', '/opt/zenoss/ZenPacks', '-d', '/opt/zenoss/ZenPacks']
                print "Installing zenpack: %s %s" % (zpName, zpFile)
                sys.stdout.flush()
                subprocess.check_call(cmd, env=os.environ, cwd=zpFile)
            else:
                cmd = ['/opt/zenoss/bin/easy_install', '--site-dirs', '/opt/zenoss/ZenPacks', '-d', '/opt/zenoss/ZenPacks', '--allow-hosts=None', '--no-deps', zpFile]
                print "Installing zenpack: %s %s" % (zpName, zpFile)
                sys.stdout.flush()
                subprocess.check_call(cmd, env=os.environ)
                fix_dependencies_installed(zpName)


def fix_dependencies_setup(zpName, zpDir):
    file = os.path.join(zpDir, 'setup.py')
    f = fileinput.input(files=(file), inplace=True, backup='.bak')
    for line in f:
        for dep in ignore_dependencies:
            if dep in line and not line.startswith("#"):
                line = "# " + line
        print line,
    f.close()

def fix_dependencies_installed(zpName):
    cmd = ['/opt/zenoss/install_scripts/zp_fix_dependencies.py', zpName, ",".join(ignore_dependencies)]
    sys.stdout.flush()
    subprocess.check_call(cmd, env=os.environ)


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

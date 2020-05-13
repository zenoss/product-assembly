#!/usr/bin/env python
import argparse
import fileinput
import pkg_resources

def main(args):
    zp = pkg_resources.Requirement.parse(args.zpName)
    if not pkg_resources.resource_exists(zp, 'EGG-INFO/requires.txt'):
        return

    file = pkg_resources.resource_filename(zp, 'EGG-INFO/requires.txt')
    f = fileinput.input(files=(file), inplace=True, backup='.bak')
    for line in f:
        skip = False
        for dep in args.remove.split(","):
            if line.startswith(dep):
                skip = True
        if not skip:
            print line,
    f.close()

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Remove specific dependencies from an installed zenpack')
    parser.add_argument('zpName', type=str,
                        help='zenpack name')
    parser.add_argument('remove', type=str,
                        help='comma-separated list of zenpacks to filter out of dependencies')
    args = parser.parse_args()
    main(args)

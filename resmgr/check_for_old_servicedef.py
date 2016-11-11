#!/usr/bin/env python


MIN_VERSION = "5.0.6"

import json
import subprocess


class ServicedefParseError(Exception):
    pass


def serviced(*args, **kwargs):
    cmd = ["serviced"]
    cmd.extend(args)
    proc = subprocess.Popen(cmd,
                            stdin=subprocess.PIPE,
                            stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE)
    stdout, stderr = proc.communicate(kwargs.get("stdin"))
    return '\n'.join((stdout, stderr)).strip()

def check_servicedef_too_old(rootservice):
    root = json.loads(serviced('service', 'list', '-v', rootservice))

    return root["Version"] < MIN_VERSION

if __name__ == '__main__':
    from argparse import ArgumentParser
    import sys
    ap = ArgumentParser()
    ap.add_argument("rootservice", type=str)
    args = ap.parse_args()
    try:
        if check_servicedef_too_old(args.rootservice):
            sys.exit(1)
    except ServicedefParseError:
        sys.exit(1)

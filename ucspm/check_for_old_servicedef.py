#!/usr/bin/env python


MIN_VERSION = "5.1.0"

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

def get_servicedef():
    try:
        return json.loads(serviced('service', 'list', '-v'))
    except ValueError as ve:
        # JSON decode error
        raise ServicedefParseError(str(ve))

def check_servicedef_too_old():
    services = get_servicedef()
    # Find root service
    root_id = ""
    for service in services:
        if service["ParentServiceID"] == "":
            root_id = service["ID"]
            break

    if not root_id:
        raise ServicedefParseError("No root node detected.")

    root = json.loads(serviced('service', 'list', '-v', root_id))

    return root["Version"] < MIN_VERSION


if __name__ == '__main__':
    import sys
    try:
        if check_servicedef_too_old():
            sys.exit(1)
    except ServicedefParseError:
        sys.exit(1)

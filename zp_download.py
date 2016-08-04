#!/usr/bin/env python
import argparse
import hashlib
import json
import os
import shutil
import tempfile
import urllib2
import urlparse

from itertools import chain


def md5Hash(filePath):
    if not os.path.exists(filePath):
        raise Exception("file does not exist: %s" % filePath)
    print("file exists %s" % filePath)
    md5 = hashlib.md5()
    with open(filePath, "rb") as f:
        bytes = f.read(4096)
        while bytes:
            md5.update(bytes)
            bytes = f.read(4096)

    return md5.hexdigest()
def urlDownload(zpVersionInfo, outdir):
    tmpFile = None
    try:
        url = zpVersionInfo['URL']
        parsed = urlparse.urlparse(url)
        if not parsed.scheme or not parsed.netloc or not parsed.path:
            print("Skipping download for %s" % zpVersionInfo)
            # TODO: this needs to raise if URL is invalid or not set
            # raise Exception("url invalid: %s" % zpVersionInfo)
        else:
            print("Downloading %s" % url)
            response = urllib2.urlopen(url)
            finalDestination = (os.path.join(outdir, os.path.basename(url)))
            downloadDestination = finalDestination
            sig = None
            tmpFile = None
            if os.path.exists(finalDestination):
                print "existing found, computing hash: %s" % finalDestination
                tmpFile = tempfile.NamedTemporaryFile()
                downloadDestination = tmpFile.name
                sig = md5Hash(finalDestination)

            with open(downloadDestination, "wb") as local_file:
                print "Saving artifact to %s" % downloadDestination
                local_file.write(response.read())
            
            # check if we detected a file already
            if sig:
                # get md5 of downloaded file to compare to
                newSig = md5Hash(downloadDestination)
                print sig
                if newSig != sig:
                    print("Replacing file: %s" % finalDestination)
                    shutil.move(downloadDestination, finalDestination)
    finally:
        if tmpFile:
            tmpFile.close()

# downloaders is a dictionary of "type" to function that can
downloaders = {"download": urlDownload}


def main(args):
    versions = json.load(args.zp_versions)
    versionsMap = {}
    for version in versions:
        versionsMap[version['name']]=version

    manifest = json.load(args.zp_manifest)
    outdir = args.outDir
    if not os.path.isdir(outdir):
        raise Exception("Path is not a directory: %s" % outdir)

    for zpName in chain(manifest['install_order'], manifest['included_not_installed']):
        if zpName not in versionsMap:
            raise Exception("zenpack version information not found: %s" % zpName)
        zpVersionInfo = versionsMap[zpName]
        if zpVersionInfo['type'] not in downloaders:
            raise Exception("Cannot not download zenpack, unknown type: %s %s" % (zpName, zpVersionInfo['type']))
        downloaders[zpVersionInfo['type']](zpVersionInfo, outdir)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Download zenpacks.')
    parser.add_argument('zp_versions', type=file,
                        help='json file with zenpack versions and locations')
    parser.add_argument('zp_manifest', type=file,
                        help='json file with list of zenpacks to be packaged or installed')
    parser.add_argument('outDir', type=str, nargs="?", default=".",
                        help='directory to download files')

    args = parser.parse_args()
    main(args)

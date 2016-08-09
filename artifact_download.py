#!/usr/bin/env python

import argparse
import fnmatch
import hashlib
import json
import os
import shutil
import sys
import tempfile
import urllib2
import urlparse

from itertools import chain


def md5Hash(filePath):
    if not os.path.exists(filePath):
        raise Exception("file does not exist: %s" % filePath)
    md5 = hashlib.md5()
    with open(filePath, "rb") as f:
        bytes = f.read(4096)
        while bytes:
            md5.update(bytes)
            bytes = f.read(4096)

    return md5.hexdigest()


def urlDownload(versionInfo, outdir):
    url = versionInfo['URL']
    downloadArtifact(url, outdir)

def downloadArtifact(url, outdir):
    parsed = urlparse.urlparse(url)
    if not parsed.scheme or not parsed.netloc or not parsed.path:
        print("Skipping download for %s" % url)
        # TODO: this needs to raise if URL is invalid or not set
        # raise Exception("url invalid: %s" % url)
    else:
        print("Downloading %s" % url)
        response = urllib2.urlopen(url)
        finalDestination = (os.path.join(outdir, os.path.basename(url)))
        downloadDestination = finalDestination
        sig = None
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
                shutil.copy(downloadDestination, finalDestination)

def jenkinsDownload(versionInfo, outdir):
    artifactName = versionInfo['name']
    jenkinsInfo = versionInfo['jenkinsInfo']

    job = jenkinsInfo['job']
    server = jenkinsInfo['server']
    baseURL = "%s/job/%s/lastSuccessfulBuild" % (server, job)
    if "subModule" in jenkinsInfo and jenkinsInfo['subModule'] != "":
        baseURL = "%s/%s" % (baseURL, jenkinsInfo['subModule'])

    # First we have to query the API to determine which artifacts are available
    queryURL = "%s/api/json?tree=artifacts[*]" % baseURL
    parsed = urlparse.urlparse(queryURL)
    if not parsed.scheme or not parsed.netloc or not parsed.path:
        print("Skipping download for %s" % queryURL)

    response = json.loads(urllib2.urlopen(queryURL).read())
    artifacts = response['artifacts']
    if len(artifacts) == 0:
        raise Exception("No artifacts available for lastSuccessfulBuild of %s job %s on Jenkins server %s" % (artifactName, job, server))

    # Secondly, loop through the list of build artifacts and download any that match the specified pattern
    nDownloaded = 0
    pattern = jenkinsInfo['pattern']
    for artifact in artifacts:
        fileName = artifact['fileName']
        if fnmatch.fnmatch(fileName, pattern):
            relativePath = artifact['relativePath']
            downloadURL = "%s/artifact/%s" % (baseURL, relativePath)
            downloadArtifact(downloadURL, outdir)
            nDownloaded += 1

    if nDownloaded == 0:
        raise Exception("No artifacts downloaded from lastSuccessfulBuild of %s job %s on Jenkins server %s" % (artifactName, job, server))


# downloaders is a dictionary of "type" to function that can
downloaders = {
    "download": urlDownload,
    "jenkins": jenkinsDownload
}


def downloadArtifacts(versionsFile, artifacts, downloadDir):
    versions = json.load(versionsFile)
    versionsMap = {}
    for version in versions:
        versionsMap[version['name']]=version


    if not os.path.isdir(downloadDir):
        raise Exception("Path is not a directory: %s" % downloadDir)

    for artifactName in artifacts:
        if artifactName not in versionsMap:
            raise Exception("Artifact version information not found: %s" % artifactName)
        versionInfo = versionsMap[artifactName]
        if versionInfo['type'] not in downloaders:
            raise Exception("Cannot not download artifact, unknown download type: %s %s" % (artifactName, versionInfo['type']))
        downloaders[versionInfo['type']](versionInfo, downloadDir)


def main(args):

    artifacts = args.artifacts

    if args.zp_manifest != None:
        manifest = json.load(args.zp_manifest)
        artifacts = list(chain(manifest['install_order'], manifest['included_not_installed']))

    if not artifacts or len(artifacts) == 0:
        sys.exit("No artifacts to download")

    downloadArtifacts(args.versions, artifacts, args.out_dir)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Download artifacts')

    parser.add_argument('versions', type=file,
                        help='json file with versions and locations')

    parser.add_argument('--out_dir', type=str, default=".",
                        help='directory to download files')

    parser.add_argument('--zp_manifest', type=file,
                        help='json file with list of zenpacks to be packaged or installed')

    parser.add_argument('artifacts', nargs='*',
                        help='artifacts to download')

    args = parser.parse_args()
    main(args)

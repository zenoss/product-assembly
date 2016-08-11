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


def urlDownload(versionInfo, outdir, downloadReport):
    url = versionInfo['URL']
    parsed = urlparse.urlparse(url)
    if not parsed.scheme or not parsed.netloc or not parsed.path:
        raise Exception("Unable to download file(s) for aritfact %s: invalid URL: %s" % (versionInfo['name'], url))

    downloadArtifact(url, outdir)

    artifactInfo = {}
    artifactInfo['name'] = versionInfo['name']
    artifactInfo['version'] = versionInfo['version']
    artifactInfo['type'] = 'releasedArtifact'
    downloadReport.append(artifactInfo)

#
# NOTE: Caller is responsible for validating basic URL syntax
def downloadArtifact(url, outdir):
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

def jenkinsDownload(versionInfo, outdir, downloadReport):
    artifactName = versionInfo['name']
    jenkinsInfo = versionInfo['jenkinsInfo']

    job = jenkinsInfo['job']
    server = jenkinsInfo['server']
    baseURL = "%s/job/%s/lastSuccessfulBuild" % (server, job)
    queryURL = "%s/api/json?tree=artifacts[*],number,actions[lastBuiltRevision[*,branch[*]]]" % baseURL
    parsed = urlparse.urlparse(queryURL)
    if not parsed.scheme or not parsed.netloc or not parsed.path:
        raise Exception("Unable to download file(s) for aritfact %s: invalid URL: %s" % (artifactName, queryURL))

    response = json.loads(urllib2.urlopen(queryURL).read())

    #
    # If the artifact has a subModule in Jenkins, then we need to query a different URL to get the subModule's artifacts
    #
    if "subModule" in jenkinsInfo and jenkinsInfo['subModule'] != "":
        baseURL = "%s/%s" % (baseURL, jenkinsInfo['subModule'])
        artifactsURL = "%s/api/json?tree=artifacts[*]" % baseURL
        parsed = urlparse.urlparse(artifactsURL)
        if not parsed.scheme or not parsed.netloc or not parsed.path:
            raise Exception("Unable to download file(s) for aritfact %s: invalid URL: %s" % (artifactName, artifactsURL))

        artifactsResponse = json.loads(urllib2.urlopen(artifactsURL).read())
        artifacts = artifactsResponse['artifacts']
    else:
        artifacts = response['artifacts']

    number = response['number']
    if len(artifacts) == 0:
        raise Exception("No artifacts available for lastSuccessfulBuild of %s (see job %s #%d on Jenkins server %s)" % (artifactName, job, number, server))

    pattern = jenkinsInfo['pattern']
    lastBuiltRevision = [item['lastBuiltRevision'] for item in response['actions'] if len(item) > 0 and item['lastBuiltRevision']]
    git_ref = lastBuiltRevision[0]['SHA1']
    branchData = lastBuiltRevision[0]['branch'][0]
    if branchData:
        git_branch = branchData['name']

    # Secondly, loop through the list of build artifacts and download any that match the specified pattern
    nDownloaded = 0
    for artifact in artifacts:
        fileName = artifact['fileName']
        if fnmatch.fnmatch(fileName, pattern):
            print ("Found artifact %s for lastSuccessfulBuild of %s (see job %s #%d on Jenkins server %s)" % (fileName, artifactName, job, number, server))
            relativePath = artifact['relativePath']
            downloadURL = "%s/artifact/%s" % (baseURL, relativePath)
            downloadArtifact(downloadURL, outdir)
            nDownloaded += 1
            #
            # TODOs:
            # 1. Add changelog info
            #
            artifactInfo = {}
            artifactInfo['name'] = versionInfo['name']
            artifactInfo['type'] = 'jenkinsBuild'
            artifactInfo['version'] = versionInfo['version']
            artifactInfo['git_ref'] = git_ref
            artifactInfo['git_branch'] = git_branch
            artifactInfo['jenkinsInfo'] = jenkinsInfo
            artifactInfo['jenkinsInfo']['job_nbr'] = number
            downloadReport.append(artifactInfo)

    if nDownloaded == 0:
        raise Exception("No artifacts downloaded from lastSuccessfulBuild of %s (see job %s #%d on Jenkins server %s)" % (artifactName, job, number, server))


# downloaders is a dictionary of "type" to function that can
downloaders = {
    "download": urlDownload,
    "jenkins": jenkinsDownload
}


def downloadArtifacts(versionsFile, artifacts, downloadDir, downloadReport):
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
        downloaders[versionInfo['type']](versionInfo, downloadDir, downloadReport)

#
# Update the report file - updates the report file with one or more artifacts from downloadReport
#
def updateReport(reportFile, downloadReport):
    lastReport = []
    if os.path.exists(reportFile):
        with open(reportFile, 'r') as inFile:
            lastReport = json.load(inFile)

    # First remove any items from lastReport that match something we've just downloaded
    for item in downloadReport:
        lastReport = [rpt for rpt in lastReport if rpt['name'] != item['name']]

    # Now add our items to the report and sort it
    lastReport.extend(downloadReport)
    def artifactName(artifactInfo):
        return artifactInfo["name"]
    sortedReport = sorted(lastReport, key=artifactName)

    with open(reportFile, 'w') as outFile:
        json.dump(sortedReport, outFile, indent=4, sort_keys=True, separators=(',', ': '))

def main(args):
    artifacts = args.artifacts

    if args.zp_manifest != None:
        manifest = json.load(args.zp_manifest)
        artifacts = list(chain(manifest['install_order'], manifest['included_not_installed']))

    if not artifacts or len(artifacts) == 0:
        sys.exit("No artifacts to download")

    downloadReport = []
    downloadArtifacts(args.versions, artifacts, args.out_dir, downloadReport)

    if args.reportFile:
        updateReport(args.reportFile, downloadReport)

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

    parser.add_argument('--reportFile', type=str, default="",
                        help='json report of downloaded artifacts')

    args = parser.parse_args()
    main(args)

#!/usr/bin/env python

import argparse
import copy
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


def zenpackDownload(versionInfo, outdir, downloadReport):
    """Download ZenPack based on requirements in versionInfo.

    Uses http://zenpacks.zenosslabs.com/requirement/ API endpoint to
    download the best ZenPack given the following versionInfo dict.

    Full versionInfo JSON example:

        {
            "name": "ZenPacks.zenoss.Example",
            "type": "zenpack",
            "requirement": "ZenPacks.zenoss.Example>=0.0.1",
            "pre": false,
            "feature": null
        }

    name:
        Required. Name for artifact. Should be the ZenPack's Python
        package name.

    type:
        Required. Must be set to "zenpack" to use this downloader.

    requirement:
        Optional. Default value is that of the name field. Accepts any
        setuptools pkg_resources requirement format. Prelease builds
        will be excluded unless the pre field is set to true (see
        below), and feature builds will be excluded unless the feature
        field is set (see below).

        http://setuptools.readthedocs.io/en/latest/pkg_resources.html#requirements-parsing

    pre:
        Optional. Default value is false. When set to false, no
        prerelease builds matching requirement will be returned. When
        set to true, prerelease, release, and postrelease builds
        matching requirement will be returned.

        Prerelease is defined by PEP 440 and includes both pre-releases
        and developmental releases.

        https://www.python.org/dev/peps/pep-0440/#pre-releases
        https://www.python.org/dev/peps/pep-0440/#developmental-releases

    feature:
        Optional. Default value is null. When set to null, no feature
        builds matching requirement will be returned. When set to a
        string value, only builds of a feature matching the string value
        that also match requirement will be returned.

        Setting feature to a non-null value implies setting the pre
        field to true. This because all feature builds are inherently
        pre-releases.

    Credible examples:

    - Specific release version:

        {
            "name": "ZenPacks.zenoss.Example",
            "type": "zenpack",
            "requirement": "ZenPacks.zenoss.Example===1.0.0"
        }

    - Newest release version:

        {
            "name": "ZenPacks.zenoss.Example",
            "type": "zenpack"
        }

    - Newest patch release within a minor release series:

        {
            "name": "ZenPacks.zenoss.Example",
            "type": "zenpack",
            "requirement": "ZenPacks.zenoss.Example>=1.0.*"
        }

    - Newest pre-release version:

        {
            "name": "ZenPacks.zenoss.Example",
            "type": "zenpack",
            "pre": true
        }

    - Newest pre-release within a minor release series:

        {
            "name": "ZenPacks.zenoss.Example",
            "type": "zenpack",
            "requirement": "ZenPacks.zenoss.Example>=1.0.*",
            "pre": true
        }

    - Specific feature by name regardless of version.

        {
            "name": "ZenPacks.zenoss.Example",
            "type": "zenpack",
            "feature": "fireworks"
        }

    """
    endpoint = "http://zenpacks.zenosslabs.com/requirement"

    # artifactInfo gets published to downloadReport. Copy versionInfo
    # into it, and specify any defaults. This ensures that all
    # information about what was requested from the endpoint gets
    # captured in the report.
    artifactInfo = copy.copy(versionInfo)
    artifactInfo.setdefault("requirement", artifactInfo["name"])
    artifactInfo.setdefault("feature", None)
    artifactInfo.setdefault("pre", False)

    requirement = urllib2.quote(artifactInfo["requirement"])
    feature = urllib2.quote(artifactInfo["feature"] or "")
    pre = bool(artifactInfo["pre"])

    # <endpoint>/<requirement>[/<feature>][?pre]
    url = "".join((
        endpoint,
        "/{}".format(requirement),
        "/{}".format(feature) if feature else "",
        "?pre" if pre else ""
        ))

    # Find best ZenPack match based on requirements.
    #
    # Example response:
    #
    #   {
    #       "md5sum": "cb67ad2fb88e07abcb7a78744010f0b2",
    #       "name": "ZenPacks.zenoss.Example",
    #       "parsed_version": {
    #           "base_version": "1.0.0",
    #           "is_postrelease": False,
    #           "is_prerelease": True",
    #           "local": "g0abcdef",
    #           "public": "1.0.0.dev2"
    #       },
    #       "platform": None,
    #       "py_version": "2.7",
    #       "requires": [
    #           "ZenPacks.zenoss.AnotherExample",
    #           "ZenPacks.zenoss.ThirdExample>=1.5"
    #       ],
    #       "shasum": "b0d69c0e175b45bdf3ecf1c455232bdcd66e3f43",
    #       "url": "http://zenpacks.zenosslabs.com/download/ZenPacks.zenoss.Example-1.0.0.dev2+g0abcdef-py2.7.egg",
    #       "version": "1.0.0.dev2+g0abcdef"
    #   }
    try:
        zenpack = json.loads(urllib2.urlopen(url).read())
    except urllib2.HTTPError as e:
        artifactInfo["zenpack"] = {
            "url": e.url,
            "code": e.code,
            "reason": e.reason,
            }

        downloadReport.append(artifactInfo)
        raise
    except Exception as e:
        artifactInfo["zenpack"] = {
            "error": str(e),
            }

        downloadReport.append(artifactInfo)
        raise

    # Include unaltered response under "zenpack" key in download report.
    artifactInfo["zenpack"] = zenpack

    if "url" not in zenpack:
        artifactInfo["zenpack"] = {
            "error": "no url in returned data",
            }

        downloadReport.append(artifactInfo)
        raise Exception(
            "No 'url' in zenpack data for artifact {}."
            .format(versionInfo["name"]))

    downloadReport.append(artifactInfo)
    downloadArtifact(zenpack["url"], outdir)


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
            artifactInfo['git_ref_url'] = versionInfo['git_repo'].replace('.git', '/tree/%s' % git_ref)
            artifactInfo['git_branch'] = git_branch
            artifactInfo['jenkinsInfo'] = jenkinsInfo
            artifactInfo['jenkinsInfo']['job_nbr'] = number
            downloadReport.append(artifactInfo)

    if nDownloaded == 0:
        raise Exception("No artifacts downloaded from lastSuccessfulBuild of %s (see job %s #%d on Jenkins server %s)" % (artifactName, job, number, server))


# downloaders is a dictionary of "type" to function that can
downloaders = {
    "download": urlDownload,
    "jenkins": jenkinsDownload,
    "zenpack": zenpackDownload,
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

#!/usr/bin/env python2.7

import argparse
import copy
import fnmatch
import hashlib
import json
import os
import re
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

    Uses http://zenpacks.zenoss.eng/requirement/ API endpoint to
    download the best ZenPack given the following versionInfo dict.

    For information on the syntax for type=zenpack, see
    README.versionInfo.md

    """
    endpoint = "http://zenpacks.zenoss.eng/requirement"

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
    #       "url": "http://zenpacks.zenoss.eng/download/ZenPacks.zenoss.Example-1.0.0.dev2+g0abcdef-py2.7.egg",
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
        raise Exception("Error querying for ZP info from %s: %s" % (url, e))
    except urllib2.URLError as e:
        artifactInfo["zenpack"] = {
            "error": str(e),
        }
        downloadReport.append(artifactInfo)
        raise Exception("Error querying for ZP info from %s: %s" % (url, e))
    except Exception as e:
        artifactInfo["zenpack"] = {
            "error": str(e),
        }
        downloadReport.append(artifactInfo)
        raise Exception("Error querying for ZP info from %s: %s" % (url, e))

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
    info = URLDownloadInfo(versionInfo)
    url = info.url
    print url
    parsed = urlparse.urlparse(url)
    if not parsed.scheme or not parsed.netloc or not parsed.path:
        raise Exception("Unable to download file(s) for aritfact %s: invalid URL: %s" % (info.name, url))

    downloadArtifact(url, outdir)

    artifactInfo = info.toDict()
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
    jenkinsInfo = JenkinsInfo(versionInfo)
    artifactName = jenkinsInfo.name

    job = jenkinsInfo.job
    server = jenkinsInfo.server
    baseURL = "%s/lastSuccessfulBuild" % jenkinsInfo.jobURL
    queryURL = "%s/api/json?tree=artifacts[*],number,actions[lastBuiltRevision[*,branch[*]]]" % baseURL
    parsed = urlparse.urlparse(queryURL)
    if not parsed.scheme or not parsed.netloc or not parsed.path:
        raise Exception("Unable to download file(s) for aritfact %s: invalid URL: %s" % (artifactName, queryURL))

    try:
        response = json.loads(urllib2.urlopen(queryURL).read())
    except urllib2.URLError as e:
        raise Exception("Error downloading %s: %s" % (queryURL, e))
    except urllib2.HTTPError as e:
        raise Exception("Error downloading %s: %s" % (queryURL, e))
    except httplib.HTTPException, e:
        raise Exception("Error downloading %s: %s" % (queryURL, e))


    #
    # If the artifact has a subModule in Jenkins, then we need to query a different URL to get the subModule's artifacts
    #
    if jenkinsInfo.subModule:
        baseURL = "%s/%s" % (baseURL, jenkinsInfo.subModule)
        artifactsURL = "%s/api/json?tree=artifacts[*]" % baseURL
        parsed = urlparse.urlparse(artifactsURL)
        if not parsed.scheme or not parsed.netloc or not parsed.path:
            raise Exception(
                "Unable to download file(s) for aritfact %s: invalid URL: %s" % (artifactName, artifactsURL))

        artifactsResponse = json.loads(urllib2.urlopen(artifactsURL).read())
        artifacts = artifactsResponse['artifacts']
    else:
        artifacts = response['artifacts']

    number = response['number']
    if len(artifacts) == 0:
        raise Exception("No artifacts available for lastSuccessfulBuild of %s (see job %s #%d on Jenkins server %s)" % (
            artifactName, job, number, server))

    lastBuiltRevision = [item['lastBuiltRevision'] for item in response['actions'] if
                         len(item) > 0 and 'lastBuiltRevision' in item]
    if lastBuiltRevision:
        git_ref = lastBuiltRevision[0]['SHA1']
        branchData = lastBuiltRevision[0]['branch'][0]
        if branchData:
            git_branch = branchData['name']
    else:
        git_ref = git_branch = None

    # Secondly, loop through the list of build artifacts and download any that match the specified pattern
    nDownloaded = 0
    for artifact in artifacts:
        fileName = artifact['fileName']
        for pattern in jenkinsInfo.patterns:
            if fnmatch.fnmatch(fileName, pattern):
                print ("Found artifact %s for lastSuccessfulBuild of %s (see job %s #%d on Jenkins server %s)" % (
                    fileName, artifactName, job, number, server))
                relativePath = artifact['relativePath']
                downloadURL = "%s/artifact/%s" % (baseURL, relativePath)
                downloadArtifact(downloadURL, outdir)
                nDownloaded += 1
                #
                # TODOs:
                # 1. Add changelog info
                #
                artifactInfo = jenkinsInfo.toDict()
                if git_ref:
                    artifactInfo['git_ref'] = git_ref
                    artifactInfo['git_ref_url'] = jenkinsInfo.gitRepo.replace('.git', '/tree/%s' % git_ref)
                    artifactInfo['git_branch'] = git_branch
                artifactInfo['jenkins.job_nbr'] = number
                artifactInfo['jenkins.artifact'] = fileName
                downloadReport.append(artifactInfo)

    if nDownloaded == 0:
        raise Exception(
            "No artifacts downloaded from lastSuccessfulBuild of %s (see job %s #%d on Jenkins server %s)" % (
                artifactName, job, number, server))
    if nDownloaded > 1:
        raise Exception("Download pattern is ambiguous, more than one artifact matched")


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
        versionsMap[version['name']] = version

    if not os.path.isdir(downloadDir):
        raise Exception("Path is not a directory: %s" % downloadDir)

    for artifactName in artifacts:
        if artifactName not in versionsMap:
            raise Exception("Artifact version information not found: %s" % artifactName)
        versionInfo = versionsMap[artifactName]
        if versionInfo['type'] not in downloaders:
            raise Exception(
                "Cannot not download artifact, unknown download type: %s %s" % (artifactName, versionInfo['type']))
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


def main(options):
    if options.pinned:
        #verify all versions are explicitly set to a release
        versions = json.load(options.versions)
        unpinned = []
        notLatest = []
        for artifact in versions:
            artifactInfo = artifactClass[artifact['type']](artifact)
            if not artifactInfo.pinned:
                if isinstance(artifactInfo, ZenPackInfo):
                    version = "requirement: %s; pre: %s" %(artifactInfo.requirement, artifactInfo.pre)
                else:
                    version = "version: %s" % artifactInfo.version
                unpinned.append("%s %s" % (artifactInfo.name, version))
            elif options.check_latest:
                latest = artifactInfo.getLatestVersion()
                if latest != "UNSUPPORTED":
                    if isinstance(artifactInfo, ZenPackInfo):
                        #pinned zenpack versions always have '==='
                        _, pinnedVersion = artifactInfo.requirement.split('===')
                    else:
                        pinnedVersion = artifactInfo.version
                    if pinnedVersion != latest:
                        notLatest.append("%s pinned version %s, does not match latest: %s" % (artifactInfo.name, pinnedVersion, latest))
        errors = []
        if unpinned:
            errors.append("unpinned versions found:\n%s" % '\n'.join(unpinned))
        if notLatest:
            msg = "not using latest versions :\n%s" % '\n'.join(notLatest)
            errors.append(msg)

        if errors:
            sys.exit("\n".join(errors))
        sys.exit(0)

    artifacts = options.artifacts
    if options.zp_manifest is not None:
        manifest = json.load(options.zp_manifest)
        artifacts = list(chain(manifest['install_order'], manifest['included_not_installed']))

    if not options.git_output:
        if not artifacts or len(artifacts) == 0:
            sys.exit("No artifacts to download")

        downloadReport = []
        downloadArtifacts(options.versions, artifacts, options.out_dir, downloadReport)

        if options.reportFile:
            updateReport(options.reportFile, downloadReport)
    else:
        gitInfo = []
        versions = json.load(options.versions)
        for artifact in versions:
            artifactInfo = artifactClass[artifact['type']](artifact)
            gitInfo.append({
                'repo': artifactInfo.gitRepo,
                'ref': artifactInfo.gitRef
            })
        if options.append:
            with open(options.git_output, 'r') as gitRepos:
                existing = json.load(gitRepos)
                existing.extend(gitInfo)
                gitInfo = existing

        with open(options.git_output, 'w') as outFile:
            json.dump(gitInfo, outFile, indent=4, sort_keys=True, separators=(',', ': '))


class ArtifactInfo(object):

    _version_regex = re.compile("^\d+\.\d+(\.\d+){0,3}$", re.IGNORECASE)

    def __init__(self, versionInfo):
        self.info = versionInfo

    @property
    def name(self):
        return self.info['name']

    @property
    def version(self):
        return self.info.get('version', None)

    @property
    def infoType(self):
        return self.info['type']

    @property
    def gitRepo(self):
        """
        git hub repo url for artifact. Use value if present or generate url base on artifact name.
        """
        if 'git_repo' in self.info:
            return self.info['git_repo']
        return 'git@github.com:%s/%s.git' % (self.gitOwner, self.info['name'])

    @property
    def gitRef(self):
        if 'git_ref' in self.info:
            return self.info['git_ref']
        return self.version

    @property
    def gitOwner(self):
        if 'git_owner' in self.info:
            return self.info['git_owner']
        return 'zenoss'

    @property
    def pinned(self):
        if self.infoType != 'download':
            return False
        elif not self.version:
            return False
        elif not self._version_regex.match(self.version):
            return False
        return True

    def toDict(self):
        return {
            "git_repo": self.gitRepo,
            "version": self.version,
            "name": self.name,
            "type": self.infoType
        }

    def getLatestVersion(self):
        return "UNSUPPORTED"


class URLDownloadInfo(ArtifactInfo):
    def __init__(self, versionInfo):
        super(URLDownloadInfo, self).__init__(versionInfo)

    @property
    def url(self):
        baseURL = self.info.get('URL')
        if not baseURL:
            baseURL = 'http://zenpip.zenoss.eng/packages/{name}-{version}.tar.gz'
        kwargs = super(URLDownloadInfo, self).toDict()
        return baseURL.format(**kwargs)

    def toDict(self):
        result = super(URLDownloadInfo, self).toDict()
        result['url'] = self.url
        return result


class JenkinsInfo(ArtifactInfo):
    def __init__(self, versionInfo):
        super(JenkinsInfo, self).__init__(versionInfo)

    @property
    def server(self):
        if 'jenkins.server' in self.info:
            return self.info['jenkins.server']
        return 'http://platform-jenkins.zenoss.eng'

    @property
    def job(self):
        if 'jenkins.job' in self.info:
            return self.info['jenkins.job']
        return 'Components/job/%s/job/%s' % (self.name, self.version)

    @property
    def jobURL(self):
        return "%s/job/%s" % (self.server, self.job)

    @property
    def subModule(self):
        return self.info.get('jenkins.subModule')

    @property
    def patterns(self):
        if 'jenkins.pattern' in self.info:
            return [self.info['jenkins.pattern']]

        return ['*.whl', '*.tgz', '*.tar.gz']

    def toDict(self):
        result = super(JenkinsInfo, self).toDict()
        jenkinsDict = {
            "jenkins.server": self.server,
            "jenkins.job": self.job,
            "jenkins.jobURL": self.jobURL,
            "jenkins.subModule": self.subModule,
            "jenkins.patterns": self.patterns
        }
        result.update(jenkinsDict)
        return result


class ZenPackInfo(ArtifactInfo):
    def __init__(self, versionInfo):
        super(ZenPackInfo, self).__init__(versionInfo)

    @property
    def pre(self):
        return self.info.get('pre', False)

    @property
    def feature(self):
        return self.info.get('feature', None)

    @property
    def requirement(self):
        return self.info.get('requirement', None)

    @property
    def gitRef(self):
        """
        try to figure out the git ref for a zenpack
        :return:
        """
        gitRef = super(ZenPackInfo, self).gitRef
        if not gitRef:
            if self.requirement and '===' in self.requirement and not self.pre:
                gitRef = self.requirement.split('===')[1]
            elif self.feature:
                gitRef = 'feature/%s' % self.feature
            elif self.pre and not self.requirement:
                gitRef = 'develop'
            elif not self.pre and not self.requirement:
                gitRef = 'master'
            else:
                raise Exception("Could not determine git_ref for %s from provided fields. "\
                        "Please specify desired git_ref field." % self.name)

        return gitRef

    def getLatestVersion(self):
        url = "http://zenpacks.zenoss.eng/requirement/%s" % self.name
        info = json.loads(urllib2.urlopen(url).read())
        return info['version']


    @property
    def pinned(self):
        """Return True if artifact is a pinned version. False if not."""
        if self.pre:
            # Pre-releases can never be considered pinned.
            return False

        if not self.requirement:
            # Pinning can't be done without an explicit requirement.
            return False

        if ',' in self.requirement:
            # A comma indicates multiple possibilities. Pinning is specific.
            return False

        if '===' in self.requirement and ',' not in self.requirement:
            # Triple-equal for a single (no commas) requirement means pinned.
            return True

        # Anything left is not pinned.
        return False

    def toDict(self):
        result = super(ZenPackInfo, self).toDict()
        zpDict = {
            "pre": self.pre,
            "requirements": self.requirement,
            "feature": self.feature,
        }
        result.update(zpDict)
        return result


#
artifactClass = {
    "download": URLDownloadInfo,
    "jenkins": JenkinsInfo,
    "zenpack": ZenPackInfo,
}

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

    parser.add_argument('--git_output', type=str, default="",
                        help='output git repo information for artifacts instead of downloading, value is name of file')

    parser.add_argument('--append', action="store_true",
                        help='only applicable to --git_output, add to existing git output file')

    parser.add_argument('--pinned', action="store_true",
                        help='Verify that the versions in the json file are pinned to an explicit release version, i.e. not develop.')

    parser.add_argument('--check-latest', action="store_true",
                        help='Used in conjunction with pinned. Check if pinned version is latest available, currently only works for zenpack versions')

    options = parser.parse_args()
    main(options)

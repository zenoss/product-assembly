#!/usr/bin/env python2

from __future__ import print_function, unicode_literals, absolute_import

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
        "?pre" if pre else "",
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
    #       "url": "http://zenpacks.zenoss.eng/download/ZenPacks.zenoss.Example-1.0.0.dev2+g0abcdef-py2.7.egg",  # noqa F501
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
    except Exception as e:
        artifactInfo["zenpack"] = {"error": str(e)}
        downloadReport.append(artifactInfo)
        raise Exception("Error querying for ZP info from %s: %s" % (url, e))

    # Include unaltered response under "zenpack" key in download report.
    artifactInfo["zenpack"] = zenpack

    if "url" not in zenpack:
        artifactInfo["zenpack"] = {"error": "no url in returned data"}
        downloadReport.append(artifactInfo)
        raise Exception(
            "No 'url' in zenpack data for artifact %s." % versionInfo["name"]
        )

    downloadReport.append(artifactInfo)
    downloadArtifact(zenpack["url"], outdir)


def urlDownload(versionInfo, outdir, downloadReport):
    info = URLDownloadInfo(versionInfo)
    url = info.url
    print(url)
    parsed = urlparse.urlparse(url)
    if not parsed.scheme or not parsed.netloc or not parsed.path:
        raise Exception(
            "Unable to download file(s) for aritfact %s: invalid URL: %s"
            % (info.name, url)
        )

    downloadArtifact(url, outdir)

    artifactInfo = info.toDict()
    artifactInfo["type"] = "releasedArtifact"
    downloadReport.append(artifactInfo)


#
# NOTE: Caller is responsible for validating basic URL syntax
def downloadArtifact(url, outdir):
    print("Downloading %s" % url)
    response = urllib2.urlopen(url)
    finalDestination = os.path.join(outdir, os.path.basename(url))
    downloadDestination = finalDestination
    sig = None
    if os.path.exists(finalDestination):
        print("existing found, computing hash: %s" % finalDestination)
        tmpFile = tempfile.NamedTemporaryFile()
        downloadDestination = tmpFile.name
        sig = md5Hash(finalDestination)

    with open(downloadDestination, "wb") as local_file:
        print("Saving artifact to %s" % downloadDestination)
        local_file.write(response.read())

    # check if we detected a file already
    if sig:
        # get md5 of downloaded file to compare to
        newSig = md5Hash(downloadDestination)
        print(sig)
        if newSig != sig:
            print("Replacing file: %s" % finalDestination)
            shutil.copy(downloadDestination, finalDestination)


def jenkinsArtifact(versionInfo, quiet=False):
    jenkinsInfo = JenkinsInfo(versionInfo)
    artifactName = jenkinsInfo.name

    job = jenkinsInfo.job
    server = jenkinsInfo.server
    baseURL = "%s/lastSuccessfulBuild" % jenkinsInfo.jobURL
    queryURL = (
        "%s/api/json"
        "?tree=artifacts[*],number,actions[lastBuiltRevision[*,branch[*]]]"
    ) % baseURL
    parsed = urlparse.urlparse(queryURL)
    if not parsed.scheme or not parsed.netloc or not parsed.path:
        raise Exception(
            "Unable to download file(s) for aritfact %s: invalid URL: %s"
            % (artifactName, queryURL)
        )

    try:
        response = json.loads(urllib2.urlopen(queryURL).read())
    except (urllib2.URLError, urllib2.HTTPError) as e:
        raise Exception("Error downloading %s: %s" % (queryURL, e))

    #
    # If the artifact has a subModule in Jenkins, then we need to query a
    # different URL to get the subModule's artifacts
    #
    if jenkinsInfo.subModule:
        baseURL = "%s/%s" % (baseURL, jenkinsInfo.subModule)
        artifactsURL = "%s/api/json?tree=artifacts[*]" % baseURL
        parsed = urlparse.urlparse(artifactsURL)
        if not parsed.scheme or not parsed.netloc or not parsed.path:
            raise Exception(
                "Unable to download file(s) for aritfact %s: invalid URL: %s"
                % (artifactName, artifactsURL)
            )

        artifactsResponse = json.loads(urllib2.urlopen(artifactsURL).read())
        artifacts = artifactsResponse["artifacts"]
    else:
        artifacts = response["artifacts"]

    number = response["number"]
    if len(artifacts) == 0:
        raise Exception(
            "No artifacts available for lastSuccessfulBuild of %s "
            "(see job %s #%d on Jenkins server %s)"
            % (artifactName, job, number, server)
        )

    lastBuiltRevision = [
        item["lastBuiltRevision"]
        for item in response["actions"]
        if len(item) > 0 and "lastBuiltRevision" in item
    ]
    if lastBuiltRevision:
        git_ref = lastBuiltRevision[0]["SHA1"]
        branchData = lastBuiltRevision[0]["branch"][0]
        if branchData:
            git_branch = branchData["name"]
    else:
        git_ref = git_branch = None

    URLs = []
    for artifact in artifacts:
        fileName = artifact["fileName"]
        for pattern in jenkinsInfo.patterns:
            if not fnmatch.fnmatch(fileName, pattern):
                continue

            if not quiet:
                print(
                    "Found artifact %s for lastSuccessfulBuild of %s "
                    "(see job %s #%d on Jenkins server %s)"
                    % (fileName, artifactName, job, number, server)
                )
            relativePath = artifact["relativePath"]
            URLs.append("%s/artifact/%s" % (baseURL, relativePath))
            #
            # TODOs:
            # 1. Add changelog info
            #
            artifactInfo = jenkinsInfo.toDict()
            if git_ref:
                artifactInfo["git_ref"] = git_ref
                artifactInfo["git_ref_url"] = jenkinsInfo.gitRepo.replace(
                    ".git", "/tree/%s" % git_ref
                )
                artifactInfo["git_branch"] = git_branch
            artifactInfo["jenkins.job_nbr"] = number
            artifactInfo["jenkins.artifact"] = fileName

    if not URLs:
        raise Exception(
            "No downloadable artifact found for %s "
            "(see job %s #%d on Jenkins server %s)"
            % (artifactName, job, number, server)
        )
    if len(URLs) > 1:
        raise Exception(
            "Download pattern is ambiguous, more than one artifact matched"
        )

    #
    # TODOs:
    # 1. Add changelog info
    #
    artifactInfo = jenkinsInfo.toDict()
    if git_ref:
        artifactInfo["git_ref"] = git_ref
        artifactInfo["git_ref_url"] = jenkinsInfo.gitRepo.replace(
            ".git", "/tree/%s" % git_ref
        )
        artifactInfo["git_branch"] = git_branch
    artifactInfo["jenkins.job_nbr"] = number
    artifactInfo["jenkins.artifact"] = fileName

    return URLs[0], artifactInfo


def jenkinsDownload(versionInfo, outdir, downloadReport):
    downloadURL, artifactInfo = jenkinsArtifact(versionInfo)
    downloadArtifact(downloadURL, outdir)
    downloadReport.append(artifactInfo)


#
# Update the report file - updates the report file with
# one or more artifacts from downloadReport
#
def updateReport(reportFile, downloadReport):
    lastReport = []
    if os.path.exists(reportFile):
        with open(reportFile, "r") as inFile:
            lastReport = json.load(inFile)

    # First remove any items from lastReport that match something
    # we've just downloaded
    for item in downloadReport:
        lastReport = [rpt for rpt in lastReport if rpt["name"] != item["name"]]

    # Now add our items to the report and sort it
    lastReport.extend(downloadReport)

    def artifactName(artifactInfo):
        return artifactInfo["name"]

    sortedReport = sorted(lastReport, key=artifactName)

    with open(reportFile, "w") as outFile:
        json.dump(
            sortedReport,
            outFile,
            indent=4,
            sort_keys=True,
            separators=(",", ": "),
        )


def check_versions(options):
    # verify all versions are explicitly set to a release
    versions = json.load(options.version_file)
    unpinned = []
    notLatest = []
    for artifact in versions:
        artifactInfo = artifactClass[artifact["type"]](artifact)
        if not artifactInfo.pinned:
            if isinstance(artifactInfo, ZenPackInfo):
                version = "requirement: %s; pre: %s" % (
                    artifactInfo.requirement,
                    artifactInfo.pre,
                )
            else:
                version = "version: %s" % artifactInfo.version
            unpinned.append("%s %s" % (artifactInfo.name, version))
        elif options.latest:
            latest = artifactInfo.getLatestVersion()
            if latest != "UNSUPPORTED":
                if isinstance(artifactInfo, ZenPackInfo):
                    # pinned zenpack versions always have '==='
                    _, pinnedVersion = artifactInfo.requirement.split(
                        "==="
                    )
                else:
                    pinnedVersion = artifactInfo.version
                if pinnedVersion != latest:
                    notLatest.append(
                        "%s pinned version %s, does not match latest: %s"
                        % (artifactInfo.name, pinnedVersion, latest)
                    )
    errors = []
    if unpinned:
        errors.append("unpinned versions found:\n%s" % "\n".join(unpinned))
    if notLatest:
        msg = "not using latest versions :\n%s" % "\n".join(notLatest)
        errors.append(msg)

    if errors:
        sys.exit("\n".join(errors))


# downloaders is a dictionary of "type" to function
downloaders = {
    "download": urlDownload,
    "jenkins": jenkinsDownload,
    "zenpack": zenpackDownload,
}


def get_artifacts(options):
    artifacts = options.artifact
    if options.zp_manifest is not None:
        manifest = json.load(options.zp_manifest)
        artifacts = list(chain(
            manifest["install_order"], manifest["included_not_installed"]
        ))

    if not artifacts or len(artifacts) == 0:
        sys.exit("No artifacts to download")

    downloadReport = []
    versions = json.load(options.version_file)
    versionsMap = {}
    for version in versions:
        versionsMap[version["name"]] = version

    if not os.path.isdir(options.out_dir):
        raise Exception("Path is not a directory: %s" % options.out_dir)

    for artifactName in artifacts:
        if artifactName not in versionsMap:
            raise Exception(
                "Artifact version information not found: %s" % artifactName
            )
        versionInfo = versionsMap[artifactName]
        if versionInfo["type"] not in downloaders:
            raise Exception(
                "Cannot not download artifact, unknown download type: %s %s"
                % (artifactName, versionInfo["type"])
            )
        downloaders[versionInfo["type"]](
            versionInfo, options.out_dir, downloadReport
        )

    if options.log:
        updateReport(options.log, downloadReport)


def url_inspector(versionInfo):
    info = URLDownloadInfo(versionInfo)
    url = info.url
    result = urlparse.urlparse(url)
    return os.path.basename(result.path)


def jenkins_inspector(versionInfo):
    url, _ = jenkinsArtifact(versionInfo, quiet=True)
    result = urlparse.urlparse(url)
    return os.path.basename(result.path)


def zenpack_inspector(versionInfo):
    """Retrieve the filename of the ZenPack.

    Uses http://zenpacks.zenoss.eng/requirement/ API endpoint to
    download the best ZenPack given the following versionInfo dict.

    For information on the syntax for type=zenpack, see
    README.versionInfo.md
    """
    endpoint = "http://zenpacks.zenoss.eng/requirement"

    if "requirement" in versionInfo:
        requirement = versionInfo["requirement"]
    else:
        requirement = versionInfo["name"]
    feature = versionInfo.get("feature")
    pre = bool(versionInfo.get("pre"))

    # <endpoint>/<requirement>[/<feature>][?pre]
    url = "".join((
        endpoint,
        "/{}".format(urllib2.quote(requirement)),
        "/{}".format(urllib2.quote(feature)) if feature else "",
        "?pre" if pre else "",
    ))

    try:
        zenpack = json.loads(urllib2.urlopen(url).read())
    except Exception as e:
        raise Exception("Error querying for ZP info from %s: %s" % (url, e))

    if "url" not in zenpack:
        raise Exception(
            "No 'url' in zenpack data for artifact %s." % versionInfo["name"]
        )

    url = zenpack["url"]
    result = urlparse.urlparse(url)
    return os.path.basename(result.path)


# downloaders is a dictionary of "type" to function
inspectors = {
    "download": url_inspector,
    "jenkins": jenkins_inspector,
    "zenpack": zenpack_inspector,
}


def filename_of_artifact(options):
    artifacts = options.artifact

    if not artifacts or len(artifacts) == 0:
        sys.exit("No artifacts to download")

    versions = json.load(options.version_file)
    versionsMap = {}
    for version in versions:
        versionsMap[version["name"]] = version

    for artifactName in artifacts:
        if artifactName not in versionsMap:
            raise Exception(
                "Artifact version information not found: %s" % artifactName
            )
        versionInfo = versionsMap[artifactName]
        if versionInfo["type"] not in downloaders:
            raise Exception(
                "Cannot not download artifact, unknown download type: %s %s"
                % (artifactName, versionInfo["type"])
            )
        print(inspectors[versionInfo["type"]](versionInfo))


def report_artifacts(options):
    gitInfo = []
    versions = json.load(options.version_file)
    for artifact in versions:
        artifactInfo = artifactClass[artifact["type"]](artifact)
        gitInfo.append(
            {"repo": artifactInfo.gitRepo, "ref": artifactInfo.gitRef}
        )

    if options.file:
        if options.append:
            with open(options.file, "r") as gitRepos:
                existing = json.load(gitRepos)
                existing.extend(gitInfo)
                gitInfo = existing

        with open(options.file, "w") as outFile:
            json.dump(
                gitInfo,
                outFile,
                indent=4,
                sort_keys=True,
                separators=(",", ": "),
            )
    else:
        print(json.dumps(
            gitInfo,
            indent=4,
            sort_keys=True,
            separators=(",", ": "),
        ))


class ArtifactInfo(object):

    _version_regex = re.compile(r"^\d+\.\d+(\.\d+){0,3}$", re.IGNORECASE)

    def __init__(self, versionInfo):
        self.info = versionInfo

    @property
    def name(self):
        return self.info["name"]

    @property
    def version(self):
        return self.info.get("version", None)

    @property
    def infoType(self):
        return self.info["type"]

    @property
    def gitRepo(self):
        """
        git hub repo url for artifact.
        Use value if present or generate url base on artifact name.
        """
        if "git_repo" in self.info:
            return self.info["git_repo"]
        return "git@github.com:%s/%s.git" % (self.gitOwner, self.info["name"])

    @property
    def gitRef(self):
        if "git_ref" in self.info:
            return self.info["git_ref"]
        return self.version

    @property
    def gitOwner(self):
        if "git_owner" in self.info:
            return self.info["git_owner"]
        return "zenoss"

    @property
    def pinned(self):
        if self.infoType != "download":
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
            "type": self.infoType,
        }

    def getLatestVersion(self):
        return "UNSUPPORTED"


class URLDownloadInfo(ArtifactInfo):
    def __init__(self, versionInfo):
        super(URLDownloadInfo, self).__init__(versionInfo)

    @property
    def url(self):
        baseURL = self.info.get("URL")
        if not baseURL:
            baseURL = (
                "http://zenpip.zenoss.eng/packages/{name}-{version}.tar.gz"
            )
        kwargs = super(URLDownloadInfo, self).toDict()
        return baseURL.format(**kwargs)

    def toDict(self):
        result = super(URLDownloadInfo, self).toDict()
        result["url"] = self.url
        return result


class JenkinsInfo(ArtifactInfo):
    def __init__(self, versionInfo):
        super(JenkinsInfo, self).__init__(versionInfo)

    @property
    def server(self):
        if "jenkins.server" in self.info:
            return self.info["jenkins.server"]
        return "http://platform-jenkins.zenoss.eng"

    @property
    def job(self):
        if "jenkins.job" in self.info:
            return self.info["jenkins.job"]
        return "Components/job/%s/job/%s" % (self.name, self.version)

    @property
    def jobURL(self):
        return "%s/job/%s" % (self.server, self.job)

    @property
    def subModule(self):
        return self.info.get("jenkins.subModule")

    @property
    def patterns(self):
        if "jenkins.pattern" in self.info:
            return [self.info["jenkins.pattern"]]

        return ["*.whl", "*.tgz", "*.tar.gz"]

    def toDict(self):
        result = super(JenkinsInfo, self).toDict()
        jenkinsDict = {
            "jenkins.server": self.server,
            "jenkins.job": self.job,
            "jenkins.jobURL": self.jobURL,
            "jenkins.subModule": self.subModule,
            "jenkins.patterns": self.patterns,
        }
        result.update(jenkinsDict)
        return result


class ZenPackInfo(ArtifactInfo):
    def __init__(self, versionInfo):
        super(ZenPackInfo, self).__init__(versionInfo)

    @property
    def pre(self):
        return self.info.get("pre", False)

    @property
    def feature(self):
        return self.info.get("feature", None)

    @property
    def requirement(self):
        return self.info.get("requirement", None)

    @property
    def gitRef(self):
        """
        try to figure out the git ref for a zenpack
        :return:
        """
        gitRef = super(ZenPackInfo, self).gitRef
        if not gitRef:
            if self.requirement and "===" in self.requirement and not self.pre:
                gitRef = self.requirement.split("===")[1]
            elif self.feature:
                gitRef = "feature/%s" % self.feature
            elif self.pre and not self.requirement:
                gitRef = "develop"
            elif not self.pre and not self.requirement:
                gitRef = "master"
            else:
                raise Exception(
                    "Could not determine git_ref for %s from provided fields. "
                    "Please specify desired git_ref field." % self.name
                )

        return gitRef

    def getLatestVersion(self):
        url = "http://zenpacks.zenoss.eng/requirement/%s" % self.name
        info = json.loads(urllib2.urlopen(url).read())
        return info["version"]

    @property
    def pinned(self):
        """Return True if artifact is a pinned version. False if not."""
        if self.pre:
            # Pre-releases can never be considered pinned.
            return False

        if not self.requirement:
            # Pinning can't be done without an explicit requirement.
            return False

        if "," in self.requirement:
            # A comma indicates multiple possibilities. Pinning is specific.
            return False

        if "===" in self.requirement and "," not in self.requirement:
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


def _build_check_cmd_args(subparsers, common):
    check_cmd = subparsers.add_parser(
        "check",
        help="Verify that the versions in the json file are "
        "pinned to an explicit release version, i.e. not develop.",
        parents=[common]
    )
    check_cmd.add_argument(
        "--latest",
        action="store_true",
        help="Check whether pinned version is latest available "
        "(zenpacks only)",
    )
    check_cmd.set_defaults(func=check_versions)


def _build_get_cmd_args(subparsers, common):
    get_cmd = subparsers.add_parser(
        "get",
        parents=[common],
        help="Download artifacts",
        description="Download artifacts named in the given version file.",
    )

    get_group = get_cmd.add_mutually_exclusive_group(required=True)
    get_group.add_argument(
        "artifact",
        nargs="*", default=[], help="Artifact to download"
    )
    get_group.add_argument(
        "--zp-manifest",
        type=file,
        help="JSON file with list of zenpacks to be packaged or installed.",
    )

    get_cmd.add_argument(
        "--out-dir",
        type=str, default=".",
        help="directory that receives downloaded files"
    )
    get_cmd.add_argument(
        "--log",
        type=str,
        help="Write a log of downloaded artifacts to this file.",
    )
    get_cmd.set_defaults(func=get_artifacts)


def _build_report_cmd_args(subparsers, common):
    report_cmd = subparsers.add_parser(
        "report",
        parents=[common],
        help="Output git data on artifacts",
        description="Produce JSON report containing git repository "
        "information about the artifacts in the version file."
    )
    report_cmd.add_argument(
        "-f", "--file",
        type=str,
        help="Write the report to this file.",
    )
    report_cmd.add_argument(
        "-a", "--append",
        action="store_true",
        help="Add to the existing report if --file is specified",
    )
    report_cmd.set_defaults(func=report_artifacts)


def _build_filename_cmd_args(subparsers, common):
    filename_cmd = subparsers.add_parser(
        "filename",
        parents=[common],
        help="Prints the filename of the artifact",
    )
    filename_cmd.add_argument(
        "artifact",
        nargs="*", default=[], help="Artifact to download"
    )
    filename_cmd.set_defaults(func=filename_of_artifact)


common = argparse.ArgumentParser(add_help=False)
common.add_argument(
    "version_file",
    type=file, help="JSON file with artifact versions and locations"
)

parser = argparse.ArgumentParser(description="Artifact Management")
subparsers = parser.add_subparsers()

_build_check_cmd_args(subparsers, common)
_build_get_cmd_args(subparsers, common)
_build_report_cmd_args(subparsers, common)
_build_filename_cmd_args(subparsers, common)

options = parser.parse_args()
options.func(options)

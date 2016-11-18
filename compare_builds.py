#!/usr/bin/env python

import argparse
import copy
import collections
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


def buildDictionary(list):
    result = {}
    for item in list:
        artifactInfo = artifactClass[item['type']](item)
        result[item["name"]] = artifactInfo
    return result

def compare_artifacts(logfile1, logfile2):
    logList1 = json.load(logfile1)
    logList2 = json.load(logfile2)

    artifacts1 = buildDictionary(logList1)
    artifacts2 = buildDictionary(logList2)

    diffs = {}
    for name, item in artifacts1.iteritems():
        if name in artifacts2:
            diff = DiffInfo(name, item, artifacts2[name])
        else:
            diff = DiffInfo(name, item, ArtifactInfo({"name": name}))
        diffs[name] = diff

    for name, item in artifacts2.iteritems():
        if not name in artifacts1:
            diff = DiffInfo(name, ArtifactInfo({"name": name}), item)
            diffs[name] = diff

    return collections.OrderedDict(sorted(diffs.items()))

def compare_components(logfile1, logfile2):
    componentDiffs = compare_artifacts(logfile1, logfile2)
    print "Component Differences:"
    print "%-40.40s %-32.32s %-32.32s Different" % ("Name", "c1 (gitRef)", "c2 (gitRef)")
    for name, item in componentDiffs.iteritems():
        if not options.verbose and not item.different:
            continue
        if item.different:
            diffIndicator = " Y"
        else:
            diffIndicator = ""
        print "%-40.40s %-32.32s %-32.32s%s" % (item.name, item.artifact1.versionInfo, item.artifact2.versionInfo, diffIndicator)

def compare_zenpacks(logfile1, logfile2):
    zenPackDiffs = compare_artifacts(logfile1, logfile2)
    print "ZenPack Differences:"
    print "%-40.40s %-32.32s %-32.32s" % ("Name", "z1 (gitRef)", "z2 (gitRef)")
    for name, item in zenPackDiffs.iteritems():
        if not options.verbose and not item.different:
            continue
        if item.different:
            diffIndicator = " *"
        else:
            diffIndicator = ""
        print "%-40.40s %-32.32s %-32.32s%s" % (item.name, item.artifact1.versionInfo, item.artifact2.versionInfo, diffIndicator)

def main(options):

    # FIXME: Add options to specify 2 jenkins builds and download the logs from there

    if options.component_log_1 is None and options.component_log_2 is not None \
       or \
       options.component_log_1 is not None and options.component_log_2 is None:
       sys.exit("if either of --component_log_1 or --component_log_2 is specified, both must be specified")

    if options.zenpacks_log_1 is None and options.zenpacks_log_2 is not None \
       or \
       options.zenpacks_log_1 is not None and options.zenpacks_log_2 is None:
       sys.exit("if either of --zenpacks_log_1 or --zenpacks_log_2 is specified, both must be specified")

    if options.component_log_1 is None and options.zenpacks_log_1 is None:
       sys.exit("Nothing to compare. Specify -c1 and -c2, or -z1 and -z2, or all four optoins")

    if options.component_log_1:
        compare_components(options.component_log_1, options.component_log_2)

    if options.zenpacks_log_1:
        # if we already reported on component differences, add a blank link before reporting ZP diffs
        if options.component_log_1:
            print ""
        compare_zenpacks(options.zenpacks_log_1, options.zenpacks_log_2)

class DiffInfo(object):
    def __init__(self, name, artifact1, artifact2):
        self.name = name
        self.artifact1 = artifact1
        self.artifact2 = artifact2

    def __str__(self):
        if self.different:
            different = "diff"
        else:
            different = "same"
        return "%s: %s: %s (%s) vs %s (%s)" % (self.name, different, self.artifact1.version, self.artifact1.gitRef, self.artifact2.version, self.artifact2.gitRef)

    @property
    def different(self):
        if self.artifact1.versionInfo == self.artifact2.versionInfo:
            return False
        return True

    def toDict(self):
        return {
            "name": self.name,
            "artifact1": self.artifact1,
            "artifact2": self.artifact2,
            "different": self.different,
        }

class ArtifactInfo(object):
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
        if not self.version:
            return False
        elif re.match('.*(dev).*|.*(snap).*', self.version, re.IGNORECASE):
            return False
        return True

    @property
    def versionInfo(self):
        if self.version is None:
            return "n/a"

        if self.gitRef is not None:
            if len(self.gitRef) > 14:
                gitRef = "%-14.14s" % self.gitRef
            else:
                gitRef = self.gitRef
        return "%s (%s)" % (self.version, gitRef)

    def toDict(self):
        return {
            "git_repo": self.gitRepo,
            "version": self.version,
            "name": self.name,
            "type": self.infoType
        }


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
                gitRef =  'feature/%s' % self.feature
            elif self.pre and not self.requirement:
                gitRef = 'develop'
            elif not self.pre and not self.requirement:
                gitRef = 'master'
            else:
                raise Exception("Could not determine git_ref for %s from provided fields. "\
                        "Please specify desired git_ref field." % self.name)

        return gitRef

    @property
    def pinned(self):
        if self.pre:
            return False
        elif self.requirement and '==' in self.requirement and not ',' in self.requirement:
            return True
        return False

    @property
    def versionInfo(self):
        zenpack = self.info.get('zenpack')
        version = zenpack.get('version')
        if version is None:
            return "n/a"
        return version

    def toDict(self):
        result = super(ZenPackInfo, self).toDict()
        zpDict = {
            "pre": self.pre,
            "requirements": self.requirement,
            "feature": self.feature,
        }
        result.update(zpDict)
        return result

artifactClass = {
    "releasedArtifact": ArtifactInfo,
    "jenkins": JenkinsInfo,
    "zenpack": ZenPackInfo,
}

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Compare build logs')
    parser.add_argument('-c1', '--component_log_1', type=file,
                        help='zenoss_component_artifact log file 1')

    parser.add_argument('-c2',  '--component_log_2', type=file,
                        help='zenoss_component_artifact log file 2')

    parser.add_argument('-z1', '--zenpacks_log_1', type=file,
                        help='zenpacks_artifact log file 1')
    parser.add_argument('-z2', '--zenpacks_log_2', type=file,
                        help='zenpacks_artifact log file 2')

    parser.add_argument('-v', '--verbose', action="store_true")

    options = parser.parse_args()
    main(options)

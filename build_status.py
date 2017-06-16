#!/usr/bin/env python
# -*- coding: utf-8 -*-
##############################################################################
#
# build-status.py - Constructs a report on the status of a product build.
#
# This utility takes as input a template describing the jobs used to perform
# a full product build of Zenoss.  Given the template and a specific product
# build number, the utility uses the Jenkins Pipeline REST API to query the
# Jenkins server for information about each job described by the template.
#
# One of the primary reasons that a template is used is that Jenkins will not
# report a full list of stages in cases where a job was only partially
# successful. Also, in the case of the appliance build job, for certain types
# of appliances we are not interested in all of the stages. For instance core
# appliances do not build AMIs or QCOWs.  So the template provides a means
# to ignore some stages in cases like that to provide a more concise report.
#
# More information about the Jenkins Pipeline REST API is available here:
# https://github.com/jenkinsci/pipeline-stage-view-plugin/blob/master/rest-api/README.md
#
##############################################################################

import argparse
import datetime
import httplib
import json
import logging as log
import os
import re
import string
import urlparse
import urllib2


SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
JENKINS_SERVER = "http://platform-jenkins.zenoss.eng"


"""JobTemplate describes the report template of a job.

Attributes:
    name (str) - The name of this job template (not necessarily the same
        as the job name).
    jobPrefixes ((:obj:`list` of :obj:`str`)) - A list of of job name prefixes
        used in cases where a single instance of this report template should be
        applied to multiple types of jobs that differ only by name.
        If empty, then 'name' will be used to match this
        template to a particular type of job in Jenkins.
        Should not be used in conjunction with instanceTemplates.
    stages (:obj:`list` of :obj:`StageTemplate`) - list of the stages that will
        be reported for these types of job.
    instanceTemplates (:obj:`list` of :obj:`InstanceTemplate`) - list of instance
        report templates. Only used to customize the report when different instances
        of the same type of job have different reporting requirements.
        Should not be used in conjunction with jobPrefixes.
"""
class JobTemplate(object):
    def __init__(self, name, jobPrefixes, stages, instanceTemplates):
        self.name = name
        self.jobPrefixes = jobPrefixes
        self.stages = stages
        self.instanceTemplates = instanceTemplates

    def __str__(self):
        return "JobTemplate name '%s', jobPrefixes %s" % (self.name, self.jobPrefixes)

    def toDict(self):
        return {
            "name": self.name,
            "jobPrefixes": self.jobPrefixes,
            "stages": self.stages,
            "instanceTemplates": self.instanceTemplates,
        }


"""StageTemplate describes the report template of a particular Stage.

Attributes:
    name (str) - The name of the stage.
    childTemplate (str) - The name of a JobTemplate if this stage
        spawns a child job.
"""
class StageTemplate(object):
    def __init__(self, name, childInfoUrl, childTemplate):
        self.name = name
        self.childInfoUrl = childInfoUrl
        self.childTemplate = childTemplate

    def __str__(self):
        return "StageTemplate name '%s'" % self.name

    def toDict(self):
        return {
            "name": self.name,
            'childInfoUrl': self.childInfoUrl,
            "childTemplate": self.childTemplate,
        }


"""InstanceTemplate describes the report template for an instance of
a particular kind of job. Used to exclude some stages from the report.

Attributes:
    jobPrefix (str) - The prefix for job names to use for this report template.
    ignoreStages (:obj:`list` of :obj:`str`) - A list of stages to be ignored for
        jobs which match this template.
    parentJob (str) - The name of the parent job for this report template.
"""
class InstanceTemplate(object):
    def __init__(self, jobPrefix, ignoreStages, parentJob):
        self.jobPrefix = jobPrefix
        self.ignoreStages = ignoreStages
        self.parentJob = parentJob

    def __str__(self):
        return "InstanceTemplate jobPrefix '%s'" % self.jobPrefix

    def toDict(self):
        return {
            "jobPrefix": self.jobPrefix,
            "ignoreStages": self.ignoreStages,
            "parentJob": self.parentJob,
        }

"""JobReport defines the full build report. It is composed of a list of
StageInfo objects, which may contain a list of one or more JobReport objects
in cases where the stage spawns child jobs.

Attributes:
    jenkinsInfo (:obj:`list` of :obj:`JenkinsInfo`) - Information about the
        Jenkins job itself (name, label, number, etc)
    timeStats (:obj:`list` of :obj:`TimeStats`) - Statistics on when the job
        started and how long it took to complete
    stages (:obj:`list` of :obj:`StageInfo`) - The list of stages for the job.
"""
class JobReport(object):
    def __init__(self, jenkinsInfo, timeStats, stageFlowNodes):
        self.jenkinsInfo = jenkinsInfo
        self.timeStats = timeStats
        self.stages = stageFlowNodes

    def __str__(self):
        return "JobReport name '%s', label '%s'" % (self.jenkinsInfo.name, self.jenkinsInfo.label)

    def toDict(self):
        return {
            "jenkinsInfo": self.jenkinsInfo.toDict() if self.jenkinsInfo else {},
            "timeStats": self.timeStats.toDict() if self.timeStats else {},
            "stages": self.stages,
        }


"""JenkinsInfo defines the jenkins job information

Attributes:
    name (str) - The name of the jenkins job
    label (str) - The label or display name of the jenkins job
    url (str) - The full URL to the job
    number (str) - The job number.
    status (str) - The job status as reported by Jenkins (SUCCESS,
        FAILURE, IN-PROGRESS, etc). Will be an empty string for stages
        that never executed because of upstream failures.
"""
class JenkinsInfo(object):
    def __init__(self, name, label, url, number, status):
        self.name = name
        self.label = label
        self.url = url
        self.number = number
        self.status = status

    def __str__(self):
        return "JobReport name '%s', label '%s', status '%s'" % (self.name, self.label, self.status)

    def toDict(self):
        return {
            "name": self.name,
            "label": self.label,
            "url": self.url,
            "number": self.number,
            "status": self.status if self.status else "",
        }


"""TimeStats defines time related statistics for a given job or stage

Attributes:
    start (int) - The start time in milliseconds.
    duration (int) - The duration in milliseconds.
    stop (int) - The stop time in milliseconds.
"""
class TimeStats(object):
    def __init__(self, start, duration):
        self.start = start
        self.duration = duration

    def __str__(self):
        return "TimeStats start '%s', label '%s'" % (self.start, self.duration)

    @property
    def stop(self):
        return self.start + self.duration

    def toDict(self):
        return {
            "start": self.start,
            "duration": self.duration,
            "stop": self.stop,
        }


"""StageInfo defines information about a single stage.

Attributes:
    name (str) - The start time in milliseconds.
    status (str) - The stop time in milliseconds.
    timeStats (:obj:`list` of :obj:`TimeStats`) - Statistics on when the stage
        started and how long it took to complete
    jobs (:obj:`list` of :obj:`JobReport`) - A list of job reports for each
        child job spawned by this stage (if any).
"""
class StageInfo(object):
    def __init__(self, name, status, timeStats, jobs):
        self.name = name
        self.status = status
        self.timeStats = timeStats
        self.jobs = jobs

    def __str__(self):
        return "StageInfo name '%s', status '%s'" % (self.name, self.status)

    def toDict(self):
        return {
            "name": self.name,
            "status": self.status if self.status else "",
            "timeStats": self.timeStats.toDict() if self.timeStats else {},
            "jobs": self.jobs if self.jobs else [],
        }


CLASS_MAPPING = {
    frozenset(('name',
        'childInfoUrl',
        'childTemplate')): StageTemplate,
    frozenset(('jobPrefix',
        'ignoreStages',
        'parentJob')): InstanceTemplate,
    frozenset(('name',
        'jobPrefixes',
        'stages',
        'instanceTemplates')): JobTemplate,
    frozenset(('templates',)): dict
}


def class_mapper(d):
    return CLASS_MAPPING[frozenset(d.keys())](**d)


def loadReportTemplates(templateFile, branch):
    templates = json.loads(templateFile.read(), object_hook=class_mapper)['templates']
    log.debug("template count = %d" % len(templates))
    branchName = branch.replace("/", "-")
    for jobTemplate in templates:
        log.debug(jobTemplate)
        for stage in jobTemplate.stages:
            stage.childInfoUrl = stage.childInfoUrl.replace("%branch%", branchName)
            log.debug("\t%s" % stage)
        for instance in jobTemplate.instanceTemplates:
            log.debug("\t%s" % instance)
    return templates


def getInfo(baseUrl):
    apiUrl = os.path.join(baseUrl, "wfapi/describe")
    log.debug("Retrieving job info from %s" % apiUrl)
    return getUrl(apiUrl)


def getJobLog(jobUrl):
    logUrl = os.path.join(jobUrl, "wfapi/log")
    log.debug("Retrieving job log from %s" % logUrl)
    return getUrl(logUrl)


def getUrl(url):
    try:
        response = json.loads(urllib2.urlopen(url).read())
    except urllib2.URLError as e:
        raise Exception("Error downloading %s: %s" % (url, e))
    except urllib2.HTTPError as e:
        raise Exception("Error downloading %s: %s" % (url, e))
    except httplib.HTTPException, e:
        raise Exception("Error downloading %s: %s" % (url, e))
    return response


def jobStages(templates, jobName, jobLabel):
    found = False
    for template in templates:
        if template.jobPrefixes:
            for prefix in template.jobPrefixes:
                if str(jobName).startswith(prefix):
                    found = True
                    log.debug("found stages: match by prefix")
                    break
            if found:
               break

        elif template.name == jobName:
            found = True
            log.debug("found stages: match by template name")
            break

    if not found:
        log.debug('No stages found for job "%s" - "%s"' % (jobName, jobLabel))
        return []

    log.debug('found stages for job "%s" - "%s" in template %s' % (jobName, jobLabel, template.name))
    return getInstanceStages(template, jobLabel)


def getInstanceStages(template, jobLabel):
    # If the template has instanceTemplates, then
    #   in cases where this job name matches an instanceTemplate
    #       filter the list of stages to exclude the ones that should be ignored
    for instance in template.instanceTemplates:
        if str(jobLabel).startswith(instance.jobPrefix):
            filteredStages = template.stages[:]
            for stage in template.stages:
                for exclusion in instance.ignoreStages:
                    if exclusion == stage.name:
                        filteredStages.remove(stage)
                        break
            return filteredStages

    return template.stages


def buildReport(templates, jobInfo, jobName):
    log.info("%s:%s - %s" % (jobName, jobInfo["name"], jobInfo["status"]))

    jenkinsInfo = JenkinsInfo(None, None, None, None, None)
    jenkinsInfo.name = jobName if jobName else jobInfo["name"]
    jenkinsInfo.label = jobInfo["name"]

    baseUrl = jobInfo["_links"]["self"]["href"][:-len('/wfapi/describe')]
    jenkinsInfo.url = "%s%s" % (JENKINS_SERVER, baseUrl)
    jenkinsInfo.number = jobInfo["id"]
    jenkinsInfo.status = jobInfo["status"]
    log.debug("JenkinsInfo = %s", jenkinsInfo)

    stages = []
    for stageTemplate in jobStages(templates, jenkinsInfo.name, jenkinsInfo.label):
        log.debug("trying to find match for stageTemplate %s" % stageTemplate.name)
        found = False
        for stage in jobInfo["stages"]:
            if stage["name"] == stageTemplate.name:
                found = True
                jobs = []
                if stageTemplate.childTemplate:
                    addChildJobs(stageTemplate, templates, stage, jobs)
                stageTime = TimeStats(stage["startTimeMillis"], stage["durationMillis"])
                stageInfo = StageInfo(stage["name"], stage["status"], stageTime, jobs)
                break

        if not found:
            jobs = []
            if stageTemplate.childTemplate:
                jobs = addChildJobTemplates(templates, stageTemplate.childTemplate, jenkinsInfo.name)
            stageInfo = StageInfo(stageTemplate.name, None, None, jobs)

        stages.append(stageInfo)

    timeStats = TimeStats(jobInfo["startTimeMillis"], jobInfo["durationMillis"])
    jobReport = JobReport(jenkinsInfo, timeStats, stages)
    return jobReport

def addChildJobs(stageTemplate, templates, stage, jobs):
    stageFlowUrl = "%s%s" % (JENKINS_SERVER, stage["_links"]["self"]["href"])
    log.debug("URL for child jobs for '%s' = %s " % (stage["name"], stageFlowUrl))
    stageFlowInfo = getUrl(stageFlowUrl)

    log.info("found %d stage(s) for '%s'" %
        (len(stageFlowInfo["stageFlowNodes"]), stage["name"]))

    for node in stageFlowInfo["stageFlowNodes"]:
        # This is a bit of a hack - the finally clause in Jenkins-begin.groovy
        #    is included in the stageFlowNodes, so the following excludes it
        #    and any other simple 'sh()' directives that may be added in the
        #   future.
        if not node["name"].startswith("Building "):
            continue

        names = node["name"].split()
        jobName = names[len(names)-1]

        logUrl = "%s%s" % (JENKINS_SERVER, node["_links"]["log"]["href"])
        log.debug("URL for stage log of child job '%s' = %s " % (jobName, logUrl))
        nodeLog = getUrl(logUrl)

        #
        # NOTE - the following is subject to breakage as Jenkins updates :-(
        #
        # The following is kind of hacky, but haven't found a better technique given
        # the data returned from Jenkins.
        #
        # What we're trying to do is determine the URL for a downstream job started by
        # the current job.  The info is only available in the 'text' attribute,
        # which unfortunately is free form (and therefore may break in the future).
        #
        matchJobNumber = re.search("(#)(\d+)", nodeLog["text"])
        if matchJobNumber and len(matchJobNumber.groups()) == 2:
            jobNumber = matchJobNumber.group(2)
        else:
            log.warning("Unable to determine number for child job for step '%s' of job %s" % (node["name"], jobName))
            log.debug( "nodeLog['text']=%s" % nodeLog["text"])
            continue

        jobUrl = stageTemplate.childInfoUrl.replace("%jobName%", jobName).replace("%jobNumber%", jobNumber)
        jobUrl = "%s%s" % (JENKINS_SERVER, jobUrl)

        jobInfo = getInfo(jobUrl)
        childJobReport = buildReport(templates, jobInfo, jobName)
        jobs.append(childJobReport)

def addChildJobTemplates(templates, childTemplateName, parentJob):
    # find childTemplateName in templates
    jobs =  []
    found = False
    for template in templates:
        if template.name == childTemplateName:
            found = True
            break
    if not found:
        log.warning("No template found for child job name %s" % childTemplateName)
        return

    # for each instanceTemplate
    #   create empty job def
    for instance in template.instanceTemplates:
        if instance.parentJob and instance.parentJob != parentJob:
            continue
        stageTemplates = getInstanceStages(template, instance.jobPrefix)
        timeStats = TimeStats(0, 0)
        stages = []
        for stage in stageTemplates:
            stageInfo = StageInfo(stage.name, "", timeStats, [])
            stages.append(stageInfo)
        jenkinsInfo = JenkinsInfo(template.name, instance.jobPrefix, "", "", "")
        job = JobReport(jenkinsInfo, timeStats, stages)
        jobs.append(job)
    return jobs


def buildJSONReport(report, data_file):
    def dumpit(obj):
        if isinstance(obj, StageInfo):
            return obj.toDict() if obj else {}
        else:
            return obj.__dict__
    with open(data_file, 'w') as outFile:
        json.dump(report.toDict(), outFile, default=dumpit, indent=4, sort_keys=True, separators=(',', ': '))

def buildHTMLReport(report, branch, html_file):
    with open("jobTemplate.html", 'r') as templateFile:
        template = string.Template(templateFile.read())

    pageHeader = "Build report for %s %s" % (branch, report.jenkinsInfo.label)
    level = 0
    dataRows = []
    dataRows.extend(buildJobHTML(report, level))

    s = template.substitute(
        title='Zenoss Build Report',
        pageHeader=pageHeader,
        dataRows='\n'.join(dataRows))
    with open(html_file, 'w') as outFile:
        outFile.write(s)
        outFile.close()

ROW_TEMPLATE = string.Template(
"<tr>"
    "<td class='$indentLevel'>$name</td>"
    "<td class='$statusClass'>$status</td>"
    "<td>$duration</td>"
"</tr>")

def buildJobHTML(job, level):
    jobRows = []
    indentLevel = "indent%d" % level
    if job.jenkinsInfo and job.jenkinsInfo.url:
        jobLink = "<a href='%s'>%s - %s</a>" % (job.jenkinsInfo.url, job.jenkinsInfo.name, job.jenkinsInfo.label)
    else:
        jobLink = job.jenkinsInfo.label
    duration = print_duration(job.timeStats.duration) if job.timeStats and job.timeStats.duration else ""
    status = job.jenkinsInfo.status if job.jenkinsInfo and validStatus(job.jenkinsInfo.status) else ""

    row = ROW_TEMPLATE.safe_substitute(
        indentLevel=indentLevel,
        name=jobLink,
        status=status,
        statusClass=setStatusClass(status),
        duration=duration)
    jobRows.append(str(row))

    level += 1
    for stage in job.stages:
        stageRows = buildStageHTML(stage, level)
        jobRows.extend(stageRows)
    return jobRows


def buildStageHTML(stage, level):
    stageRows = []
    indentLevel = "indent%d" % level
    duration = print_duration(stage.timeStats.duration) if stage.timeStats and stage.timeStats.duration else ""
    status = stage.status if validStatus(stage.status) else ""

    row = ROW_TEMPLATE.substitute(
        indentLevel=indentLevel,
        name=stage.name,
        status=status,
        statusClass=setStatusClass(status),
        duration=duration)
    stageRows.append(str(row))

    level += 1
    for job in stage.jobs:
        stageRows.extend(buildJobHTML(job, level))

    return stageRows


# When this report is called from the finally block of job, some of the
#   jobs/stages might technically still be IN_PROGRESS because the
#   parent job is not really done until the finally block finishes.
#   Reporting "in progress" for the last stage is potentially confusing,
#   so don't report anything at all in that case.
#
# Note that if the report is run after the parent job has completly finished
#   then we'll never encounter a status of IN_PROGRESS
def validStatus(status):
    return status and status != "IN_PROGRESS"


def setStatusClass(status):
    if status and status != "SUCCESS":
        return "failure"
    return "success"


ONE_HOUR = 3600
ONE_MINUTE = 60


def print_duration(duration):
  elapsed = datetime.timedelta(0, 0, 0, duration)
  if elapsed.seconds < 1:
    return "%dms" % (elapsed.microseconds / 1000)
  elif elapsed.seconds < ONE_MINUTE:
    return "%ds" % (elapsed.seconds)
  elif elapsed.seconds < ONE_HOUR:
    minutes = elapsed.seconds / ONE_MINUTE
    seconds = elapsed.seconds % ONE_MINUTE
    return "%dmin %ds" % (minutes, seconds)
  else:
    hours = elapsed.seconds / ONE_HOUR
    minutes = (elapsed.seconds % ONE_HOUR) / ONE_MINUTE
    return "%dh %dmin" % (hours, minutes)


def main(options):
    templates = loadReportTemplates(options.template, options.branch)
    beginJobInfo = getInfo(options.build_url)
    if options.job_status:
        beginJobInfo["status"] = options.job_status
    report = buildReport(templates, beginJobInfo, "begin")

    buildJSONReport(report, options.json_output_file)
    buildHTMLReport(report, options.branch, options.html_output_file)
    return


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description='Report build status')
    parser.add_argument('-p', '--product-number', type=str, required=True,
                        help='the product build number')
    parser.add_argument('-b',  '--branch', type=str, required=True,
                        help='the product branch; e.g. develop or support-5.2.x')

    parser.add_argument('-n',  '--job-name', type=str,
                        default='begin',
                        help='Name of the beginning Jenkins job')
    parser.add_argument('-s',  '--job-status', type=str,
                        help='Status of the beginning Jenkins job')
    parser.add_argument('-u',  '--build-url', type=str,
                        help='Jenkins URL to current build')
    parser.add_argument('-j',  '--json-output-file', type=str,
                        default='buildReport.json',
                        help='Name of the JSON output file; default is buildReport.json')
    parser.add_argument('-html',  '--html-output-file', type=str,
                        default='buildReport.html',
                        help='Name of the HTML output file; default is buildReport.html')
    parser.add_argument('-t',  '--template', type=file,
                        default='jobTemplate.json',
                        help='The template describing each of the build jobs')
    parser.add_argument('-v', '--verbose', action="store_true",
                        help='verbose mode')
    parser.set_defaults(verbose=False)

    options = parser.parse_args()
    log.basicConfig(level=log.DEBUG if options.verbose else log.INFO)
    main(options)

# versionInfo Syntax

# Table of Contents
  - [Overview](#overview)
  - [Using Nightly Builds](#using-nightly-builds)
    - [Using Nightly Builds for Components](#using-nightly-builds-for-components)
    - [Using Nightly Builds for ZenPacks](#using-nightly-builds-for-zenpacks)
  - [Pinning Versions](#pinning-versions)
    - [Pinning Versions for Components](#pinning-versions-for-components)
    - [Pinning Versions for ZenPacks](#pinning-versions-for-zenpacks)
  - [Syntax Details](#syntax-details)
    - [Download-type artifacts](#download-type-artifacts)
    - [Jenkins-type artifacts](#jenkins-type-artifacts)
    - [ZenPack-type artifacts](#zenpack-type-artifacts)

# Overview
Both [component_versions.json](component_versions.json) and [zenpack_versions.json](zenpack_versions.json) are processed by the `artifact_dowload.py` script. That script supports 3 different types of downloads:
* `"type": "download"` - artifacts available from any generic HTTP file server; e.g. files that can downloaded using a tool like wget or curl
* `"type": "jenkins"` - artifacts available on a Jenkins build server. Jenkins supports a REST API which allows the download script to locate artifacts for the `lastSuccessfulBuild`
* `"type": "zenpack"` - used for all ZenPacks. ZenPack releases, nightly builds and builds for long-running feature development are all stored on a pypiserver. The downloader script for ZenPacks takes advantage of Python conventions for identifying different types of artifacts

The JSON file sytnax details for each of these types is available [below](#syntax-details)

# Using Nightly Builds

## Using Nightly Builds for Components
Assuming the `component_versions.json` file already specifies a pinned version of the component (`"type": "download"`),
modify the file to use `"type": "jenkins"`.  The following example illustrates the simplest case. Some Java-based artifacts may require additional properties.
For more information see the section on [Jenkins-type artifacts](#jenkins-type-artifacts) below.

Before (using a pinned release):
```
    {
        "URL": "http://zenpip.zendev.org/packages/{name}-{version}.tar.gz",
        "name": "zproxy",
        "type": "download",
        "version": "1.0.0"
    }
```

After (using the last successful build from Jenkins):
```
    {
        "name": "zproxy",
        "type": "jenkins",
        "version": "develop"
    }
```

## Using Nightly Builds for Zenpacks
Assuming the `zenpacks_versions.json` file already specifies latest GA release of the zenpack
modify the file to use `"pre": "true"`.
For more information see the section on [ZenPack-type artifacts](#zenpack-type-artifacts) below.

Before (using latest release):
```
    {
        "name": "ZenPacks.zenoss.Example",
        "type": "zenpack",
    }
```

After (the latest prerelease is the most recent build from the `develop` branch):
```
    {
        "name": "ZenPacks.zenoss.Example",
        "type": "zenpack",
        "pre": "true",
    }
```

# Pinning Versions

## Pinning Versions for Components
To pin the version for a component in `component_versions.json`, change the `type` property to `download` and specify the `version`.
For more information see the section on [Download-type artifacts](#download-type-artifacts) below.

Before (using the last successful build from Jenkins):
```
    {
        "name": "zproxy",
        "type": "jenkins",
        "version": "develop"
    }
```

After (using a pinned release):
```
    {
        "URL": "http://zenpip.zendev.org/packages/{name}-{version}.tar.gz",
        "name": "zproxy",
        "type": "download",
        "version": "1.0.0"
    }
```

## Pinning Versions for Zenpacks
To pin the version for a ZenPack in `zenpack_versions.json`, add a `requirement` property with an exact version.
For more information see the section on [ZenPack-type artifacts](#zenpack-type-artifacts) below.

Before (using latest release):
```
    {
        "name": "ZenPacks.zenoss.Example",
        "type": "zenpack",
    }
```

After (using exactly version 1.2.3):
```
    {
        "name": "ZenPacks.zenoss.Example",
        "type": "zenpack",
        "requirement": "ZenPacks.zenoss.Example===1.2.3"
    }
```

# Syntax Details

## Download-type artifacts
The type `download` is suitable for any artifacts which have been published to a file server somewhere, such that they can be downloaded with a simple curl or wget.

The full `versionInfo` JSON syntax:
```
    {
        "name": "metricshipper",
        "type": "download",
        "version": "1.1.2",
        "URL": "http://zenpip.zendev.org/packages/{name}-{version}.tgz"
    }
```

### Property Definitions:

* `name` - Required. Name for the artifact. By convention, should be the name of the artifact's github repo minus the "zenoss/" prefix.

* `type` - Required. Must be set to `download` to use this downloader.

* `version` - Required. The version of this artifact.

* `URL` - Required. The URL of the artifact. The macros `{name}` and `{version}` may be specified to avoid repitition of the name and version values, respectively.

## Jenkins-type artifacts
The type `jenkins` is suitable for any artifacts built and cached on one of Zenoss' jenkins servers. To use type `jenkins`, the corresponding Jenkins job must be defined with the Post Build Action `Archive the Artifacts`.  Most of the attributes are optional assuming that the component is built on `platform-jenkins.zenoss.eng` per standard conventions.

The full `versionInfo` JSON syntax:
```
    {
        "name": "zenoss-zep",
        "type": "jenkins",
        "version": "develop",
        "jenkins.subModule": "org.zenoss.zep$zep-dist",
        "jenkins.server": "http://platform-jenkins.zenoss.eng",
        "jenkins.job": "Components/job/zenoss-zep/job/develop",
        "jenkins.jobURL": "http://platform-jenkins.zenoss.eng/job/Components/job/zenoss-zep/job/develop",
        "jenkins.patterns": "['*.whl', '*.tgz', '*.tar.gz']",
    }
```

### Property Definitions:

* `name` - Required. Name for the artifact. By convention, should be the name of the artifact's github repo minus the "zenoss/" prefix.

* `type` - Required. Must be set to `jenkins` to use this downloader.

* `version` - Required. The version of the artifact. More specifically, the name of the branch of being built.

* `jenkins.subModule` - Optional. Only used for Java-based artifacts where the maven pom defines submodules. If specified, must identify the maven submodule containing the distribution artifact. If not specified, defaults to an empty string.

* `jenkins.server` - Optional. The URL of the Jenkins server. If not specified, the default is `http://platform-jenkins.zenoss.eng`.

* `jenkins.job` - Optional. The name of the Jenkins job that builds the artifact. If the job is nested in a folder, the string should include the folder-relative path. If not specified, the default is `Components/job/{name}/job/{version}`.

* `jenkins.jobURL` - Optional. The full URL of the jenkins job. If not specified, the default is `{jenkins.server}/job/{jenkins.job}`.

* `jenkins.patterns` - Optional. A list of patterns describing the artifact(s) that should be downloaded. If not specified, the default is `['*.whl', '*.tgz', '*.tar.gz']`.

## ZenPack-type artifacts
The type `zenpack` is suitable for all ZenPacks.

The full `versionInfo` JSON syntax:
```
    {
        "name": "ZenPacks.zenoss.Example",
        "type": "zenpack",
        "requirement": "ZenPacks.zenoss.Example>=0.0.1",
        "pre": false,
        "feature": null
    }
```
### Property Definitions:

* `name` - Required. Name for the artifact. Should be the ZenPack's Python package name.

* `type` - Required. Must be set to `zenpack` to use this downloader.

* `requirement` - Optional. Default value is that of the `name` field. Accepts any setuptools pkg_resources requirement format. Prelease builds
will be excluded unless the `pre` field is set to `true` (see
below), and feature builds will be excluded unless the `feature`
field is set (see below). See also [Python Setuptools documentation](http://setuptools.readthedocs.io/en/latest/pkg_resources.html#requirements-parsing)

* `pre` - Optional. Default value is `false`. When set to false, no
prerelease builds matching requirement will be returned. When
set to `true`, prerelease, release, and postrelease builds
matching requirement will be returned.

    Prerelease is defined by PEP 440 and includes both pre-releases
and developmental releases.

    https://www.python.org/dev/peps/pep-0440/#pre-releases
    https://www.python.org/dev/peps/pep-0440/#developmental-releases

* `feature` - Optional. Default value is null. When set to null, no feature
builds matching requirement will be returned. When set to a string value, only builds of a feature matching the string value
that also match requirement will be returned.

    Setting feature to a non-null value implies setting the `pre`
    field to true. This because all feature builds are inherently pre-releases.

### Credible examples:

* Specific release version:
```
    {
        "name": "ZenPacks.zenoss.Example",
        "type": "zenpack",
        "requirement": "ZenPacks.zenoss.Example===1.0.0"
    }
```
* Newest release version:
```
    {
        "name": "ZenPacks.zenoss.Example",
        "type": "zenpack"
    }
```
* Newest patch release within a minor release series:
```
    {
        "name": "ZenPacks.zenoss.Example",
        "type": "zenpack",
        "requirement": "ZenPacks.zenoss.Example==1.0.*"
    }
```
* Newest pre-release version (i.e. latest version built from develop):
```
    {
        "name": "ZenPacks.zenoss.Example",
        "type": "zenpack",
        "pre": true
    }
```
* Newest pre-release within a minor release series:
```
    {
        "name": "ZenPacks.zenoss.Example",
        "type": "zenpack",
        "requirement": "ZenPacks.zenoss.Example==1.0.*",
        "pre": true
    }
```
* Specific feature by name regardless of version.
```
    {
        "name": "ZenPacks.zenoss.Example",
        "type": "zenpack",
        "feature": "fireworks"
    }
```

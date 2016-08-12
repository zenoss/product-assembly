# product-assembly

# Table of Contents
  - [Overview](#overview)
  - [Updating Version Numbers](#updating-version-numbers)
  - [Adding/Removing a new component or ZenPack](#adding-or-removing-a-new-component-or-zenpack)
    - [Adding or Removing components](#adding-or-removing-components)
    - [Adding or Removing ZenPacks](#adding-or-removing-zenpacks)
  - [Using Nightly Builds](#using-nightly-builds)
  - [Setting up Builds for a Maintenance Release](#setting-up-builds-for-a-maintenance-release)

## Overview

This repository assembles products such as Zenoss Core and Zenoss Resource Manager.
The assembly results for each Zenoss product are:
* A Docker image for the product
* A JSON service template file
* An RPM containing the JSON service template file

Each of the subdirectories `core`, `resmgr`, and `product-base` have a makefile which will build a docker image
The `zenoss/product-base` image must be built first. This image contains the
[core Zenoss platform](https://github.com/zenoss/zenoss-prodbin)
and all of the third-party services required to run Zenoss (Zope, RabbitMQ, redis, etc).
The  docker images for Core and RM are start with `zenoss/product-base` and
simply add the ZenPacks appropriate for that particular product.

## Updating Version Numbers

The product assembly integrates different kinds of components that are sourced
from a variety of locations (github, Docker hub, artifact servers). The table below
defines the files in this repo which are used to record the version numbers for different
components included in the various product images.

| Artifact | Source | Version(s) Defined Here |
| -------- | ------ | -------------------- |
| Zenoss Product Version | this repo | See `VERSION` and `SHORT_VERSION` in [versions.mk](versions.mk) |
| Supplementary Docker images such as HBase | [Docker Hub](https://hub.docker.com/u/zenoss/dashboard/)  | E.g. `HBASE_VERSION` in [versions.mk](versions.mk) |
| CC Service Templates | [github/zenoss/zenoss.service](https://github.com/zenoss/zenoss-service) | See `SVCDEF_GIT_REF` in [versions.mk](versions.mk) |
| Versions of components such as centralquery and core (prodbin) included in `zenoss/product-base` | various locations | [component_versions.json](component_versions.json) |
| ZenPack versions  | various locations | [zenpack_versions.json](zenpack_versions.json) |

## Adding or Removing a new component or ZenPack

### Adding or Removing components
In this context a "component" is anything in the image that is NOT a ZenPack.
Currently, all such components are installed in the `zenoss/product-base` image, so they are shared by
both Core and RM. The list of components to be installed is maintained in the file
[component_versions.json](component_versions.json).

So to add or a remove a component, simply modify [component_versions.json](component_versions.json).

### Adding or Removing ZenPacks
ZenPack information is split across two files
* [zenpack_versions.json](zenpack_versions.json) defines the versions and download sources for the various ZenPacks
* [core/zenpacks.json](core/zenpacks.json) defines the set of ZenPacks included in the Zenoss Core image
* [resmgr/zenpacks.json](resmgr/zenpacks.json) defines the set of ZenPacks included in the Zenoss Resource Manager image

To add a ZenPack, first add an entry to `zenpack_versions.json`, then update the `zenpacks.json` file for Core and/or RM as approviate.

## Using Nightly Builds
To update nightly builds for a component, find the entry for the component in either
`component_versions.json` or `zenpack_versions.json`.
Remove the `URL` attribute,
change the `type` property to `"jenkins"`, and
add a `jenkinsInfo` property identifying the jenkins jobs and the associated artifact of that job.

In the following example, the Before illustrates a download-type component, and the After illustrates
the same component record modified to be a jenkins-type component.

Before:
```
    {
        "URL": "http://zenpip.zendev.org/packages/prodbin-5.2.0-develop.tar.gz",
        "git_ref": "develop",
        "git_repo": "https://github.com/zenoss/zenoss-prodbin.git",
        "name": "zenoss-prodbin",
        "type": "download",
        "version": "develop"
    },
```

After:
```
    {
        "git_ref": "develop",
        "git_repo": "https://github.com/zenoss/zenoss-prodbin.git",
        "jenkinsInfo": {
            "job": "prodbin-merge-develop",
            "pattern": "prodbin*.tar.gz",
            "server": "http://jenkins.zendev.org"
        },
        "name": "zenoss-prodbin",
        "type": "jenkins",
        "version": "develop"
    },
```

## Setting up Builds for a Maintenance Release
This section assumes that a maintenance release is based on a branch of this repo like `support/5.2.x`.
The branch name has to be modified in two files in this repo - [Jenkins-begin.groovy](Jenkins-begin.groovy) and
[versions.mk](versions.mk).

In `Jenkins-begin.groovy`, change the `git branch:` statement in the first stage ('Checkout product-assembly repo'), to be the name of the support branch (e.g. `support/5.2.x`).

In `verions.mk`, change the value of `SVCDEF_GIT_REF` to be the name of the support branch (e.g. `support/5.2.x`).

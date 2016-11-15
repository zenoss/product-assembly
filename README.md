# product-assembly

# Table of Contents
  - [Overview](#overview)
  - [Updating Version Numbers](#updating-version-numbers)
  - [Adding/Removing a new component or ZenPack](#adding-or-removing-a-new-component-or-zenpack)
    - [Adding or Removing components](#adding-or-removing-components)
    - [Adding or Removing ZenPacks](#adding-or-removing-zenpacks)
  - [Build like Jenkins](#build-like-jenkins)
  - [Test like Jenkins](#test-like-jenkins)

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
The  docker images for Core and RM start with `zenoss/product-base`, then
the build initializes Zenoss, and adds the ZenPacks appropriate for that particular product.

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

For a detailed description of the syntax for [component_versions.json](component_versions.json) and [zenpack_versions.json](zenpack_versions.json), see [README.versionInfo.md](README.versionInfo.md)

## Adding or Removing a new component or ZenPack

### Adding or Removing components
In this context a "component" is anything in the image that is NOT a ZenPack.
Currently, all such components are installed in the `zenoss/product-base` image, so they are shared by
both Core and RM. The list of components to be installed is maintained in the file
[component_versions.json](component_versions.json).

So to add or remove a component, simply modify [component_versions.json](component_versions.json).
The other file that needs to be changed is [product-base/install_scripts/zenoss_component_install.sh](product-base/install_scripts/zenoss_component_install.sh). This script is run inside the Docker image as it is being
built.  It is responsible for downloading the artifact by name and then unpacking it into the image at the
correct location.

### Adding or Removing ZenPacks
ZenPack information is split across two files
* [zenpack_versions.json](zenpack_versions.json) defines the versions and download sources for the various ZenPacks
* [core/zenpacks.json](core/zenpacks.json) defines the set of ZenPacks included in the Zenoss Core image
* [resmgr/zenpacks.json](resmgr/zenpacks.json) defines the set of ZenPacks included in the Zenoss Resource Manager image

To add a ZenPack, first add an entry to `zenpack_versions.json`, then update the `zenpacks.json` file for Core and/or RM as approviate.

## Build Like Jenkins
The nightly build in Jenkins essentially runs these steps:
```
cd product-base
make clean build
cd ../core
make clean build
cd ../resmgr
make clean build
```

The first step builds the docker image `zenoss/product-base:5.2.0_DEV_DEV` (or whatever version your branch is on). The next two steps build `zenoss/core_5.2:5.2.0_DEV_DEV` and `zenoss/resmgr_5.2:5.2.0_DEV_DEV` (again with the respective versions for your local branch).

The last 2 makes are performed in parallel for the nightly build. A developer typically only needs to build one of core or resmgr.

# Test Like Jenkins
The nightly build in Jenkins runs these steps to test an image after it is built
```
cd ../core
make run-tests
cd ../resmgr
make run-tests
```
Again, the last 2 makes are performed in parallel for the nightly build. A developer typically only needs to test one of core or resmgr.


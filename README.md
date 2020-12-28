# product-assembly

# Table of Contents
  - [Overview](#overview)
  - [Updating Version Numbers](#updating-version-numbers)
  - [Adding/Removing a new component or ZenPack](#adding-or-removing-a-new-component-or-zenpack)
    - [Adding or Removing components](#adding-or-removing-components)
    - [Adding or Removing ZenPacks](#adding-or-removing-zenpacks)
  - [Build like Jenkins](#build-like-jenkins)
  - [Test like Jenkins](#test-like-jenkins)
  - [Compare Builds](#compare-builds)
  - [Developer Config](#configure-cz-for-development)

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
The nightly build in Jenkins runs these steps to test an image after it is built:
```
cd ../core
make run-tests
cd ../resmgr
make run-tests
```
Again, the last 2 makes are performed in parallel for the nightly build. A developer typically only needs to test one of core or resmgr.

# Compare Builds

`compare_builds.py` compares the build logs from 2 different builds to identify which artifacts are different. By default, the comparison only reports differences. If you specify `-v`, it will report all artifacts, not just the different ones.

**NOTE:** This tool does NOT compare:
* Changes to service definitions, because [zenoss-service](https://github.com/zenoss/zenoss-service) is not built/packaged as an artifact like the other components (though it should be).  See `SVCDEF_GIT_REF` in [versions.mk](versions.mk) for information about which version of service definitions were used in a build.
* Changes to serviced included in downstream appliances and other build artifacts. Again, see [versions.mk](versions.mk) for details about serviced versions included in a particular build.
* Changes that may have been made to this repo itself (i.e. changes in the build process).
* Any changes to the downstream appliance build process (see [zenoss-deploy](https://github.com/zenoss/zenoss-deploy)).

The following examples illustrate that the only difference between Core 5.2.0 RC2 and the Core 5.3.0 pipeline build 3 is zenoss-prodbin.   The ZenPacks output is particular reassuring because all of the zenpacks in Core 5.2.0 RC2 are pinned to a specific version, where as Core 5.3.0 on develop is pulling the most recently released ZPs - so that proves that pinned versions in 5.2.0 RC2 are really the latest ones.

**1. Compare 2 jenkins jobs**
```
$ ./compare_builds.py -b1 support-5.2.x/core-pipeline/242 -b2 develop/core-pipeline/3
Component Differences:
Name                                     c1 (gitRef)                      c2 (gitRef)                      Different
zenoss-prodbin                           5.2.0 (5.2.0)                    develop (85f5b99d40e35b)         Y

ZenPack Differences:
Name                                     z1 (gitRef)                      z2 (gitRef)
```

**2. Compare just the components (using previously downloaded log files)**
```
$ ./compare_builds.py -c1 zenoss_component_artifact52.RC2.log -c2 zenoss_component_artifact53.log
Component Differences:
Name                                     c1 (gitRef)                      c2 (gitRef)                      Different
zenoss-prodbin                           5.2.0 (5.2.0)                    develop (85f5b99d40e35b)         Y
```

**3. Compare just the zenpacks (using previously downloaded log files)**
```
$ ./compare_builds.py -z1 zenpacks_artifact52.RC2.log -z2 zenpacks_artifact53.log
ZenPack Differences:
Name                                     z1 (gitRef)                      z2 (gitRef)
```

**4. Generate manifest for changelog utility**
```
$ ./compare_builds.py -c1 zenoss_component_artifact52.RC2.log -c2 zenoss_component_artifact53.log -f json > repos.json
$ cat repos.json
{
    "services": [
        {
            "repo": "git@github.com:zenoss/query.git", 
            "start": "0.1.33", 
            "end": "f4270f7edd3b326f5e372489ac1bba9666f0d322", 
            "service": "query"
        }, 
        {
            "repo": "git@github.com:zenoss/zenoss-prodbin.git", 
            "start": "7.0.7", 
            "end": "d9859ee97ffa17615ac73ca2a8da0825150b5f8c", 
            "service": "zenoss-prodbin"
        }, 
        {
            "repo": "git@github.com:zenoss/zenoss-zep.git", 
            "start": "2.7.0", 
            "end": "2.7.1", 
            "service": "zenoss-zep"
        }
    ]
}
```
The same is for zenpacks:
```
$ ./compare_builds.py -z1 zenpacks_artifact52.RC2.log -z2 zenpacks_artifact53.log -f json > repos.json
$ cat repos.json
{
    "services": [
        {
            "repo": "git@github.com:zenoss/ZenPacks.zenoss.Dashboard.git", 
            "start": "1.3.3", 
            "end": "1.3.4", 
            "service": "ZenPacks.zenoss.Dashboard"
        }, 
        {
            "repo": "git@github.com:zenoss/ZenPacks.zenoss.Dell.PowerEdge.git", 
            "start": "2.0.4", 
            "end": "3.0.0", 
            "service": "ZenPacks.zenoss.Dell.PowerEdge"
        }
```

# Configure CZ for Development
These changes allow you to access the RM directly without using Auth0 and SmartView, although it does make SmartView not work anymore.
1. In Control Center, click `Edit Variables` for the "Zenoss.cse" service and comment out the following lines:
   ```
   global.conf.auth0-audience https://dev.zing.ninja
   global.conf.auth0-emailkey https://dev.zing.ninja/email
   global.conf.auth0-tenant https://zenoss-dev.auth0.com/
   global.conf.auth0-tenantkey https://dev.zing.ninja/tenant
   global.conf.auth0-whitelist <login-id>
   ```
   where `<login-id>` is your ID.
2. Staying in the "Zenoss.cse" service, edit the `/opt/zenoss/zproxy/conf/zproxy-nginx.conf` file and comment out these lines (lines 169-172 in the 7.0.15 service defs):
   ```
   location ~* ^/zport/acl_users/cookieAuthHelper/login {
      # ZEN-30567: Disallow the basic auth login page.
      return 403;
   }
   ```
3. Restart your services.  Probably only the "Zope", "ZAuth", "zenapi", "zenreports", and "Zenoss.cse" services need restarting rather than all the services.  Not all the services look at the `auth0` settings in the `global.conf` file or the `zproxy-nginx.conf` file.
4. After the services have restarted, go to `https://<login-id>.zing.soy/cz0/zport/dmd` and use `admin/zenoss` for your credentials.

# product-assembly

This repository assembles products such as Zenoss Core and Zenoss Resource Manager.
The assembly results for each Zenoss product are:
* A Docker image for the product
* A JSON service template file
* An RPM containing the JSON service template file

## Updating Version Numbers

The product assembly integrates different kinds of components that are sourced
from a variety of locations (github, Docker hub, artifact servers). The table below
defines the files in this repo which are used to record the version numbers for different 
components included in the various product images.

| Artifact | Source | Version Defined Here |
| -------- | ------ | -------------------- |
| Zenoss Product Version | this repo | See `VERSION` and `SHORT_VERSION` in [versions.mk](versions.mk) |
| Supplementary Docker images such as HBase | [Docker Hub](https://hub.docker.com/u/zenoss/dashboard/)  | E.g. `HBASE_VERSION` in [versions.mk](versions.mk) |
| CC Service Templates | [github/zenoss/zenoss.service](https://github.com/zenoss/zenoss-service) | See `SVCDEF_GIT_REF` in [versions.mk](versions.mk) |
| Component versions defined in the `zenoss/product-base` | various locations | TBD |
| ZenPack versions  | various locations | [zenpack_versions.json](zenpack_versions.json) |

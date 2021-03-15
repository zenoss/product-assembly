#
# versions.mk - Common version numbers for various portions of the product
#               assembly process
#
# NOTE: This file must be formatted as a Java Properties file becuase it is
# read from Jenkins-image.groovy.  Fortunately, Java properties and make
# properties are equivalent in the simplest case.

#
# HBASE_VERSION     the HBase image version
# HDFS_VERSION      the HDFS image version
# OPENTSDB_VERSION  the opentsdb image version
# ZING_CONNECTOR_VERSION the version tag for the zing-connector image
# OTSDB_BIGTABLE_VERSION  version of the otsdb with bigtable support image
# SHORT_VERSION     the two-digit Zenoss product version; e.g. 5.2
# SVCDEF_GIT_REF    the git branch name, tag name or SHA for the version of the
#                   github.com:zenoss/zenoss-service repo to checkout and build
# VERSION           the full Zenoss product version; e.g. 5.2.0
# UCSPM_VERSION     the version of the ucspm release; e.g 2.1.0
#
SHORT_VERSION=7.0
SVCDEF_GIT_REF=hotfix/7.0.19
VERSION=7.0.19
VERSION_TAG=1

#
# Currently, HDFS and OpenTSDB use the same image as HBASE
# So these versions should always be the same.
# these are not used for CSE GCP builds
HBASE_VERSION=24.0.8
HDFS_VERSION=24.0.8
OPENTSDB_VERSION=24.0.8

ZING_CONNECTOR_VERSION=2021-03-15-0
OTSDB_BIGTABLE_VERSION=v3
IMPACT_VERSION=5.5.3.0.0
ZING_API_PROXY_VERSION=2019-10-08-0
ZENOSS_CENTOS_BASE_VERSION=1.3.4

#Image project or organization used for images eg.  zing-registry-188222/cse_7.0:[TAG]
IMAGE_PROJECT=zing-registry-188222

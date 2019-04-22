#
# versions.mk - Common version numbers for various portions of the product assembly process
#
# NOTE: This file must be formatted as a Java Properties file becuase it is read from Jenkins-image.groovy.
#       Fortunately, Java properties and make properties are equivalent in the simplest case.

#
# HBASE_VERSION     the HBase image version
# HDFS_VERSION      the HDFS image version
# OPENTSDB_VERSION  the opentsdb image version
# SHORT_VERSION     the two-digit Zenoss product version; e.g. 5.2
# SVCDEF_GIT_REF    the git branch name, tag name or SHA for the version of the
#                   github.com:zenoss/zenoss-service repo to checkout and build
# VERSION           the full Zenoss product version; e.g. 5.2.0
# UCSPM_VERSION     the version of the ucspm release; e.g 2.1.0
#
SHORT_VERSION=6.4
SVCDEF_GIT_REF=support/6.x
VERSION=6.4.0
UCSPM_VERSION=3.0.0
VERSION_TAG=1

#
# Currently, HDFS and OpenTSDB use the same image as HBASE
# So these versions should always be the same.
#
HBASE_VERSION=24.0.8
HDFS_VERSION=24.0.8
OPENTSDB_VERSION=24.0.8


#
# The serviced information is used to create the appliance artifacts for a given RM release.
# There are two ways to identify which version of serviced to use in the appliances:
#
# 1. Use the last successful build
#
#    Specify SERVICED_BRANCH with the name of the branch, and the appliance build will look
#    up the last successful build for that branch to get the RPM version information necessary
#    to install the serviced RPM from the unstable yum repo into the appliances.
#
#    If SERVICED_BRANCH is specified, both SERVICED_VERSION and SERVICED_BUILD_NUMBER must be blank.
#
# 2. Specify a specific version and build
#
#    Specify the 3-digit version of serviced with SERVICED_VERSION and the build number with
#    SERVICED_BUILD_NUMBER. The corresponding RPM must be available in the stable yum repo.
#
#    SERVICED_VERSION and SERVICED_BUILD_NUMBER have to be specified together, and
#    SERVICED_BRANCH must be blank if both are specified.
#
#    If SERVICED_BRANCH is specified, then SERVICED_MATURITY must be 'unstable'.
#    If SERVICED_VERSION and SERVICED_BUILD_NUMBER are specified, then the
#    SERVICED_BRANCH should be 'testing' or 'stable'
#
SERVICED_BRANCH=
SERVICED_MATURITY=unstable
SERVICED_VERSION=1.6.5
SERVICED_BUILD_NUMBER=343

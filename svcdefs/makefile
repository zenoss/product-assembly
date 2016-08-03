#
# Makefile to compile service definitions as part of the product assembly process.
#
# This file REQUIRES the following input variables
#
# HBASE_VERSION		the HBase image version
# HDFS_VERSION		the HDFS image version
# OPENTSDB_VERSION	the opentsdb image version
# SHORT_VERSION		the two-digit Zenoss product version; e.g. 5.2
# SVCDEF_GIT_SHA	the git branch, tag name or SHA for the version of the
# 					github.com:zenoss/zenoss-service repo to checkout and build
# TARGET_PRODUCT	the target product name (e.g. 'core', 'resmgr', 'ucspm', etc)
# VERSION			the full Zenoss product version; e.g. 5.2.0
#
# The following input variables are OPTIONAL:
#
# BUILD_NUMBER	the build number for this product pipeline build; defaults to YYYYMMDDhhmmss
# IMAGE_NUMBER	the docker image number for this build; defaults to DEV
# MATURITY		the image maturity level (e.g. 'unstable', 'testing', 'stable'); defaults to DEV
#

BUILD_NUMBER ?= $(shell date +%Y%m%d%H%M%S)
IMAGE_NUMBER ?= DEV
MATURITY     ?= DEV

verifyInputs:
ifndef HBASE_VERSION
	$(error HBASE_VERSION is not set)
endif
ifndef HDFS_VERSION
	$(error HDFS_VERSION is not set)
endif
ifndef OPENTSDB_VERSION
	$(error OPENTSDB_VERSION is not set)
endif
ifndef SHORT_VERSION
	$(error SHORT_VERSION is not set)
endif
ifndef SVCDEF_GIT_SHA
	$(error SVCDEF_GIT_SHA is not set)
endif
ifndef TARGET_PRODUCT
	$(error TARGET_PRODUCT is not set)
endif
ifndef VERSION
	$(error VERSION is not set)
endif

TEMP_DIR := build

.PHONY: verifyInputs clean

default: build

buildTempDir:
	if [ ! -d $(TEMP_DIR) ]; then mkdir $(TEMP_DIR); fi

build: verifyInputs buildTempDir
	cd $(TEMP_DIR) && git clone git@github.com:zenoss/zenoss-service.git 
	cd $(TEMP_DIR)/zenoss-service && git checkout $(SVCDEF_GIT_SHA)
	cd $(TEMP_DIR)/zenoss-service && \
		BUILD_NUMBER=$(BUILD_NUMBER) \
		hbase_VERSION=$(HBASE_VERSION) \
		hdfs_VERSION=$(HDFS_VERSION) \
		IMAGE_NUMBER=$(IMAGE_NUMBER) \
		MILESTONE=$(MATURITY) \
		opentsdb_VERSION=$(OPENTSDB_VERSION) \
		SHORT_VERSION=$(SHORT_VERSION) \
		VERSION=$(VERSION) \
		make docker_svcdefpkg-$(TARGET_PRODUCT)

clean:
	-rm -rf $(TEMP_DIR)

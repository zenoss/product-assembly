#
# Makefile to compile service definitions as part of the product assembly process.
#

#
# This file REQUIRES the following input variables.  Note that all of these
# except TARGET_PRODUCT are defined in ../versions.mk
#
# HBASE_VERSION     the HBase image version
# HDFS_VERSION      the HDFS image version
# OPENTSDB_VERSION  the opentsdb image version
# SHORT_VERSION     the two-digit Zenoss product version; e.g. 5.2
# TARGET_PRODUCT    the target product name (e.g. 'core', 'resmgr', 'ucspm', etc)
# VERSION           the full Zenoss product version; e.g. 5.2.0
#
include ../versions.mk

#
# The following input variables are OPTIONAL:
#
# BUILD_NUMBER      the build number for this product pipeline build; defaults to YYYYMMDDhhmmss
# IMAGE_NUMBER      the docker image number for this build; defaults to DEV
# MATURITY          the image maturity level (e.g. 'unstable', 'testing', 'stable'); defaults to DEV
# SVCDEF_GIT_READY  a flag that is only set when the svcdef repo has already been checked out
#                   by the caller. If this flag is set, SVCDEF_GIT_REF is ignored.
# SVCDEF_GIT_REF    the git branch name, tag name or SHA for the version of the
#                   github.com:zenoss/zenoss-service repo to checkout and build
#                   Ignored (i.e. optional) if SVCDEF_GET_READY is set; required if
#                   SVCDEF_GIT_READY is NOT set.
#

BUILD_NUMBER ?= $(shell date +%Y%m%d%H%M%S)
IMAGE_NUMBER ?= DEV
MATURITY     ?= DEV

MIGRATION_WHEEL = zenservicemigration-$(VERSION)-py2-none-any.whl

TEMP_DIR := src
SVC_REPO_DIR := $(TEMP_DIR)/zenoss-service
SVC_REPO := $(SVC_REPO_DIR)/.git

.PHONY: clean default build repo_dir verifyInputs migrations

default: build

verifyInputs:
ifndef BUILD_NUMBER
	$(error BUILD_NUMBER is not set)
endif
ifndef HBASE_VERSION
	$(error HBASE_VERSION is not set)
endif
ifndef HDFS_VERSION
	$(error HDFS_VERSION is not set)
endif
ifndef IMAGE_NUMBER
	$(error IMAGE_NUMBER is not set)
endif
ifndef OPENTSDB_VERSION
	$(error OPENTSDB_VERSION is not set)
endif
ifndef SHORT_VERSION
	$(error SHORT_VERSION is not set)
endif
ifndef SVCDEF_GIT_REF
	$(error SVCDEF_GIT_REF is not set)
endif
ifndef VERSION
	$(error VERSION is not set)
endif

repo_dir: $(SVC_REPO_DIR)

build: $(SVC_REPO)/HEAD verifyInputs
ifndef TARGET_PRODUCT
	$(error TARGET_PRODUCT is not set)
endif
	make -C $(dir $(<D)) docker_svcdefpkg-$(TARGET_PRODUCT) \
		BASE_IMAGE_VERSION=$(ZENOSS_CENTOS_BASE_VERSION) \
		BUILD_NUMBER=$(BUILD_NUMBER) \
		hbase_VERSION=$(HBASE_VERSION) \
		hdfs_VERSION=$(HDFS_VERSION) \
		IMAGE_NUMBER=$(IMAGE_NUMBER) \
		MILESTONE=$(MATURITY) \
		opentsdb_VERSION=$(OPENTSDB_VERSION) \
		RELEASE_PHASE=$(RELEASE_PHASE) \
		SHORT_VERSION=$(SHORT_VERSION) \
		VERSION=$(VERSION)

migrations: $(MIGRATION_WHEEL) verifyInputs

$(MIGRATION_WHEEL): $(SVC_REPO_DIR)/output/$(MIGRATION_WHEEL)
	cp $(SVC_REPO_DIR)/output/$@ $@

$(SVC_REPO_DIR)/output/$(MIGRATION_WHEEL): $(SVC_REPO)/HEAD 
	cd $(SVC_REPO_DIR) && git checkout $(SVCDEF_GIT_REF)
	make -C $(SVC_REPO_DIR) build-migrations VERSION=$(VERSION)

# Using $(SVC_REPO)/HEAD as the target because GNU make appears to
# consider a hidden directory target as always unsatisfied.
$(SVC_REPO)/HEAD: | $(SVC_REPO_DIR)
	cd $(SVC_REPO_DIR) && git clone git@github.com:zenoss/zenoss-service.git .

$(SVC_REPO_DIR):
	@mkdir -p $@
	@echo $@

clean:
	@-rm -rf $(TEMP_DIR)
	@-rm -f *.whl

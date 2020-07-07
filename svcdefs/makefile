#
# Makefile to compile service definitions as part of the product assembly process.
#

#
# This file REQUIRES the following input variables.  Note that all of these
# except TARGET_PRODUCT are defined in ../versions.mk
#
# HBASE_VERSION          the HBase image version
# HDFS_VERSION           the HDFS image version
# OPENTSDB_VERSION       the opentsdb image version
# ZING_CONNECTOR_VERSION the version tag for the zing-connector image
# ZING_API_PROXY_VERSION the version tag for the api-key-proxy image
# SHORT_VERSION          the two-digit Zenoss product version; e.g. 5.2
# TARGET_PRODUCT         the target product name (e.g. 'core', 'resmgr', 'ucspm', etc)
# VERSION                the full Zenoss product version; e.g. 5.2.0
#
include ../versions.mk

#
# The following input variables are OPTIONAL:
#
# BUILD_NUMBER      the build number for this product pipeline build; defaults to YYYYMMDDhhmmss
# IMAGE_NUMBER      the docker image number for this build; defaults to DEV
# MATURITY          the image maturity level (e.g. 'unstable', 'testing', 'stable'); defaults to DEV
# SVCDEF_GIT_REF    the git branch name, tag name or SHA for the version of the
#                   github.com:zenoss/zenoss-service repo to checkout and build
#

BUILD_NUMBER ?= $(shell date +%Y%m%d%H%M%S)
IMAGE_NUMBER ?= DEV
MATURITY     ?= DEV

TEMP_DIR := src
SVC_REPO_DIR := $(TEMP_DIR)/zenoss-service
SVC_REPO := $(SVC_REPO_DIR)/.git

.PHONY: clean default build repo_dir verifyInputs

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
ifndef ZING_CONNECTOR_VERSION
	$(error ZING_CONNECTOR_VERSION is not set)
endif
ifndef ZING_API_PROXY_VERSION
	$(error ZING_API_PROXY_VERSION is not set)
endif
ifndef OTSDB_BIGTABLE_VERSION
	$(error OTSDB_BIGTABLE_VERSION is not set)
endif
ifndef IMPACT_VERSION
	$(error IMPACT_VERSION is not set)
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


default: build

repo_dir: $(SVC_REPO_DIR)

build: $(SVC_REPO)/HEAD verifyInputs
ifndef TARGET_PRODUCT
	$(error TARGET_PRODUCT is not set)
endif
    #delete infrastructure services not used in GCP
	cd $(SVC_REPO_DIR) && \
        rm -rf services/Zenoss.cse/Infrastructure/HBase && \
        rm -rf services/Zenoss.cse/Infrastructure/HDFS && \
        rm -rf services/Zenoss.cse/Infrastructure/opentsdb/writer && \
        rm -rf services/Zenoss.cse/Infrastructure/opentsdb/reader && \
		BUILD_NUMBER=$(BUILD_NUMBER) \
		hbase_VERSION=$(HBASE_VERSION) \
		hdfs_VERSION=$(HDFS_VERSION) \
		zing_connector_VERSION=$(ZING_CONNECTOR_VERSION) \
		zing_api_proxy_VERSION=$(ZING_API_PROXY_VERSION) \
		otsdb_bigtable_VERSION=$(OTSDB_BIGTABLE_VERSION) \
		impact_VERSION=$(IMPACT_VERSION) \
		IMAGE_NUMBER=$(IMAGE_NUMBER) \
		MILESTONE=$(MATURITY) \
		RELEASE_PHASE=$(RELEASE_PHASE) \
		opentsdb_VERSION=$(OPENTSDB_VERSION) \
		SHORT_VERSION=$(SHORT_VERSION) \
		VERSION=$(VERSION) \
		make docker_svcdef-$(TARGET_PRODUCT)

# Using $(SVC_REPO)/HEAD as the target because GNU make appears to
# consider a hidden directory target as always unsatisfied.
$(SVC_REPO)/HEAD: | $(SVC_REPO_DIR)
	cd $(SVC_REPO_DIR) && git clone git@github.com:zenoss/zenoss-service.git .
	cd $(SVC_REPO_DIR) && git checkout $(SVCDEF_GIT_REF)

$(SVC_REPO_DIR):
	@mkdir -p $@
	@echo $@

migrations: $(SVC_REPO)/HEAD verifyInputs
	make -C $(dir $(<D)) build-migrations
	cp $(dir $(<D))/output/*.whl ./

clean:
	@-rm -rf $(TEMP_DIR)
	@-rm *.whl

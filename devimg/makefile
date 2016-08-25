#
# Makefile to build zendev/devimg
#
# At high level, the image "stack" for zendev/devimg looks like:
#
# zendev/devimg:<envName>
#     ^
#     |
# zendev/devimg-base:<envName>
#     ^
#     |
# zenoss/zenoss-centos-base:<ver>.devtools
#
# zenoss-centos-base:<ver>.devtools is a variant of zenoss-centos-base that
# contains development tools like the JDK, Maven, make and GO.
#
# devimg-base:<envName> is a variant of product-base with the uid/gid of the
# zenoss user/group remapped to the uid/gid of the developer creating devimg.
#
# zendev/devimg is built just like the standard product images, except:
#   - the ZenPacks are link-installed with soft-links
#   - Java apps are soft-linked from ZENHOME/lib/<appDir> back to their
#     source directory
#
# This file REQUIRES the following input variables.  Note that all of these
# except TARGET_PRODUCT are defined in ../versions.mk
#
# ZENDEV_ROOT     the parent directory created by zendev which contains the
#                 zenhome and var_zenoss subdirectories. In other words, the
#                 developer's ZENHOME=$ZENDEV_ROOT/zenhome.
# SRCROOT         the root directory of the zendev's environment source code.
#                 Typically, something like $HOME/src/<envName>/src
#
# The following input variables are OPTIONAL. They may be set in various special
# circumstances, but in most case only TARGET_PRODUCT is specified
#
# TARGET_PRODUCT  the name of the product to use in order to decide which zenpacks
#                 to install into the devimg; e.g. 'core', 'resmgr', etc
# ZENPACK_FILE    An alternative to TARGET_PRODUCT - the path to a "zenpacks.json"
#                 file containing a custom list of zenpacks to install into devimg.
#                 The file name must be "zenpacks.json".
#                 For example, ZENPACK_FILE=../core/zenpacks.json is equivalent
#                 to TARGET_PRODUCT=core
# FROM_IMAGE      Specifies an alternate copy of zenoss-centos-base to use as
#                 the basis for zendev/devimg-base
# PRODBIN_SRC     the full directory path to the developers local checkout of zenoss-prodbin
# ZENPACK_SRC     the full directory path to the parent directory containing all
#                 of the ZenPacks checked out locally by the developer
#
include ../versions.mk
IMAGENAME  = devimg
DEV_ENV ?= metis
TAG = zendev/$(IMAGENAME):$(DEV_ENV)
BASE_TAG = zendev/$(IMAGENAME)-base:$(DEV_ENV)

FROM_IMAGE ?= zenoss-centos-base:1.2.5
CONTAINER_ZENHOME=/opt/zenoss

.PHONY: clean build

verifyInputs:
ifndef ZENDEV_ROOT
	$(error ZENDEV_ROOT is not set)
endif
ifndef SRCROOT
	$(error SRCROOT is not set)
endif

# Note that this list includes the directories used as mount points. We create
# need to create those directories here so they are owned by the current user
# (otherwise, they will be owned by root when docker creates them).
make-dirs: verifyInputs $(ZENDEV_ROOT)/zenhome $(ZENDEV_ROOT)/zenhome/devimg $(ZENDEV_ROOT)/zenhome/packs $(ZENDEV_ROOT)/var_zenoss

$(ZENDEV_ROOT)/%:
	mkdir -p $@

select-zenpacks: verifyInputs
ifdef TARGET_PRODUCT
	@echo "Using TARGET_PRODUCT='$(TARGET_PRODUCT)'"
	$(eval ZENPACK_FILE=../$(TARGET_PRODUCT)/zenpacks.json)
else
ifdef ZENPACK_FILE
	@echo "Using ZENPACK_FILE='$(ZENPACK_FILE)'"
else
	@echo "Building without zenpacks"
endif
endif
	@echo "ZENPACK_FILE='$(ZENPACK_FILE)'"
	@if [ ! -f $(ZENPACK_FILE) ]; then echo "ZENPACK_FILE=$(ZENPACK_FILE) does not exist"; exit 1; fi

ZENPACK_SRC ?= $(SRCROOT)
PRODBIN_SRC ?= $(SRCROOT)/zenoss-prodbin

#
# four major steps to creating the devimg:
# 1. build-devbase - Create a devimg-base image starting the same as product-base, but
#    built on the ".devtools" version of zenoss-centos-base.
# 2. initialize-zenhome - Copies the contents of /opt/zenoss/* from the image
#    into our local ZENHOME directory
# 3. add-zenpack-file - Adds the zenpacks to the image based on a file
#    containing a list of zenpacks (optional)
# 4. build.sh - Initialize zenoss, link-install zenpacks (if any), and setup other
#    linkages like Java apps, zenoss-protocols, etc.
#
build: make-dirs select-zenpacks build-devbase initialize-zenhome add-zenpack-file
	BASE_TAG=$(BASE_TAG) \
	TAG=$(TAG) \
	ZENDEV_ROOT=$(ZENDEV_ROOT) \
	PRODBIN_SRC=$(PRODBIN_SRC) \
	ZENPACK_SRC=$(ZENPACK_SRC) \
	./build.sh

clean:
	-cd ../product-base;TAG=$(BASE_TAG) make clean
	-docker rmi -f $(TAG)
	rm -rf $(ZENDEV_ROOT)/zenhome/* $(ZENDEV_ROOT)/var_zenoss/*

build-devbase:
	@echo "Building $(BASE_TAG) ..."
	FROM_IMAGE=$(FROM_IMAGE) BASE_TAG=$(BASE_TAG) ./build-devbase.sh

# Initialize our local ZENHOME using the contents from the initial devimg
initialize-zenhome: make-dirs
	@echo "Initializing ZENHOME from container contents..."
	docker run --rm \
		-v $(ZENDEV_ROOT)/zenhome:/mnt/local-zenhome \
		-t $(BASE_TAG) \
		bash -c "rm -rf /mnt/local-zenhome/*; cp -rp $(CONTAINER_ZENHOME)/* /mnt/local-zenhome"

add-zenpack-file:
	@if [ -z "$(ZENPACK_FILE)" ]; then \
		echo "ZENPACK_FILE is empty; not installing any zenpacks"; \
	else \
		echo "Using the zenpacks defined by $(ZENPACK_FILE)"; \
		cp $(ZENPACK_FILE) $(ZENDEV_ROOT)/zenhome/install_scripts; \
	fi
	@echo "No downloaded zenpacks; all zenpacks link-installed from source" > $(ZENDEV_ROOT)/zenhome/log/zenpacks_artifact.log

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
# zendev/user-change:<envName>
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
#   - zenoss-prodbin/Products is mounted/linked into ZENHOME/Products
#   - the ZenPacks are link-installed with soft-links
#   - Java apps are soft-linked from ZENHOME/lib/<appDir> back to their
#     source directory
#
# This file REQUIRES the following input variables.  Note that all of these
# except TARGET_PRODUCT are defined in ../versions.mk
#
# ZENDEV_ROOT     the parent directory created by zendev which contains the
#                 zenhome and var_zenoss subdirectories. In other words, the
#                 developer's ZENHOME=$ZENDEV_ROOT/zenhome; aka
#                 $HOME/src/<envName>/zenhome
# SRCROOT         the root directory of the Zenoss source code.
#                 Typically, something like $HOME/src/<envName>/src/github.com/zenoss
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
# ZENPACK_BLACKLIST The path to a "zp_blacklist.json" file which contains a list
#                 of ZenPacks to be excluded from the image.
#                 If not specifeid, defaults to ../devimg/zp_blacklist.json
#
include ../versions.mk

SHELL := /bin/bash

SOURCE_IMAGE = zenoss/zenoss-centos-base:$(ZENOSS_CENTOS_BASE_VERSION).devtools

IMAGE_TAG ?= $(shell zendev env)

IMAGE_PROJECT = zendev

ZENDEV_USER_IMAGE = $(IMAGE_PROJECT)/user-change:$(IMAGE_TAG)

PRODUCT_BASE_IMAGE_REPO = $(IMAGE_PROJECT)/devimg-base
PRODUCT_BASE_IMAGE_ID = $(PRODUCT_BASE_IMAGE_REPO):$(IMAGE_TAG)

PRODUCT_IMAGE_REPO = $(IMAGE_PROJECT)/devimg
PRODUCT_IMAGE_ID = $(PRODUCT_IMAGE_REPO):$(IMAGE_TAG)

MARIADB_BASE_IMAGE_REPO = $(IMAGE_PROJECT)/mariadb-base
MARIADB_BASE_IMAGE_ID = $(MARIADB_BASE_IMAGE_REPO):$(IMAGE_TAG)

MARIADB_IMAGE_REPO = $(IMAGE_PROJECT)/mariadb
MARIADB_IMAGE_ID = $(MARIADB_IMAGE_REPO):$(IMAGE_TAG)

ZENPACK_BLACKLIST ?= $(CURDIR)/zp_blacklist.json

ZENDEV_ROOT ?= $(shell zendev root || echo)
# Verify that ZENDEV_ROOT is set
ifeq ($(ZENDEV_ROOT),)
	$(error ZENDEV_ROOT is not set)
endif

SRCROOT = $(ZENDEV_ROOT)/src/github.com/zenoss

LOCAL_UID = $(shell id -u)
LOCAL_GID = $(shell id -g)

ifdef TARGET_PRODUCT
$(info Using TARGET_PRODUCT='$(TARGET_PRODUCT)')
ZENPACK_FILE = $(realpath ../$(TARGET_PRODUCT)/zenpacks.json)
$(info $(ZENPACK_FILE))
endif

ifdef ZENPACK_FILE
$(info Build devimg with zenpacks from $(ZENPACK_FILE).)
ZENPACK_BLACKLIST := $(realpath $(ZENPACK_BLACKLIST))
else
ZENPACK_FILE =
ZENPACK_BLACKLIST =
endif

export PRODUCT_BASE_IMAGE_ID
export MARIADB_BASE_IMAGE_ID
export PRODUCT_IMAGE_ID
export MARIADB_IMAGE_ID
export ZENDEV_ROOT
export ZENWIPE_ARGS
export SRCROOT

.PHONY: clean clean-devimg-base clean-mariadb-base build build-devimg-base build-mariadb-base add-zenpack-file dumpdb initialize-zenhome make-dirs

dumpdb: 
	@./docker_run_dumpzodb.sh

#
# four major steps to creating the devimg:
# 1. build-zendev-user-image - Create the base image that switches the zenoss user
#    UID and GID values to the local user.
# 2. build-devbase - Create a devimg-base image using the product-base build.
# 2. initialize-zenhome - Copies the contents of /opt/zenoss/* from the image
#    into our local ZENHOME directory
# 3. add-zenpack-file - Adds a 'zenpack.json' file to ZENHOME within the image
#    such that the last step can use that file to install zenpacks (optional)
# 4. build.sh - Initialize zenoss, link-install zenpacks (if any), and setup other
#    linkages like Java apps, zenoss-protocols, etc.
#
build: build-mariadb-base add-zenpack-file
	@./build.sh

build-devimg-base: build-zendev-user-image
	@echo "Building $(PRODUCT_BASE_IMAGE_ID) ..."
	@rm -f ../product-base/Dockerfile
	@make -C ../product-base build-base-image FROM_IMAGE=$(ZENDEV_USER_IMAGE) USE_CACHE=Y

build-zendev-user-image: Dockerfile
	@docker build -t $(ZENDEV_USER_IMAGE) .

build-mariadb-base: build-devimg-base
	@echo "Building $(MARIADB_BASE_IMAGE_ID) ..."
	@make -C ../mariadb-base build GID=$(LOCAL_GID) UID=$(LOCAL_UID)

clean: clean-devimg-base clean-mariadb-base
	@-docker image rm -f $(PRODUCT_IMAGE_ID) $(MARIADB_IMAGE_ID) $(ZENDEV_USER_IMAGE)
	@echo "Cleaning ZENDEV_ROOT=$(ZENDEV_ROOT) (requires sudo) ..."
	@sudo rm -rf $(ZENDEV_ROOT)/zenhome/* $(ZENDEV_ROOT)/var_zenoss/*

clean-devimg-base:
	@-make -C ../product-base clean

clean-mariadb-base:
	@-make -C ../mariadb-base clean

# Note that this list includes the directories used as mount points. We create
# need to create those directories here so they are owned by the current user
# (otherwise, they will be owned by root when docker creates them).
make-dirs: $(ZENDEV_ROOT)/zenhome  $(ZENDEV_ROOT)/var_zenoss
	@mkdir -p $$HOME/.m2

# devimg ZENHOME-based path directory maker
$(ZENDEV_ROOT)/%:
	@mkdir -p $@

# Initialize our local ZENHOME using the contents from the initial devimg
initialize-zenhome: make-dirs build-devimg-base
	@echo "Initializing ZENHOME from container contents..."
	@docker run --rm \
		-v $(ZENDEV_ROOT)/zenhome:/mnt/local-zenhome \
		-v $(CURDIR):/mnt/devimg \
		-t $(PRODUCT_BASE_IMAGE_ID) \
		bash -c "/mnt/devimg/init_devimg_zenhome.sh /mnt/local-zenhome"

add-zenpack-file: initialize-zenhome
ifdef ZENPACK_FILE
	@echo "Using the zenpacks defined by $(ZENPACK_FILE)"
	@cp $(ZENPACK_FILE) $(ZENDEV_ROOT)/zenhome/install_scripts
endif
	@echo "No downloaded zenpacks; all zenpacks link-installed from source" > $(ZENDEV_ROOT)/zenhome/log/zenpacks_artifact.log
ifdef ZENPACK_BLACKLIST
	@echo "Using the zenpack blacklist defined by $(ZENPACK_BLACKLIST)"
	@cp $(ZENPACK_BLACKLIST) $(ZENDEV_ROOT)/zenhome/install_scripts/zp_blacklist.json
endif

Dockerfile: Dockerfile.in
	@sed \
		-e "s|%IMAGE%|$(SOURCE_IMAGE)|g" \
		-e "s|%UID%|$(LOCAL_UID)|g" \
		-e "s|%GID%|$(LOCAL_GID)|g" \
		$^ > $@

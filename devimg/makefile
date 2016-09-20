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
IMAGENAME  = devimg
DEV_ENV ?= metis
TAG = zendev/$(IMAGENAME):$(DEV_ENV)
BASE_TAG = zendev/$(IMAGENAME)-base:$(DEV_ENV)
DIR = ${CURDIR}
ZENPACK_BLACKLIST ?= ${CURDIR}/zp_blacklist.json

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
make-dirs: verifyInputs $(ZENDEV_ROOT)/zenhome  $(ZENDEV_ROOT)/var_zenoss
	@mkdir -p $$HOME/.m2

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
	@echo "ZENPACK_BLACKLIST='$(ZENPACK_BLACKLIST)'"
	@if [ ! -f $(ZENPACK_BLACKLIST) ]; then echo "ZENPACK_BLACKLIST=$(ZENPACK_BLACKLIST) does not exist"; exit 1; fi

#
# four major steps to creating the devimg:
# 1. build-devbase - Create a devimg-base image starting the same as product-base, but
#    built on the ".devtools" version of zenoss-centos-base.
# 2. initialize-zenhome - Copies the contents of /opt/zenoss/* from the image
#    into our local ZENHOME directory
# 3. add-zenpack-file - Adds a 'zenpack.json' file to ZENHOME within the image
#    such that the last step can use that file to install zenpacks (optional)
# 4. build.sh - Initialize zenoss, link-install zenpacks (if any), and setup other
#    linkages like Java apps, zenoss-protocols, etc.
#
build: make-dirs select-zenpacks build-devbase initialize-zenhome add-zenpack-file
	BASE_TAG=$(BASE_TAG) \
	TAG=$(TAG) \
	ZENDEV_ROOT=$(ZENDEV_ROOT) \
	./build.sh

clean:
	-cd ../product-base;TAG=$(BASE_TAG) make clean
	@echo "Removing $(TAG) (if any)..."
	-docker rmi -f $(TAG)
	@echo "Cleaning ZENDEV_ROOT=$(ZENDEV_ROOT) (requires sudo) ..."
	sudo rm -rf $(ZENDEV_ROOT)/zenhome/* $(ZENDEV_ROOT)/var_zenoss/*

build-devbase:
	@echo "Building $(BASE_TAG) ..."
	BASE_TAG=$(BASE_TAG) ./build-devbase.sh

# Initialize our local ZENHOME using the contents from the initial devimg
initialize-zenhome: make-dirs
	@echo "Initializing ZENHOME from container contents..."
	docker run --rm \
		-v $(ZENDEV_ROOT)/zenhome:/mnt/local-zenhome \
		-v ${DIR}:/mnt/devimg \
		-t $(BASE_TAG) \
		bash -c "/mnt/devimg/init_devimg_zenhome.sh /mnt/local-zenhome"

add-zenpack-file:
	@if [ -z "$(ZENPACK_FILE)" ]; then \
		echo "ZENPACK_FILE is empty; not installing any zenpacks"; \
	else \
		echo "Using the zenpacks defined by $(ZENPACK_FILE)"; \
		cp $(ZENPACK_FILE) $(ZENDEV_ROOT)/zenhome/install_scripts; \
	fi
	@echo "No downloaded zenpacks; all zenpacks link-installed from source" > $(ZENDEV_ROOT)/zenhome/log/zenpacks_artifact.log
	@echo "Using the zenpack blacklist defined by $(ZENPACK_BLACKLIST)"
	cp $(ZENPACK_BLACKLIST) $(ZENDEV_ROOT)/zenhome/install_scripts/zp_blacklist.json


include ../../versions.mk

IMAGENAME  = zennub
MATURITY ?= DEV
BUILD_NUMBER  ?= DEV
# Note: I'm only using the devtools image because I want to upgrade
# pyyaml to use CLoader, and doing so requires a compiler.
FROM_IMAGE ?= zenoss-centos-base:1.2.23.devtools

TAG ?= zenoss/$(IMAGENAME):$(VERSION)_$(BUILD_NUMBER)_$(MATURITY)

DEV_ENV ?= zennub
ZENDEV_BASE_TAG = zendev/$(IMAGENAME)-base:$(DEV_ENV)
ZENDEV_TAG = zendev/$(IMAGENAME):$(DEV_ENV)

.PHONY: change-from-image build-deps build build-devbase build-devimg push clean Dockerfile

build-deps: component_versions Dockerfile

build: build-deps
	docker build --no-cache=true -t $(TAG) .

build-devbase: build-deps
	@echo "Building $(ZENDEV_BASE_TAG) ..."
	touch ../zenpacks_artifact.log
	cd ..; docker build -f devimg/Dockerfile --no-cache=true -t $(ZENDEV_BASE_TAG) .

build-devimg: build-devbase make-dirs initialize-zenhome add-zenpack-file
	BASE_TAG=$(ZENDEV_BASE_TAG) \
	TAG=$(ZENDEV_TAG) \
	ZENHOME=$(ZENHOME) \
	./build.sh

# Initialize our local ZENHOME using the contents from the initial devimg
initialize-zenhome: make-dirs
	@echo "Initializing ZENHOME from container contents..."
	docker run --rm \
		-v $(ZENHOME)/zenhome:/mnt/local-zenhome \
		-v $(shell (cd ../../devimg; pwd)):/mnt/devimg \
		-t $(ZENDEV_BASE_TAG) \
		bash -c "/mnt/devimg/init_devimg_zenhome.sh /mnt/local-zenhome"


# Note that this list includes the directories used as mount points. We create
# need to create those directories here so they are owned by the current user
# (otherwise, they will be owned by root when docker creates them).
make-dirs: verifyInputs $(ZENHOME)/zenhome  $(ZENHOME)/var_zenoss
	@mkdir -p $$HOME/.m2

$(ZENHOME)/%:
	mkdir -p $@

verifyInputs:
ifndef ZENHOME
	$(error ZENHOME is not set)
endif
ifndef SRCROOT
	$(error SRCROOT is not set)
endif

add-zenpack-file:
	cp ../zenpacks.json $(ZENHOME)/zenhome/install_scripts;
	cp ../zp_blacklist.json $(ZENHOME)/zenhome/install_scripts;

push:
	docker push $(TAG)

clean:
	rm -rf Dockerfile
	-docker rmi -f $(ZENDEV_BASE_TAG)
	-docker rmi -f $(ZENDEV_TAG)

component_versions: component_info
	@cp ../../artifact_download.py ../../component_versions.json component_info/.
	@echo "export BUILD_NUMBER=$(BUILD_NUMBER)" > component_info/versions.sh
	@echo "export VERSION=$(VERSION)" >> component_info/versions.sh

component_info:
	@mkdir component_info

Dockerfile: Dockerfile.in
	$(eval INSTALL_OPTIONS=--change-uid $(shell id -u):$(shell id -g))
	sed -e 's/%SHORT_VERSION%/$(SHORT_VERSION)/g; s/%FROM_IMAGE%/$(FROM_IMAGE)/g; s/%INSTALL_OPTIONS%/$(INSTALL_OPTIONS)/g;' Dockerfile.in > Dockerfile

#	@sed -e 's/%SHORT_VERSION%/$(SHORT_VERSION)/g; s/%FROM_IMAGE%/$(FROM_IMAGE)/g; s/%INSTALL_OPTIONS%/$(INSTALL_OPTIONS)/g;' Dockerfile.in > $@


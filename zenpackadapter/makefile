
include ../versions.mk

IMAGENAME  = zenpackadapter
MATURITY ?= DEV
BUILD_NUMBER  ?= DEV
# Note: I'm only using the devtools image because I want to upgrade
# pyyaml to use CLoader, and doing so requires a compiler.
FROM_IMAGE ?= zenoss-centos-base:1.2.23.devtools

TAG ?= zenoss/$(IMAGENAME):$(VERSION)_$(BUILD_NUMBER)_$(MATURITY)

DEV_ENV ?= zenpackadapter
ZENDEV_BASE_TAG = zendev/$(IMAGENAME)-base:$(DEV_ENV)
ZENDEV_TAG = zendev/$(IMAGENAME):$(DEV_ENV)

.PHONY: change-from-image build-deps build devimg push clean Dockerfile

build-deps: component_versions Dockerfile zenpack_download

build: build-deps
	docker build --no-cache=true -t $(TAG) .

devimg:
	make -C devimg build-devimg

push:
	docker push $(TAG)

clean:
	rm -rf component_info Dockerfile zenpacks_artifact.log
	-docker rmi -f $(TAG)
	make -C devimg clean

component_versions: component_info
	@cp ../artifact_download.py ../component_versions.json component_info/.
	@echo "export BUILD_NUMBER=$(BUILD_NUMBER)" > component_info/versions.sh
	@echo "export VERSION=$(VERSION)" >> component_info/versions.sh

component_info:
	@mkdir component_info

Dockerfile: Dockerfile.in
	@sed -e 's/%SHORT_VERSION%/$(SHORT_VERSION)/g; s/%FROM_IMAGE%/$(FROM_IMAGE)/g; s/%INSTALL_OPTIONS%/$(INSTALL_OPTIONS)/g;' Dockerfile.in > $@

zenpacks:
	@mkdir $@

zenpack_download: zenpacks
	../artifact_download.py ../zenpack_versions.json --zp_manifest zenpacks.json --out_dir zenpacks --reportFile zenpacks_artifact.log

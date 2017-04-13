include ../versions.mk
IMAGENAME  = product-base
MATURITY ?= DEV
BUILD_NUMBER  ?= DEV
FROM_IMAGE ?= zenoss-centos-base:1.2.10

TAG ?= zenoss/$(IMAGENAME):$(VERSION)_$(BUILD_NUMBER)_$(MATURITY)

.PHONY: change-from-image build-deps build build-devimg push clean

build-deps: component_versions $(SHORT_VERSION).x/pull-docker-images.sh Dockerfile

build: build-deps
	docker build --no-cache=true -t $(TAG) .

# To build the dev image, change the FROM_IMAGE value to use the .devtools base
# image and then build like any other product-base image.
build-devimg: change-from-image build

change-from-image:
	$(eval FROM_IMAGE = $(FROM_IMAGE).devtools)
	@echo "Building an image for development with FROM_IMAGE=$(FROM_IMAGE)"
	# Force creation of a new Dockerfile to minimize rebuild confusion
	rm -f Dockerfile

push:
	docker push $(TAG)

clean:
	rm -rf component_info Dockerfile
	rm -f $(SHORT_VERSION).x/pull-docker-images.sh
	-docker rmi -f $(TAG)

component_versions: component_info
	@cp ../artifact_download.py ../component_versions.json component_info/.
	@echo "export BUILD_NUMBER=$(BUILD_NUMBER)" > component_info/versions.sh
	@echo "export VERSION=$(VERSION)" >> component_info/versions.sh

component_info:
	@mkdir component_info

$(SHORT_VERSION).x/pull-docker-images.sh:
	@mkdir -p $(SHORT_VERSION).x
	@sed -e 's/%HBASE_VERSION%/$(HBASE_VERSION)/g; s/%OPENTSDB_VERSION%/$(OPENTSDB_VERSION)/g;'  pull-docker-images.sh.in > $@
	@chmod +x $@

Dockerfile:
	@sed -e 's/%SHORT_VERSION%/$(SHORT_VERSION)/g; s/%FROM_IMAGE%/$(FROM_IMAGE)/g; s/%INSTALL_OPTIONS%/$(INSTALL_OPTIONS)/g;' Dockerfile.in > $@

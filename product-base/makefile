SHELL := /bin/bash

include ../variables.mk

FROM_IMAGE ?= zenoss-centos-base:$(ZENOSS_CENTOS_BASE_VERSION)

.PHONY: change-from-image build build-devimg push clean

COPIED_DEPS = $(addprefix component_info/,artifact_download.py component_versions.json)

BUILD_DEPENDENCIES = \
	$(SHORT_VERSION).x/pull-docker-images.sh \
	Dockerfile \
	component_info/versions.sh \
	$(COPIED_DEPS)

build: $(BUILD_DEPENDENCIES)
	docker build --no-cache=true -t $(PRODUCT_BASE_IMAGE_ID) .

# To build the dev image, change the FROM_IMAGE value to use the .devtools base
# image and then build like any other product-base image.
build-devimg: change-from-image build

change-from-image:
	$(eval FROM_IMAGE = $(FROM_IMAGE).devtools)
	@echo "Building an image for development with FROM_IMAGE=$(FROM_IMAGE)"
	# Force creation of a new Dockerfile to minimize rebuild confusion
	@rm -f Dockerfile

push:
	docker push $(PRODUCT_BASE_IMAGE_ID)

clean:
	@rm -f $(BUILD_DEPENDENCIES)
	@rm -rf $(SHORT_VERSION).x component_info
	@-docker image rm -f $(PRODUCT_BASE_IMAGE_ID)

component_info $(SHORT_VERSION).x:
	@mkdir -p $@

$(COPIED_DEPS): | component_info
$(COPIED_DEPS): component_info/%: ../%
	@cp $< $@

component_info/versions.sh: | component_info
component_info/versions.sh:
	@echo "export BUILD_NUMBER=$(BUILD_NUMBER)" > component_info/versions.sh
	@echo "export VERSION=$(VERSION)" >> component_info/versions.sh

$(SHORT_VERSION).x/pull-docker-images.sh: | $(SHORT_VERSION).x
$(SHORT_VERSION).x/pull-docker-images.sh: pull-docker-images.sh.in
	@sed \
		-e 's/%HBASE_VERSION%/$(HBASE_VERSION)/g' \
		-e 's/%OPENTSDB_VERSION%/$(OPENTSDB_VERSION)/g' \
		$< > $@
	@chmod +x $@

Dockerfile: Dockerfile.in
	@sed \
		-e 's/%SHORT_VERSION%/$(SHORT_VERSION)/g' \
		-e 's/%FROM_IMAGE%/$(FROM_IMAGE)/g' \
		-e 's/%INSTALL_OPTIONS%/$(INSTALL_OPTIONS)/g;' \
		$< > $@

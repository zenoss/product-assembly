SHELL := /bin/bash

include ../variables.mk

FROM_IMAGE ?= zenoss/zenoss-centos-base:$(ZENOSS_CENTOS_BASE_VERSION)

ifeq ($(USE_CACHE),)
CACHE_OPTION = --no-cache=true
else
CACHE_OPTION =
endif

COPIED_DEPS = $(addprefix component_info/,artifact_download.py component_versions.json)

MIGRATION_WHEEL = zenservicemigration-${VERSION}-py2-none-any.whl

BUILD_DEPENDENCIES = \
	Dockerfile \
	component_info/versions.sh \
	$(COPIED_DEPS)

.PHONY: build-base-image build push clean

build-base-image: $(BUILD_DEPENDENCIES)
	docker build $(CACHE_OPTION) -t $(PRODUCT_BASE_IMAGE_ID) .

build: component_info/${MIGRATION_WHEEL} build-base-image

clean:
	@rm -f $(BUILD_DEPENDENCIES)
	@rm -rf component_info
	@-docker image rm -f $(PRODUCT_BASE_IMAGE_ID)

component_info:
	@mkdir -p $@

$(COPIED_DEPS): | component_info
$(COPIED_DEPS): component_info/%: ../%
	@cp $< $@

component_info/versions.sh: | component_info
component_info/versions.sh:
	@echo "export BUILD_NUMBER=$(BUILD_NUMBER)" > $@
	@echo "export VERSION=$(VERSION)" >> $@

component_info/${MIGRATION_WHEEL}: | component_info
component_info/${MIGRATION_WHEEL}: ../svcdefs/${MIGRATION_WHEEL}
	@cp ../svcdefs/${MIGRATION_WHEEL} $@

../svcdefs/${MIGRATION_WHEEL}:
	@make -C ../svcdefs clean migrations

Dockerfile: Dockerfile.in
	@sed \
		-e 's|%SHORT_VERSION%|$(SHORT_VERSION)|g' \
		-e 's|%IMAGE%|$(FROM_IMAGE)|g' \
		-e 's|%VERSION%|$(VERSION)|g;' \
		-e 's|%BUILD_NUMBER%|$(BUILD_NUMBER)|g;' \
		$< > $@

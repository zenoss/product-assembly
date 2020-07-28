SHELL := /bin/bash

include ../variables.mk
include components.mk

# Component versions
PYDEPS_VERSION = 5.6.4
PHANTOMJS_VERSION = 1.9.7
LIBSMI_VERSION = 0.5.0-1
SOLR_VERSION = 1.0dev

PYDEPS = pydeps-$(PYDEPS_VERSION)-el7-1.tar.gz
PHANTOMJS = phantomjs-$(PHANTOMJS_VERSION)-linux-x86_64.tar.bz2
RPM_LIBSMI = libsmi-$(LIBSMI_VERSION).el7.x86_64.rpm
JSBUILDER = JSBuilder2.zip
SOLR = zenoss-solr-$(SOLR_VERSION).tgz
GET_PIP = get-pip.py

FROM_IMAGE ?= centos-base:$(CENTOS_BASE_VERSION)

.PHONY: change-from-image build-base-image build build-devimg push clean

COPIED_DEPS = $(addprefix component_info/,artifact_download.py component_versions.json)

MIGRATION_WHEEL = zenservicemigration-${VERSION}-py2-none-any.whl

BUILD_DEPENDENCIES = \
	$(SHORT_VERSION).x/pull-docker-images.sh \
	Dockerfile \
	component_info/versions.sh \
	$(RPM_LIBSMI) $(PYDEPS) $(JSBUILDER) $(PHANTOMJS) $(GET_PIP) \
	$(SOLR) \
	$(MIGRATION_WHEEL) \
	$(COMPONENTS) \
	$(COPIED_DEPS)

build-base-image: scrub.sh $(BUILD_DEPENDENCIES)
	docker build -t $(PRODUCT_BASE_IMAGE_ID) .
	# docker build --no-cache=true -t $(PRODUCT_BASE_IMAGE_ID) .

build: build-base-image

# To build the dev image, change the FROM_IMAGE value to use the .devtools base
# image and then build like any other product-base image.
build-devimg: change-from-image build-base-image

change-from-image:
	$(eval FROM_IMAGE = $(FROM_IMAGE).devtools)
	@echo "Building an image for development with FROM_IMAGE=$(FROM_IMAGE)"
	# Force creation of a new Dockerfile to minimize rebuild confusion
	@rm -f Dockerfile

get-components: $(COMPONENTS)

$(RPM_LIBSMI) $(PYDEPS) $(JSBUILDER) $(PHANTOMJS) $(SOLR):
	wget http://zenpip.zenoss.eng/packages/$@ -O $@

$(GET_PIP):
	wget https://bootstrap.pypa.io/get-pip.py

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
	@echo "export VERSION=$(VERSION)" > $@

$(MIGRATION_WHEEL): ../svcdefs/$(MIGRATION_WHEEL)
	@cp $< $@

../svcdefs/$(MIGRATION_WHEEL):
	@make -C ../svcdefs clean migrations

$(SHORT_VERSION).x/pull-docker-images.sh: | $(SHORT_VERSION).x
$(SHORT_VERSION).x/pull-docker-images.sh: pull-docker-images.sh.in
	@sed \
		-e 's/%HBASE_VERSION%/$(HBASE_VERSION)/g' \
		-e 's/%OPENTSDB_VERSION%/$(OPENTSDB_VERSION)/g' \
		$< > $@
	@chmod +x $@

Dockerfile: Dockerfile.in
	@sed \
		-e 's/%VERSION%/$(VERSION)/g' \
		-e 's/%SHORT_VERSION%/$(SHORT_VERSION)/g' \
		-e 's/%BASE_VERSION%/$(CENTOS_BASE_VERSION)/g' \
		-e 's/%BUILD%/$(BUILD_NUMBER)/g;' \
		-e 's/%INSTALL_OPTIONS%/$(INSTALL_OPTIONS)/g' \
		-e 's/%RPM_LIBSMI%/$(RPM_LIBSMI)/g' \
		-e 's/%PYDEPS%/$(PYDEPS)/g' \
		-e 's/%GETPIP%/$(GET_PIP)/g' \
		-e 's/%JSBUILDER%/$(JSBUILDER)/g' \
		-e 's/%PHANTOMJS%/$(PHANTOMJS)/g' \
		-e 's/%PRODBIN%/$(PRODBIN)/g' \
		-e 's/%METRIC_CONSUMER%/$(METRIC_CONSUMER)/g' \
		-e 's/%QUERY%/$(QUERY)/g' \
		-e 's/%PROTOCOLS%/$(PROTOCOLS)/g' \
		-e 's/%PYNETSNMP%/$(PYNETSNMP)/g' \
		-e 's/%EXTJS%/$(EXTJS)/g' \
		-e 's/%ZEP%/$(ZEP)/g' \
		-e 's/%METRICSHIPPER%/$(METRICSHIPPER)/g' \
		-e 's/%ZMINION%/$(ZMINION)/g' \
		-e 's/%REDISMON%/$(REDISMON)/g' \
		-e 's/%ZPROXY%/$(ZPROXY)/g' \
		-e 's/%TOOLBOX%/$(TOOLBOX)/g' \
		-e 's/%MIGRATION%/$(MIGRATION)/g' \
		-e 's/%SOLR%/$(SOLR)/g' \
		-e 's/%MIGRATION_WHEEL%/$(MIGRATION_WHEEL)/g' \
		-e 's/%MODEL_INDEX%/$(MODEL_INDEX)/g' \
		$< > $@

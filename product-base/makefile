include ../versions.mk
IMAGENAME  = product-base
MATURITY ?= DEV
BUILD_NUMBER  ?= DEV
FROM_IMAGE ?= zenoss-centos-base:1.2.4

TAG ?= zenoss/$(IMAGENAME):$(VERSION)_$(BUILD_NUMBER)_$(MATURITY)

.PHONY: build push clean

build:  component_versions $(SHORT_VERSION).x/pull-docker-images.sh Dockerfile
	docker build --no-cache=true -t $(TAG) .

push:
	docker push $(TAG)

clean:
	rm -rf component_info Dockerfile
	rm -f $(SHORT_VERSION).x/pull-docker-images.sh
	-docker rmi -f $(TAG)

component_versions: component_info
	@cp ../artifact_download.py ../component_versions.json component_info/.

component_info:
	@mkdir component_info

$(SHORT_VERSION).x/pull-docker-images.sh:
	@mkdir -p $(SHORT_VERSION).x
	@sed -e 's/%HBASE_VERSION%/$(HBASE_VERSION)/g; s/%OPENTSDB_VERSION%/$(OPENTSDB_VERSION)/g;'  pull-docker-images.sh.in > $@
	@chmod +x $@

Dockerfile:
	@sed -e 's/%SHORT_VERSION%/$(SHORT_VERSION)/g; s/%FROM_IMAGE%/$(FROM_IMAGE)/g;' Dockerfile.in > $@

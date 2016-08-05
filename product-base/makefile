IMAGENAME  = product-base
VERSION   ?= 5.2.0
MATURITY ?= DEV
BUILD_NUMBER  ?= DEV

TAG = zenoss/$(IMAGENAME):$(VERSION)_$(BUILD_NUMBER)_$(MATURITY)

.PHONY: build push clean

build:  component_versions
	docker build --no-cache=true -t $(TAG) .

push:
	docker push $(TAG)

clean:
	rm -rf component_info
	-docker rmi -f $(TAG)

component_versions: component_info 
	@cp ../artifact_download.py ../component_versions.json component_info/.

component_info:
	@mkdir component_info 

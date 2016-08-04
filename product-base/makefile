IMAGENAME  = product-base
VERSION   ?= 5.2.0
MATURITY ?= DEV
BUILD_NUMBER  ?= DEV

TAG = zenoss/$(IMAGENAME):$(VERSION)_$(BUILD_NUMBER)_$(MATURITY)

.PHONY: build push clean

build:
	docker build --no-cache=true -t $(TAG) .

push:
	docker push $(TAG)

clean:
	-docker rmi -f $(TAG)

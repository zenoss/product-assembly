include ../versions.mk
IMAGENAME  = resmgr_$(SHORT_VERSION)

MATURITY ?= DEV
BUILD_NUMBER  ?= DEV

FROM_IMAGE = product-base:$(VERSION)_$(BUILD_NUMBER)_$(MATURITY)

TAG = zenoss/$(IMAGENAME):$(VERSION)_$(BUILD_NUMBER)_$(MATURITY)

.PHONY: build push clean


build: Dockerfile zenpack_download
	docker build  -t $(TAG) .

Dockerfile:
	echo $(FROM_IMAGE)
	@sed -e  's/%FROM_IMAGE%/$(FROM_IMAGE)/g' Dockerfile.in > Dockerfile

zenpacks:
	@mkdir zenpacks

zenpack_download: zenpacks
	../zp_download.py ../zenpack_versions.json zenpacks.json zenpacks

push:
	docker push $(TAG)

clean:
	rm -rf zenpacks
	rm -f Dockerfile
	-docker rmi -f $(TAG)

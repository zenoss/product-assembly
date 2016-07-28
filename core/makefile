IMAGENAME  = core_5.2
VERSION   ?= 5.2.0
MATURITY ?= DEV
BUILD_NUMBER  ?= DEV

FROM_IMAGE = zenoss-product-base:$(VERSION)_$(BUILD_NUMBER)_$(MATURITY)

TAG = zenoss/$(IMAGENAME):$(VERSION)_$(BUILD_NUMBER)_$(MATURITY)

.PHONY: build push clean


build: zenpacks Dockerfile
	docker build  -t $(TAG) .

Dockerfile:
	echo $(FROM_IMAGE)
	@sed -e  's/%FROM_IMAGE%/$(FROM_IMAGE)/g' Dockerfile.in > Dockerfile

downloads:
	@mkdir downloads

zenpacks: downloads
	../zp_download.py ../zenpack_versions.json zenpacks.json downloads

push:
	docker push $(TAG)

clean:
	rm -rf downloads
	rm -f Dockerfile
	docker rmi $(TAG)

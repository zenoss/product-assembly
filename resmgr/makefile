include ../versions.mk
IMAGENAME  = resmgr_$(SHORT_VERSION)

MATURITY ?= DEV
BUILD_NUMBER  ?= DEV

FROM_IMAGE = product-base:$(VERSION)_$(BUILD_NUMBER)_$(MATURITY)

TAG = zenoss/$(IMAGENAME):$(VERSION)_$(BUILD_NUMBER)_$(MATURITY)

.PHONY: build push clean getDownloadLogs


build: Dockerfile zenpack_download
	docker build  -t $(TAG) .

Dockerfile:
	echo $(FROM_IMAGE)
	@sed -e  's/%FROM_IMAGE%/$(FROM_IMAGE)/g' Dockerfile.in > Dockerfile

zenpacks:
	@mkdir zenpacks

zenpack_download: zenpacks
	../artifact_download.py ../zenpack_versions.json --zp_manifest zenpacks.json --out_dir zenpacks --reportFile zenpacks_install.log

push:
	docker push $(TAG)

clean:
	rm -rf zenpacks
	rm -f Dockerfile
	rm -f zenoss_component_install.log
	rm -f zenpacks_install.log
	-docker rmi -f $(TAG)

getDownloadLogs:
	docker run --rm -v $(PWD):/mnt/export -ti $(TAG) rsync -a /opt/zenoss/log/zenoss_component_install.log /opt/zenoss/log/zenpacks_install.log /mnt/export

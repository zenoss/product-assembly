include ../versions.mk
IMAGENAME  = core_$(SHORT_VERSION)

MATURITY ?= DEV
BUILD_NUMBER  ?= DEV

FROM_IMAGE = product-base:$(VERSION)_$(BUILD_NUMBER)_$(MATURITY)

TAG = zenoss/$(IMAGENAME):$(VERSION)_$(BUILD_NUMBER)_$(MATURITY)

.PHONY: build push clean getDownloadLogs


build: Dockerfile zenpack_download
	docker build  -t $(TAG) .

Dockerfile: upgrade-core.txt upgrade-core.sh
	echo $(FROM_IMAGE)
	@sed -e  's/%FROM_IMAGE%/$(FROM_IMAGE)/g; s/%SHORT_VERSION%/$(SHORT_VERSION)/g' Dockerfile.in > $@

zenpacks:
	@mkdir $@

zenpack_download: zenpacks
	../artifact_download.py ../zenpack_versions.json --zp_manifest zenpacks.json --out_dir zenpacks --reportFile zenpacks_artifact.log

push:
	docker push $(TAG)

clean:
	rm -rf zenpacks
	rm -f Dockerfile upgrade-core.txt upgrade-core.sh zenoss_component_artifact.log zenpacks_artifact.log
	-docker rmi -f $(TAG)

getDownloadLogs:
	docker run --rm -v $(PWD):/mnt/export -t $(TAG) rsync -a /opt/zenoss/log/zenoss_component_artifact.log /opt/zenoss/log/zenpacks_artifact.log /mnt/export


upgrade-core.txt:
	@sed -e 's/%HBASE_VERSION%/$(HBASE_VERSION)/g; s/%OPENTSDB_VERSION%/$(OPENTSDB_VERSION)/g; s/%SHORT_VERSION%/$(SHORT_VERSION)/g; s/%VERSION%/$(VERSION)/g; s/%RELEASE_PHASE%/$(MATURITY)/g; ' upgrade-core.txt.in > $@

upgrade-core.sh:
	@sed -e 's/%SHORT_VERSION%/$(SHORT_VERSION)/g; s/%VERSION%/$(VERSION)/g;' upgrade-core.sh.in > $@

run-tests:
	docker run -i --rm $(TAG) /opt/zenoss/install_scripts/starttests.sh

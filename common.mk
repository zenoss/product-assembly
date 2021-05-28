include ../variables.mk

UPGRADE_SCRIPTS = pull-docker-images.sh upgrade-$(PRODUCT).txt upgrade-$(PRODUCT).sh $(ADDITIONAL_UPGRADE_SCRIPTS)

ZENPACK_DIR = zenpacks

export PRODUCT_IMAGE_ID
export PRODUCT_BASE_IMAGE_ID
export MARIADB_IMAGE_ID
export MARIADB_BASE_IMAGE_ID

.PHONY: build build-deps push clean getDownloadLogs download_zenpacks

build: build-deps
	@./build.sh

build-deps: $(UPGRADE_SCRIPTS) copy_upgrade_scripts.sh download_zenpacks

product-image-id:
	@echo $(PRODUCT_IMAGE_ID)

product-image-tag:
	@echo $(PRODUCT_IMAGE_TAG)

mariadb-image-id:
	@echo $(MARIADB_IMAGE_ID)

mariadb-image-tag:
	@echo $(MARIADB_IMAGE_TAG)

copy_upgrade_scripts.sh: copy_upgrade_scripts.sh.in
	@sed -e "s/%SHORT_VERSION%/$(SHORT_VERSION)/g" $< > $@
	@chmod +x $@

$(ZENPACK_DIR):
	@mkdir $@

download_zenpacks: | $(ZENPACK_DIR)
	@../artifact_download.py \
		--zp_manifest zenpacks.json \
		--out_dir zenpacks \
		--reportFile zenpacks_artifact.log \
		../zenpack_versions.json

clean:
	@rm -rf $(ZENPACK_DIR)
	@rm -f copy_upgrade_scripts.sh $(UPGRADE_SCRIPTS) zenoss_component_artifact.log zenpacks_artifact.log
	@-docker image rm -f $(PRODUCT_IMAGE_ID) $(MARIADB_IMAGE_ID) 2>/dev/null

getDownloadLogs:
	@docker run --rm \
		-v $(PWD):/mnt/export \
		-t $(PRODUCT_IMAGE_ID) \
		rsync -a /opt/zenoss/log/zenoss_component_artifact.log /opt/zenoss/log/zenpacks_artifact.log /mnt/export

upgrade-%.txt: upgrade-%.txt.in
	@sed \
		-e 's/%ZING_CONNECTOR_VERSION%/$(ZING_CONNECTOR_VERSION)/g' \
		-e 's/%ZING_API_PROXY_VERSION%/$(ZING_API_PROXY_VERSION)/g' \
		-e 's/%OTSDB_BIGTABLE_VERSION%/$(OTSDB_BIGTABLE_VERSION)/g' \
		-e 's/%SHORT_VERSION%/$(SHORT_VERSION)/g' \
		-e 's/%VERSION%/$(VERSION)/g' \
		-e 's/%UCSPM_VERSION%/$(UCSPM_VERSION)/g' \
		-e 's/%RELEASE_PHASE%/$(MATURITY)/g' \
		-e 's/%VERSION_TAG%/$(VERSION_TAG)/g' \
		$^ > $@

upgrade-%.sh: upgrade-%.sh.in
	@sed \
		-e 's/%SHORT_VERSION%/$(SHORT_VERSION)/g' \
		-e 's/%VERSION%/$(VERSION)/g' \
		-e 's/%UCSPM_VERSION%/$(UCSPM_VERSION)/g' \
		-e 's/%VERSION_TAG%/$(VERSION_TAG)/g' \
		$^ > $@
	@chmod +x $@

pull-docker-images.sh: ../product-base/pull-docker-images.sh.in
	@sed \
		-e 's/%HBASE_VERSION%/$(HBASE_VERSION)/g' \
		-e 's/%OPENTSDB_VERSION%/$(OPENTSDB_VERSION)/g' \
		-e 's/%PRODUCT%/$(PRODUCT)/g' \
		-e 's/%VERSION%/$(VERSION)/g' \
		$< > $@
	@chmod +x $@

run-tests:
	@../test_image.sh

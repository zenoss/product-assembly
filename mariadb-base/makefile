SHELL := /bin/bash

include ../variables.mk

GID ?= 1202
UID ?= 1202

.PHONY: clean build

build: img/exported.tar Dockerfile
	@docker build -f Dockerfile -t $(MARIADB_BASE_IMAGE_ID) img

clean:
	@-docker image rm -f $(MARIADB_BASE_IMAGE_ID) 2>/dev/null
	@rm -rf img exported_files
	@rm -f Dockerfile

Dockerfile: Dockerfile.in
	@sed -e "s/%GID%/$(GID)/" -e "s/%UID%/$(UID)/" $< > $@

dirs = img exported_files exported_files/opt/zenoss/bin exported_files/home/zenoss exported_files/etc

etc_files = exported_files/etc/my.cnf
zenoss_bin_files = exported_files/opt/zenoss/bin/upgrade_database.sh
home_zenoss_files = \
	exported_files/home/zenoss/permissions.sql.in \
	exported_files/home/zenoss/permissions_common.sql.in \
	exported_files/home/zenoss/initialize_db.sh

img/exported.tar: | $(dirs)
img/exported.tar: source_files_to_copy.txt $(etc_files) $(zenoss_bin_files) $(home_zenoss_files)
	./export_from_product_base.sh "$(PRODUCT_BASE_IMAGE_ID)" $< exported_files
	cd exported_files && tar cf ../$@ *

$(dirs):
	@mkdir -p $@

$(etc_files): | exported_files/etc
$(etc_files): exported_files/etc/%: %
	cp $< $@

$(zenoss_bin_files): | exported_files/opt/zenoss/bin
$(zenoss_bin_files): exported_files/opt/zenoss/bin/%: %
	cp $< $@

$(home_zenoss_files): | exported_files/home/zenoss
$(home_zenoss_files): exported_files/home/zenoss/%: %
	cp $< $@

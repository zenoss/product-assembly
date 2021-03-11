SHELL := /bin/bash

include ../variables.mk

GID ?= 1202
UID ?= 1202

PACKAGES = $(shell tr '\n' ' ' < packages.txt)

.PHONY: clean build

build: exported.tar Dockerfile
	@docker build -t $(MARIADB_BASE_IMAGE_ID) .

clean: clean-toolbox
	@-docker image rm -f $(MARIADB_BASE_IMAGE_ID) 2>/dev/null
	@rm -f exported.tar Dockerfile
	@rm -rf exported_files

Dockerfile: Dockerfile.in
	@sed \
		-e "s/%GID%/$(GID)/" \
		-e "s/%UID%/$(UID)/" \
		-e "s/%PACKAGES%/${PACKAGES}/" \
		$< > $@

dirs = exported_files exported_files/opt/zenoss/bin exported_files/home/zenoss exported_files/etc

toolbox_wheel = zends.toolbox-$(VERSION)-py2-none-any.whl
etc_files = exported_files/etc/my.cnf

upgrade_files = fix_permissions.sql.in upgrade_database.sh
zenoss_bin_files := $(addprefix exported_files/opt/zenoss/bin/,$(upgrade_files))

initialize_files = permissions.sql initialize_db.sh
home_zenoss_files := $(addprefix exported_files/home/zenoss/,$(initialize_files))

exported.tar: | $(dirs)
exported.tar: source_files_to_copy.txt $(etc_files) $(zenoss_bin_files) $(home_zenoss_files) tools/dist/$(toolbox_wheel)
	./export_from_product_base.sh "$(PRODUCT_BASE_IMAGE_ID)" $< exported_files
	cp tools/dist/$(toolbox_wheel) exported_files/home/zenoss/
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

tools/dist/$(toolbox_wheel):
	@make -C tools package

clean-toolbox:
	@make -C tools clean

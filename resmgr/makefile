TARGET_PRODUCT = resmgr
ADDITIONAL_UPGRADE_SCRIPTS = upgrade-impact.txt

ACTIVEPYTHON_ARCHIVE = ActivePython-2.7.18.2.0000-linux-x86_64-glibc-2.17-db6b4da0.tar.gz

include ../common.mk

.PHONY: clean-resmgr

build: activepython/_install.py

clean: clean-resmgr

clean-resmgr:
	@rm -rf activepython
	@rm -f $(ACTIVEPYTHON_ARCHIVE)

activepython/_install.py: | activepython
	curl http://zenpip.zenoss.eng/packages/$(ACTIVEPYTHON_ARCHIVE) | tar --strip-components=1 -C activepython -xz

activepython:
	@mkdir -p $@

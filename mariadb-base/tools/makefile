include ../../versions.mk

DOCKER = $(shell which docker)
PWD = ${CURDIR}
UID = $(shell id -u)
GID = $(shell id -g)
BUILD_IMAGE = "zenoss/zendstoolbox_build"

package: image
	$(DOCKER) run \
		--rm \
		-v $(PWD):/mnt/pwd \
		-e "VERSION=$(VERSION)" \
		-w /mnt/pwd \
		-u builder \
		$(BUILD_IMAGE) \
		python2 setup.py bdist_wheel

image: Dockerfile
	@$(DOCKER) build -t $(BUILD_IMAGE) .

Dockerfile: Dockerfile.in
	@sed \
		-e "s/%VERSION%/$(ZENOSS_CENTOS_BASE_VERSION)/g" \
		-e "s/%GID%/$(GID)/g" \
		-e "s/%UID%/$(UID)/g" \
		$< > $@

wheel:
	@python2 setup.py bdist_wheel

develop:
	@python2 setup.py develop

clean:
	@rm -rf build dist Dockerfile src/zends.toolbox.egg-info

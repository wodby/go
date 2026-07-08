-include env_make

GO_VER ?= 1.26.5
GO_VER_MINOR := $(shell v='$(GO_VER)'; echo "$${v%.*}")

REPO = wodby/go
NAME = go-$(GO_VER_MINOR)

PLATFORM ?= linux/arm64

ifeq ($(WODBY_USER_ID),)
    WODBY_USER_ID := 1000
endif

ifeq ($(WODBY_GROUP_ID),)
    WODBY_GROUP_ID := 1000
endif

ifeq ($(TAG),)
	ifneq ($(GO_DEV),)
		ifeq ($(WODBY_USER_ID),501)
			TAG := $(GO_VER_MINOR)-dev-macos
			NAME := $(NAME)-dev-macos
		else
			TAG := $(GO_VER_MINOR)-dev
			NAME := $(NAME)-dev
		endif
	else
		TAG := $(GO_VER_MINOR)
	endif
endif

IMAGETOOLS_TAG ?= $(TAG)

ifneq ($(ARCH),)
	override TAG := $(TAG)-$(ARCH)
endif

.PHONY: build buildx-build buildx-push test push shell run start stop logs clean release buildx-imagetools-create

default: build

build:
	docker build -t $(REPO):$(TAG) \
		--build-arg GO_VER=$(GO_VER) \
		--build-arg GO_DEV=$(GO_DEV) \
		--build-arg WODBY_GROUP_ID=$(WODBY_GROUP_ID) \
		--build-arg WODBY_USER_ID=$(WODBY_USER_ID) \
		./

buildx-build:
	docker buildx build --platform $(PLATFORM) -t $(REPO):$(TAG) \
		--build-arg GO_VER=$(GO_VER) \
		--build-arg GO_DEV=$(GO_DEV) \
		--build-arg WODBY_GROUP_ID=$(WODBY_GROUP_ID) \
		--build-arg WODBY_USER_ID=$(WODBY_USER_ID) \
		--load \
		./

buildx-push:
	docker buildx build --platform $(PLATFORM) --push -t $(REPO):$(TAG) \
		--build-arg GO_VER=$(GO_VER) \
		--build-arg GO_DEV=$(GO_DEV) \
		--build-arg WODBY_GROUP_ID=$(WODBY_GROUP_ID) \
		--build-arg WODBY_USER_ID=$(WODBY_USER_ID) \
		./

buildx-imagetools-create:
	docker buildx imagetools create -t $(REPO):$(IMAGETOOLS_TAG) \
				  $(REPO):$(TAG)-amd64 \
				  $(REPO):$(TAG)-arm64

test:
ifneq ($(GO_DEV),)
	cd ./tests && GO_IMAGE=$(REPO):$(TAG) ./run.sh
else
	@echo "We run tests only for DEV images."
endif

push:
	docker push $(REPO):$(TAG)

shell:
	docker run --rm --name $(NAME) -i -t $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) /bin/bash

run:
	docker run --rm --name $(NAME) $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG) $(CMD)

start:
	docker run -d --name $(NAME) $(PORTS) $(VOLUMES) $(ENV) $(REPO):$(TAG)

stop:
	docker stop $(NAME)

logs:
	docker logs $(NAME)

clean:
ifneq ($(GO_DEV),)
	cd ./tests && GO_IMAGE=$(REPO):$(TAG) docker compose down -v
endif
	-docker rm -f $(NAME)

release: build push

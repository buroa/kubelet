REGISTRY ?= ghcr.io
USERNAME ?= siderolabs
SHA ?= $(shell git describe --match=none --always --abbrev=8 --dirty)
TAG ?= $(shell git describe --tag --always --dirty)
BRANCH ?= $(shell git rev-parse --abbrev-ref HEAD)
REGISTRY_AND_USERNAME := $(REGISTRY)/$(USERNAME)
NAME := kubelet
KUBELET_VER := v1.24.7
KUBELET_SHA512_AMD64 := 25a182cc72a55a25042262caab6a89c90e5ff83018c7f9a7da035d060efa5c2a2ab5872b5c359321c2417e7461d6b12294388dd20981a4b4e516ede59281ef13
KUBELET_SHA512_ARM64 := b31f122ce4a51e2b399e538838f2aedc48fecbe0c2f72b836902cac9bee724bbe938c5eda9a277f9acdd5461a60369a915b5816dbea958fc899970e4fde7802e

BUILD := docker buildx build
PLATFORM ?= linux/amd64,linux/arm64
PROGRESS ?= auto
PUSH ?= false
COMMON_ARGS := --file=Dockerfile
COMMON_ARGS += --progress=$(PROGRESS)
COMMON_ARGS += --platform=$(PLATFORM)
COMMON_ARGS += --build-arg=REGISTRY_AND_USERNAME=$(REGISTRY_AND_USERNAME)
COMMON_ARGS += --build-arg=NAME=$(NAME)
COMMON_ARGS += --build-arg=TAG=$(TAG)
COMMON_ARGS += --build-arg=KUBELET_VER=$(KUBELET_VER)
COMMON_ARGS += --build-arg=KUBELET_SHA512_AMD64=$(KUBELET_SHA512_AMD64)
COMMON_ARGS += --build-arg=KUBELET_SHA512_ARM64=$(KUBELET_SHA512_ARM64)

all: container

target-%: ## Builds the specified target defined in the Dockerfile. The build result will remain only in the build cache.
	@$(BUILD) \
		--target=$* \
		$(COMMON_ARGS) \
		$(TARGET_ARGS) .

local-%: ## Builds the specified target defined in the Dockerfile using the local output type. The build result will be output to the specified local destination.
	@$(MAKE) target-$* TARGET_ARGS="--output=type=local,dest=$(DEST) $(TARGET_ARGS)"

docker-%: ## Builds the specified target defined in the Dockerfile using the default output type.
	@$(MAKE) target-$* TARGET_ARGS="--tag $(REGISTRY_AND_USERNAME)/$(NAME):$(TAG) $(TARGET_ARGS)"

.PHONY: container
container:
	@$(MAKE) docker-$@ TARGET_ARGS="--push=$(PUSH)"

.PHONY: update-sha
update-sha: update-sha-amd64 update-sha-arm64 ## Updates the kubelet sha512 checksums in the Makefile.

update-sha-%:
	sha512=`curl -sL https://storage.googleapis.com/kubernetes-release/release/$(KUBELET_VER)/bin/linux/${*}/kubelet.sha512`; \
		sed -i "s/KUBELET_SHA512_$(shell echo '$*' | tr '[:lower:]' '[:upper:]') := .*/KUBELET_SHA512_$(shell echo '$*' | tr '[:lower:]' '[:upper:]') := $${sha512}/" Makefile

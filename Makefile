.PHONY: help build image-release chart-release

IMAGE ?= claude-code
LOCAL_TAG ?= local
CLAUDE_CODE_VERSION ?= latest
CHART_FILE := charts/claude-code/Chart.yaml
VALUES_FILE := charts/claude-code/values.yaml

help:
	@echo "Targets:"
	@echo "  build                         Build the container image locally as $(IMAGE):$(LOCAL_TAG)."
	@echo "                                Override pinned Claude version with CLAUDE_CODE_VERSION=X.Y.Z."
	@echo "  image-release VERSION=X.Y.Z   Tag claude-X.Y.Z at HEAD and push it, triggering the build-image workflow."
	@echo "  chart-release VERSION=X.Y.Z   Bump $(CHART_FILE) to X.Y.Z, sync image.tag in $(VALUES_FILE)"
	@echo "                                to the latest claude-* git tag, commit, and push, triggering chart-releaser."

build:
	docker build \
		--build-arg CLAUDE_CODE_VERSION=$(CLAUDE_CODE_VERSION) \
		-t $(IMAGE):$(LOCAL_TAG) .

image-release:
ifndef VERSION
	$(error VERSION is required, e.g. make image-release VERSION=2.1.139)
endif
	@git diff-index --quiet HEAD -- || { echo "Working tree is dirty; commit before releasing"; exit 1; }
	git tag claude-$(VERSION)
	git push origin claude-$(VERSION)

chart-release:
ifndef VERSION
	$(error VERSION is required, e.g. make chart-release VERSION=0.0.4)
endif
	@git diff-index --quiet HEAD -- || { echo "Working tree is dirty; commit before releasing"; exit 1; }
	$(eval IMAGE_TAG := $(shell git tag -l 'claude-[0-9]*' --sort=-creatordate | head -n1 | sed 's/^claude-//'))
	@test -n "$(IMAGE_TAG)" || { echo "No claude-* tags found; run 'make image-release VERSION=X.Y.Z' first"; exit 1; }
	sed -i 's/^version: .*/version: $(VERSION)/' $(CHART_FILE)
	sed -i 's/^  tag: .*/  tag: "$(IMAGE_TAG)"/' $(VALUES_FILE)
	git add $(CHART_FILE) $(VALUES_FILE)
	git commit -m "chore: Bump Helm chart version to $(VERSION)"
	git push

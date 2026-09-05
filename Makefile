# pbdc-volume-bootstrap — toolchain for this repository.

# CONTAINER can be set to docker inside the toolchain dev container (it talks to
# the host's rootless podman socket); podman on the host.
CONTAINER ?= podman
IMAGE ?= localhost/pbdc-volume-bootstrap:fedora
GIT_URL ?= https://github.com/microsoft/vscode-remote-try-python.git

.PHONY: build image test docs docs-serve

build:
	npm run typecheck && npm run build

image: build
	$(CONTAINER) build -t $(IMAGE) .

test:
	CONTAINER=$(CONTAINER) ./scripts/e2e.sh $(GIT_URL)

docs:
	uv run mkdocs build

docs-serve:
	uv run mkdocs serve
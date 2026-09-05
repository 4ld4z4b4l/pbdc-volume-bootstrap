#syntax=docker/dockerfile:1
FROM docker.io/library/node:22-bookworm-slim

RUN apt-get update \
    && apt-get install -y --no-install-recommends podman podman-docker git ca-certificates curl \
    && rm -rf /var/lib/apt/lists/* \
    && npm install -g @devcontainers/cli

COPY entrypoint.sh /usr/local/bin/devctl.sh
RUN chmod +x /usr/local/bin/devctl.sh \
    && mkdir -p /workspace

ENV DEV_WORKSPACE=/workspace
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/devctl.sh"]
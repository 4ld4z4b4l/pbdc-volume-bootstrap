#syntax=docker/dockerfile:1
FROM registry.fedoraproject.org/fedora-minimal:latest

RUN microdnf install -y nodejs npm git podman tar gzip ca-certificates bash \
    && microdnf clean all \
    && npm install -g @devcontainers/cli

COPY dist/bootstrap.mjs /usr/local/bin/pbdc-volume-bootstrap.mjs

ENV DEV_WORKSPACE=/workspace
WORKDIR /workspace
ENTRYPOINT ["node", "/usr/local/bin/pbdc-volume-bootstrap.mjs"]
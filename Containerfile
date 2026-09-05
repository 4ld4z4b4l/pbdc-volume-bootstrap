#syntax=docker/dockerfile:1
FROM registry.fedoraproject.org/fedora-minimal:latest

RUN microdnf install -y nodejs npm git podman tar gzip ca-certificates bash \
    && microdnf clean all \
    && npm install -g @devcontainers/cli

COPY dc-podman-volume-bootstrap.sh /usr/local/bin/dc-podman-volume-bootstrap.sh
RUN chmod +x /usr/local/bin/dc-podman-volume-bootstrap.sh \
    && mkdir -p /workspace

ENV DEV_WORKSPACE=/workspace
WORKDIR /workspace
ENTRYPOINT ["/usr/local/bin/dc-podman-volume-bootstrap.sh"]
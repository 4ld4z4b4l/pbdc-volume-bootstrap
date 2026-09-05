# pbdc-volume-bootstrap

A 100% open-source, rootless **podman** equivalent of Microsoft's
*"Clone Repository in Container Volume"* flow for
[Dev Containers](https://containers.dev).

Given a public git URL, it clones the project into a **persistent named
podman volume** and launches a dev container whose workspace lives entirely
inside that volume — no host-dependent bind mounts, no Docker, no root, no
VS Code.

## Objectives

- **100% OSS**: MIT-licensed `@devcontainers/cli` + the open
  [Development Container Specification](https://containers.dev/implementors/spec/)
  (CC-BY 4.0) on rootless podman. No Docker, no proprietary runtime.
- **Rootless end-to-end**: everything runs under a plain user's podman,
  including the resulting dev container.
- **Clone in a volume**: identical workspace semantics to Microsoft's
  clone-in-volume (`workspaceMount` into a named volume, `git pull` on re-run
  instead of re-clone).
- **Ephemeral bootstrap**: a slim `fedora-minimal` image clones the project
  and drives `devcontainer up` against the host's rootless podman socket.
- **`devnet` network**: the bootstrap and the resulting dev container both
  attach to the `devnet` rootless bridge.

## Why

The devcontainer tooling refuses a repo that lives in a named volume unless
`workspaceMount` is injected explicitly. This project automates that, and
documents it in the open — see [Background](background/README.md).

Continue with [Architecture](architecture/README.md) or
[Usage](usage/README.md).
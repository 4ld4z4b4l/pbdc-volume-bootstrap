# dc-podman-volume-bootstrap

[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](LICENSE)

A 100% open-source, rootless **podman** implementation of the "Clone Repository
in Container Volume" devcontainer flow. Given a public git URL, it clones the
project into a **persistent named container volume** and launches a
[Dev Container](https://containers.dev) whose workspace lives entirely inside
that volume — no host-dependent bind mounts, no Docker, no root, no VS Code.

The name follows the [containers.dev](https://containers.dev) specification
naming (the *Dev Container Spec*, `devcontainer.json`) and deliberately avoids
the `devcontainers` tradename held by Microsoft/GitHub's organization.

## Objectives

- **OSS, no proprietary runtime**: built on the MIT-licensed
  [`@devcontainers/cli`](https://github.com/devcontainers/cli), the
  [Development Container Specification](https://containers.dev/implementors/spec/)
  (CC-BY 4.0), and rootless podman. Nothing requires Docker, Docker Desktop, or
  a commercial subscription.
- **Rootless end-to-end**: every container runs under a plain user's podman
  (`--userns=keep-id`, user socket) — no root daemons anywhere.
- **Clone in a volume, not a bind mount**: the workspace lives in a persistent
  named podman volume (`dc-podman-volume-bootstrap-<project>`), the same
  semantics as Microsoft's *Clone Repository in Container Volume*. A re-run
  refreshes the existing clone with `git pull` instead of re-cloning.
- **Bootstrap is ephemeral**: a slim `fedora-minimal` image clones the project
  and drives `devcontainer up` against the host's rootless podman socket, then
  exits. The bootstrap and the resulting devcontainer both join the `devnet`
  network, so containers discover each other by name.
- **Portability**: the host only needs a podman socket; the bootstrapping logic
  ships inside the container image.

## Why this exists

`@devcontainers/cli` (and the Dev Containers extension) will not run
`devcontainer up` against a repo that lives in a named volume out of the box:
when no `workspaceMount` is present the CLI synthesizes a
`type=bind,source=<host git root>,target=/workspaces/<name>` mount, which
breaks when there is no host path (the exact failure Microsoft's internal
`vsc-volume-bootstrap` image was built to solve). This project reproduces that
solution in the open — see [Background](docs/background.md) for the upstream
references ([devcontainers/cli#403](https://github.com/devcontainers/cli/issues/403)).

## Quick start

Requires a running rootless podman socket on the host
(`systemctl --user start podman.socket`), e.g. at
`unix:///run/user/1000/podman/podman.sock`.

```console
$ dc-podman-volume-bootstrap https://github.com/microsoft/vscode-remote-try-python.git
```

Under the hood:

1. `podman volume create dc-podman-volume-bootstrap-vscode-remote-try-python` (if missing)
2. `podman run --rm --network devnet \
     -v dc-podman-volume-bootstrap-vscode-remote-try-python:/workspace \
     -v /run/user/1000/podman/podman.sock:/root/.poop/poop \
     -e GIT_URL=... -e PROJECT_NAME=... -e WORKSPACE_VOLUME=... -e NETWORK=devnet \
     localhost/dc-podman-volume-bootstrap:fedora`

See [Usage](docs/usage.md) and [Architecture](docs/architecture.md).

## Status

Experimental. Works against rootless podman 6.x on CachyOS; see
[docs/background.md](docs/background.md) for the documented quirks.

## Repository layout

| Path                  | Purpose                                              |
| --------------------- | ---------------------------------------------------- |
| `Containerfile`       | `fedora-minimal` bootstrap image definition          |
| `dc-podman-volume-bootstrap.sh` | Image entrypoint (clone/pull + inject + `devcontainer up`) |
| `docs/`               | MkDocs site (index, architecture, usage, background) |
| `catalog-info.yaml`   | Backstage catalog entity                              |
| `AGENTS.md`           | Agent/editor guidance for this repository             |

## License

[BSD-3-Clause](LICENSE), Copyright (c) 2026 Aitor Aldazabal.
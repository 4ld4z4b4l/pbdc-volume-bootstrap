# pbdc-volume-bootstrap

[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD--3--Clause-blue.svg)](LICENSE)

A 100% open-source, rootless **podman** implementation of the "Clone Repository
in Container Volume" devcontainer flow. Part of the **pbdc** family
(podman-based-devcontainers). Given a public git URL, it clones the project
into a **persistent named container volume** and launches a
[Dev Container](https://containers.dev) whose workspace lives entirely inside
that volume — no host-dependent bind mounts, no Docker, no root, no VS Code.

## Objectives

- **OSS, no proprietary runtime**: built on the MIT-licensed
  [`@devcontainers/cli`](https://github.com/devcontainers/cli), the
  [Development Container Specification](https://containers.dev/implementors/spec/)
  (CC-BY 4.0), and rootless podman.
- **Rootless end-to-end**: every container runs under a plain user's podman
  (`--userns=keep-id`, user socket) — no root daemons anywhere.
- **Clone in a volume, not a bind mount**: the workspace lives in a persistent
  named podman volume (`pbdc-volume-bootstrap-<project>`), the same semantics
  as Microsoft's *Clone Repository in Container Volume*. A re-run refreshes
  the existing clone with `git pull` instead of re-cloning.
- **Bootstrap is ephemeral**: a slim `fedora-minimal` image clones the project
  and drives `devcontainer up` against the host's rootless podman socket, then
  exits. The bootstrap and the resulting dev container both join the `devnet`
  network, so containers discover each other by name.
- **Portability**: the host only needs a podman socket; the bootstrapping logic
  (a single compiled ESM bundle) ships inside the container image.

## Why this exists

`@devcontainers/cli` (and the Dev Containers extension) will not run
`devcontainer up` against a repo that lives in a named volume out of the box:
when no `workspaceMount` is present the CLI synthesizes a
`type=bind,source=<host git root>,target=/workspaces/<name>` mount, which
breaks when there is no host path. This project reproduces the fix in the open —
see [Background](docs/background/README.en.md) for the upstream references
([devcontainers/cli#403](https://github.com/devcontainers/cli/issues/403)).

## Quick start

Requires a running rootless podman socket on the host
(`systemctl --user start podman.socket`), e.g. at
`unix:///run/user/1000/podman/podman.sock`.

```console
$ pbdc-volume-bootstrap https://github.com/microsoft/vscode-remote-try-python.git
```

Under the hood:

1. `podman volume create pbdc-volume-bootstrap-vscode-remote-try-python` (if missing)
2. `podman run --rm --network devnet \
     -v pbdc-volume-bootstrap-vscode-remote-try-python:/workspace \
     -v /run/user/1000/podman/podman.sock:/root/.poop/poop \
     -e GIT_URL=... -e PROJECT_NAME=... -e WORKSPACE_VOLUME=... -e NETWORK=devnet \
     localhost/pbdc-volume-bootstrap:fedora`

Naming of the resulting dev container and image follows
`<project>.<machine>.<namespace>.<repo>.devcontainer` /
`<namespace>/<repo>-devcontainer` (project part skipped when it equals the repo
name), e.g. `rog.microsoft.vscode-remote-try-python.devcontainer` on
`microsoft/vscode-remote-try-python-devcontainer`.

See [Usage](docs/usage/README.en.md) and [Architecture](docs/architecture/README.en.md).

## Status

`v0.1.0` — still scaffolding. The end-to-end flow works against rootless
podman 6.x on CachyOS (clone in a volume, rootless dev container on `devnet`,
JSONC config injection), but do not depend on this yet: APIs and layout are
subject to change until `v1.0.0`. See
[docs/background/README.en.md](docs/background/README.en.md) for the
documented quirks.

## Repository layout

| Path                          | Purpose                                              |
| ----------------------------- | ---------------------------------------------------- |
| `src/bootstrap.ts`            | Bootstrap entrypoint (TypeScript), compiled to `dist/` by esbuild |
| `Containerfile`               | `fedora-minimal` bootstrap output image (`COPY dist/bootstrap.mjs`) |
| `.devcontainer/`              | Toolchain dev container (TypeScript/npm/uv + podman) |
| `scripts/e2e.sh`, `Makefile`  | Image build (`make image`), e2e test (`make test`), docs (`make docs`) |
| `package.json`, `tsconfig.json`, `pyproject.toml` | Node/TS + MkDocs tooling |
| `docs/`                       | MkDocs site (index, architecture, usage, background) |
| `catalog-info.yaml`           | Backstage catalog entity                              |
| `AGENTS.md`                   | Agent/editor guidance for this repository             |

## License

[BSD-3-Clause](LICENSE), Copyright (c) 2026 Aitor Aldazabal.
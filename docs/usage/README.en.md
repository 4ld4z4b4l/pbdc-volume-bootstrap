# Usage

## Prerequisites

- Rootless podman with its API socket running:

  ```console
  $ systemctl --user start podman.socket
  $ podman info | grep -A2 socket
  ```

  The bootstrap mounts the socket at `/root/.poop/poop`
  (`unix:///run/user/<uid>/podman/podman.sock`).

## Wrapper

```console
$ pbdc-volume-bootstrap https://github.com/microsoft/vscode-remote-try-python.git
```

Volume name is derived from the repo name (lowercased):

```console
$ podman volume ls | grep pbdc-volume-bootstrap
pbdc-volume-bootstrap-vscode-remote-try-python
```

A second run refreshes the existing clone (`git pull`) and re-launches the
dev container — it never re-clones.

## What the wrapper does

```console
$ podman volume create pbdc-volume-bootstrap-<proj>   # if missing
$ podman run --rm --network devnet \
    -v pbdc-volume-bootstrap-<proj>:/workspace \
    -v /run/user/1000/podman/podman.sock:/root/.poop/poop \
    -e GIT_URL=<url> \
    -e PROJECT_NAME=<proj> \
    -e WORKSPACE_VOLUME=pbdc-volume-bootstrap-<proj> \
    -e NETWORK=devnet \
    localhost/pbdc-volume-bootstrap:fedora
```

## Environment variables

| Variable | Meaning |
| --- | --- |
| `GIT_URL` | Public git URL to clone. |
| `PROJECT_NAME` | Directory name inside `/workspace`; defaults to the repo basename. |
| `WORKSPACE_VOLUME` | Named volume hosting `/workspace`; used for the injected `workspaceMount`. |
| `NETWORK` | Network for the resulting dev container (`runArgs`). |
| `LOCAL_MACHINE` | Machine name embedded in the dev container name (defaults to `local`). |

## Naming

The resulting dev container and image follow the pbdc convention:

- container: `<project>.<machine>.<namespace>.<repo>.devcontainer`
  (project part is skipped when it equals the repo name),
- image: `<namespace>/<repo>-devcontainer`.

For `https://github.com/microsoft/vscode-remote-try-python.git` on machine
`rog` this yields `rog.microsoft.vscode-remote-try-python.devcontainer`
(image `microsoft/vscode-remote-try-python-devcontainer`). The bootstrap
container itself is named `pbdcb-<proj>`.

## Example repositories

- `https://github.com/microsoft/vscode-remote-try-python.git`
- `https://github.com/microsoft/vscode-remote-try-node.git`

## Under the hood

The bootstrap:

1. Binds the poop socket to `/run/podman/podman.sock` and sets `DOCKER_HOST`.
2. Clones `GIT_URL` into `/workspace/<proj>` (or `git pull` if present).
3. Injects `workspaceMount: "type=volume,source=<WORKSPACE_VOLUME>,target=/workspace"`,
   `workspaceFolder: "/workspace/<proj>"`, and
   `runArgs: ["--network=" + NETWORK]`.
4. Runs `devcontainer up` with `--docker-path /usr/bin/podman` and
   `--mount-workspace-git-root=false`.
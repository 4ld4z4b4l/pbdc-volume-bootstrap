# Background

## The problem

`@devcontainers/cli` and the Dev Containers extension assume the workspace
source lives on the host filesystem. When merging a repository's
`devcontainer.json`, if no `workspaceMount` key is present the tooling
synthesizes one:

```
type=bind,source=<host git root>,target=/workspaces/<basename>
```

For a workspace living in a **named container volume** there is no host path
to bind — this is exactly the failure that made clone-in-volume impossible
with the plain tooling.

## How Microsoft solves it

VS Code's *"Clone Repository in Container Volume"* is implemented by an
internal `vsc-volume-bootstrap` image that:

1. creates a named volume (`<repo>-<hash>`, labelled `vsch.local.repository`),
2. runs a long-lived `docker run -d --mount type=volume,src=<vol>,dst=/workspaces
   -v /var/run/docker.sock:/var/run/docker.sock --security-opt label=disable
   vsc-volume-bootstrap sleep infinity`,
3. `git clone`s the repository into the volume,
4. runs `devcontainer up` with an `--override-config` that injects the
   volume-based `workspaceMount` and `workspaceFolder`.

This project reproduces that design — rootless, podman-native, and open.

```mermaid
sequenceDiagram
    participant U as user
    participant W as wrapper
    participant B as bootstrap container
    participant V as named volume
    participant D as dev container (devnet)
    U->>W: pbdc-volume-bootstrap &lt;git-url&gt;
    W->>V: podman volume create (if missing)
    W->>B: podman run --rm --network devnet + user socket
    B->>B: bind socket -> DOCKER_HOST
    B->>V: git clone / git pull
    B->>B: inject workspaceMount + workspaceFolder + runArgs
    B->>D: devcontainer up --docker-path /usr/bin/podman
    D-->>B: ok (container up)
    B-->>W: exit
```

## Upstream references

- [devcontainers/cli#403](https://github.com/devcontainers/cli/issues/403) —
  open feature request: "clone repository into a docker volume with
  `devcontainer up`".
- [microsoft/vscode-remote-release#10135](https://github.com/microsoft/vscode-remote-release/issues/10135) —
  internals of the bootstrap image.
- [microsoft/vscode-remote-release#11691](https://github.com/microsoft/vscode-remote-release/issues/11691) —
  exact `vsc-volume-bootstrap` commands (volume create, `docker run`,
  clone, `--override-config`).
- [Development Container Specification](https://containers.dev/implementors/spec/) —
  the open spec (CC-BY 4.0) this project implements.
- `devcontainer.json` reference — `workspaceMount` and `workspaceFolder`
  semantics.

## Naming rationale

The `devcontainers` name (no space) is the GitHub organization and tradename
held by Microsoft. This project uses the `dc-` prefix referencing the **Dev
Container** spec naming instead, and is not affiliated with either.

## Known quirks

- podman 6.x may mount the API socket at `/root/.poop/poop` — the entrypoint
  binds it to the conventional socket paths.
- `--mount-workspace-git-root=false` is required so the CLI does not attempt
  to bind-mount a non-existent host checkout.
- The CLI's `cliVariant` is auto-detected as `podman` from `<dockerPath> -v`,
  which adds `--userns=keep-id` and `--security-opt label=disable` for
  non-root `remoteUser`.
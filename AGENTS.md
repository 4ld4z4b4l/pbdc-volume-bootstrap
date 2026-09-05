# AGENTS.md

Operational guidance for AI agents working in this repository. README.md and
`docs/` are for humans; the plan/roadmap lives outside this repo.

## Conventions

- Rootless everywhere: no root daemons, no `sudo podman`, no system services.
- Do not add code comments unless asked.
- Follow the existing patterns in `Containerfile` and the entrypoint script
  (`sh`, POSIX-safe, `set -e`).
- Keep the "clone in a volume, not a bind mount" invariant — never reintroduce
  host-path bind mounts.
- Reference the containers.dev spec naming (`dc-` prefix); do not use the
  `devcontainers` tradename in project naming.

## Git / identity

- The commit identity (persona) for this repo — name `Aitor Aldazabal`, email
  `aitor.aldazabal@outlook.com` — is applied externally via the
  `~/.gitconfig-github` includeif for paths under `~/code/github/`.
- **Never commit git settings.** Do not track `user.name`, `user.email`,
  `.gitconfig*`, credentials, tokens, or any identity/config file. Keep them
  strictly out of the repository.
- Do not commit non-standard AI configuration (see the `.gitignore` section).

## Build

```console
$ podman build -t localhost/dc-podman-volume-bootstrap:fedora .
```

## Test (e2e)

```console
$ dc-podman-volume-bootstrap https://github.com/microsoft/vscode-remote-try-python.git
```

Verify:
- clone appears in host volume (`podman volume ls`, inspect mount),
- the dev container runs rootless on `devnet` (`podman network inspect devnet`),
- the configured `postCreateCommand` ran,
- a second run performs `git pull`, not a re-clone.

## License

BSD-3-Clause, Copyright (c) 2026 Aitor Aldazabal.
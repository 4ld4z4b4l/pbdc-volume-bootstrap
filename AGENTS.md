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

## Workflow (trunk-based development)

- The default branch is `trunk`; all work lands on `trunk`.
- Small changes commit directly to `trunk`. Use short-lived branches (e.g.
  `feat/some-idea`, `docs/fix`) only when a change wants review, and merge them
  back into `trunk` right away.
- No long-lived or release branches. Release by tagging `trunk`
  (e.g. `git tag v0.1.0 && git push origin trunk v0.1.0`).

## Releases / changelog

- Changelog is generated with [git-cliff](https://github.com/orhun/git-cliff)
  from conventional commit messages (`cliff.toml`).
- Before tagging a release, run `git-cliff -o CHANGELOG.md` and commit the
  regenerated file, then `git tag vX.Y.Z && git push origin trunk vX.Y.Z`.

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
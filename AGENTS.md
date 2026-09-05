# AGENTS.md

Agent guidance for this repository, written to the
[AGENTS.md specification](https://agents.md) and its recommended structure.
That conformance is this file's first and foremost rule.

## Agent files

Only standardized AI files may be used in this repository (`AGENTS.md`,
`SKILLS.md`). Do not introduce non-standardized agent files.

## Project overview

`pbdc-volume-bootstrap` clones a git project into a persistent named podman
volume and launches a dev container whose workspace lives entirely in that
volume — rootless and podman-native, no Docker. Details live in README.md and
`docs/`.

## Development policy

Trunk-based development:

- The default branch is `trunk`; all work lands on `trunk`.
- Scaffolding is not yet done for any project in the pbdc family, so small
  changes commit directly to `trunk` for now.
- Once scaffolding is done, always use short-lived branches: create a branch,
  merge it back into `trunk` right away, delete it.
- No long-lived or release branches; releases are tags on `trunk`.
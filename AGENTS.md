# AGENTS.md

Agent guidance for this repository, written to the
[AGENTS.md specification](https://agents.md) and its recommended structure.
That conformance is this file's first and foremost rule.

## Project overview

`pbdc-volume-bootstrap` clones a git project into a persistent named podman
volume and launches a dev container whose workspace lives entirely in that
volume — rootless and podman-native, no Docker. Details live in README.md and
`docs/`.

## Development policy

Trunk-based development:

- The default branch is `trunk`; all work lands on `trunk` in small commits.
- Short-lived branches only when a change needs review; merge back immediately.
- Releases are tags on `trunk`; no long-lived branches.
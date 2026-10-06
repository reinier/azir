# Pin keyd to an exact upstream commit

- **Status:** done
- **Created:** 2026-10-06
- **Area:** image (`Containerfile`, `keyd-build` stage)
- **Related:** `config-nixos` backlog 0035 (supply-chain audit) and its `keyd.nix`;
  `dotfiles-azir` backlog `0014` (the rest of what Azir took from that config).

## Decision

The `keyd-build` stage still clones by tag (`KEYD_VERSION=v2.6.0`) but now also checks
`git rev-parse HEAD` against `KEYD_COMMIT=7c0aecb8bfd34dc8642bf4eefd2e59c89e61cec3`, and
fails the build if they differ.

## Why

config-nixos's supply-chain audit flagged keyd as the highest-risk package in the set:
root, reads every keystroke on the internal keyboard, effectively one maintainer
(rvaiya ~480 commits, next contributor 7). A tag can be re-pointed upstream, so "v2.6.0"
alone doesn't guarantee the code that was reviewed. NixOS pins the same commit.

Considered there and not repeated here: forking keyd to the forge (a pin already fixes the
bytes, a fork only adds upkeep), and switching to kanata (257 crates vs keyd's plain C).

## Checked

`v2.6.0` is a lightweight tag pointing straight at `7c0aecb` (no annotated tag object), so
a `--depth 1` clone's `HEAD` is that commit. The exact check was run against a real clone
from the devbox and passes.

## Bumping

Read `github.com/rvaiya/keyd/compare/7c0aecb...<new>` first, then update `KEYD_VERSION` and
`KEYD_COMMIT` together.

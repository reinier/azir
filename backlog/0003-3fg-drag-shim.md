# Three-finger-drag libinput shim

- **Status:** open (blocked on `dotfiles-azir` backlog `0007`'s validation spike)
- **Created:** 2026-09-01
- **Area:** image (`Containerfile`, new build stage)
- **Related:** [enable-3fg-drag](https://github.com/joaodriessen/enable-3fg-drag);
  `dotfiles-azir` backlog `0007` (validates the mechanism on niri before this is
  worth doing) and `0008` (runtime activation, once this exists in the image).

## Decision

Bake [enable-3fg-drag](https://github.com/joaodriessen/enable-3fg-drag)'s
`LD_PRELOAD` shim (`libenable-3fg-drag.so` — intercepts `libinput_get_event()`
and turns on libinput's built-in, off-by-default three-finger-drag) into the
image, the same way `keyd` already is: a dedicated multi-stage build stage,
compiled from source, `COPY --from=`'d into the final image.

## Why this belongs here, not in dotfiles-azir

Silverblue/bootc's whole model is a **read-only `/usr` at runtime** — that's
not a style preference this project has, it's the mechanism the atomic image
provides. `enable-3fg-drag`'s own default install path is
`/usr/lib/libenable-3fg-drag.so`; there is no way to place a file there from a
chezmoi script the way `dotfiles-azir` places, say, a Go binary under
`~/.local/bin`. Compiling it has to happen at image build time. This mirrors
`keyd` exactly (also a small C project, also built from source in its own
stage, also landing under a system path the final image can't write to later).

## What "done" looks like

A new stage, alongside `keyd-build`:

```dockerfile
FROM registry.fedoraproject.org/fedora:44 AS 3fg-drag-build
RUN dnf5 -y install git make gcc pkg-config libinput-devel \
 && git clone --depth 1 https://github.com/joaodriessen/enable-3fg-drag /src \
 && make -C /src \
 && install -Dm755 /src/libenable-3fg-drag.so /out/usr/lib/libenable-3fg-drag.so
```

(`enable-3fg-drag`'s `Makefile` has a plain build target — `make` alone
produces just `libenable-3fg-drag.so` via `pkg-config`-resolved libinput
headers, no install/systemd/DE-detection logic pulled in; that logic lives in
the repo's separate `install.sh`, which this stage deliberately does NOT run —
runtime activation is `dotfiles-azir` `0008`'s job, not this stage's.)

Then in the final stage, alongside the existing `COPY --from=keyd-build /out/ /`:

```dockerfile
COPY --from=3fg-drag-build /out/ /
```

**Pin a version/commit** the way `keyd`'s `ARG KEYD_VERSION=v2.6.0` does, once
`enable-3fg-drag` has tagged releases to pin to — as of writing it may only
have `main`; note this if so rather than silently pinning a moving branch.

No systemd unit, `/etc/ld.so.preload` entry, or any other activation added
here — this stage's only job is "the compiled `.so` exists in the image at a
known path." Nothing loads it until `dotfiles-azir` `0008` does.

## Verification

Builds green + `bootc container lint` (existing pattern). Rebase a test
machine, confirm `file /usr/lib/libenable-3fg-drag.so` reports a valid shared
object. Actual drag behavior isn't testable from this repo alone — that's
`dotfiles-azir` `0008`'s acceptance check, once this is baked in and something
points `LD_PRELOAD` at it.

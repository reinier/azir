# Three-finger-drag libinput shim

- **Status:** open (unblocked — reworked 2026-09-30, see "What changed")
- **Created:** 2026-09-01
- **Area:** image (`Containerfile`, new build stage)
- **Related:** [enable-3fg-drag](https://github.com/joaodriessen/enable-3fg-drag);
  `dotfiles-azir` backlog `0007` (activation in GNOME — first, as an isolated test) and
  `0008` (activation in niri, after GNOME works). Both depend on this item.

## Decision

Bake [enable-3fg-drag](https://github.com/joaodriessen/enable-3fg-drag)'s `LD_PRELOAD` shim
(`libenable-3fg-drag.so` — interposes `libinput_get_event()` and, on each new touchpad,
turns on libinput's built-in, off-by-default three-finger-drag) into the image, the same way
`keyd` already is: a dedicated build stage, compiled from source, `COPY --from=`'d in.

This item only makes the `.so` **exist** in the image. Nothing loads it: activation is a
per-compositor systemd user drop-in in `dotfiles-azir` (`0007` GNOME, `0008` niri), so an
image with this item and no drop-ins behaves exactly like one without it.

## Why the image, not dotfiles

`/usr` is read-only at runtime on bootc/ostree, and the shim is a compiled C library. It
has to be built at image build time, like `keyd`. Activation, on the other hand, is plain
files in `~/.config/systemd/user/` — no sudo, no `/etc` — so it belongs in the dotfiles.

## Facts this is based on (checked 2026-09-30 against the F44 packages, not assumed)

- **Still needed:** libinput `1.31.3` has the feature (≥ 1.28, plus 1.31's fast-swipe), but
  neither `libmutter-18.so` (mutter/gnome-shell 50.5) nor `/usr/bin/niri` (26.04) contains
  any `3fg_drag` symbol reference, and `org.gnome.desktop.peripherals` has no key for it.
- **Both compositors are hookable:** niri requires `libinput.so.10` dynamically (so symbol
  interposition works); gnome-shell does too, via libmutter.
- **Neither binary has file capabilities** (`rpm -qp --filecaps`), so the loader is not in
  secure-execution mode: a plain path in `LD_PRELOAD` works. Upstream's `4755` /
  bare-soname dance exists only for KWin (`cap_sys_nice`) and is **not** needed here.
- **Upstream has no tags** — only `main` (HEAD `09e9ca7` as of 2026-09-30). Pin the commit.

## What "done" looks like

A new stage, alongside `keyd-build`:

```dockerfile
# --- enable-3fg-drag: built from source, pinned to an upstream commit (no tags upstream) ---
FROM registry.fedoraproject.org/fedora:44 AS drag3fg-build
ARG ENABLE_3FG_DRAG_COMMIT=09e9ca763eca05c33a183c7a6cf582bdd77dbbb1
RUN dnf5 -y install git make gcc pkgconf-pkg-config libinput-devel \
 && git clone https://github.com/joaodriessen/enable-3fg-drag /src \
 && git -C /src checkout "$ENABLE_3FG_DRAG_COMMIT" \
 && make -C /src \
 && install -Dm755 /src/libenable-3fg-drag.so /out/usr/lib64/libenable-3fg-drag.so
```

and in the final stage, next to `COPY --from=keyd-build /out/ /`:

```dockerfile
COPY --from=drag3fg-build /out/ /
```

Plus a guard line in the app-layer guard `RUN`: the file exists, exports
`libinput_get_event` (`nm -D --defined-only`), and links only against libc (`ldd` — upstream
resolves every libinput symbol via `RTLD_NEXT` on purpose).

Two corrections to this item's original draft (2026-09-01), both would have broken things:

- **Stage name can't start with a digit** — `3fg-drag-build` is not a valid build-stage
  name; hence `drag3fg-build`.
- **`/usr/lib64`, not upstream's `/usr/lib`.** On Fedora x86_64, `/usr/lib` is the *32-bit*
  libdir. Upstream only uses `/usr/lib` for its KWin soname trick (not needed here); the
  drop-ins in `dotfiles-azir` give a full path, so put the 64-bit object where 64-bit
  objects live.

Only `make` (the plain build target), never upstream's `install.sh` — that one writes
`/etc/ld.so.preload` or KWin drop-ins, neither of which this setup uses.

## Verification

- CI green + `bootc container lint` (existing pattern); the guard line passes in the log.
- On the machine after `bootc upgrade`: `file /usr/lib64/libenable-3fg-drag.so` reports a
  64-bit ELF shared object. Nothing else should change until a drop-in points at it.

## What changed (2026-09-30)

Originally blocked on a niri-on-TTY validation spike, with activation planned as a global
`/etc/ld.so.preload`. Package inspection (above) answered the spike's questions, and showed
both compositors run as systemd user units without file caps — so scoped per-compositor
drop-ins replace the global preload, and GNOME goes first as an isolated test (`dotfiles-azir`
`0007`) before niri (`0008`).

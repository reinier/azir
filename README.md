# Azir

Azir is a personal Fedora **Silverblue**-based atomic desktop. It keeps the full GNOME
desktop and adds **[niri](https://github.com/YaLTeR/niri)** — a scrollable-tiling Wayland
compositor — driven by **[Dux Shell](https://github.com/duxlabs-dev/dux-shell)** (formerly DankMaterialShell, still `dms`)
(bar, launcher, notifications, lock), with a
[wlr-which-key](https://github.com/MaxVerevkin/wlr-which-key) leader menu. Pick **GNOME** or
**Niri** at the login screen.

**What "atomic" means:** the whole OS is a single image. Updates swap in a new image; if one
breaks, `bootc rollback` returns to the previous one in a single step. Every machine runs the
exact same thing.

Built on **[Roshar](https://github.com/reinier/roshar)** — the bare, generic niri+DMS-on-
Silverblue base, also independently rebase-able on its own. Azir adds the personal layer on
top: niri from git main, 1Password, Chromium, Tailscale, and a few CLI extras.

## Install

Start from a [Fedora Silverblue](https://fedoraproject.org/atomic-desktops/silverblue/)
install, then rebase onto Azir:

```sh
sudo bootc switch ghcr.io/reinier/azir:latest
sudo systemctl reboot
```

**Niri sets itself up on first login** via Roshar's baked default config, which launches DMS —
nothing to run yourself, and it steps aside entirely if `~/.config/niri/config.kdl` already
exists. One catch: that default binds `Mod+T` to Ptyxis, which Azir removes in favour of
kitty, so rebind it in `~/.config/niri/local.kdl` (my dotfiles take care of this).

## What you get

On top of everything Silverblue already provides (GNOME, GDM, GNOME Software, PipeWire,
printing, firmware updates, keyring):

- **A second desktop** — niri + Dux Shell, with niri built from git main (the
  pinned [niri-git COPR](https://copr.fedorainfracloud.org/coprs/yalter/niri-git/) build,
  not Fedora's release) for its bare-modifier binds, plus the Kitty terminal and
  xwayland-satellite for X11 apps. DMS handles multi-monitor (arrangement + display profiles).
- **Browsers** — Chromium with full media codecs, plus Microsoft Edge (Firefox is stripped — reinstall as a Flatpak if you want it back).
- **Apps** — 1Password (+ CLI), VS Code, Tailscale.
- **Input** — wlr-which-key for the leader menu, opened by a bare Mod tap (a niri
  release bind; no keyd).
- **Terminal toolkit** — fish, starship, eza, bat, yazi; distrobox for ad-hoc tooling.
- **Containers** — rootless Podman, with `docker` and `docker compose` as stand-ins (no Docker daemon).

## Updating

Two manual streams, nothing unattended:

```sh
sudo bootc upgrade     # the OS image
flatpak update         # your apps
```

`sudo bootc rollback` returns to the previous image.

## Configuration

Azir provides the desktop and apps, not a personal setup. Bring your own dotfiles for the
niri/DMS config, theming, shell config, and key remaps.

## Notes

A personal project, not an official Fedora product — the author daily-drives it, but there's
no support. niri and Dux Shell are independent upstream projects. Named for a nation
of Roshar.

# Azir

Azir is a personal Fedora **Silverblue**-based atomic desktop. It keeps the full GNOME
desktop and adds **[niri](https://github.com/YaLTeR/niri)** — a scrollable-tiling Wayland
compositor — driven by **[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)**
(bar, launcher, notifications, lock, and a dank-lader leader menu). Pick **GNOME** or **Niri**
at the login screen.

**What "atomic" means:** the whole OS is a single image. Updates swap in a new image; if one
breaks, `bootc rollback` returns to the previous one in a single step. Every machine runs the
exact same thing.

## Install

Start from a [Fedora Silverblue](https://fedoraproject.org/atomic-desktops/silverblue/)
install, then rebase onto Azir:

```sh
sudo bootc switch ghcr.io/reinier/azir:latest
sudo systemctl reboot
```

Important: you should have a Niri config ready where DMS is launched from config. My personal dotfiles take care of this and it's not build into this Azir image.

## What you get

On top of everything Silverblue already provides (GNOME, GDM, GNOME Software, PipeWire,
printing, firmware updates, keyring):

- **A second desktop** — niri + DankMaterialShell, with the Ghostty terminal and
  xwayland-satellite for X11 apps. DMS handles multi-monitor (arrangement + display profiles).
- **Browser** — Chromium with full media codecs (Firefox is stripped — reinstall as a Flatpak if you want it back).
- **Apps** — 1Password (+ CLI), Tailscale.
- **Input** — keyd for tap-hold key remaps.
- **Terminal toolkit** — fish, starship, eza, bat, yazi; distrobox for ad-hoc tooling.

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
no support. niri and DankMaterialShell are independent upstream projects. Named for a nation
of Roshar.

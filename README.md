# Azir

Azir is a personal Fedora **Silverblue**-based atomic desktop that keeps the full GNOME
desktop and adds **[niri](https://github.com/YaLTeR/niri)** (a scrollable-tiling Wayland
compositor) driven by **[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell)**
(DMS — bar, launcher, notifications, lock, dank-lader leader menu) as an **alternative
session** picked at the login screen.

**What "atomic" means:** the whole OS is a single image. Updates swap in a new image; if one
breaks, `bootc rollback` returns to the previous one in a single step.

Azir is *additive* — niri/DMS layer on top of stock Silverblue without removing GNOME. It's
the **DMS counterpart to [Tashikk](https://github.com/reinier/tashikk)** (which uses Noctalia
on the same base), and the additive cousin of [Steen](https://github.com/reinier/steen)
(niri-only, DMS, on a Sway Atomic base).

> ## 🚧 Work in progress
>
> Early scaffolding. The image builds. **Signing needs the `SIGNING_SECRET` repo secret** (the
> same cosign key as Steen/Tashikk) — until it's set, pushes are unsigned. Not hardware-
> verified. Personal project, no support.

## Install

Start from [Fedora Silverblue](https://fedoraproject.org/atomic-desktops/silverblue/), then:

```sh
sudo bootc switch ghcr.io/reinier/azir:latest
sudo systemctl reboot
```

At GDM, use the session picker (gear icon) → **Niri** or **GNOME**.

## What you get

On top of stock Silverblue (GNOME, GDM, GNOME Software, PipeWire, printing, keyring):

- **Second desktop** — niri + DMS (kitty terminal, xwayland-satellite, kanshi + wdisplays for
  displays). DMS is spawned from niri (dotfiles) so it only runs in the niri session.
- **Browser** — Chromium with full media codecs (Firefox stays too).
- **Apps** — 1Password (+ CLI), Synology Drive, Tailscale.
- **Input** — keyd (tap-hold remaps; enabled via your dotfiles).
- **Terminal toolkit** — fish, starship, eza, bat, yazi; distrobox for ad-hoc tooling.

## Updating

```sh
sudo bootc upgrade     # the OS image
flatpak update         # your apps
```
`sudo bootc rollback` returns to the previous image.

## Configuration

Bring your own dotfiles (`dotfiles-azir`, derived from `dotfiles-steen`): the vendored
niri/DMS config, DMS spawn, dank-lader, matugen theming, shell config, keyd remaps.

## Notes

Personal project, not an official Fedora product. niri and DMS are independent upstream
projects. Named for a nation of Roshar.

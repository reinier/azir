# gum for the Azir Menu

- **Status:** done (image side) — on-hardware check is `dotfiles-azir` `0013`
- **Created:** 2026-10-06
- **Area:** image (`Containerfile`, CLI toolkit line + app-layer guard)
- **Related:** `dotfiles-azir` backlog `0013` (the menu itself); ported from
  `config-nixos`'s `scripts/rl-menu` ("Roshar Menu").

## Decision

Add Fedora's `gum` package to the CLI-toolkit `dnf5 install` line, and to the app-layer
guard's `rpm -q` list.

`rl-menu` ("Azir Menu", Dank Lader `g`) is a `gum choose` / `gum confirm` / `gum pager`
picker for host maintenance: stage an image update and diff it, roll back, read the
booted image's changelog, pin the image, update Flatpaks, the `apps` distrobox, dotfiles
and firmware. NixOS got `gum` through the script's own `runtimeInputs`; on Azir it has to
be in the image.

## Why the image, not the apps distrobox

The menu updates the host and the `apps` distrobox itself. If `gum` lived in that
distrobox, a broken or mid-upgrade container would take the menu down with it. It's one
small Go binary from Fedora's own repos, so no COPR and no repo file to clean up.

# First-boot checklist — verify on real hardware

- **Status:** open (living document)
- **Created:** 2026-08-06

CI proves packages resolve and the image lints — not that both sessions come up or DMS
spawns. Rebase a test machine and work top-to-bottom.

```sh
sudo bootc switch ghcr.io/reinier/azir:latest && sudo systemctl reboot
```

## A. Both sessions + DMS spawn (the Azir-specific bit)

- [ ] GDM offers **GNOME** and **Niri**.
- [ ] **GNOME** session logs in and works normally (additive build didn't disturb it).
- [ ] **DMS does NOT run in the GNOME session** (`pgrep -af dms`/quickshell shows nothing there
      — it's not `--global` enabled; this is the key design check).
- [ ] **Niri** session logs in → the dotfiles' `spawn-at-startup` brings up **DMS** (bar,
      launcher, dank-lader, notifications). `niri msg version` responds; `dms ipc` works.
- [ ] **X11 apps run** (`pgrep -af xwayland-satellite`); **screencast** works (portal-gnome).
- [ ] kitty + Nerd Font glyphs render.

## B. Apps ported from Steen/Tashikk (re-verify on this base)

- [ ] 1Password unlocks, browser integration, `op`, 1PUX export dialog (gid≥1000 + ptrace).
- [ ] Chromium plays H.264; Synology syncs; `tailscale up`; keyd tap-hold; CLI toolkit +
      `distrobox create`; Flathub present.

## C. Silverblue plumbing (should be untouched)

- [ ] Audio, WiFi/DNS, Bluetooth, printing (GNOME panel), fingerprint, fwupd.

## D. Displays (niri session)

- [ ] `wdisplays` arranges; niri `output {}` blocks persist; kanshi dock/undock.

## E. Updates + trust

- [ ] No OS auto-update timer active; `bootc upgrade` → `rollback` work.
- [ ] Signing: once `SIGNING_SECRET` is set (0001), `bootc upgrade` verifies the signature.

## Findings log

| Date | Check | Result | Follow-up |
|---|---|---|---|
| | | | |

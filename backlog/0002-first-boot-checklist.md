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
- [ ] Kitty + Nerd Font glyphs render; DMS theming writes `~/.config/kitty/dank-theme.conf`.

## B. Apps ported from Steen/Tashikk (re-verify on this base)

- [ ] 1Password unlocks, browser integration, `op`, 1PUX export dialog (gid≥1000 + ptrace).
- [ ] Chromium plays H.264; `tailscale up`; keyd tap-hold; CLI toolkit +
      `distrobox create`; Flathub present.

## C. Silverblue plumbing (should be untouched)

- [ ] Audio, WiFi/DNS, Bluetooth, printing (GNOME panel), fingerprint, fwupd.
- [ ] Bluetooth audio negotiates **aptX** where the headset supports it (`pipewire-codec-aptx`
      is in the image; the codec still has to be picked at connect time).
- [ ] HEIC/HEIF and video files show **thumbnails in Nautilus**, not blank tiles
      (`libheif-freeworld` + `heif-pixbuf-loader` + `ffmpegthumbnailer`). Flatpak viewers
      bundle their own decoders, so "it opens fine" does not prove this works.
- [ ] **VAAPI hardware decode** is actually live: `vainfo` lists `VAProfileH264*` and
      `VAProfileHEVC*` entrypoints. Fedora's stock `mesa-va-drivers` has these stripped; the
      image swaps in `mesa-va-drivers-freeworld`, and the build guard fails if that reverts.
- [ ] **TRIM reaches the SSD through LUKS** — encrypted installs only, and easy to miss:
      dm-crypt blocks discards by default, so TRIM silently never reaches the drive no matter
      what the filesystem does. `lsblk --discard` should show non-zero `DISC-GRAN`/`DISC-MAX`
      on the **LUKS mapper**, not just on the physical disk. If they're zeroed:
      ```sh
      sudo cryptsetup --allow-discards --persistent refresh /dev/mapper/luks-<UUID>
      lsblk --discard && sudo fstrim -v /sysroot
      ```
      `--persistent` survives reboots, so no kernel argument is needed. This is
      per-installation disk state, not image content — it cannot be baked into the
      Containerfile, which is exactly why it lives on this checklist.

## D. Displays (niri session)

- [ ] DMS manages displays: its settings panel arranges outputs; `dms ipc outputs
      cycleProfile` (Mod+P) switches profiles. (No kanshi/wdisplays — DMS owns this.)

## E. Updates + trust

- [ ] No OS auto-update timer active; `bootc upgrade` → `rollback` work.
- [ ] Signing: once `SIGNING_SECRET` is set (0001), `bootc upgrade` verifies the signature.

## Findings log

| Date | Check | Result | Follow-up |
|---|---|---|---|
| | | | |

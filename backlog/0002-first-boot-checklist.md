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

### The Flatpak app set (first real run of the fedora→Flathub move)

`chezmoi apply` moves Silverblue's 18 preinstalled apps off the base's own `fedora`
remote onto Flathub, then retires that remote. **Watch this step rather than walking
away**: each app is uninstalled before its Flathub copy is pulled, so a network drop
in between leaves it uninstalled. It says so loudly (`ERROR: … it is gone, reinstall
by hand`) and one `flatpak install` recovers it, but nothing retries automatically.

- [ ] The move ran and completed: `==> Moving declared apps off the "fedora" remote`,
      with no `ERROR: … it is gone` lines.
- [ ] The remote retired itself — `flatpak remotes` lists **only** `flathub`. If
      `fedora` is still there the script kept it deliberately and named what is still
      installed from it; those apps need declaring in `APPS` (or removing), then re-run.
- [ ] All declared apps present: `flatpak list --system --app | wc -l` matches the
      `APPS` count the script reports (`==> Installing/updating N Flatpak apps`).
- [ ] No drift between what's installed and what's declared — this should print nothing
      (fish; `psub` is fish's process substitution):
      ```fish
      comm -23 (flatpak list --system --app --columns=application | sort | psub) \
               (sed -n '/^APPS=(/,/^)/p' ~/.local/share/chezmoi/.chezmoiscripts/run_onchange_install-flatpaks.sh \
                  | grep -vE '^\s*#' | grep -E '^  \S' | tr -d ' ' | sort | psub)
      ```
- [ ] **Unverified, worth watching here:** whether Silverblue's preinstall mechanism can
      re-run after the remote is gone and re-add apps from it. Re-check `flatpak remotes`
      after a few reboots and a GNOME Software launch. If `fedora` comes back on its own,
      that is new information and the move needs a guard against it.

## C. Silverblue plumbing (should be untouched)

- [ ] Audio, WiFi/DNS, Bluetooth, printing (GNOME panel), fingerprint, fwupd.
- [ ] Bluetooth audio negotiates **aptX** where the headset supports it (`pipewire-codec-aptx`
      is in the image; the codec still has to be picked at connect time).
- [ ] HEIC/HEIF and video files show **thumbnails in Nautilus**, not blank tiles
      (`libheif-freeworld` + `heif-pixbuf-loader` + `ffmpegthumbnailer`). Flatpak viewers
      bundle their own decoders, so "it opens fine" does not prove this works.
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

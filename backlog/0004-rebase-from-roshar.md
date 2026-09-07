# Rebase Azir onto Roshar

- **Status:** done
- **Created:** 2026-09-07
- **Area:** image (`Containerfile` `FROM` + overall shape)
- **Related:** [Roshar](https://github.com/reinier/roshar) `0000`, `0004`, `0005` (the base
  image this now builds on); this repo's `0000` (superseded decision), `0001` (signing,
  amended).

## What changed

`azir/Containerfile`'s `FROM quay.io/fedora-ostree-desktops/silverblue:44` became
`FROM ghcr.io/reinier/roshar:latest`. This was the anticipated end-state noted in
`backlog/README.md` back when Roshar was first split out (2026-09-02) — deliberately deferred
until Roshar shipped and proved itself standalone. It has: the first-boot config-seed race
(bare niri, no DMS, permanently, on a truly fresh account) was root-caused and fixed in
Roshar's own `0004`/`0005`, confirmed with a clean boot on real hardware.

Roshar's niri/DMS/quickshell install, its provenance + additive/session guards, its CLI
toolkit subset, Flathub remote, distrobox, and signing/trust setup were all byte-identical or
functionally identical to what Azir was independently duplicating (both build from the same
Silverblue 44 pin with the same avengemedia COPR repo files). All of that is now deleted from
Azir's own Containerfile and inherited instead.

## Package-list arithmetic

**CLI toolkit** — Azir's old 15-package list (`fish eza bat jq zip fuse-sshfs fzf
xdg-terminal-exec ripgrep chezmoi git-core wl-clipboard ddcutil fastfetch btop`) minus
Roshar's 9-package CLI line + its bundled `ddcutil` (10 overlap) leaves 5:
`fish jq zip fuse-sshfs xdg-terminal-exec`.

**Lean-out strip** — Azir's old 18-package list (its own guard message said 17, an existing
off-by-one, fixed while touching this) minus Roshar's 13 already-stripped leaves leaves 5:
`firefox firefox-langpacks ptyxis toolbox rpmfusion-free-release`.

Both remainders match exactly what Roshar's own Containerfile comments already predicted
("fish, xdg-terminal-exec, jq, zip, fuse-sshfs stay Azir-only"; "Azir also removes
firefox/ptyxis/toolbox, but only because it replaces them with Chromium/ghostty/distrobox") —
a good cross-check that the split boundary was already correctly anticipated on the Roshar
side before this rebase happened.

Guards were trimmed to match what's installed *here*, but kept checking everything that
should still be present — inherited packages are re-verified as defense-in-depth (e.g. against
Roshar's own build regressing upstream), not dropped from the `rpm -q` lists just because this
Containerfile no longer installs them directly.

## Signing/trust: inherited, not re-baked

Roshar's own build already bakes `cosign.pub`, a `sigstoreSigned`/`matchRepository`
`policy.json` entry, and a registries.d file — all scoped to the `ghcr.io/reinier`
**namespace**, not just `.../roshar`. Confirmed `cosign.pub` byte-identical between the two
repos via `diff`. So `ghcr.io/reinier/azir` was already covered by inheritance; Azir's own
`cosign.pub`, `patch-policy.py`, and `files/azir-registries.yaml` were deleted as redundant.
See `0001` for the amended write-up. CI's own push-side signing (`SIGNING_SECRET` on
`reinier/azir`, same shared key) is unaffected.

## Two UX inheritances, deliberately kept

Both come for free (no Containerfile change needed either way) and were confirmed with the
user before implementing:

- **Roshar's config-seed fallback** (a systemd unit that seeds a working niri+DMS config if
  none exists before niri's first start) — kept. It's a strict improvement: Azir previously had
  zero protection if a fresh account logged into Niri before `dotfiles-azir`'s chezmoi
  bootstrap ran, which could hit the exact stock-config lockout bug Roshar's own `0004` fixed.
  chezmoi's own `config.kdl` always overwrites the seeded one once applied — no lasting effect
  on an already-bootstrapped machine.
- **Roshar's Bazaar auto-install-at-login** — kept, despite Azir's original backlog explicitly
  listing Bazaar under "deliberately not here (GNOME Software)". Harmless and free alongside
  Azir's existing Chromium + dotfiles-managed Flatpak strategy; not worth the extra
  Containerfile removal step just for consistency with a decision made before this option
  existed.

## CI

`.github/workflows/build.yaml`: the pre-pull step now pulls `ghcr.io/reinier/roshar:latest`
instead of the Silverblue base directly. Confirmed anonymously pullable (public GHCR package,
matching Roshar's own "meant to be rebased onto by anyone" framing) — no auth changes needed.

Also fixed a real scheduling gap surfaced while touching this: Roshar's own daily rebuild runs
at 05:00 UTC, but Azir's ran at 04:00 UTC — *before* it, meaning Azir would always rebuild
against yesterday's Roshar image. Moved Azir's schedule to 06:00 UTC.

## Verification

CI green (inheritance guard, trimmed package counts, extended lean-out guard message, `bootc
container lint`). Real hardware: plain `bootc upgrade` on an existing Azir machine (the tracked
`ghcr.io/reinier/azir:latest` ref doesn't change) — no new trust-on-first-use event expected,
GDM still offers GNOME + Niri, GNOME unaffected, niri session brings up DMS + Azir's personal
layer (dank-lader, keyd, 1Password, Chromium) exactly as before. 1Password's fixed sysusers
GIDs (1500/1501/1502) have no collision risk — Roshar creates no build-time system
users/groups of its own. See `0002` for the standing first-boot checklist this re-runs.

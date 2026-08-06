# Base + architecture: niri + DMS additive on Silverblue

- **Status:** accepted
- **Created:** 2026-08-06
- **Area:** image (`Containerfile` `FROM` + overall shape)
- **Related:** [Tashikk](https://github.com/reinier/tashikk) (Noctalia on the same base);
  [Steen](https://github.com/reinier/steen) (DMS, niri-only, Sway Atomic base).

## Decision

Azir builds **`FROM quay.io/fedora-ostree-desktops/silverblue:44`**, **additive**: keep GNOME
+ GDM, add **niri + DankMaterialShell** as an alternative session. It is Tashikk's image with
the shell swapped from Noctalia to DMS.

## The three things that differ from Tashikk

1. **DMS from the avengemedia STABLE COPR**, not Fedora. Fedora only has the too-old DMS
   1.4.4 / quickshell 0.2.1; DMS 1.5.x needs quickshell 0.3.x. So Azir ports Steen's COPR
   stanza + the **quickshell provenance guard** (asserts quickshell came from `avengemedia`,
   not Fedora's older build — the mismatch that once crashed the shell).
2. **DMS is NOT `--global` enabled.** On Steen (niri-only) `dms.service` is global-enabled and
   the greetd→niri flow starts it. Here GNOME coexists, and a global-enabled `dms.service`
   (WantedBy=graphical-session.target) would start DMS in the GNOME session too. So DMS is
   **spawned from the niri config** in the dotfiles (like Tashikk spawns Noctalia), keeping it
   niri-session-only. This is the one genuinely new design point.
3. **No wlr-which-key.** DMS provides dank-lader as its leader menu, so Azir drops Tashikk's
   wlr-which-key builder stage entirely.

## Config

`dms setup` is policy-blocked on atomic (unchanged from Steen), so the niri/DMS config stays
**vendored in the dotfiles** — which `dotfiles-steen` already does, so `dotfiles-azir` derives
from it almost verbatim (drop the greetd assumptions, add the DMS spawn).

## Coexistence caveats (same as Tashikk)

Portal backend routing under niri, theming split-brain (DMS/matugen vs GNOME color-scheme),
and carrying GNOME's weight/churn. Accepted for the fallback-desktop + GNOME-Settings benefit.

## Verification

Builds green + `bootc container lint`. Rebase from Silverblue; GDM offers GNOME and Niri; the
niri session brings up DMS (spawned, not global); GNOME session unaffected. See 0002.

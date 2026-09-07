# backlog

Build plan for **Azir** — niri + DMS on Silverblue, additive (GNOME kept). Azir recombines
two things already built: **[Tashikk](https://github.com/reinier/tashikk)**'s additive
Silverblue image skeleton and **[Steen](https://github.com/reinier/steen)**'s DMS-from-COPR
stanza. Most items are "ported from X"; this backlog is short.

## The shape (vs Tashikk / Steen)

- **Base:** `FROM ghcr.io/reinier/roshar:latest` (itself Silverblue, additive — keep GNOME +
  GDM, add niri/DMS as a session). See `0004`.
- **Shell:** DMS from the **avengemedia stable COPR** (Fedora's 1.4.4/0.2.1 is too old),
  with a quickshell **provenance guard** — same as Steen. NOT a clean Fedora install like
  Tashikk's Noctalia.
- **DMS launch:** **not** `--global` enabled (would leak into the GNOME session). The dotfiles
  spawn DMS from niri, so it's niri-session-only. This is the one genuinely new bit.
- **No wlr-which-key:** DMS ships dank-lader as its leader menu.

## Items

0. [0000-base-and-architecture.md](0000-base-and-architecture.md) — decision record.
1. [0001-signing.md](0001-signing.md) — **done.** Signed update stream (shared
   key); `SIGNING_SECRET` confirmed set, CI signing since 2026-08-06.
2. [0002-first-boot-checklist.md](0002-first-boot-checklist.md) — living hardware/boot
   verification.
3. [0003-3fg-drag-shim.md](0003-3fg-drag-shim.md) — open, blocked on
   `dotfiles-azir` `0007`. Bake
   [enable-3fg-drag](https://github.com/joaodriessen/enable-3fg-drag)'s
   `LD_PRELOAD` libinput shim into the image (new build stage, mirrors `keyd`)
   so `dotfiles-azir` `0008` has something to point `/etc/ld.so.preload` at.
4. [0004-rebase-from-roshar.md](0004-rebase-from-roshar.md) — **done.** Azir now builds
   `FROM ghcr.io/reinier/roshar:latest` instead of stock Silverblue directly.

## Ported wholesale (see Steen / Tashikk for reasoning) — Azir-only remainder

1Password (+CLI, /opt relocation, sysusers GIDs, ptrace), Chromium+codecs,
keyd (source build), Tailscale, Nerd Font, and the fish/jq/zip/fuse-sshfs/xdg-terminal-exec/
starship/yazi/ghostty CLI remainder. (Displays are DMS's job — no kanshi/wdisplays, unlike
Tashikk's Noctalia.) Flathub remote, distrobox, the rest of the CLI toolkit (ripgrep/fzf/bat/
eza/fastfetch/btop/git-core/wl-clipboard/ddcutil/chezmoi), and the signing/trust setup are no
longer ported here — they're inherited from the `roshar` base (see `0004`).

## Deliberately NOT here (Silverblue provides it, DMS does, or it's inherited)

greetd + dms-greeter (keep GDM), the printer GUI (GNOME panel), the Sway-subtraction layer
(nothing to subtract), and wlr-which-key (DMS has dank-lader). Bazaar *is* present — inherited
from Roshar's base (see `0004`) and kept deliberately despite Azir's original GNOME-Software-
only stance, since it's free and harmless alongside it.

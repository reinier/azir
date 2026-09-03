# backlog

Build plan for **Azir** — niri + DMS on Silverblue, additive (GNOME kept). Azir recombines
two things already built: **[Tashikk](https://github.com/reinier/tashikk)**'s additive
Silverblue image skeleton and **[Steen](https://github.com/reinier/steen)**'s DMS-from-COPR
stanza. Most items are "ported from X"; this backlog is short.

## The shape (vs Tashikk / Steen)

- **Base:** Silverblue, additive — keep GNOME + GDM, add niri/DMS as a session. No
  subtraction layer.
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

## Deferred: rebuild `FROM roshar`

[Roshar](https://github.com/reinier/roshar) (2026-09-02) is a new, separate repo: the bare
niri+DMS core of this Containerfile (lines 26-81) plus a small broadly-useful app tier,
split out so a working niri+DMS desktop doesn't require Azir's full personal layer. The
eventual goal is Azir itself starting `FROM ghcr.io/reinier/roshar:latest` instead of stock
Silverblue directly, and dropping everything Roshar now covers — deliberately **not** done
yet. Roshar ships and proves itself standalone first; this becomes a numbered item once
that's picked up.

## Ported wholesale (see Steen / Tashikk for reasoning)

1Password (+CLI, /opt relocation, sysusers GIDs, ptrace), Chromium+codecs,
keyd (source build), Tailscale, CLI toolkit (Fedora + Terra), Nerd Font, distrobox, Flathub
remote, and the manual-update timer masking. (Displays are DMS's job — no kanshi/wdisplays,
unlike Tashikk's Noctalia.)

## Deliberately NOT here (Silverblue provides it, or DMS does)

greetd + dms-greeter (keep GDM), the printer GUI (GNOME panel), Bazaar (GNOME Software), the
Sway-subtraction layer (nothing to subtract), and wlr-which-key (DMS has dank-lader).

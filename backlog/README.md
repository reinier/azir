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
1. [0001-signing.md](0001-signing.md) — signed update stream (shared key; needs
   `SIGNING_SECRET` on the azir repo).
2. [0002-first-boot-checklist.md](0002-first-boot-checklist.md) — living hardware/boot
   verification.

## Ported wholesale (see Steen / Tashikk for reasoning)

1Password (+CLI, /opt relocation, sysusers GIDs, ptrace), Synology Drive, Chromium+codecs,
keyd (source build), Tailscale, CLI toolkit (Fedora + Terra), Nerd Font, distrobox, Flathub
remote, and the manual-update timer masking. (Displays are DMS's job — no kanshi/wdisplays,
unlike Tashikk's Noctalia.)

## Deliberately NOT here (Silverblue provides it, or DMS does)

greetd + dms-greeter (keep GDM), the printer GUI (GNOME panel), Bazaar (GNOME Software), the
Sway-subtraction layer (nothing to subtract), and wlr-which-key (DMS has dank-lader).

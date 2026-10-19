# Azir — Fedora Silverblue + niri + DankMaterialShell (DMS), GNOME kept.
#
# Azir is the personal layer on top of Roshar (github.com/reinier/roshar): the bare,
# reusable niri+DMS-on-Silverblue core — repo install, quickshell provenance guard, additive
# session, CLI toolkit subset, Flathub remote, distrobox, signing/trust — all lives there now.
# This Containerfile only adds what's Azir-specific on top: 1Password, Chromium+codecs, keyd,
# Tailscale, kitty/starship/yazi, and the personal CLI remainder Roshar doesn't cover.
#
# DMS is NOT `--global` enabled (inherited decision, unchanged) — the dotfiles spawn it from
# niri, so it only runs in the niri session, never leaking into GNOME.
# The leader menu is wlr-which-key (built from source below), not DMS's dank-lader plugin.

# --- keyd: built from source, pinned to an exact upstream commit ---
# Commit, not just tag (backlog 0006): keyd runs as root and sees every keystroke, and upstream
# is effectively one maintainer. A tag can be re-pointed upstream; the commit check below fails
# the build if v2.6.0 ever stops meaning the code that was reviewed. Same pin as config-nixos's
# keyd.nix. To bump: read github.com/rvaiya/keyd/compare/<old>...<new>, then update both ARGs.
FROM registry.fedoraproject.org/fedora:44 AS keyd-build
ARG KEYD_VERSION=v2.6.0
ARG KEYD_COMMIT=7c0aecb8bfd34dc8642bf4eefd2e59c89e61cec3
RUN dnf5 -y install git make gcc kernel-headers \
 && git clone --depth 1 --branch "$KEYD_VERSION" https://github.com/rvaiya/keyd /src \
 && actual="$(git -C /src rev-parse HEAD)" \
 && { [ "$actual" = "$KEYD_COMMIT" ] \
      || { echo "ERROR: keyd $KEYD_VERSION is $actual, expected pinned $KEYD_COMMIT" >&2; exit 1; }; } \
 && make -C /src PREFIX=/usr \
 && make -C /src PREFIX=/usr DESTDIR=/out FORCE_SYSTEMD=1 install

# --- wlr-which-key: built from source, pinned to an exact upstream commit ---
# The leader menu (dotfiles-azir: rl-which-key on Mod+F12, i.e. a Super tap via keyd). Fedora
# doesn't package it. Pinned like keyd, and to the same version as config-nixos's
# wlr-which-key.nix, so the menu only changes when bumped on purpose: 1.2.0 already changed the
# config format once. `--locked` builds against upstream's own Cargo.lock. Its runtime libraries
# (cairo, pango, glib2, libxkbcommon) are all in the Silverblue base. To bump: read the
# upstream changelog, check dotfiles-azir's config.yaml against the new README, then update
# both ARGs.
FROM registry.fedoraproject.org/fedora:44 AS wlr-which-key-build
ARG WLR_WHICH_KEY_VERSION=v1.3.0
ARG WLR_WHICH_KEY_COMMIT=6d66599f0a7ff5f71b81fd402de1c3e6f390ac13
RUN dnf5 -y install git cargo rust pkgconf-pkg-config cairo-devel cairo-gobject-devel pango-devel \
      glib2-devel libxkbcommon-devel \
 && git clone --depth 1 --branch "$WLR_WHICH_KEY_VERSION" https://github.com/MaxVerevkin/wlr-which-key /src \
 && actual="$(git -C /src rev-parse HEAD)" \
 && { [ "$actual" = "$WLR_WHICH_KEY_COMMIT" ] \
      || { echo "ERROR: wlr-which-key $WLR_WHICH_KEY_VERSION is $actual, expected pinned $WLR_WHICH_KEY_COMMIT" >&2; exit 1; }; } \
 && cargo build --release --locked --manifest-path /src/Cargo.toml \
 && install -D -m 755 /src/target/release/wlr-which-key /out/usr/bin/wlr-which-key

# Roshar — niri + DMS + quickshell + CLI toolkit subset + Flathub + distrobox + signing/trust,
# all already baked and guarded there. GNOME + GDM stay (inherited, additive).
FROM ghcr.io/reinier/roshar:latest

# Guard: confirm the inherited niri/DMS/quickshell core actually arrived intact before this
# layer starts diverging from it (removing ptyxis, etc., below). Re-checks provenance rather
# than trusting Roshar's own build-time guard blindly — that guard ran in a different build,
# this one runs against what actually got pulled as FROM.
RUN set -e; \
    rpm -q niri xwayland-satellite ddcutil dms dms-cli quickshell matugen ptyxis >/dev/null; \
    ! rpm -q DankMaterialShell >/dev/null 2>&1 \
      || { echo "ERROR: Fedora's DankMaterialShell is installed alongside COPR dms" >&2; exit 1; }; \
    qs_repo="$(dnf5 repoquery --installed --qf '%{from_repo}' quickshell | head -1)"; \
    case "$qs_repo" in \
      *avengemedia*) ;; \
      *) echo "ERROR: quickshell came from '${qs_repo}', not the avengemedia COPR." >&2; exit 1;; \
    esac; \
    test -f /usr/share/wayland-sessions/niri.desktop \
      || { echo "ERROR: niri GDM session file missing" >&2; exit 1; }; \
    rpm -q gnome-shell gdm xdg-desktop-portal-gnome gnome-keyring \
           pipewire wireplumber NetworkManager >/dev/null \
      || { echo "ERROR: GNOME/plumbing missing from the roshar base" >&2; exit 1; }; \
    echo "inherited from roshar: niri $(rpm -q --qf '%{VERSION}' niri), dms $(rpm -q --qf '%{VERSION}' dms), quickshell $(rpm -q --qf '%{VERSION}' quickshell) [${qs_repo}]"

# --- JetBrainsMono Nerd Font ---
ARG NERD_FONT_VERSION=v3.4.0
RUN curl -fsSL -o /tmp/JetBrainsMono.tar.xz \
      "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/JetBrainsMono.tar.xz" \
 && mkdir -p /usr/share/fonts/jetbrainsmono-nerd \
 && tar -xJf /tmp/JetBrainsMono.tar.xz -C /usr/share/fonts/jetbrainsmono-nerd \
 && rm -f /tmp/JetBrainsMono.tar.xz \
 && fc-cache -f /usr/share/fonts/jetbrainsmono-nerd

# --- Native Chromium + codecs ---
# Everything needing RPM Fusion has to live in THIS RUN: the repo file is deleted at the end,
# so a package added anywhere later silently fails to resolve.
#   ffmpeg (RPM Fusion, swapped in for Fedora's ffmpeg-free) — H.264/HEVC etc. for Chromium,
#     gstreamer, thumbnailers, Qt multimedia. See below for why the full swap.
#   libheif-freeworld         — HEIC/HEIF decode (phone photos).
#   heif-pixbuf-loader, ffmpegthumbnailer — thumbnails for those and for video, in Nautilus,
#     which is host-native from the Silverblue base. Flatpak viewers bundle their own
#     decoders, so files always *open*; without these the file manager just shows blank tiles.
#     heif-pixbuf-loader is a Provides of gdk-pixbuf2 on F44, not a package of its own, so
#     this install is a no-op today — kept so the requirement is stated, and so it still
#     resolves if Fedora ever splits the loader back out. The guard below has to ask
#     --whatprovides for the same reason: plain `rpm -q` matches names, never provides.
#   pipewire-codec-aptx       — aptX for Bluetooth audio.
#
# Why swap to RPM Fusion's full ffmpeg instead of layering libavcodec-freeworld on Fedora's
# -free libs: freeworld is ONE lib from RPM Fusion shadowing ONE of Fedora's (same soname,
# /usr/lib64/ffmpeg searched first), so the two repos' release timing has to line up. On
# 2026-09-28 it didn't — RPM Fusion shipped freeworld 8.1.3 before Fedora's 8.1.3 was stable,
# dnf fell back to freeworld 8.0.1-6 and downgraded the -free libs from updates-archive, and
# an older libavcodec under a newer libavformat broke every ffmpeg consumer (undefined
# LIBAVCODEC_62 symbols). The full swap replaces ALL the -free libs (ffmpeg-libs Conflicts
# with each) with one set built together, so there is no cross-repo version pairing left.
# Every consumer requires the sonames (libavcodec.so.62 …), not the -free package names.
#
# If the swap can't resolve, fall back to Fedora's own -free stack (consistent, just no
# patented codecs) with a CI warning, rather than failing: a codec hiccup must not block the
# rest of the image's updates. The smoke test at the end does fail the build — it only trips
# on a stack that is actually broken, which must never ship.
RUN set -e; \
    dnf5 -y install "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm"; \
    if dnf5 -y swap --best --allowerasing ffmpeg-free ffmpeg; then \
      codecs=full; \
    else \
      codecs=free; \
      echo "::warning title=azir codecs::RPM Fusion ffmpeg swap failed — image ships Fedora's ffmpeg-free (no H.264/HEVC). Retries on the next build."; \
    fi; \
    dnf5 -y install --best chromium libheif-freeworld \
      heif-pixbuf-loader ffmpegthumbnailer pipewire-codec-aptx; \
    rm -f /etc/yum.repos.d/rpmfusion-*.repo; \
    dnf5 clean all; \
    if [ "$codecs" = full ]; then \
      ffmpeg -hide_banner -v error -f lavfi -i testsrc=d=1 -c:v libx264 -y /tmp/smoke.mkv; \
      ffmpeg -hide_banner -v error -i /tmp/smoke.mkv -f null -; \
      rm -f /tmp/smoke.mkv; \
    else \
      ffmpeg -hide_banner -v error -f lavfi -i testsrc=d=1 -f null -; \
    fi; \
    echo "ffmpeg stack OK ($codecs): $(rpm -q --whatprovides 'libavcodec.so.62()(64bit)')"

# Pin Chromium's Wayland app_id. Chromium takes it from $CHROME_DESKTOP when set, and every
# Electron app sets that variable for itself (from its desktopName) and passes it on to what it
# spawns. So a Chromium first started by clicking a link in a native Electron app — VS Code
# (code.desktop) or 1Password — would come up with that app's app_id, and the leader menu's
# `rl-run-or-cycle chromium-browser` would no longer find it (config-nixos hit this with Slack).
# Flatpak apps don't leak it: their links go through the portal. Fedora's launcher sources
# /etc/chromium/chromium.conf as bash right before exec'ing Chromium, so one export there
# covers every launch path; no wrapper needed. Webapp windows (--app=) are unaffected: their
# app_id is derived from the app URL.
RUN printf '\n# Azir: pin the Wayland app_id; Electron apps leak their own CHROME_DESKTOP (see the\n# Azir Containerfile).\nexport CHROME_DESKTOP=chromium-browser.desktop\n' \
      >> /etc/chromium/chromium.conf \
 && grep -qx 'export CHROME_DESKTOP=chromium-browser.desktop' /etc/chromium/chromium.conf

# --- 1Password: desktop app + CLI ---
# Silverblue is ostree, so /opt is a symlink to /var/opt: relocate the payload into
# /usr/lib/opt, restore the symlink, tmpfiles recreates /opt/1Password at boot. setuid/setgid
# baked here; groups via sysusers.d at FIXED GIDs >=1000.
COPY files/1password.repo /etc/yum.repos.d/1password.repo
COPY files/1password-sysusers.conf /usr/lib/sysusers.d/1password-azir.conf
RUN rpm --import https://downloads.1password.com/linux/keys/1password.asc \
 && systemd-sysusers /usr/lib/sysusers.d/1password-azir.conf \
 && opt_link="$(readlink /opt)" \
 && rm /opt && mkdir /opt \
 && mkdir -p "$(realpath -m /usr/local)" \
 && dnf5 -y install 1password 1password-cli \
 && rm -f /etc/yum.repos.d/1password.repo \
 && mkdir -p /usr/lib/opt \
 && mv /opt/1Password /usr/lib/opt/1Password \
 && rmdir /opt \
 && ln -s "$opt_link" /opt \
 && chmod 4755 /usr/lib/opt/1Password/chrome-sandbox \
 && chgrp onepassword /usr/lib/opt/1Password/1Password-BrowserSupport \
 && chmod 2755 /usr/lib/opt/1Password/1Password-BrowserSupport \
 && chgrp onepassword-cli /usr/bin/op \
 && chmod 2755 /usr/bin/op \
 && dnf5 clean all
COPY files/1password-opt.conf /usr/lib/tmpfiles.d/1password-opt.conf
COPY files/60-1password-ptrace.conf /usr/lib/sysctl.d/60-1password-ptrace.conf

# --- VS Code (Microsoft's build) ---
# Replaced the VSCodium Flatpak (2026-10), matching config-nixos. Native rather than Flatpak:
# from inside the Flatpak sandbox the host's podman/docker and distrobox aren't on PATH,
# which breaks Dev Containers (dotfiles-azir installs that extension, plus nix-ide).
# Installs to /usr/share/code, so unlike 1Password no /opt relocation is needed; its
# chrome-sandbox ships setuid root, checked in the guard below. Its postinstall no longer
# writes a repo file of its own (checked on 1.142), and the one copied here is removed again,
# so updates arrive with image rebuilds, like everything else.
COPY files/vscode.repo /etc/yum.repos.d/vscode.repo
RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc \
 && dnf5 -y install code \
 && rm -f /etc/yum.repos.d/vscode.repo \
 && dnf5 clean all

# --- Microsoft Edge ---
# A second browser next to Chromium, matching config-nixos (2026-10). Same /opt dance as
# 1Password: the payload lands in /opt/microsoft/msedge, gets relocated into /usr/lib/opt,
# and tmpfiles recreates /opt/microsoft at boot. msedge-sandbox ships setuid root (re-set
# after the move, checked in the guard). Its postinstall's device-trust setup (msedgemgmt
# group, a signing key under /etc/opt) only runs when an enterprise defaults file asks for it,
# so on a plain install it does nothing (checked on 155.0). The postinstall DOES re-add
# /etc/yum.repos.d/microsoft-edge.repo and install /etc/cron.daily/microsoft-edge, which would
# re-add it daily; both are removed so updates come only with image rebuilds.
COPY files/microsoft-edge.repo /etc/yum.repos.d/microsoft-edge.repo
RUN rpm --import https://packages.microsoft.com/keys/microsoft.asc \
 && opt_link="$(readlink /opt)" \
 && rm /opt && mkdir /opt \
 && dnf5 -y install microsoft-edge-stable \
 && rm -f /etc/yum.repos.d/microsoft-edge.repo /etc/cron.daily/microsoft-edge \
 && mkdir -p /usr/lib/opt \
 && mv /opt/microsoft /usr/lib/opt/microsoft \
 && rmdir /opt \
 && ln -s "$opt_link" /opt \
 && chmod 4755 /usr/lib/opt/microsoft/msedge/msedge-sandbox \
 && dnf5 clean all
COPY files/microsoft-edge-opt.conf /usr/lib/tmpfiles.d/microsoft-edge-opt.conf

# --- CLI toolkit (Azir-only remainder) ---
# Roshar's own base already covers ripgrep/fzf/bat/eza/fastfetch/btop/git-core/wl-clipboard/
# chezmoi (its CLI toolkit) and ddcutil (bundled into its niri/dms install line). What's left
# is tied to Azir's own shell/editor/terminal choices, not broadly useful enough for Roshar:
# fish (the shell), xdg-terminal-exec (default-terminal resolution), jq/zip/fuse-sshfs (used
# by dotfiles-azir scripts + Mount Rainier's SSHFS mounts). wl-kbptr: keyboard-driven pointer
# control (github.com/moverest/wl-kbptr) — official Fedora package, no COPR needed. Confirmed
# niri implements all three protocols it needs (wlr-layer-shell, wlr-virtual-pointer,
# wlr-screencopy — checked niri's own src/protocols/ directly, not just wl-kbptr's own
# compatibility claim). Bound to Mod+Ctrl+F12 in dotfiles-azir's local/binds.kdl. wtype:
# Wayland key-injection tool, needed by voxtype's (dictation, dotfiles-fetched AppImage —
# see dotfiles-azir) "type" output mode; niche enough to voxtype specifically that it stays
# here rather than in Roshar's own generic wl-clipboard-tier utilities. kitty: the
# terminal (replaced ghostty, 2026-09-23) — Fedora packages it, so unlike ghostty it needs no
# Terra and sits on this line instead of the one below. tmux: terminal multiplexer, mainly for
# persistent sessions over SSH into Azir — host-native rather than in the apps distrobox so it
# survives independently of any container; runs on tmux's own defaults (no dotfiles config).
# gum: the picker/confirm/pager UI for dotfiles-azir's rl-menu ("Azir Menu" — image update,
# rollback, changelog, Flatpak/distrobox/dotfiles/firmware updates). Host-native, not in the
# apps distrobox: the menu's whole job is updating the host and that distrobox, so it can't
# depend on either being healthy. Fedora packages it, no COPR needed.
RUN dnf5 -y install fish jq zip fuse-sshfs xdg-terminal-exec wl-kbptr wtype kitty tmux gum \
 && dnf5 clean all

# --- Containers: rootless Podman with a `docker` stand-in ---
# Same setup as config-nixos's containers.nix: rootless Podman only, no Docker daemon. podman
# itself comes from the Silverblue base (distrobox needs it).
#   podman-docker  — `docker` on PATH is podman, so `docker run/build/exec` and READMEs written
#     for Docker just work. /etc/containers/nodocker silences the "Emulate Docker CLI" notice
#     its wrapper otherwise prints on every call; files/50-azir-compose.conf does the same for
#     podman's "Executing external compose provider" banner on every compose call.
#   docker-compose — the compose provider, for both `docker compose` and `podman compose`
#     (podman prefers it over podman-compose, which this replaces, like config-nixos). It
#     talks to the rootless Podman socket through DOCKER_HOST, which dotfiles-azir sets and
#     whose socket unit it enables, along with podman-restart.service and linger, so
#     `restart: always` containers come back after a reboot.
# Not a rootful socket: podman-docker's own system tmpfiles link /run/docker.sock →
# /run/podman/podman.sock stays dangling, since the system podman.socket is never enabled.
# A rootful socket would be a separate image store from the `docker` commands run as the user.
RUN dnf5 -y install podman-docker docker-compose \
 && mkdir -p /etc/containers \
 && touch /etc/containers/nodocker \
 && dnf5 clean all
COPY files/50-azir-compose.conf /etc/containers/containers.conf.d/50-azir-compose.conf

COPY files/terra.repo /etc/yum.repos.d/terra.repo
# starship/yazi: neither is packaged by Fedora, and neither is in Roshar.
RUN dnf5 -y install starship yazi \
 && rm -f /etc/yum.repos.d/terra.repo \
 && dnf5 clean all

# --- keyd artifacts ---
COPY --from=keyd-build /out/ /

# --- wlr-which-key artifact ---
COPY --from=wlr-which-key-build /out/ /

# --- Tailscale ---
RUN dnf5 -y install tailscale \
 && systemctl enable tailscaled.service \
 && dnf5 clean all

# --- Lean out: strip what Roshar's base doesn't already strip ---
# Roshar's own build already removes 13 leaves shared with Azir's old list (gnome-tour,
# gnome-user-docs, yelp, fedora-third-party, open-vm-tools-desktop, virtualbox-guest-additions,
# qemu-guest-agent, hyperv-daemons, b43-fwcutter, b43-openfwwf, iwlegacy-firmware, bluez-cups,
# gamemode) — checked against `dnf5 repoquery --installed --leaves` on real hardware
# originally, now just inherited. What's left is Azir-specific: Roshar keeps Firefox, Ptyxis,
# and toolbox because it doesn't replace them with anything; Azir does (Chromium, kitty,
# distrobox — installed above/below), so those come out here instead.
#   firefox, firefox-langpacks — native Chromium (+ H.264) is the only browser Azir wants
#     baked in; reinstall as a Flatpak if Firefox is ever needed again.
#   ptyxis — Kitty is the terminal now (see the CLI toolkit section above).
#   toolbox — redundant with distrobox (from Roshar's base), which Azir standardizes on.
#   rpmfusion-free-release — this image's own rpmfusion repo file is deleted right after use,
#     earlier in this file (Chromium/ffmpeg codecs); the release package itself is
#     inert rpmdb bookkeeping once that repo is gone. Roshar never installs this at all.
# Deliberately NOT stripped, despite being leaves too: VPN protocol plugins beyond Tailscale,
# realmd/sssd-kcm (domain join), mobile broadband, SMB/NFS + gvfs backends, printer-brand
# drivers, CJK ibus engines, brltty, hfsplus-tools, orca, and gnome-initial-setup — all either
# in active use or judged not worth the risk.
RUN dnf5 -y remove \
      firefox firefox-langpacks ptyxis toolbox rpmfusion-free-release \
 && dnf5 clean all

# Guard: confirm the stripped-here packages are gone, the 13 Roshar already stripped are still
# gone (defense-in-depth against Roshar's own build regressing upstream), and GNOME/GDM survived.
RUN set -e; \
    for pkg in firefox firefox-langpacks ptyxis toolbox rpmfusion-free-release; do \
      ! rpm -q "$pkg" >/dev/null 2>&1 || { echo "ERROR: $pkg still installed after strip" >&2; exit 1; }; \
    done; \
    for pkg in gnome-tour gnome-user-docs yelp fedora-third-party open-vm-tools-desktop \
               virtualbox-guest-additions qemu-guest-agent hyperv-daemons \
               b43-fwcutter b43-openfwwf iwlegacy-firmware bluez-cups gamemode; do \
      ! rpm -q "$pkg" >/dev/null 2>&1 || { echo "ERROR: $pkg unexpectedly present — was it re-added upstream in roshar?" >&2; exit 1; }; \
    done; \
    rpm -q gnome-shell gdm xdg-desktop-portal-gnome gnome-keyring \
           pipewire wireplumber NetworkManager >/dev/null \
      || { echo "ERROR: the strip disturbed GNOME/plumbing (should only remove the named leaves)" >&2; exit 1; }; \
    echo "lean-out OK: 5 stripped here + 13 inherited-absent verified, GNOME/GDM intact"

# Guard for the whole app layer. First rpm -q group is installed by this layer; second is
# inherited from ghcr.io/reinier/roshar, verified here as defense-in-depth.
RUN set -e; \
    rpm -q chromium 1password 1password-cli code microsoft-edge-stable \
           fish jq zip fuse-sshfs xdg-terminal-exec wl-kbptr wtype kitty tmux gum podman-docker docker-compose \
           starship yazi tailscale \
           libheif-freeworld ffmpegthumbnailer pipewire-codec-aptx >/dev/null; \
    rpm -q --whatprovides heif-pixbuf-loader >/dev/null 2>&1 \
      || { echo "ERROR: nothing provides heif-pixbuf-loader — HEIF thumbnails will be blank" >&2; exit 1; }; \
    rpm -q ripgrep fzf bat eza fastfetch btop git-core wl-clipboard ddcutil chezmoi distrobox >/dev/null; \
    ! command -v lazygit >/dev/null || { echo "ERROR: lazygit is in the image — it belongs in the apps distrobox (dotfiles)" >&2; exit 1; }; \
    test -L /opt || { echo "ERROR: /opt is no longer a symlink — ostree layout broken" >&2; exit 1; }; \
    test -d /usr/lib/opt/1Password || { echo "ERROR: 1Password payload not relocated into /usr" >&2; exit 1; }; \
    test -u /usr/lib/opt/1Password/chrome-sandbox || { echo "ERROR: chrome-sandbox lost its setuid bit" >&2; exit 1; }; \
    test -g /usr/lib/opt/1Password/1Password-BrowserSupport || { echo "ERROR: 1Password-BrowserSupport lost its setgid bit" >&2; exit 1; }; \
    test -g /usr/bin/op || { echo "ERROR: op lost its setgid bit" >&2; exit 1; }; \
    grep -qx 'export CHROME_DESKTOP=chromium-browser.desktop' /etc/chromium/chromium.conf || { echo "ERROR: Chromium's CHROME_DESKTOP pin is missing from chromium.conf" >&2; exit 1; }; \
    test -u /usr/share/code/chrome-sandbox || { echo "ERROR: VS Code's chrome-sandbox lost its setuid bit" >&2; exit 1; }; \
    ! ls /etc/yum.repos.d/ | grep -qiE "^(vscode|code)\.repo$" || { echo "ERROR: a VS Code repo file was left in the image" >&2; exit 1; }; \
    test -d /usr/lib/opt/microsoft/msedge || { echo "ERROR: Edge payload not relocated into /usr" >&2; exit 1; }; \
    test -u /usr/lib/opt/microsoft/msedge/msedge-sandbox || { echo "ERROR: msedge-sandbox lost its setuid bit" >&2; exit 1; }; \
    test -f /usr/lib/tmpfiles.d/microsoft-edge-opt.conf || { echo "ERROR: Edge /opt tmpfiles entry missing" >&2; exit 1; }; \
    ! test -e /etc/yum.repos.d/microsoft-edge.repo && ! test -e /etc/cron.daily/microsoft-edge \
      || { echo "ERROR: Edge's repo file or its cron job (which re-adds it) was left in the image" >&2; exit 1; }; \
    test -f /usr/lib/sysusers.d/1password-azir.conf || { echo "ERROR: 1password sysusers drop-in missing" >&2; exit 1; }; \
    getent group onepassword     | grep -q ':1500:' || { echo "ERROR: onepassword group not at fixed gid 1500 (must be >=1000)" >&2; exit 1; }; \
    getent group onepassword-cli | grep -q ':1501:' || { echo "ERROR: onepassword-cli group not at fixed gid 1501" >&2; exit 1; }; \
    [ "$(stat -c %g /usr/lib/opt/1Password/1Password-BrowserSupport)" = 1500 ] || { echo "ERROR: BrowserSupport setgid not onepassword(1500)" >&2; exit 1; }; \
    [ "$(stat -c %g /usr/bin/op)" = 1501 ] || { echo "ERROR: op setgid not onepassword-cli(1501)" >&2; exit 1; }; \
    test -f /usr/lib/sysctl.d/60-1password-ptrace.conf || { echo "ERROR: ptrace_scope drop-in missing" >&2; exit 1; }; \
    command -v keyd >/dev/null || { echo "ERROR: keyd binary missing" >&2; exit 1; }; \
    command -v wlr-which-key >/dev/null || { echo "ERROR: wlr-which-key binary missing" >&2; exit 1; }; \
    ! ldd /usr/bin/wlr-which-key | grep -q 'not found' \
      || { echo "ERROR: wlr-which-key has unresolved libraries" >&2; ldd /usr/bin/wlr-which-key >&2; exit 1; }; \
    [ "$(readlink -f "$(command -v docker)")" = /usr/bin/docker ] && grep -q "exec /usr/bin/podman" /usr/bin/docker \
      || { echo "ERROR: docker is not podman-docker's podman wrapper" >&2; exit 1; }; \
    test -e /etc/containers/nodocker || { echo "ERROR: /etc/containers/nodocker missing — every docker call would print a notice" >&2; exit 1; }; \
    test -f /etc/containers/containers.conf.d/50-azir-compose.conf || { echo "ERROR: compose banner drop-in missing" >&2; exit 1; }; \
    test -f /usr/lib/systemd/user/podman.socket && test -f /usr/lib/systemd/user/podman-restart.service \
      || { echo "ERROR: podman user units missing — dotfiles-azir enables both" >&2; exit 1; }; \
    test -f /usr/lib/systemd/system/keyd.service || { echo "ERROR: keyd.service missing — FORCE_SYSTEMD did not take" >&2; exit 1; }; \
    test -s /etc/flatpak/remotes.d/flathub.flatpakrepo || { echo "ERROR: Flathub remote missing (should be inherited from roshar)" >&2; exit 1; }; \
    systemctl is-enabled tailscaled.service >/dev/null || { echo "ERROR: tailscaled is not enabled" >&2; exit 1; }; \
    echo "apps OK: chromium $(rpm -q --qf '%{VERSION}' chromium), code $(rpm -q --qf '%{VERSION}' code), edge $(rpm -q --qf '%{VERSION}' microsoft-edge-stable), 1password $(rpm -q --qf '%{VERSION}' 1password), tailscale $(rpm -q --qf '%{VERSION}' tailscale)"

# --- Update policy: manual only ---
# Roshar's own base already masks both timers; just re-verify the mask survived inheritance.
RUN for t in bootc-fetch-apply-updates.timer rpm-ostreed-automatic.timer; do \
      [ "$(readlink -f "/etc/systemd/system/$t")" = /dev/null ] \
        || { echo "ERROR: $t not masked in the roshar base" >&2; exit 1; }; \
    done \
 && echo "update timers confirmed masked (inherited from roshar)"

# --- Image-update trust: inherited from ghcr.io/reinier/roshar ---
# Roshar's own build already bakes cosign.pub, a sigstoreSigned policy.json entry, and a
# registries.d file — all scoped to the ghcr.io/reinier NAMESPACE, not just .../roshar, so
# ghcr.io/reinier/azir is already covered by inheritance. No Azir-specific COPY needed here.
# See backlog/0004.

# Fail the build on real bootc issues (warnings are fine).
RUN bootc container lint

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
# No wlr-which-key here — DMS provides dank-lader as its leader menu.

# --- keyd: built from source, pinned to an upstream release tag ---
FROM registry.fedoraproject.org/fedora:44 AS keyd-build
ARG KEYD_VERSION=v2.6.0
RUN dnf5 -y install git make gcc kernel-headers \
 && git clone --depth 1 --branch "$KEYD_VERSION" https://github.com/rvaiya/keyd /src \
 && make -C /src PREFIX=/usr \
 && make -C /src PREFIX=/usr DESTDIR=/out FORCE_SYSTEMD=1 install

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

# --- Native Chromium + free codecs ---
# Everything needing RPM Fusion has to live in THIS RUN: the repo file is deleted two lines
# down, so a package added anywhere later silently fails to resolve.
#   libavcodec-freeworld      — the ffmpeg side of H.264/HEVC, for Chromium.
#   libheif-freeworld         — HEIC/HEIF decode (phone photos).
#   heif-pixbuf-loader, ffmpegthumbnailer — thumbnails for those and for video, in Nautilus,
#     which is host-native from the Silverblue base. Flatpak viewers bundle their own
#     decoders, so files always *open*; without these the file manager just shows blank tiles.
#     heif-pixbuf-loader is a Provides of gdk-pixbuf2 on F44, not a package of its own, so
#     this install is a no-op today — kept so the requirement is stated, and so it still
#     resolves if Fedora ever splits the loader back out. The guard below has to ask
#     --whatprovides for the same reason: plain `rpm -q` matches names, never provides.
#   pipewire-codec-aptx       — aptX for Bluetooth audio.
RUN dnf5 -y install "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
 && dnf5 -y install chromium libavcodec-freeworld libheif-freeworld \
      heif-pixbuf-loader ffmpegthumbnailer pipewire-codec-aptx \
 && rm -f /etc/yum.repos.d/rpmfusion-*.repo \
 && dnf5 clean all

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
# here rather than in Roshar's own generic wl-clipboard-tier utilities. podman-compose: podman
# itself comes from Silverblue's base image already (distrobox needs it); this just adds the
# compose provider `podman compose` looks for, needed to run the plaiground repo's rl-devbox
# devcontainer (docker/docker-compose.yml there) via Podman instead of Docker. kitty: the
# terminal (replaced ghostty, 2026-09-23) — Fedora packages it, so unlike ghostty it needs no
# Terra and sits on this line instead of the one below.
RUN dnf5 -y install fish jq zip fuse-sshfs xdg-terminal-exec wl-kbptr wtype podman-compose kitty \
 && dnf5 clean all
COPY files/terra.repo /etc/yum.repos.d/terra.repo
# starship/yazi: neither is packaged by Fedora, and neither is in Roshar.
RUN dnf5 -y install starship yazi \
 && rm -f /etc/yum.repos.d/terra.repo \
 && dnf5 clean all

# --- keyd artifacts ---
COPY --from=keyd-build /out/ /

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
#     earlier in this file (Chromium/libavcodec-freeworld); the release package itself is
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
    rpm -q chromium libavcodec-freeworld 1password 1password-cli \
           fish jq zip fuse-sshfs xdg-terminal-exec wl-kbptr wtype podman-compose kitty \
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
    test -f /usr/lib/sysusers.d/1password-azir.conf || { echo "ERROR: 1password sysusers drop-in missing" >&2; exit 1; }; \
    getent group onepassword     | grep -q ':1500:' || { echo "ERROR: onepassword group not at fixed gid 1500 (must be >=1000)" >&2; exit 1; }; \
    getent group onepassword-cli | grep -q ':1501:' || { echo "ERROR: onepassword-cli group not at fixed gid 1501" >&2; exit 1; }; \
    [ "$(stat -c %g /usr/lib/opt/1Password/1Password-BrowserSupport)" = 1500 ] || { echo "ERROR: BrowserSupport setgid not onepassword(1500)" >&2; exit 1; }; \
    [ "$(stat -c %g /usr/bin/op)" = 1501 ] || { echo "ERROR: op setgid not onepassword-cli(1501)" >&2; exit 1; }; \
    test -f /usr/lib/sysctl.d/60-1password-ptrace.conf || { echo "ERROR: ptrace_scope drop-in missing" >&2; exit 1; }; \
    command -v keyd >/dev/null || { echo "ERROR: keyd binary missing" >&2; exit 1; }; \
    test -f /usr/lib/systemd/system/keyd.service || { echo "ERROR: keyd.service missing — FORCE_SYSTEMD did not take" >&2; exit 1; }; \
    test -s /etc/flatpak/remotes.d/flathub.flatpakrepo || { echo "ERROR: Flathub remote missing (should be inherited from roshar)" >&2; exit 1; }; \
    systemctl is-enabled tailscaled.service >/dev/null || { echo "ERROR: tailscaled is not enabled" >&2; exit 1; }; \
    echo "apps OK: chromium $(rpm -q --qf '%{VERSION}' chromium), 1password $(rpm -q --qf '%{VERSION}' 1password), tailscale $(rpm -q --qf '%{VERSION}' tailscale)"

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

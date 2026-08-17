# Azir — Fedora Silverblue + niri + DankMaterialShell (DMS), GNOME kept.
#
# Azir is the DMS counterpart to Tashikk: same ADDITIVE Silverblue base (keep the full
# GNOME desktop + GDM, add niri as an alternative session), but the shell is DMS instead of
# Noctalia. So it recombines Tashikk's image skeleton with Steen's DMS-from-COPR stanza.
#
# Two differences from Tashikk worth noting:
#   - DMS comes from the avengemedia STABLE COPR (Fedora only has the too-old DMS 1.4.4 /
#     quickshell 0.2.1), with a quickshell provenance guard — NOT a clean Fedora install.
#   - DMS is NOT `--global` enabled (that would start it in the GNOME session too). The
#     dotfiles spawn it from niri, so it only runs in the niri session.
# No wlr-which-key here (unlike Tashikk) — DMS provides dank-lader as its leader menu.

# --- keyd: built from source, pinned to an upstream release tag ---
FROM registry.fedoraproject.org/fedora:44 AS keyd-build
ARG KEYD_VERSION=v2.6.0
RUN dnf5 -y install git make gcc kernel-headers \
 && git clone --depth 1 --branch "$KEYD_VERSION" https://github.com/rvaiya/keyd /src \
 && make -C /src PREFIX=/usr \
 && make -C /src PREFIX=/usr DESTDIR=/out FORCE_SYSTEMD=1 install

# Silverblue base — the full GNOME atomic desktop. GNOME stays; GDM stays (it gains a
# "Niri" session entry once niri is installed below).
FROM quay.io/fedora-ostree-desktops/silverblue:44

# --- niri + DankMaterialShell session (added alongside GNOME) ---
# niri Recommends waybar/fuzzel/swaylock/alacritty — install with weak deps OFF so those
# don't come along (DMS provides bar/launcher/lock; GNOME provides the rest). niri's wanted
# recommends (gnome-keyring, wireplumber, portals) are already present from Silverblue.
# niri has NO built-in Xwayland, so xwayland-satellite drives the base's Xwayland server.
# kitty is the terminal. Nothing else in this line: DMS owns the desktop's system integration
# NATIVELY (per its docs, only Quickshell is required) — display arrangement + profiles, media
# via Quickshell's MPRIS service, and brightness via its Go backend. So no kanshi/wdisplays
# (display, Noctalia-only) and no brightnessctl/playerctl (DMS's doctor lists neither as a
# dependency — they were Noctalia-era carryover, not DMS needs).
#
# DMS + quickshell + dms-cli as a MATCHED PAIR from upstream's *stable* COPRs — Fedora's DMS
# 1.4.4 / quickshell 0.2.1 are too old for DMS 1.5.x. matugen (DMS theming) from Fedora.
# DMS is spawned from niri in the dotfiles (NOT --global enabled), so it stays niri-only.
COPY files/avengemedia-dms.repo files/avengemedia-danklinux.repo /etc/yum.repos.d/
RUN dnf5 -y install --setopt=install_weak_deps=False \
      niri kitty xwayland-satellite \
 && dnf5 -y install dms matugen \
 && rm -f /etc/yum.repos.d/avengemedia-dms.repo \
          /etc/yum.repos.d/avengemedia-danklinux.repo \
 && dnf5 clean all

# Guard: assert quickshell PROVENANCE, not versions. dms's dependency is the unversioned
# `(quickshell or quickshell-git)`, so rpm is equally satisfied by Fedora's much older
# quickshell — it only resolves to the COPR build because that repo is enabled and dnf takes
# the highest version. A silently mismatched quickshell crashed the shell on Steen once.
RUN set -e; \
    rpm -q niri kitty xwayland-satellite dms dms-cli quickshell matugen >/dev/null; \
    ! rpm -q DankMaterialShell >/dev/null 2>&1 \
      || { echo "ERROR: Fedora's DankMaterialShell is installed alongside COPR dms" >&2; exit 1; }; \
    command -v niri >/dev/null || { echo "ERROR: niri binary missing" >&2; exit 1; }; \
    command -v dms  >/dev/null || { echo "ERROR: dms CLI missing" >&2; exit 1; }; \
    qs_repo="$(dnf5 repoquery --installed --qf '%{from_repo}' quickshell | head -1)"; \
    case "$qs_repo" in \
      *avengemedia*) ;; \
      *) echo "ERROR: quickshell came from '${qs_repo}', not the avengemedia COPR." >&2; exit 1;; \
    esac; \
    echo "desktop core: niri $(rpm -q --qf '%{VERSION}' niri), dms $(rpm -q --qf '%{VERSION}' dms), quickshell $(rpm -q --qf '%{VERSION}' quickshell) [${qs_repo}]"

# SwayNotificationCenter can leak in as a weak dep of the dms/niri COPR stack (dms is
# installed weak-deps-ON for matugen/cava); DMS provides notifications, so purge it.
RUN rpm -q SwayNotificationCenter >/dev/null 2>&1 && dnf5 -y remove SwayNotificationCenter || true \
 && dnf5 clean all

# Additive guard: the niri/DMS session landed AND GNOME/GDM/plumbing survived (nothing should
# be removed on an additive build). Also assert niri ships its GDM session file so the "Niri"
# entry appears at login.
RUN set -e; \
    test -f /usr/share/wayland-sessions/niri.desktop \
      || { echo "ERROR: niri GDM session file missing — GDM won't offer a Niri session; bake one" >&2; exit 1; }; \
    rpm -q gnome-shell gdm xdg-desktop-portal-gnome gnome-keyring \
           pipewire wireplumber NetworkManager >/dev/null \
      || { echo "ERROR: GNOME/plumbing was disturbed by the niri layer (should be additive)" >&2; exit 1; }; \
    ! rpm -q sddm >/dev/null 2>&1 || { echo "ERROR: sddm present — GDM should be the only DM" >&2; exit 1; }; \
    echo "session OK: niri + dms added; GNOME/GDM intact"

# --- JetBrainsMono Nerd Font ---
ARG NERD_FONT_VERSION=v3.4.0
RUN curl -fsSL -o /tmp/JetBrainsMono.tar.xz \
      "https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONT_VERSION}/JetBrainsMono.tar.xz" \
 && mkdir -p /usr/share/fonts/jetbrainsmono-nerd \
 && tar -xJf /tmp/JetBrainsMono.tar.xz -C /usr/share/fonts/jetbrainsmono-nerd \
 && rm -f /tmp/JetBrainsMono.tar.xz \
 && fc-cache -f /usr/share/fonts/jetbrainsmono-nerd

# --- Native Chromium + free codecs ---
RUN dnf5 -y install "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
 && dnf5 -y install chromium libavcodec-freeworld \
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

# --- CLI toolkit ---
# git-core (NOT the full `git` meta-package): the base already ships git-core, and chezmoi/
# lazygit only need the git binary. Naming full `git` here dragged in the whole Perl tree
# (~63 pkgs: perl-interpreter + perl-Git + modules, for git-svn/send-email/gitk) — nothing on
# Azir uses Perl. Requesting git-core is a no-op on the base yet documents the dependency
# without the Perl bloat. lazygit is NOT baked — apps distrobox (dotfiles).
RUN dnf5 -y install fish eza bat jq zip fuse-sshfs fzf xdg-terminal-exec ripgrep chezmoi git-core \
 && dnf5 clean all
COPY files/terra.repo /etc/yum.repos.d/terra.repo
RUN dnf5 -y install starship yazi \
 && rm -f /etc/yum.repos.d/terra.repo \
 && dnf5 clean all

# --- Synology Drive ---
COPY files/synology-drive.repo /etc/yum.repos.d/synology-drive.repo
RUN opt_link="$(readlink /opt)" \
 && rm /opt && mkdir /opt \
 && dnf5 -y install synology-drive-noextra \
 && rm -f /etc/yum.repos.d/synology-drive.repo \
 && mkdir -p /usr/lib/opt \
 && mv /opt/Synology /usr/lib/opt/Synology \
 && rmdir /opt \
 && ln -s "$opt_link" /opt \
 && dnf5 clean all
COPY files/synology-drive-opt.conf /usr/lib/tmpfiles.d/synology-drive-opt.conf

# --- keyd artifacts ---
COPY --from=keyd-build /out/ /

# --- Tailscale ---
RUN dnf5 -y install tailscale \
 && systemctl enable tailscaled.service \
 && dnf5 clean all

# --- Flathub remote ---
RUN mkdir -p /etc/flatpak/remotes.d \
 && curl -fsSL -o /etc/flatpak/remotes.d/flathub.flatpakrepo \
      https://dl.flathub.org/repo/flathub.flatpakrepo

# --- Dev containers ---
RUN dnf5 -y install distrobox \
 && dnf5 clean all

# Guard for the whole app layer.
RUN set -e; \
    rpm -q chromium libavcodec-freeworld 1password 1password-cli \
           fish eza bat jq zip fuse-sshfs fzf xdg-terminal-exec ripgrep chezmoi git-core starship yazi \
           synology-drive-noextra tailscale distrobox >/dev/null; \
    ! command -v lazygit >/dev/null || { echo "ERROR: lazygit is in the image — it belongs in the apps distrobox (dotfiles)" >&2; exit 1; }; \
    test -L /opt || { echo "ERROR: /opt is no longer a symlink — ostree layout broken" >&2; exit 1; }; \
    test -d /usr/lib/opt/1Password || { echo "ERROR: 1Password payload not relocated into /usr" >&2; exit 1; }; \
    test -d /usr/lib/opt/Synology  || { echo "ERROR: Synology payload not relocated into /usr" >&2; exit 1; }; \
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
    test -s /etc/flatpak/remotes.d/flathub.flatpakrepo || { echo "ERROR: Flathub remote missing" >&2; exit 1; }; \
    systemctl is-enabled tailscaled.service >/dev/null || { echo "ERROR: tailscaled is not enabled" >&2; exit 1; }; \
    echo "apps OK: chromium $(rpm -q --qf '%{VERSION}' chromium), 1password $(rpm -q --qf '%{VERSION}' 1password), synology $(rpm -q --qf '%{VERSION}' synology-drive-noextra), tailscale $(rpm -q --qf '%{VERSION}' tailscale)"

# --- Update policy: manual only ---
RUN systemctl mask bootc-fetch-apply-updates.timer rpm-ostreed-automatic.timer \
 && for t in bootc-fetch-apply-updates.timer rpm-ostreed-automatic.timer; do \
      [ "$(readlink -f "/etc/systemd/system/$t")" = /dev/null ] \
        || { echo "ERROR: $t not masked" >&2; exit 1; }; \
    done \
 && echo "update timers masked: bootc-fetch-apply-updates + rpm-ostreed-automatic"

# --- Image-update trust ---
# Verify our own update stream (ghcr.io/reinier/azir). Shared cosign key with Steen/Tashikk;
# signedIdentity=matchRepository binds each signature to its own repo, so no cross-repo auth.
# NOTE: requires SIGNING_SECRET (the same key) set on the azir repo, or the first push is
# UNSIGNED and `bootc upgrade` (once on Azir) will reject it. First rebase FROM Silverblue is
# still trust-on-first-use regardless.
COPY cosign.pub /usr/share/pki/containers/cosign.pub
COPY patch-policy.py /tmp/patch-policy.py
RUN python3 /tmp/patch-policy.py && rm -f /tmp/patch-policy.py

COPY files/azir-registries.yaml /usr/share/factory/etc/containers/registries.d/azir.yaml
RUN mkdir -p /etc/containers/registries.d \
 && cp /usr/share/factory/etc/containers/registries.d/azir.yaml \
       /etc/containers/registries.d/azir.yaml

# Fail the build on real bootc issues (warnings are fine).
RUN bootc container lint

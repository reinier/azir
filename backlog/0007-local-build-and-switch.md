# Local build: build Azir on the machine itself and switch to it

- **Status:** open (nothing built or tested yet)
- **Created:** 2026-10-07
- **Area:** image (`Containerfile`: one build argument) + a documented workflow
- **Related:** `roshar` backlog `0006` (building Roshar locally too). Background: the
  GitHub-alternatives discussion of 2026-10-07 — GitHub Actions + ghcr.io stay the main
  path for now; this item is the self-build fallback.

## Why

Be able to build the image on the Azir machine itself (or another Linux box) and boot
it, without GitHub Actions or ghcr.io. Uses:

- **Fallback** when GitHub Actions or ghcr.io is down, or when GitHub goes away later.
- **Testing** a Containerfile change on real hardware before pushing it.

bootc can switch to an image straight from local podman storage — no registry needed.

## 1. Containerfile change (do first)

The Roshar base is hard-coded: `FROM ghcr.io/reinier/roshar:latest`. To build on a
locally built Roshar (`roshar` `0006`), make it a build argument. A global `ARG` before
the first `FROM` is visible to every `FROM` line:

```dockerfile
ARG ROSHAR_IMAGE=ghcr.io/reinier/roshar:latest

# --- keyd: built from source … (unchanged)
FROM registry.fedoraproject.org/fedora:44 AS keyd-build
…
FROM ${ROSHAR_IMAGE}
```

The default keeps CI exactly as it is. (`podman build --from` is not an alternative: it
replaces the *first* `FROM`, which is the keyd build stage.) Note the image's own Roshar
guard right after `FROM` still runs, so a broken local base fails the build early.

## 2. Build

On the machine that will run the image, **as root** — bootc runs as root and only sees
root's container storage (`/var/lib/containers/storage`), not rootless podman's:

```bash
cd ~/dev/AzirOS/azir && git pull
sudo podman build -t localhost/azir:local .
# on a local Roshar instead (roshar 0006):
sudo podman build --build-arg ROSHAR_IMAGE=localhost/roshar:local -t localhost/azir:local .
```

- The base (`ghcr.io/reinier/roshar`) is still pulled from ghcr.io in the first variant;
  that pull is checked against the image's own sigstore policy (the build host is Azir,
  which carries Roshar's `policy.json` + `registries.d` entry), so a tampered base fails.
- The build ends with `RUN bootc container lint`, so a broken image fails here, not at boot.
- Needs network: Fedora mirrors, RPM Fusion, 1Password's repo, Terra, GitHub (keyd source,
  Nerd Font). Expect roughly 15–30 min on a laptop (CI: ~6 min on 4 vCPU), and ~10 GB
  free in `/var` for the base, layers and the result.

## 3. Switch to it

```bash
sudo bootc switch --transport containers-storage localhost/azir:local
sudo systemctl reboot
```

- After the reboot, `bootc status` / the Azir Menu stats box show `localhost/azir:local`.
- **Local images aren't signature-checked.** Roshar's trust rule covers the `docker`
  transport for `ghcr.io/reinier` only; `containers-storage` falls under Fedora's default
  policy (accept). That's expected for an image you just built yourself — confirm it
  once on the machine (`cat /etc/containers/policy.json`) rather than assume.
- The previous image stays as the rollback entry: `sudo bootc rollback` (or the Azir Menu)
  if the local build misbehaves.

## 4. Updating while on the local image

```bash
cd ~/dev/AzirOS/azir && git pull
sudo podman build -t localhost/azir:local .      # same tag
sudo bootc upgrade                                # stages the rebuilt image
sudo systemctl reboot
```

- While switched to the local tag, the Azir Menu's "Check for an image update" and
  "Update OS image" look at **local storage**, not ghcr.io — no CI builds arrive until you
  switch back.
- Clean up old build layers afterwards: `sudo podman image prune` (and
  `sudo podman system df` to see what's using space).

## 5. Back to the published image

```bash
sudo bootc switch ghcr.io/reinier/azir:latest
sudo systemctl reboot
```

Signed updates from CI resume; the local image becomes the rollback entry.

## Variant: build on one machine, run on another

For when the laptop shouldn't do the build itself (e.g. build on the desktop, or the
devbox). Two ways, simplest first:

- **Archive file, no registry:**
  ```bash
  # build machine
  sudo podman save --format oci-archive -o azir.ociarchive localhost/azir:local
  # copy azir.ociarchive to the target (scp, USB), then on the target:
  sudo bootc switch --transport oci-archive /path/to/azir.ociarchive
  ```
  Updates mean copying a new archive and switching again (`bootc upgrade` re-reads the
  same path, if the file is replaced in place).
- **A registry on the LAN** (e.g. `podman run -d -p 5000:5000 registry:2` on the build
  machine, push to it, `bootc switch <host>:5000/azir:local` on the target). Needs either
  TLS or an `insecure = true` entry for that host in `/etc/containers/registries.conf.d/`
  on the target, and isn't covered by the sigstore trust rule either — more moving parts
  than the archive, only worth it for regular use across several machines.

## Acceptance (on real hardware)

1. Containerfile change merged; CI build still green and unchanged (default `ROSHAR_IMAGE`).
2. Local build on the Azir laptop succeeds; note the build time and `/var` usage here.
3. `bootc switch --transport containers-storage localhost/azir:local` → reboot → booted
   image is the local one; niri/DMS session comes up.
4. Rebuild after a trivial change → `bootc upgrade` stages it → reboot shows it.
5. `bootc switch ghcr.io/reinier/azir:latest` → back on CI images.
6. Write the measured build time / disk usage and anything that differed from this item
   back into it.

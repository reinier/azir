# Signed update stream

- **Status:** done — `SIGNING_SECRET` confirmed set on `reinier/azir` (added
  2026-08-06); CI runs since then show `--sign-by-sigstore-private-key` +
  `Storing signatures`, not the unsigned fallback.
- **Created:** 2026-08-06
- **Related:** Steen `0001`, Tashikk `0001` (same machinery).

## What's baked

Azir verifies its own update stream (`ghcr.io/reinier/azir`): a `cosign.pub` + a
`sigstoreSigned` `policy.json` entry (`signedIdentity: matchRepository`) + a registries.d file
for sigstore attachment reads — all keyed on the `ghcr.io/reinier` **namespace**, not just one
repo. CI signs the `:latest` push when `SIGNING_SECRET` is present.

**Update (2026-09-07, see `0004`):** since Azir now builds `FROM ghcr.io/reinier/roshar:latest`
(see `0000`), this trust config is **inherited from Roshar's own build**, not baked directly
by Azir's own Containerfile anymore — `cosign.pub`, `patch-policy.py`, and
`files/azir-registries.yaml` were deleted from this repo as redundant. The namespace-scoped
`matchRepository` policy already covers `ghcr.io/reinier/azir` regardless of which layer wrote
it. Everything below (the shared key, the `SIGNING_SECRET`-on-`reinier/azir` requirement, CI
push-side signing) is unaffected — this only changes how the *pulling* side of trust gets
baked into the image, not the *pushing* side.

## Shared key — one action needed

The cosign key is **shared** with Steen and Tashikk (same `SIGNING_SECRET`). `matchRepository`
binds each signature to its own repo, so a Steen/Tashikk signature can't authorize an Azir
pull. **You must set `SIGNING_SECRET` on the `reinier/azir` repo** (same private key) — until
then CI pushes UNSIGNED (with a warning).

Because the policy is baked, an unsigned `:latest` will be **rejected by `bootc upgrade`** once
you're on Azir. The first `bootc switch` *from Silverblue* is still trust-on-first-use (the
source system's policy doesn't require the key), so a first boot-test works either way — but
set the secret before relying on updates.

## Verify

- CI push log shows `--sign-by-sigstore-private-key` + `Storing signatures`.
- `bootc switch` verifies against the baked policy; subsequent `bootc upgrade` is enforced.

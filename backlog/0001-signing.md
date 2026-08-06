# Signed update stream

- **Status:** in-progress (policy baked; needs `SIGNING_SECRET` on the azir repo)
- **Created:** 2026-08-06
- **Related:** Steen `0001`, Tashikk `0001` (same machinery).

## What's baked

Azir verifies its own update stream (`ghcr.io/reinier/azir`): a baked `cosign.pub` + a
`sigstoreSigned` `policy.json` entry (`patch-policy.py`, keyed on the `ghcr.io/reinier`
namespace, `signedIdentity: matchRepository`) + `files/azir-registries.yaml` for sigstore
attachment reads. CI signs the `:latest` push when `SIGNING_SECRET` is present.

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

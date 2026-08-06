#!/usr/bin/env python3
"""Add a sigstoreSigned trust entry for the ghcr.io/reinier namespace.

Tashikk is what this machine boots, so it must verify its own update stream rather
than inherit that trust from the base. The Silverblue base ships only Fedora's
default container policy, so establish the ghcr.io/reinier chain from scratch. The
base manages its container policy via the bootc factory template
(/usr/share/factory/etc/containers/policy.json), which populates /etc at boot; some
builds also materialize /etc directly. Patch every policy.json that exists so the
entry is present whichever file the system ends up reading.

The signedIdentity is matchRepository, so a signature is bound to the exact repo it
was made for. Tashikk shares its signing key with Steen (same SIGNING_SECRET), but a
Steen signature (identity ghcr.io/reinier/steen) can NOT authorize a Tashikk pull and
vice-versa — shared trust root, per-repo signature identity.
"""
import json
import os

CANDIDATES = [
    "/usr/share/factory/etc/containers/policy.json",
    "/etc/containers/policy.json",
    "/usr/share/containers/policy.json",
]
ENTRY = [
    {
        "type": "sigstoreSigned",
        "keyPaths": ["/usr/share/pki/containers/cosign.pub"],
        "signedIdentity": {"type": "matchRepository"},
    }
]

patched = 0
for path in CANDIDATES:
    if not os.path.exists(path):
        continue
    with open(path) as f:
        policy = json.load(f)
    policy.setdefault("transports", {}).setdefault("docker", {})["ghcr.io/reinier"] = ENTRY
    with open(path, "w") as f:
        json.dump(policy, f, indent=4)
        f.write("\n")
    patched += 1
    print(f"patched {path}")

if patched == 0:
    raise SystemExit("no container policy.json found to patch")

#!/usr/bin/env python3
"""Pin and bundle HaGeZi PRO mini as data; never fetch lists while browsing.

Usage: python3 Tools/update_content_blocker.py <40-character upstream commit>
The original list and GPL-3.0 license are retained in the app bundle.
"""
import hashlib
import json
from pathlib import Path
import re
import sys
import urllib.request

revision = sys.argv[1] if len(sys.argv) == 2 else ""
if not re.fullmatch(r"[0-9a-f]{40}", revision):
    raise SystemExit("Pass an immutable hagezi/dns-blocklists commit SHA.")

root = Path(__file__).resolve().parents[1] / "lite" / "Resources"
base = f"https://raw.githubusercontent.com/hagezi/dns-blocklists/{revision}/"

def fetch(path):
    with urllib.request.urlopen(base + path, timeout=45) as response:
        data = response.read(8_000_001)
    if len(data) > 8_000_000:
        raise ValueError("Unexpectedly large upstream file")
    return data

source = fetch("wildcard/pro.mini-onlydomains.txt")
license_text = fetch("LICENSE")
domains = [line for line in source.decode("utf-8").splitlines() if line and not line.startswith("#")]
if not 10_000 < len(domains) < 150_000:
    raise ValueError("Unexpected list size; review upstream before updating")
if any(not re.fullmatch(r"(?:[a-z0-9](?:[a-z0-9-]*[a-z0-9])?\.)+[a-z0-9-]+", d) for d in domains):
    raise ValueError("Unexpected domain syntax")
if b"GNU GENERAL PUBLIC LICENSE" not in license_text:
    raise ValueError("Upstream license changed; review before updating")

root.mkdir(parents=True, exist_ok=True)
(root / "AdBlockDomains.txt").write_bytes(source)
(root / "AdBlockLicense.txt").write_bytes(license_text)
metadata = {
    "name": "HaGeZi Multi PRO mini",
    "source": base + "wildcard/pro.mini-onlydomains.txt",
    "revision": revision,
    "sha256": hashlib.sha256(source).hexdigest(),
    "domains": len(set(domains)),
    "license": "GPL-3.0 (bundled blocklist data)",
    "modifications": "Original list retained. Lite derives WebKit domain rules and adds its original ten domains and cosmetic rules at runtime."
}
(root / "AdBlockProvenance.json").write_text(json.dumps(metadata, indent=2) + "\n")
print(f"Bundled {metadata['domains']:,} domains at {revision}")

#!/usr/bin/env python3
from pathlib import Path

TEMPLATE_FILE = Path("user-data.template")
OUTPUT_FILE = Path("user-data")
KEYS_DIR = Path("ssh-public-keys")

template = TEMPLATE_FILE.read_text()

keys = []
for pubfile in sorted(KEYS_DIR.glob("*.pub")):
    key = pubfile.read_text().strip()
    if key:
        # 6 spaces indent so it lines up under ssh_authorized_keys:
        keys.append(f"      - {key}")

if not keys:
    raise SystemExit("No .pub files found in keys/ directory")

keys_block = "\n".join(keys)

output = template.replace("[ AUTHORIZED_SSH_PUBLIC_KEYS ]", keys_block)

OUTPUT_FILE.write_text(output)
print(f"Wrote {OUTPUT_FILE}")


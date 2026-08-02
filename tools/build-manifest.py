#!/usr/bin/env python3
"""Regenerate manifest.json.

The loader uses the manifest to work out what actually changed in an update, so it can delete and
re-download only those files instead of wiping the whole install. That only works while the manifest
matches the tree, so this is run by .github/workflows/manifest.yml on every push - do not hand-edit
manifest.json.

Hashes are the first 16 hex characters of the file's SHA-256. They are only ever compared for
equality (the loader never computes a hash), so 64 bits is far more than enough and keeps the
manifest small enough to fetch on every startup.
"""

import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MANIFEST = ROOT / 'manifest.json'

# Everything tracked in git is listed except the manifest itself (which would never settle) and
# repository furniture the loader has no use for.
EXCLUDE_EXACT = {'manifest.json'}
# deobfuscated/ is reverse-engineering notes about third-party scripts - it is not client content,
# so listing it would only make every install download it on update.
EXCLUDE_PREFIX = ('.github/', 'tools/', 'deobfuscated/')


def tracked_files():
    out = subprocess.run(
        ['git', 'ls-files', '-z'],
        cwd=ROOT, check=True, capture_output=True, text=True,
    ).stdout
    for path in out.split('\0'):
        if not path:
            continue
        if path in EXCLUDE_EXACT or path.startswith(EXCLUDE_PREFIX):
            continue
        yield path


def short_hash(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open('rb') as handle:
        for block in iter(lambda: handle.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()[:16]


def build() -> dict:
    files = {}
    for rel in sorted(tracked_files()):
        full = ROOT / rel
        if not full.is_file():
            continue
        files[rel] = short_hash(full)
    return {'version': 1, 'files': files}


def main() -> int:
    manifest = build()
    text = json.dumps(manifest, indent=1, sort_keys=True) + '\n'
    previous = MANIFEST.read_text() if MANIFEST.exists() else None
    if previous == text:
        print('manifest.json is already up to date (%d files)' % len(manifest['files']))
        return 0
    MANIFEST.write_text(text)
    print('manifest.json written (%d files, %d bytes)' % (len(manifest['files']), len(text)))
    return 0


if __name__ == '__main__':
    sys.exit(main())

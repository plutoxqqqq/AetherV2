#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
GAME_DIR = ROOT / 'games' / '6872274481'
MAIN = GAME_DIR / 'main.lua'
BUNDLE = GAME_DIR / 'bundle.lua'
MARKER = re.compile(r'--\[\[AETHER_MODULE:([^\]]+)\]\]')


def build() -> str:
    source = MAIN.read_text(encoding='utf-8')
    seen = []

    def replace(match: re.Match[str]) -> str:
        relative = match.group(1).strip()
        if relative.startswith('/') or '..' in Path(relative).parts:
            raise RuntimeError(f'Unsafe module marker: {relative}')
        module_path = GAME_DIR / relative
        if not module_path.is_file():
            raise RuntimeError(f'Module marker points to missing file: {relative}')
        seen.append(relative)
        return module_path.read_text(encoding='utf-8').rstrip() + '\n'

    bundle = MARKER.sub(replace, source)
    if MARKER.search(bundle):
        raise RuntimeError('Unresolved BedWars module marker remains')
    header = '-- GENERATED FILE. Edit games/6872274481/main.lua or a category module instead.\n'
    BUNDLE.write_text(header + bundle.lstrip('\ufeff'), encoding='utf-8')
    return f'Built {BUNDLE.relative_to(ROOT)} from {len(seen)} module files'


if __name__ == '__main__':
    print(build())

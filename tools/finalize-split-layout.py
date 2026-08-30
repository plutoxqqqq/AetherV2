#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BED = ROOT / 'games' / '6872274481'
MAIN = BED / 'main.lua'


def main():
    fragment = BED / 'kits' / 'Multiplier.lua'
    marker = '--[[AETHER_MODULE:kits/Multiplier.lua]]'
    if fragment.exists():
        source = MAIN.read_text(encoding='utf-8')
        if marker not in source:
            raise RuntimeError('Multiplier marker missing from main.lua')
        content = fragment.read_text(encoding='utf-8').rstrip()
        MAIN.write_text(source.replace(marker, content, 1), encoding='utf-8')
        fragment.unlink()
        print('Inlined kits/Multiplier.lua option fragment into main.lua')

    # Final split is not allowed to leave obsolete grouping folders behind.
    for folder in ('mixed', 'visuals', 'minigames'):
        path = BED / folder
        if path.exists():
            leftovers = list(path.rglob('*'))
            files = [p for p in leftovers if p.is_file()]
            if files:
                raise RuntimeError(f'obsolete {folder}/ still contains files: {[str(p.relative_to(BED)) for p in files]}')
            for directory in sorted([p for p in leftovers if p.is_dir()], reverse=True):
                directory.rmdir()
            path.rmdir()

    print('Final split layout cleanup complete')


if __name__ == '__main__':
    main()

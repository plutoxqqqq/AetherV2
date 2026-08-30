#!/usr/bin/env python3
from pathlib import Path
text = Path('games/6872274481/main.lua').read_text().splitlines()
needle = '--[[AETHER_MODULE:kits/Multiplier.lua]]'
for index, line in enumerate(text):
    if needle in line:
        start = max(0, index - 80); end = min(len(text), index + 80)
        print(f'KIT_FRAGMENT_LINES={start+1}-{end}')
        for i in range(start, end): print(f'{i+1:06d}|{text[i]}')
        break
else:
    print('KIT_FRAGMENT_MISSING')

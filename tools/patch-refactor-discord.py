#!/usr/bin/env python3
from pathlib import Path

path = Path(__file__).with_name('apply-bedwars-refactor.py')
text = path.read_text(encoding='utf-8')
needle = "def patch_discord_bot():\n    path = ROOT / 'backend' / 'discord-bot.js'\n    text = read(path)\n"
replacement = "def patch_discord_bot():\n    path = ROOT / 'backend' / 'discord-bot.js'\n    text = read(path)\n    # Existing conflict selector has one extra closing parenthesis; fix it before adding /stats.\n    text = text.replace('      }))));', '      })));', 1)\n"
if replacement in text:
    print('Discord syntax repair is already part of the refactor')
elif needle not in text:
    raise SystemExit('Could not locate patch_discord_bot()')
else:
    path.write_text(text.replace(needle, replacement, 1), encoding='utf-8')
    print('Added Discord syntax repair to refactor')

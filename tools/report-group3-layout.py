#!/usr/bin/env python3
from pathlib import Path
import re

path = Path('games/6872274481/mixed/AutoWin__group3.lua')
if not path.exists():
    print('GROUP3_MISSING')
    raise SystemExit
text = path.read_text(encoding='utf-8')
lines = text.splitlines()
print('GROUP3_LINES', len(lines), 'BYTES', len(text.encode()))
for i, line in enumerate(lines, 1):
    stripped = line.strip()
    if stripped.startswith('-- ') and len(stripped) > 5 and not stripped.startswith('-- [['):
        if any(word in stripped.lower() for word in ('autowin', 'jade', 'trixie', 'alsploit', 'yamini', 'antihit', 'nofall', 'balloon', 'multiaction', 'sigrid', 'runtime', 'ports', 'exploit', 'register')):
            print(f'HEADING|{i}|{stripped[:150]}')
    if re.search(r"register\s*\(\s*['\"]", line) or ':CreateModule({' in line or 'pcall(kits.CreateModule' in line:
        window = '\n'.join(lines[i-1:i+5])
        m = re.search(r"Name\s*=\s*['\"]([^'\"]+)", window)
        r = re.search(r"register\s*\(\s*['\"]([^'\"]+)['\"]\s*,\s*['\"]([^'\"]+)", window)
        name = r.group(2) if r else (m.group(1) if m else '?')
        cat = r.group(1) if r else '?'
        print(f'MODULE|{i}|{cat}|{name}|{stripped[:120]}')
    if re.match(r'\s*local function (registerAetherRuntime|patchAetherRuntime|registerTrixie|registerAlSploit|registerAlSploitV2)', line):
        print(f'FUNCTION|{i}|{stripped}')

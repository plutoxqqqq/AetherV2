#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
GAME_DIR = ROOT / 'games' / '6872274481'
IGNORE = {'main.lua', 'bundle.lua'}
OBSOLETE_DIRS = {'mixed', 'visuals', 'minigames'}

CREATE = re.compile(r'(?:(?:vape\s*\.\s*Categories\s*\.\s*([A-Za-z0-9_]+))|(\bkits\b))\s*:\s*CreateModule\s*\(\s*\{', re.M)
REGISTER = re.compile(r'\bregister\s*\(\s*([\'\"])([^\'\"]+)\1\s*,\s*([\'\"])([^\'\"]+)\3\s*,\s*\{', re.M)
NAME = re.compile(r'\bName\s*=\s*([\'\"])(.*?)\1', re.S)


def logical_modules(source):
    found = []
    for match in REGISTER.finditer(source):
        found.append((match.group(4).strip(), match.group(2).strip()))
    for match in CREATE.finditer(source):
        category = match.group(1) or 'Kits'
        snippet = source[match.end():match.end() + 1600]
        name_match = NAME.search(snippet)
        if name_match:
            found.append((name_match.group(2).strip(), category))
    unique = []
    seen = set()
    for name, category in found:
        key = name.lower()
        if key not in seen:
            seen.add(key)
            unique.append((name, category))
    return unique


def main():
    problems = []
    files = []
    for path in sorted(GAME_DIR.rglob('*.lua')):
        if path.name in IGNORE:
            continue
        rel = path.relative_to(GAME_DIR)
        files.append(rel)
        modules = logical_modules(path.read_text(encoding='utf-8'))
        if rel.parts[0].lower() in OBSOLETE_DIRS:
            problems.append((str(rel), 'obsolete directory', modules))
        if len(modules) == 0:
            problems.append((str(rel), 'zero module registrations', modules))
        elif len(modules) > 1:
            problems.append((str(rel), f'{len(modules)} unique modules in one file', modules))
        elif path.stem.lower() != re.sub(r'[^a-z0-9_.-]+', '_', modules[0][0].lower()).strip('._'):
            problems.append((str(rel), f'filename does not match module {modules[0][0]}', modules))

    print(f'AUDIT_FILES={len(files)}')
    print(f'AUDIT_PROBLEMS={len(problems)}')
    for rel, problem, modules in problems:
        names = ', '.join(f'{name}[{category}]' for name, category in modules) or '-'
        print(f'PROBLEM|{rel}|{problem}|{names}')

    if '--report-only' not in sys.argv and problems:
        raise SystemExit(1)


if __name__ == '__main__':
    main()

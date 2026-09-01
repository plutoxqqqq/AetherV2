#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
GAME_DIR = ROOT / 'games' / '6872274481'
IGNORE = {'main.lua', 'bundle.lua'}
OBSOLETE_DIRS = {'mixed', 'visuals', 'minigames'}

# Accept ordinary `receiver:CreateModule({...})`, register(category, name, {...}), and
# protected `pcall(receiver.CreateModule, receiver, {...})` forms. The latter is used by
# TrixieExploit so a missing kit API cannot abort the whole BedWars file.
CREATE = re.compile(r'([A-Za-z_][A-Za-z0-9_\.]*)\s*:\s*CreateModule\s*\(\s*\{', re.M)
PCALL_CREATE = re.compile(r'pcall\s*\(\s*([A-Za-z_][A-Za-z0-9_\.]*)\.CreateModule\s*,\s*\1\s*,\s*\{', re.M)
REGISTER = re.compile(r'\bregister\s*\(\s*([\'\"])([^\'\"]+)\1\s*,\s*([\'\"])([^\'\"]+)\3\s*,\s*\{', re.M)
OVERLAY = re.compile(r'([A-Za-z_][A-Za-z0-9_\.]*)\s*:\s*CreateOverlay\s*\(\s*\{', re.M)
NAME = re.compile(r'\bName\s*=\s*([\'\"])(.*?)\1', re.S)
EXPLICIT_NAME = re.compile(r'^\s*--\s*AETHER_MODULE_NAME:\s*(.+?)\s*$', re.M)


def receiver_category(receiver):
    if receiver == 'kits': return 'Kits'
    if '.Categories.' in receiver: return receiver.rsplit('.', 1)[-1]
    return 'Dynamic'


def logical_modules(source):
    found = []
    for match in REGISTER.finditer(source):
        found.append((match.group(4).strip(), match.group(2).strip()))
    for regex in (CREATE, PCALL_CREATE):
        for match in regex.finditer(source):
            snippet = source[match.end():match.end() + 1800]
            name_match = NAME.search(snippet)
            if name_match:
                found.append((name_match.group(2).strip(), receiver_category(match.group(1))))
    unique = []
    seen = set()
    for name, category in found:
        key = name.lower()
        if key not in seen:
            seen.add(key)
            unique.append((name, category))
    return unique


def logical_overlays(source):
    found = []
    for match in OVERLAY.finditer(source):
        snippet = source[match.end():match.end() + 1600]
        name_match = NAME.search(snippet)
        if name_match: found.append(name_match.group(2).strip())
    return list(dict.fromkeys(found))


def safe_stem(value):
    return re.sub(r'[^a-z0-9_.-]+', '_', value.lower()).strip('._')


def main():
    problems = []
    files = []
    for path in sorted(GAME_DIR.rglob('*.lua')):
        if path.name in IGNORE:
            continue
        rel = path.relative_to(GAME_DIR)
        files.append(rel)
        source = path.read_text(encoding='utf-8')
        explicit = EXPLICIT_NAME.search(source)
        modules = [(explicit.group(1).strip(), receiver_category('Dynamic'))] if explicit else logical_modules(source)
        overlays = logical_overlays(source)
        if rel.parts[0].lower() in OBSOLETE_DIRS:
            problems.append((str(rel), 'obsolete directory', modules, overlays))
        if modules and overlays:
            problems.append((str(rel), 'mixes module and overlay registrations', modules, overlays))
        elif len(modules) > 1:
            problems.append((str(rel), f'{len(modules)} unique modules in one file', modules, overlays))
        elif len(overlays) > 1:
            problems.append((str(rel), f'{len(overlays)} unique overlays in one file', modules, overlays))
        elif len(modules) == 0 and len(overlays) == 0:
            problems.append((str(rel), 'zero module/overlay registrations', modules, overlays))
        elif modules and path.stem.lower() != safe_stem(modules[0][0]):
            problems.append((str(rel), f'filename does not match module {modules[0][0]}', modules, overlays))
        elif overlays and path.stem.lower() != safe_stem(overlays[0]).replace(' ', '_'):
            if re.sub(r'[^a-z0-9]', '', path.stem.lower()) != re.sub(r'[^a-z0-9]', '', overlays[0].lower()):
                problems.append((str(rel), f'filename does not match overlay {overlays[0]}', modules, overlays))

    print(f'AUDIT_FILES={len(files)}')
    print(f'AUDIT_PROBLEMS={len(problems)}')
    for rel, problem, modules, overlays in problems:
        names = ', '.join(f'{name}[{category}]' for name, category in modules)
        if overlays: names += (', ' if names else '') + ', '.join(f'{name}[Overlay]' for name in overlays)
        print(f'PROBLEM|{rel}|{problem}|{names or "-"}')

    if '--report-only' not in sys.argv and problems:
        raise SystemExit(1)


if __name__ == '__main__':
    main()

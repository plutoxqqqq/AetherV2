#!/usr/bin/env python3
"""Split games/universal.lua into maintainable category modules.

The generated main.lua keeps all non-module/shared setup and replaces each module
block with a marker. bundle.lua restores those blocks in their original lexical
positions, so splitting does not change runtime scope or load order.
"""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'games' / 'universal.lua'
GAME_DIR = ROOT / 'games' / 'universal'
TEMPLATE = GAME_DIR / 'main.lua'
BUNDLE = GAME_DIR / 'bundle.lua'

RUN_START = re.compile(r'\brun\s*\(\s*function\s*\(\s*\)')
MODULE_CALL = re.compile(r'vape\s*\.\s*Categories\s*\.\s*([A-Za-z0-9_]+)\s*:\s*CreateModule\s*\(')
NAME_LITERAL = re.compile(r'\bName\s*=\s*([\'\"])(.*?)\1', re.S)


def mask_lua(source):
    out = list(source)
    i = 0
    n = len(source)

    def blank(a, b):
        for j in range(a, b):
            if out[j] not in '\r\n':
                out[j] = ' '

    def long_end(start):
        if start >= n or source[start] != '[':
            return None
        j = start + 1
        while j < n and source[j] == '=':
            j += 1
        if j >= n or source[j] != '[':
            return None
        close = ']' + '=' * (j - start - 1) + ']'
        end = source.find(close, j + 1)
        return n if end < 0 else end + len(close)

    while i < n:
        if source.startswith('--', i):
            lb = long_end(i + 2)
            if lb is not None:
                blank(i, lb); i = lb; continue
            e = source.find('\n', i + 2)
            e = n if e < 0 else e
            blank(i, e); i = e; continue
        if source[i] in "'\"":
            q = source[i]; j = i + 1
            while j < n:
                if source[j] == '\\': j += 2; continue
                if source[j] == q:
                    j += 1; break
                j += 1
            blank(i, min(j, n)); i = min(j, n); continue
        if source[i] == '[':
            lb = long_end(i)
            if lb is not None:
                blank(i, lb); i = lb; continue
        i += 1
    return ''.join(out)


def balanced_spans(masked, regex):
    spans = []
    for match in regex.finditer(masked):
        opening = masked.find('(', match.start(), match.end())
        depth = 0
        end = None
        for i in range(opening, len(masked)):
            if masked[i] == '(':
                depth += 1
            elif masked[i] == ')':
                depth -= 1
                if depth == 0:
                    end = i + 1
                    break
        if end is None:
            raise RuntimeError(f'Unclosed block near byte {match.start()}')
        spans.append((match.start(), end))
    return spans


def safe(value):
    value = re.sub(r'[^A-Za-z0-9_.-]+', '_', value).strip('._')
    return value or 'module'


def module_calls(source, masked):
    calls = []
    for m in MODULE_CALL.finditer(masked):
        snippet = source[m.start():min(len(source), m.end() + 1800)]
        nm = NAME_LITERAL.search(snippet)
        name = nm.group(2).strip() if nm else f'ModuleAt{m.start()}'
        calls.append({'pos': m.start(), 'category': m.group(1).lower(), 'name': name})
    return calls


def extract():
    source = SOURCE.read_text(encoding='utf-8')
    masked = mask_lua(source)
    spans = balanced_spans(masked, RUN_START)
    calls = module_calls(source, masked)
    if not calls:
        raise RuntimeError('No universal CreateModule registrations found')

    selected = []
    assignments = []
    for call in calls:
        containing = [s for s in spans if s[0] <= call['pos'] < s[1]]
        if containing:
            span = min(containing, key=lambda s: s[1] - s[0])
        else:
            m = MODULE_CALL.match(masked, call['pos'])
            if not m:
                raise RuntimeError(f'Could not parse standalone module {call["name"]}')
            opening = m.end() - 1
            depth = 0
            end = None
            for i in range(opening, len(masked)):
                if masked[i] == '(':
                    depth += 1
                elif masked[i] == ')':
                    depth -= 1
                    if depth == 0:
                        end = i + 1; break
            if end is None:
                raise RuntimeError(f'Unclosed standalone module {call["name"]}')
            span = (call['pos'], end)
        assignments.append((call, span))
        if span not in selected:
            selected.append(span)

    selected.sort()
    # Reject overlapping selected blocks: this would make a marker reconstruction ambiguous.
    for a, b in zip(selected, selected[1:]):
        if b[0] < a[1]:
            raise RuntimeError('Overlapping module blocks detected')

    GAME_DIR.mkdir(parents=True, exist_ok=True)
    for p in GAME_DIR.iterdir():
        if p.is_dir() and p.name not in {'.git'}:
            # Only remove generated category directories; preserve future shared helpers.
            if p.name not in {'shared'}:
                import shutil; shutil.rmtree(p)
    for p in (GAME_DIR / 'bundle.lua', GAME_DIR / 'structure.json'):
        if p.exists(): p.unlink()

    entries = []
    used = set()
    for number, span in enumerate(selected, 1):
        members = [c for c, s in assignments if s == span]
        if not members:
            continue
        keys = {(m['category'], m['name'].lower()) for m in members}
        if len(keys) != len(members):
            raise RuntimeError(f'Duplicate module registration inside block {number}')
        category = members[0]['category']
        if any(m['category'] != category for m in members):
            category = 'mixed'
        stem = safe(members[0]['name']) if len(members) == 1 else safe(members[0]['name']) + '__group'
        rel = Path(category) / f'{stem}.lua'
        key = str(rel).lower()
        if key in used:
            raise RuntimeError(f'Duplicate generated module path: {rel}')
        used.add(key)
        target = GAME_DIR / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(source[span[0]:span[1]], encoding='utf-8')
        entries.append({'start': span[0], 'end': span[1], 'path': rel.as_posix(), 'modules': members})

    out = []
    cursor = 0
    for e in entries:
        out.append(source[cursor:e['start']])
        out.append(f'--[[AETHER_UNIVERSAL_MODULE:{e["path"]}]]')
        cursor = e['end']
    out.append(source[cursor:])
    TEMPLATE.write_text(''.join(out), encoding='utf-8')

    build_bundle()
    manifest = {
        'generatedFrom': 'games/universal.lua',
        'moduleBlocks': len(entries),
        'moduleRegistrations': len(calls),
        'categories': sorted({c['category'] for c in calls}),
        'modules': [m for e in entries for m in e['modules']],
    }
    (GAME_DIR / 'structure.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print(f'Split {len(calls)} universal module registrations into {len(entries)} blocks across {len(manifest["categories"])} categories')


def build_bundle():
    template = TEMPLATE.read_text(encoding='utf-8')
    for marker in re.findall(r'--\[\[AETHER_UNIVERSAL_MODULE:([^\]]+)\]\]', template):
        path = GAME_DIR / marker
        if not path.exists():
            raise RuntimeError(f'Missing module source for {marker}')
        template = template.replace(f'--[[AETHER_UNIVERSAL_MODULE:{marker}]]', path.read_text(encoding='utf-8'), 1)
    BUNDLE.write_text(template, encoding='utf-8')


def write_entrypoint():
    wrapper = '''-- AetherV2 universal compatibility entrypoint. Source lives in games/universal/.
local function fetchBundle()
\tlocal path = 'aetherv2/games/universal/bundle.lua'
\tif type(shared.AetherV2FetchSource) == 'function' then
\t\tlocal ok, result = pcall(shared.AetherV2FetchSource, path)
\t\tif ok and type(result) == 'string' and result ~= '' then return result end
\tend
\tlocal commit = 'main'
\tpcall(function()
\t\tlocal saved = readfile('aetherv2/profiles/commit.txt')
\t\tif type(saved) == 'string' and saved ~= '' then commit = saved end
\tend)
\treturn game:HttpGet('https://raw.githubusercontent.com/plutoxqqqq/AetherV2/'..commit..'/games/universal/bundle.lua', true)
end
local source = fetchBundle()
local chunk, err = loadstring(source, 'games/universal/bundle.lua')
if not chunk then error(err) end
return chunk(...)
'''
    SOURCE.write_text(wrapper, encoding='utf-8')


if __name__ == '__main__':
    extract()
    write_entrypoint()
''
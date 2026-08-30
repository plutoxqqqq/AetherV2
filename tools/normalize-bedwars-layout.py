#!/usr/bin/env python3
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
BED = ROOT / 'games' / '6872274481'
MAIN = BED / 'main.lua'

RUN_START = re.compile(r'\brun\s*\(\s*function\s*\(\s*\)')
CREATE_ANY = re.compile(r'([A-Za-z_][A-Za-z0-9_\.]*|kits)\s*:\s*CreateModule\s*\(\s*\{', re.M)
REGISTER = re.compile(r'\bregister\s*\(\s*([\'\"])([^\'\"]+)\1\s*,\s*([\'\"])([^\'\"]+)\3\s*,\s*\{', re.M)
NAME = re.compile(r'\bName\s*=\s*([\'\"])(.*?)\1', re.S)

SPECIAL_CATEGORY = {
    'AutoEnchant': 'inventory',
    'AutoHonor': 'utility',
    'BedPlates': 'render',
    'Breaker': 'world',
    'ChillLighting': 'render',
}
CATEGORY_MAP = {'Visuals': 'render', 'Minigames': 'utility'}


def read(path): return path.read_text(encoding='utf-8')
def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(data, encoding='utf-8')


def safe_name(value):
    return re.sub(r'[^A-Za-z0-9_.-]+', '_', value).strip('._') or 'Module'


def run_spans(source):
    spans = []
    for match in RUN_START.finditer(source):
        opening = source.find('(', match.start(), match.end())
        depth, quote, escaped = 0, None, False
        i = opening
        while i < len(source):
            c = source[i]
            if quote:
                if escaped: escaped = False
                elif c == '\\': escaped = True
                elif c == quote: quote = None
                i += 1; continue
            if c in ('\'', '"', '`'):
                quote = c; i += 1; continue
            if source.startswith('--', i):
                nl = source.find('\n', i + 2)
                i = len(source) if nl < 0 else nl + 1
                continue
            if c == '(':
                depth += 1
            elif c == ')':
                depth -= 1
                if depth == 0:
                    spans.append((match.start(), i + 1))
                    break
            i += 1
    return spans


def top_level_runs(source):
    spans = run_spans(source)
    return [span for span in spans if not any(other[0] < span[0] and span[1] <= other[1] for other in spans)]


def modules(source):
    found = []
    for match in REGISTER.finditer(source):
        found.append((match.group(4).strip(), match.group(2).strip().lower()))
    for match in CREATE_ANY.finditer(source):
        snippet = source[match.end():match.end() + 1800]
        nm = NAME.search(snippet)
        if not nm: continue
        name = nm.group(2).strip()
        receiver = match.group(1)
        category = SPECIAL_CATEGORY.get(name)
        if not category:
            if receiver == 'kits': category = 'kits'
            elif receiver.startswith('vape.Categories.'):
                raw = receiver.rsplit('.', 1)[-1]
                category = CATEGORY_MAP.get(raw, raw.lower())
        found.append((name, category or 'utility'))
    out, seen = [], set()
    for name, category in found:
        if name.lower() not in seen:
            seen.add(name.lower()); out.append((name, category))
    return out


def marker(path): return '--[[AETHER_MODULE:' + path.replace('\\', '/') + ']]'


def replace_marker(old_path, new_paths):
    text = read(MAIN)
    old = marker(old_path)
    if old not in text:
        if all(marker(p) in text for p in new_paths): return
        raise RuntimeError('Missing marker ' + old_path)
    replacement = '\n'.join(marker(p) for p in new_paths)
    write(MAIN, text.replace(old, replacement, 1))


def split_run_batch(relative):
    path = BED / relative
    if not path.exists(): return
    source = read(path)
    entries, generated = [], []
    for start, end in top_level_runs(source):
        block = source[start:end]
        mods = modules(block)
        if len(mods) != 1:
            raise RuntimeError(f'{relative}: expected one module per top-level run, got {mods}')
        name, category = mods[0]
        target = f'{category}/{safe_name(name)}.lua'
        generated.append((target, block.rstrip() + '\n'))
        entries.append(target)
    if not entries:
        raise RuntimeError(f'{relative}: no top-level module runs')
    replace_marker(relative, entries)
    for target, block in generated:
        if target != relative:
            write(BED / target, block)
    same = next((block for target, block in generated if target == relative), None)
    if same is not None:
        write(path, same)
    elif path.exists():
        path.unlink()
    print(f'Split {relative} -> {len(entries)} files')


def smallest_run(source, needle):
    pos = source.find(needle)
    if pos < 0: raise RuntimeError('Missing ' + needle)
    spans = [s for s in run_spans(source) if s[0] <= pos < s[1]]
    if not spans: raise RuntimeError('No run block for ' + needle)
    return min(spans, key=lambda s: s[1] - s[0])


def split_group1():
    relative = 'mixed/HitregAdjuster__group1.lua'
    path = BED / relative
    if not path.exists(): return
    source = read(path)
    extracted = {}
    for name, target in [('HitregAdjuster', 'combat/HitregAdjuster.lua'), ('DeathAdderAimbot', 'blatant/DeathAdderAimbot.lua')]:
        span = smallest_run(source, "Name = '" + name + "'")
        block = source[span[0]:span[1]]
        extracted[target] = 'if canDebug then\n' + block + '\nend\n'
    reach = source
    for target, block in extracted.items():
        inner = block[len('if canDebug then\n'):-len('\nend\n')]
        reach = reach.replace(inner, '', 1)
        write(BED / target, block)
    write(BED / 'combat/Reach.lua', reach)
    replace_marker(relative, ['combat/HitregAdjuster.lua', 'blatant/DeathAdderAimbot.lua', 'combat/Reach.lua'])
    path.unlink()
    print('Split mixed group1')


def split_group2():
    relative = 'mixed/LongJump__group2.lua'
    path = BED / relative
    if not path.exists(): return
    source = read(path)
    split_at = source.find('    -- LongJumpBypass:')
    close = source.rfind('\nend)')
    if split_at < 0 or close < 0: raise RuntimeError('Could not split LongJump group')
    prefix = source[:split_at]
    bypass = source[split_at:close]
    runtime = '''    local api = {\n        Module = LongJump,\n        Methods = LongJumpMethods,\n        GetHeldMethod = heldLongJumpMethod,\n        GetJumpTick = function() return JumpTick end\n    }\n    shared.AetherLongJumpRuntime = api\n    vape:Clean(function() if shared.AetherLongJumpRuntime == api then shared.AetherLongJumpRuntime = nil end end)\n'''
    longjump = prefix + runtime + 'end)\n'
    write(BED / 'blatant/LongJump.lua', longjump)
    bypass = bypass.replace('heldLongJumpMethod()', 'runtime.GetHeldMethod()')
    bypass = bypass.replace('for name in LongJumpMethods do', 'for name in runtime.Methods do')
    bypass = bypass.replace('LongJump.Enabled', 'runtime.Module.Enabled')
    bypass = bypass.replace('LongJump:Toggle()', 'runtime.Module:Toggle()')
    bypass = bypass.replace('JumpTick > tick()', 'runtime.GetJumpTick() > tick()')
    bypass_source = '''run(function()\n    local runtime = shared.AetherLongJumpRuntime\n    if not runtime or not runtime.Module then warn('[AetherV2] LongJumpBypass requires LongJump runtime'); return end\n    local LongJumpBypass, BypassBoost\n''' + bypass + '\nend)\n'
    write(BED / 'exploits/LongJumpBypass.lua', bypass_source)
    replace_marker(relative, ['blatant/LongJump.lua', 'exploits/LongJumpBypass.lua'])
    path.unlink()
    print('Split mixed group2')


def balanced_call(source, start):
    opening = source.find('(', start)
    if opening < 0: raise RuntimeError('Missing call opening')
    depth, quote, escaped = 0, None, False
    i = opening
    while i < len(source):
        c = source[i]
        if quote:
            if escaped: escaped = False
            elif c == '\\': escaped = True
            elif c == quote: quote = None
            i += 1; continue
        if c in ('\'', '"', '`'): quote = c; i += 1; continue
        if source.startswith('--', i):
            nl = source.find('\n', i + 2); i = len(source) if nl < 0 else nl + 1; continue
        if c == '(': depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0: return i + 1
        i += 1
    raise RuntimeError('Unclosed call')


def split_autobuy():
    relative = 'inventory/AutoBuy__group4.lua'
    path = BED / relative
    if not path.exists(): return
    source = read(path)
    start = source.find('\tOpenShop = vape.Categories.Inventory:CreateModule({')
    if start < 0: raise RuntimeError('OpenShop block missing')
    end = balanced_call(source, start)
    open_block = source[start:end]
    auto = source[:start] + source[end:]
    final = auto.rfind('\nend)')
    if final < 0: raise RuntimeError('AutoBuy outer close missing')
    api = "\n\tlocal shopApi = {activateShop = activateShop, nearestItemShop = nearestItemShop}\n\tshared.AetherShopRuntime = shopApi\n\tvape:Clean(function() if shared.AetherShopRuntime == shopApi then shared.AetherShopRuntime = nil end end)\n"
    auto = auto[:final] + api + auto[final:]
    write(BED / 'inventory/AutoBuy.lua', auto)
    open_block = open_block.replace('activateShop(nearestItemShop())', 'runtime.activateShop(runtime.nearestItemShop())')
    open_source = "run(function()\n\tlocal runtime = shared.AetherShopRuntime\n\tif not runtime then warn('[AetherV2] OpenShop requires AutoBuy shop runtime'); return end\n\tlocal OpenShop\n" + open_block + "\nend)\n"
    write(BED / 'inventory/OpenShop.lua', open_source)
    replace_marker(relative, ['inventory/AutoBuy.lua', 'inventory/OpenShop.lua'])
    path.unlink()
    print('Split AutoBuy/OpenShop')


def move_obsolete():
    moves = {
        'visuals/ChillLighting.lua': ('render/ChillLighting.lua', "vape.Categories.Visuals", "vape.Categories.Render"),
        'minigames/AutoHonor.lua': ('utility/AutoHonor.lua', "vape.Categories.Minigames", "vape.Categories.Utility"),
        'minigames/BedPlates.lua': ('render/BedPlates.lua', "vape.Categories.Minigames", "vape.Categories.Render"),
        'minigames/Breaker.lua': ('world/Breaker.lua', "vape.Categories.Minigames", "vape.Categories.World"),
    }
    for old, (new, before, after) in moves.items():
        old_path = BED / old
        if not old_path.exists(): continue
        data = read(old_path).replace(before, after)
        write(BED / new, data)
        replace_marker(old, [new])
        old_path.unlink()
        print(f'Moved {old} -> {new}')
    for folder in ('visuals', 'minigames'):
        directory = BED / folder
        if directory.exists() and not any(directory.iterdir()): directory.rmdir()


def clean_category_aliases():
    text = read(MAIN)
    text = re.sub(r"\nif vape\.Categories and not vape\.Categories\.Visuals then\n\tvape\.Categories\.Visuals = vape\.Categories\.Render\nend\n", '\n', text, count=1)
    text = text.replace("local kits = vape.Categories.Kits or vape.Categories.Minigames\nif vape.Categories and not vape.Categories.Minigames then\n    vape.Categories.Minigames = vape.Categories.World or vape.Categories.Utility\nend\n", "local kits = vape.Categories.Kits\n")
    write(MAIN, text)


def update_structure():
    path = BED / 'structure.json'
    if not path.exists(): return
    data = json.loads(read(path))
    data['categories'] = ['blatant', 'combat', 'exploits', 'inventory', 'kits', 'legit', 'render', 'utility', 'world']
    data['layout'] = 'one-module-per-file'
    write(path, json.dumps(data, indent=2) + '\n')


def main():
    split_run_batch('utility/MP3Player.lua')
    split_group1()
    split_group2()
    split_autobuy()
    move_obsolete()
    clean_category_aliases()
    update_structure()
    print('Applied BedWars layout normalization')


if __name__ == '__main__': main()

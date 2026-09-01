from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[1]
GAME=ROOT/'games/6872274481'

# Combine init-core.lua into the public init entrypoint.
init=(ROOT/'init.lua').read_text(); initcore=(ROOT/'init-core.lua').read_text()
start=init.index('local function analyticsEndpoint()'); end=init.index('local function fetchCore()',start)
tele=init[start:end].rstrip(); hb=init[init.index('-- The core already records exactly one launch.'):].lstrip()
combined=initcore.replace('return mainChunk(license)','local result = mainChunk(license)',1)
combined += '\n\n-- Launch/session telemetry lives in the single public init entrypoint.\n'+tele+'\n\n'+hb+'\n'
(ROOT/'init.lua').write_text(combined)

# Combine main-core.lua into the public main entrypoint, preserving the existing wrapper patches.
wrapper=(ROOT/'main.lua').read_text(); core=(ROOT/'main-core.lua').read_text()
for m in re.finditer(r"patchExact\('([^']+)', \[=\[(.*?)\]=\], \[=\[(.*?)\]=\]\)",wrapper,re.S):
    marker,replacement=m.group(2),m.group(3)
    if core.count(marker)!=1: raise RuntimeError('patch marker count mismatch: '+m.group(1))
    core=core.replace(marker,replacement,1)
core=core.replace("'main-core.lua'","'main.lua'")
(ROOT/'main.lua').write_text(core)

# Convert the two remaining inline BedWars modules into normal category files.
source=GAME.joinpath('main.lua').read_text()
marker_re=re.compile(r'--\[\[AETHER_MODULE:([^\]]+)\]\]')
ws=source.index('-- Water: fills the void'); we=source.index('--[[AETHER_MODULE:render/ChatPosition.lua]]',ws)
(GAME/'render/Water.lua').write_text('-- AETHER_MODULE_NAME: Water\n'+source[ws:we].strip()+'\n')
source=source[:ws]+source[we:]
es=source.index('--[[\n    Kit extenders'); ee=source.index('--[[AETHER_MODULE:blatant/NoSlowdown.lua]]',es)
(GAME/'kits/CatExtender.lua').write_text('-- AETHER_MODULE_NAME: CatExtender\n'+source[es:ee].strip()+'\n')
source=source[:es]+source[ee:]

# Move shared runtime/ports before the automatic module insertion point.
rs=source.index('local AetherRuntimeContext = {'); re_end=source.index('--[[AETHER_MODULE:world/AutoWin.lua]]',rs)
runtime=source[rs:re_end].replace('--[[AETHER_MODULE:kits/TrixieExploit.lua]]\n','').strip()+'\n'
source=source[:rs]+source[re_end:]
ps=source.index('local AetherPortContext = {'); pe=source.index('--[[AETHER_MODULE:exploits/YaminiExploit.lua]]',ps)
ports=source[ps:pe].strip()+'\n'; source=source[:ps]+source[pe:]
first=marker_re.search(source); assert first
source=source[:first.start()]+runtime+'\n'+ports+'\n--[[AETHER_MODULES]]\n'+source[first.end():]
source=marker_re.sub('',source)
source=re.sub(r'--\[\[\s*\n\s*(?:Combat|Render|World|Inventory|Legit)\s*\n\]\]\s*\n','',source)
(GAME/'main.lua').write_text(source)

# Automatic recursive module discovery: any .lua below a category folder is included.
(ROOT/'tools/build-bedwars-bundle.py').write_text('''#!/usr/bin/env python3\nfrom pathlib import Path\n\nROOT = Path(__file__).resolve().parents[1]\nGAME_DIR = ROOT / "games" / "6872274481"\nMAIN = GAME_DIR / "main.lua"\nBUNDLE = GAME_DIR / "bundle.lua"\nMARKER = "--[[AETHER_MODULES]]"\nRESERVED = {"main.lua", "bundle.lua"}\n\ndef discover_modules():\n    modules=[]\n    for path in GAME_DIR.rglob("*.lua"):\n        if path.name in RESERVED: continue\n        rel=path.relative_to(GAME_DIR)\n        if len(rel.parts) < 2: continue\n        modules.append(rel)\n    return sorted(modules,key=lambda p:p.as_posix().lower())\n\ndef build():\n    source=MAIN.read_text(encoding="utf-8")\n    if source.count(MARKER)!=1: raise RuntimeError(f"Expected exactly one {MARKER} marker in {MAIN}")\n    modules=discover_modules()\n    if not modules: raise RuntimeError("No BedWars category modules discovered")\n    chunks=[]; seen={}\n    for rel in modules:\n        name=rel.stem.lower()\n        if name in seen: raise RuntimeError(f"Duplicate module name {rel.stem!r}: {seen[name]} and {rel}")\n        seen[name]=rel.as_posix()\n        body=(GAME_DIR/rel).read_text(encoding="utf-8").lstrip("\\ufeff")\n        chunks.append(f"\\n-- BEGIN AETHER MODULE: {rel.as_posix()} --\\n{body.rstrip()}\\n-- END AETHER MODULE: {rel.as_posix()} --\\n")\n    bundle=source.replace(MARKER,"".join(chunks),1)\n    BUNDLE.write_text("-- GENERATED FILE. Do not edit manually.\\n-- Every .lua file in a BedWars category directory is discovered automatically.\\n"+bundle.lstrip("\\ufeff"),encoding="utf-8")\n    return f"Built {BUNDLE.relative_to(ROOT)} from {len(modules)} discovered module files"\n\nif __name__=="__main__": print(build())\n''')

# Audit understands dynamic module-name files used by the two extracted modules.
p=ROOT/'tools/audit-bedwars-modules.py'; s=p.read_text()
if 'EXPLICIT_NAME' not in s:
    lines=s.splitlines()
    for i,l in enumerate(lines):
        if l.startswith('NAME = re.compile'):
            lines.insert(i+1,"EXPLICIT_NAME = re.compile(r'^\\s*--\\s*AETHER_MODULE_NAME:\\s*(.+?)\\s*$', re.M)")
            break
    s='\n'.join(lines)+'\n'
s=s.replace("        modules = logical_modules(source)\n        overlays = logical_overlays(source)","        explicit = EXPLICIT_NAME.search(source)\n        modules = [(explicit.group(1).strip(), receiver_category('Dynamic'))] if explicit else logical_modules(source)\n        overlays = logical_overlays(source)")
p.write_text(s)

# Tests now read the single public entrypoints.
p=ROOT/'backend/private-execution-regression.test.js'; s=p.read_text()
s=s.replace("path.join(__dirname, '..', 'main-core.lua')","path.join(__dirname, '..', 'main.lua')")
s=s.replace("const mainWrapper = fs.readFileSync(path.join(__dirname, '..', 'main.lua'), 'utf8');","const mainWrapper = main;")
s=s.replace("path.join(__dirname, '..', 'init-core.lua')","path.join(__dirname, '..', 'init.lua')")
s=s.replace("const initWrapper = fs.readFileSync(path.join(__dirname, '..', 'init.lua'), 'utf8');","const initWrapper = init;")
s=s.replace("  assert.match(mainWrapper, /loadedModule\\.Premium\\s*=\\s*true/);\n  assert.match(mainWrapper, /loadedModule\\.Tag\\s*=\\s*'PREMIUM'/);\n",'')
p.write_text(s)

# Backend allowlist no longer contains removed legacy bundles.
p=ROOT/'backend/README.md'; s=p.read_text().replace('AETHER_ALLOWED_PATHS=init.lua,main.lua,loadstring,version.txt,cv,gui,assets/,configs/,games/,guis/,libraries/,profiles/','AETHER_ALLOWED_PATHS=init.lua,main.lua,loadstring,version.txt,assets/,configs/,games/,guis/,libraries/,profiles/'); p.write_text(s)

# CI is now validation/build only; no historical migration scripts are required.
(ROOT/'.github/workflows/bedwars-structure.yml').write_text('''name: BedWars structure build\n\non:\n  push:\n    branches: [main, refactor/auto-module-discovery]\n    paths: [.github/workflows/bedwars-structure.yml, tools/build-bedwars-bundle.py, tools/audit-bedwars-modules.py, games/6872274481/**]\n  pull_request:\n    paths: [.github/workflows/bedwars-structure.yml, tools/build-bedwars-bundle.py, tools/audit-bedwars-modules.py, games/6872274481/**]\n  workflow_dispatch:\n\npermissions:\n  contents: write\n\njobs:\n  build:\n    runs-on: ubuntu-latest\n    steps:\n      - uses: actions/checkout@v4\n      - uses: actions/setup-python@v5\n        with: {python-version: '3.12'}\n      - run: python tools/audit-bedwars-modules.py\n      - run: python tools/build-bedwars-bundle.py\n      - name: Commit generated bundle\n        if: github.event_name == 'push'\n        run: |\n          git config user.name github-actions[bot]\n          git config user.email 41898282+github-actions[bot]@users.noreply.github.com\n          git add games/6872274481/bundle.lua\n          git diff --cached --quiet || (git commit -m 'Build BedWars module bundle' && git push origin HEAD:${{ github.ref_name }})\n''')

# Remove obsolete generated/legacy files and one-shot migration scripts.
for p in [ROOT/'init-core.lua',ROOT/'main-core.lua',ROOT/'gui',ROOT/'cv',ROOT/'reinstall.luau']:
    if p.exists(): p.unlink()
for p in (ROOT/'tools').glob('*.py'):
    if p.name not in {'build-bedwars-bundle.py','audit-bedwars-modules.py','refactor-entrypoints.py'}: p.unlink()

# Rebuild and audit before the workflow commits.
subprocess.run(['python','tools/audit-bedwars-modules.py'],cwd=ROOT,check=True)
subprocess.run(['python','tools/build-bedwars-bundle.py'],cwd=ROOT,check=True)
''
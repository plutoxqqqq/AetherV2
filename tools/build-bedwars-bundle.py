#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAME_DIR = ROOT / "games" / "6872274481"
MAIN = GAME_DIR / "main.lua"
BUNDLE = GAME_DIR / "bundle.lua"
MARKER = "--[[AETHER_MODULES]]"
RESERVED = {"main.lua", "bundle.lua"}

def discover_modules():
    modules=[]
    for path in GAME_DIR.rglob("*.lua"):
        if path.name in RESERVED: continue
        rel=path.relative_to(GAME_DIR)
        if len(rel.parts) < 2: continue
        modules.append(rel)
    return sorted(modules,key=lambda p:p.as_posix().lower())

def build():
    source=MAIN.read_text(encoding="utf-8")
    if source.count(MARKER)!=1: raise RuntimeError(f"Expected exactly one {MARKER} marker in {MAIN}")
    modules=discover_modules()
    if not modules: raise RuntimeError("No BedWars category modules discovered")
    chunks=[]; seen={}
    for rel in modules:
        name=rel.stem.lower()
        if name in seen: raise RuntimeError(f"Duplicate module name {rel.stem!r}: {seen[name]} and {rel}")
        seen[name]=rel.as_posix()
        body=(GAME_DIR/rel).read_text(encoding="utf-8").lstrip("\ufeff")
        chunks.append(f"\n-- BEGIN AETHER MODULE: {rel.as_posix()} --\n{body.rstrip()}\n-- END AETHER MODULE: {rel.as_posix()} --\n")
    bundle=source.replace(MARKER,"".join(chunks),1)
    BUNDLE.write_text("-- GENERATED FILE. Do not edit manually.\n-- Every .lua file in a BedWars category directory is discovered automatically.\n"+bundle.lstrip("\ufeff"),encoding="utf-8")
    return f"Built {BUNDLE.relative_to(ROOT)} from {len(modules)} discovered module files"

if __name__=="__main__": print(build())

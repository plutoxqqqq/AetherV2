#!/usr/bin/env python3
"""Split AetherV2 game monoliths into Vape V4-style module files."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GAMES = ROOT / "games"

NAME_RE = [
    re.compile(r"vape\.Categories\.(\w+):CreateModule\(\{\s*Name\s*=\s*'([^']+)'", re.S),
    re.compile(r'vape\.Categories\.(\w+):CreateModule\(\{\s*Name\s*=\s*"([^"]+)"', re.S),
    re.compile(r"register\('(\w+)',\s*'([^']+)'"),
]

CAT_MAP = {
    "blatant": "Blatant",
    "combat": "Combat",
    "legit": "Legit",
    "render": "Render",
    "utility": "Utility",
    "world": "World",
    "inventory": "Inventory",
    "exploits": "Exploits",
    "kits": "Kits",
}


def safe_name(name: str) -> str:
    return re.sub(r"[^A-Za-z0-9_\-]+", "", name) or "module"


def classify(chunk: str):
    for pattern in NAME_RE:
        match = pattern.search(chunk)
        if match:
            return match.group(1), match.group(2)
    return None, None


def category_folder(cat: str) -> str:
    key = (cat or "").lower()
    if key in CAT_MAP:
        return CAT_MAP[key]
    return cat[:1].upper() + cat[1:] if cat else "Shared"


def split_monolith(src: Path, dest: Path) -> int:
    text = src.read_text(errors="replace")
    dest.mkdir(parents=True, exist_ok=True)
    starts = [m.start() for m in re.finditer(r"(?m)^run\(function\(", text)]
    blocks = []
    for i, start in enumerate(starts):
        end = starts[i + 1] if i + 1 < len(starts) else len(text)
        chunk = text[start:end]
        cat, name = classify(chunk)
        blocks.append((start, end, cat, name, chunk))

    first = next((i for i, block in enumerate(blocks) if block[2] and block[3]), None)
    if first is None:
        (dest / "base.lua").write_text(text)
        (dest / "files.txt").write_text("base.lua\n")
        return 0

    (dest / "base.lua").write_text(text[: blocks[first][0]].rstrip() + "\n")
    files = ["base.lua"]
    used: dict[str, int] = {}
    current_rel = None
    parts: list[str] = []

    def flush() -> None:
        nonlocal current_rel, parts
        if not current_rel:
            return
        path = dest / current_rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("".join(parts).rstrip() + "\n")
        files.append(current_rel)
        parts = []

    for _, _, cat, name, chunk in blocks[first:]:
        if cat and name:
            flush()
            rel = f"{category_folder(cat)}/{safe_name(name)}.lua"
            count = used.get(rel, 0)
            if count:
                rel = f"{category_folder(cat)}/{safe_name(name)}{count + 1}.lua"
            used[rel] = count + 1
            current_rel = rel
            parts = [chunk]
        elif current_rel:
            parts.append(chunk)
        else:
            current_rel = "Shared/extra.lua"
            parts = [chunk]
    flush()
    (dest / "files.txt").write_text("\n".join(files) + "\n")
    return len(files) - 1


def main() -> None:
    mapping = {
        GAMES / "universal.lua": GAMES / "universal",
        GAMES / "6872274481.lua": GAMES / "6872274481",
    }
    for src, dest in mapping.items():
        if not src.exists():
            print(f"skip missing {src}")
            continue
        count = split_monolith(src, dest)
        print(f"split {src.name} -> {dest} ({count} modules)")
        placeholder = dest / "blatant" / "x.lua"
        if placeholder.exists():
            placeholder.unlink()


if __name__ == "__main__":
    main()

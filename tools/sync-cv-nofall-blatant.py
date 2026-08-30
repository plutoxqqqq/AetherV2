#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'games' / '6872274481' / 'blatant' / 'NoFallDamage.lua'
text = PATH.read_text(encoding='utf-8')

# cv's NoFall has a Damage 0-100% control that shifts the intervention threshold
# from -45 down to -(45 + Damage * 0.75). Keep that behavior exactly on Blatant.
if '    local CvDamage\n' not in text:
    text = text.replace('    local DamagePercent\n', '    local DamagePercent\n    local CvDamage\n', 1)

text = text.replace(
    '            if trackedVelocity < -45 then',
    '            if trackedVelocity < -(45 + ((CvDamage and CvDamage.Value or 0) * 0.75)) then',
    1
)

# Blatant-only cv option visibility; all Aether clutch settings remain Legit-only.
needle = "        local legit = Mode and Mode.Value == 'Legit'\n"
if needle in text and "CvDamage.Object.Visible" not in text:
    text = text.replace(
        needle,
        needle + "        if CvDamage and CvDamage.Object then CvDamage.Object.Visible = not legit end\n",
        1
    )

slider_marker = "    MinVelocity = NoFall:CreateSlider({\n"
if "CvDamage = NoFall:CreateSlider({" not in text:
    slider = """    CvDamage = NoFall:CreateSlider({
        Name = 'Damage',
        Min = 0,
        Max = 100,
        Default = 0,
        Suffix = '%',
        Tooltip = 'Blatant only: matches cv NoFallDamage damage percentage behavior'
    })
"""
    if slider_marker not in text:
        raise RuntimeError('Could not find NoFall minimum velocity slider')
    text = text.replace(slider_marker, slider + slider_marker, 1)

# Final invariants: exactly two modes, no V2 runtime, cv threshold present.
required = [
    "List = {'Blatant', 'Legit'}",
    "Mode.Value == 'Blatant'",
    "Mode.Value == 'Legit'",
    "CvDamage = NoFall:CreateSlider({",
    "-(45 + ((CvDamage and CvDamage.Value or 0) * 0.75))",
    "groundHit.Fire",
    "StateChanged"
]
for item in required:
    if item not in text:
        raise RuntimeError('Missing expected NoFall behavior: ' + item)
for forbidden in ("Mode.Value == 'V2'", "startV2(", "'Blatant', 'V2', 'Legit'"):
    if forbidden in text:
        raise RuntimeError('V2 residue remains: ' + forbidden)

PATH.write_text(text, encoding='utf-8')
print('Synced cv NoFallDamage Blatant behavior, including Damage %, while preserving Aether Legit')

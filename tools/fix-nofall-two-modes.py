#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PATH = ROOT / 'games' / '6872274481' / 'blatant' / 'NoFallDamage.lua'

text = PATH.read_text(encoding='utf-8')

# Remove the former NoFallDamageV2 runtime completely. Blatant remains the cv path;
# Legit remains Aether's existing clutch implementation.
start = text.find('    local function startV2(generation)')
end = text.find('    local function setSettingsVisible()', start)
if start != -1:
    if end == -1:
        raise RuntimeError('Could not find end of V2 runtime')
    text = text[:start] + text[end:]

text = text.replace('    local v2Busy = false\n', '')
text = text.replace('                v2Busy = false\n\n', '')
text = text.replace('                v2Busy = false\n', '')
text = text.replace("                elseif Mode.Value == 'V2' then\n                    startV2(generation)\n", '')
text = text.replace("List = {'Blatant', 'V2', 'Legit'}", "List = {'Blatant', 'Legit'}")
text = text.replace(
    "Tooltip = 'Prevents fall damage. Blatant uses cv; V2 preserves the previous landed-state method; Legit keeps Aether clutch logic.'",
    "Tooltip = 'Prevents fall damage. Blatant uses cv NoFallDamage behavior; Legit keeps Aether clutch logic.'"
)
text = text.replace(
    "Tooltip = 'Blatant - cv landed/GroundHit behaviour\\nV2 - previous Aether landed-state velocity method\\nLegit - Aether clutch logic'",
    "Tooltip = 'Blatant - cv NoFallDamage behavior\\nLegit - Aether clutch logic'"
)
text = text.replace(
    "Tooltip = 'How fast the drop has to be before Legit uses a clutch. Blatant and V2 ignore it'",
    "Tooltip = 'How fast the drop has to be before Legit uses a clutch. Blatant ignores it'"
)

# Guard against the V2 implementation leaking back into the module.
for forbidden in ("Mode.Value == 'V2'", "startV2(", "local v2Busy", "'Blatant', 'V2', 'Legit'"):
    if forbidden in text:
        raise RuntimeError('V2 residue remains: ' + forbidden)

if "List = {'Blatant', 'Legit'}" not in text:
    raise RuntimeError('Expected Blatant/Legit mode list not found')
if "Mode.Value == 'Blatant'" not in text or "Mode.Value == 'Legit'" not in text:
    raise RuntimeError('Expected Blatant/Legit runtime branches not found')
if "groundHit" not in text or "StateChanged" not in text:
    raise RuntimeError('cv Blatant path appears to be missing')

PATH.write_text(text, encoding='utf-8')
print('NoFallDamage now has only cv Blatant + Aether Legit modes')

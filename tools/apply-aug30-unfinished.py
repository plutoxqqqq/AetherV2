#!/usr/bin/env python3
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
BED = ROOT / 'games' / '6872274481'
CV = ROOT / 'cv'
UNIVERSAL = ROOT / 'games' / 'universal.lua'
ENTITY = ROOT / 'libraries' / 'entity.lua'


def read(path):
    return path.read_text(encoding='utf-8')


def write(path, text):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding='utf-8')


def mask_lua(source):
    out = list(source)
    length = len(source)
    i = 0

    def blank(start, end):
        for index in range(start, end):
            if out[index] not in ('\n', '\r'):
                out[index] = ' '

    def long_bracket(start):
        if start >= length or source[start] != '[':
            return None
        j = start + 1
        while j < length and source[j] == '=':
            j += 1
        if j >= length or source[j] != '[':
            return None
        close = ']' + ('=' * (j - start - 1)) + ']'
        end = source.find(close, j + 1)
        return length if end == -1 else end + len(close)

    while i < length:
        if source.startswith('--', i):
            lb = long_bracket(i + 2)
            if lb is not None:
                blank(i, lb)
                i = lb
                continue
            end = source.find('\n', i + 2)
            if end == -1:
                end = length
            blank(i, end)
            i = end
            continue
        if source[i] in ('\'', '"'):
            quote = source[i]
            j = i + 1
            while j < length:
                if source[j] == '\\':
                    j += 2
                    continue
                if source[j] == quote:
                    j += 1
                    break
                j += 1
            blank(i, min(j, length))
            i = min(j, length)
            continue
        if source[i] == '[':
            lb = long_bracket(i)
            if lb is not None:
                blank(i, lb)
                i = lb
                continue
        i += 1
    return ''.join(out)


RUN_START = re.compile(r'\brun\s*\(\s*function\s*\(\s*\)')


def run_spans(source):
    masked = mask_lua(source)
    spans = []
    for match in RUN_START.finditer(masked):
        opening = masked.find('(', match.start(), match.end())
        depth = 0
        end = None
        for index in range(opening, len(masked)):
            char = masked[index]
            if char == '(':
                depth += 1
            elif char == ')':
                depth -= 1
                if depth == 0:
                    end = index + 1
                    break
        if end is None:
            raise RuntimeError('Unclosed run(function()) near byte ' + str(match.start()))
        spans.append((match.start(), end))
    return spans


def extract_run(source, marker):
    pos = source.find(marker)
    if pos < 0:
        raise RuntimeError('Could not find reference marker: ' + marker)
    containing = [span for span in run_spans(source) if span[0] <= pos < span[1]]
    if not containing:
        raise RuntimeError('Reference marker is not inside run(function()): ' + marker)
    start, end = min(containing, key=lambda span: span[1] - span[0])
    return source[start:end]


def replace_run(source, marker, replacement):
    pos = source.find(marker)
    if pos < 0:
        if replacement in source:
            return source
        raise RuntimeError('Could not find existing module marker: ' + marker)
    containing = [span for span in run_spans(source) if span[0] <= pos < span[1]]
    if not containing:
        raise RuntimeError('Existing module marker is not inside run(function()): ' + marker)
    start, end = min(containing, key=lambda span: span[1] - span[0])
    return source[:start] + replacement + source[end:]


def ensure_module_marker(main, relative):
    marker = '--[[AETHER_MODULE:' + relative + ']]'
    if marker in main:
        return main
    first = main.find('--[[AETHER_MODULE:')
    if first < 0:
        raise RuntimeError('BedWars template has no module markers')
    return main[:first] + marker + '\n' + main[first:]


def port_cv_modules():
    cv = read(CV)
    ports = {
        "Name = 'AntiEffect'": 'utility/AntiEffect.lua',
        "Name = 'MemoryFixer'": 'utility/MemoryFixer.lua',
        "Name = 'NoClickDelay'": 'combat/NoClickDelay.lua',
        "Name = 'Hit Accuracy'": 'render/HitAccuracy.lua'
    }
    main_path = BED / 'main.lua'
    main = read(main_path)
    for marker, relative in ports.items():
        block = extract_run(cv, marker)
        if relative == 'utility/MemoryFixer.lua':
            block = block.replace('for _, event in bedwars.SyncEvents do', 'for _, event in bedwars.SyncEvents or {} do')
        if relative == 'render/HitAccuracy.lua':
            block = block.replace("getvapeasset('catsix/assets/new/aim.png')", "getcustomasset('aetherv2/assets/new/targetinfoicon.png')")
            block = block.replace('getfontbounds', 'getfontsize')
        write(BED / relative, block)
        main = ensure_module_marker(main, relative)
    write(main_path, main)


def patch_hit_accuracy_shared():
    path = BED / 'main.lua'
    text = read(path)
    if 'hitchance = {}' not in text:
        marker = '\tselfProjectiles = {},\n'
        if marker not in text:
            raise RuntimeError('Could not locate BedWars store selfProjectiles field')
        text = text.replace(marker, marker + '\thitchance = {},\n', 1)

    if 'local function getHitChance(ent, flight)' not in text:
        marker = 'local function projectileAcceleration(gravity)\n'
        helper = '''local hitMotion = setmetatable({}, {__mode = 'k'})
local function getHitChance(ent, flight)
\tflight = tonumber(flight)
\tlocal root = ent and ent.RootPart
\tif not root or not root.Parent or not flight or flight <= 0 or flight ~= flight then return 0 end
\tlocal now = tick()
\tlocal velocity = root.AssemblyLinearVelocity
\tlocal horizontal = (velocity * Vector3.new(1, 0, 1)).Magnitude
\tlocal last = hitMotion[root]
\tlocal acceleration = 0
\tif last and now > last.Clock then
\t\tacceleration = ((velocity - last.Velocity) / math.max(now - last.Clock, 1 / 240)).Magnitude
\tend
\thitMotion[root] = {Velocity = velocity, Clock = now}
\tlocal airborne = ent.Humanoid and ent.Humanoid.FloorMaterial == Enum.Material.Air
\tlocal errorBudget = (horizontal * flight * 0.28) + (acceleration * flight * flight * 0.12)
\tif airborne then errorBudget += math.abs(velocity.Y) * flight * 0.12 end
\treturn math.clamp(math.round(100 - errorBudget), 0, 100)
end

'''
        if marker not in text:
            raise RuntimeError('Could not locate projectileAcceleration helper')
        text = text.replace(marker, helper + marker, 1)
    write(path, text)


def target_part_helper(name):
    return f'''\n\tlocal function {name}(ent, requested, projectileType)\n\t\tlocal character = ent and ent.Character\n\t\tlocal root = ent and (ent.RootPart or ent.HumanoidRootPart) or character and character.PrimaryPart\n\t\tif not character then return root end\n\t\tlocal function first(...)\n\t\t\tfor index = 1, select('#', ...) do\n\t\t\t\tlocal partName = select(index, ...)\n\t\t\t\tlocal part = partName and character:FindFirstChild(partName)\n\t\t\t\tif part and part:IsA('BasePart') then return part end\n\t\t\tend\n\t\t\treturn root\n\t\tend\n\t\tif requested == 'Dynamic' then\n\t\t\trequested = tostring(projectileType or ''):lower():find('headhunter', 1, true) and 'Head' or 'RootPart'\n\t\tend\n\t\tif requested == 'Head' then return first('Head') end\n\t\tif requested == 'Torso' then return first('UpperTorso', 'Torso', 'LowerTorso') end\n\t\tif requested == 'Left arm' then return first('LeftHand', 'LeftLowerArm', 'LeftUpperArm', 'Left Arm') end\n\t\tif requested == 'Right arm' then return first('RightHand', 'RightLowerArm', 'RightUpperArm', 'Right Arm') end\n\t\tif requested == 'Left leg' then return first('LeftFoot', 'LeftLowerLeg', 'LeftUpperLeg', 'Left Leg') end\n\t\tif requested == 'Right leg' then return first('RightFoot', 'RightLowerLeg', 'RightUpperLeg', 'Right Leg') end\n\t\tif requested == 'Random' then\n\t\t\tlocal available = {{first('Head'), first('UpperTorso', 'Torso'), first('LeftHand', 'Left Arm'), first('RightHand', 'Right Arm'), first('LeftFoot', 'Left Leg'), first('RightFoot', 'Right Leg')}}\n\t\t\tlocal filtered = {{}}\n\t\t\tfor _, part in available do if part and part ~= root then table.insert(filtered, part) end end\n\t\t\treturn #filtered > 0 and filtered[math.random(1, #filtered)] or root\n\t\tend\n\t\treturn root\n\tend\n'''


def patch_projectile_aiming():
    # ProjectileAimbot keeps Aether's launch hook/solver and only gains the richer target-part selector.
    path = BED / 'blatant' / 'ProjectileAimbot.lua'
    text = read(path)
    if 'resolveProjectileAimbotPart' not in text:
        marker = '\tlocal launchHook\n'
        text = text.replace(marker, marker + target_part_helper('resolveProjectileAimbotPart'), 1)
    text = text.replace("\t\t\t\t\tlocal targetPart = plr[TargetPart.Value]\n", "\t\t\t\t\tlocal targetPart = resolveProjectileAimbotPart(plr, TargetPart.Value, projectileType)\n", 1)
    text = text.replace("\t\tList = {'RootPart', 'Head'}\n", "\t\tList = {'RootPart', 'Head', 'Torso', 'Left arm', 'Right arm', 'Left leg', 'Right leg', 'Random', 'Dynamic'}\n", 1)
    chance_line = "\t\t\t\t\t\t\tstore.hitchance.ProjectileAimbot = {Value = getHitChance(plr, (targetPart.Position - origin).Magnitude / math.max(speed, 1)), Clock = tick()}\n"
    anchor = '\t\t\t\t\t\tif solution then\n'
    if chance_line not in text:
        text = text.replace(anchor, anchor + chance_line, 1)
    write(path, text)

    # SilentAim: preserve its stronger launch hook while expanding the same part behaviour.
    path = BED / 'combat' / 'SilentAim.lua'
    text = read(path)
    if 'resolveSilentAimPart' not in text:
        marker = '\tlocal launchHook\n'
        text = text.replace(marker, marker + target_part_helper('resolveSilentAimPart'), 1)
    old = '''\tlocal function getPosition(ent)\n\t\tif TargetPart.Value == 'Closest' then\n'''
    if old in text:
        text = text.replace(old, '''\tlocal function getPosition(ent, projectileType)\n\t\tif TargetPart.Value == 'Closest' then\n''', 1)
        text = text.replace("\t\telseif TargetPart.Value == 'Dynamic' then\n\t\t\tlocal tool = store.hand.tool\n\t\t\tif tool and tool.Name:find('headhunter') and ent:FindFirstChild('Head') then\n\t\t\t\treturn ent.Head.Position\n\t\t\tend\n\t\t\treturn ent.PrimaryPart and ent.PrimaryPart.Position\n\t\tend\n\t\treturn\n\tend\n", "\t\tend\n\t\tlocal wrapper = entitylib.getEntity and select(1, entitylib.getEntity(ent)) or nil\n\t\tlocal part = resolveSilentAimPart(wrapper or {Character = ent, RootPart = ent.PrimaryPart}, TargetPart.Value, projectileType)\n\t\treturn part and part.Position or ent.PrimaryPart and ent.PrimaryPart.Position\n\tend\n", 1)
    text = text.replace('local targetpos = getPosition(plr.Character) or targetpart and targetpart.Position', 'local targetpos = getPosition(plr.Character, projType) or targetpart and targetpart.Position', 1)
    text = text.replace("\t\tList = {'RootPart', 'Head', 'Dynamic', 'Closest'},\n", "\t\tList = {'RootPart', 'Head', 'Torso', 'Left arm', 'Right arm', 'Left leg', 'Right leg', 'Random', 'Dynamic', 'Closest'},\n", 1)
    chance = "\t\tstore.hitchance.SilentAim = {Value = getHitChance(plr, (targetpos - origin).Magnitude / math.max(speed, 1)), Clock = tick()}\n"
    anchor = '\t\tif not solution then return end\n\n'
    if chance not in text:
        text = text.replace(anchor, anchor + chance, 1)
    write(path, text)

    # ProjectileAura gets the same selector instead of being permanently root-only.
    path = BED / 'blatant' / 'ProjectileAura.lua'
    text = read(path)
    if 'local Part\n' not in text:
        text = text.replace('\tlocal Range\n', '\tlocal Range\n\tlocal Part\n', 1)
    if 'resolveProjectileAuraPart' not in text:
        marker = '\tlocal generation = 0\n'
        text = text.replace(marker, marker + target_part_helper('resolveProjectileAuraPart'), 1)
    old = "\t\t\t\t\t\t\tlocal now = workspace:GetServerTimeNow()\n"
    new = old + "\t\t\t\t\t\t\tlocal aimPart = resolveProjectileAuraPart(ent, Part.Value, projectile)\n\t\t\t\t\t\t\tif not aimPart then continue end\n"
    if 'local aimPart = resolveProjectileAuraPart' not in text:
        text = text.replace(old, new, 1)
    text = text.replace('ent, ent.RootPart.Position, {', 'ent, aimPart.Position, {')
    chance = "\t\t\t\t\t\t\t\t\tstore.hitchance.ProjectileAura = {Value = getHitChance(ent, (aimPart.Position - shootPosition).Magnitude / math.max(speed, 1)), Clock = tick()}\n"
    anchor = '\t\t\t\t\t\t\t\tif solution then\n'
    if chance not in text:
        text = text.replace(anchor, anchor + chance, 1)
    if "Part = ProjectileAura:CreateDropdown" not in text:
        marker = "\tList = ProjectileAura:CreateTextList({\n"
        option = "\tPart = ProjectileAura:CreateDropdown({\n\t\tName = 'Part',\n\t\tList = {'RootPart', 'Head', 'Torso', 'Left arm', 'Right arm', 'Left leg', 'Right leg', 'Random', 'Dynamic'},\n\t\tDefault = 'Dynamic',\n\t\tTooltip = 'Dynamic uses Head for headhunters and the body/root for other projectiles'\n\t})\n"
        text = text.replace(marker, option + marker, 1)
    write(path, text)


def patch_fpsboost():
    path = BED / 'legit' / 'FPSBoost.lua'
    text = read(path)
    # Preserve Aether's reversible profile implementation, but add the useful cv-style late visual cuts.
    text = text.replace("'Projectile effects'},\n\t\tPotato", "'Projectile effects', 'Lights', 'Atmosphere'},\n\t\tPotato", 1)
    text = text.replace("'Textures', 'Materials', 'Lighting'},", "'Textures', 'Materials', 'Lighting', 'Lights', 'Atmosphere'},", 1)
    if "selected('Lights')" not in text:
        marker = "    local function applyObject(object)\n"
        insertion = "    local function applyObject(object)\n        if object:IsDescendantOf(coreGui) or (lplr.PlayerGui and object:IsDescendantOf(lplr.PlayerGui)) then return end\n"
        text = text.replace(marker, insertion, 1)
        marker = "        if selected('Weather') and (object:GetAttribute('WeatherEffect') or object.Name:lower():find('weather')) then\n"
        extra = "        if selected('Lights') and object:IsA('Light') then setProperty(object, 'Enabled', false) end\n        if selected('Atmosphere') and object:IsA('Atmosphere') then\n            setProperty(object, 'Density', 0)\n            setProperty(object, 'Haze', 0)\n            setProperty(object, 'Glare', 0)\n        end\n"
        text = text.replace(marker, extra + marker, 1)
    write(path, text)


def patch_target_priorities():
    path = BED / 'main.lua'
    text = read(path)
    marker = 'local sortmethods, breakmethods = {'
    start = text.find(marker)
    if start < 0:
        raise RuntimeError('Could not locate sortmethods table')
    if 'shared.AetherScreenSorts' not in text:
        # Find the end of both table literals in `local sortmethods, breakmethods = {...}, {...}`.
        masked = mask_lua(text)
        first_open = masked.find('{', start)
        def close_brace(opening):
            depth = 0
            for i in range(opening, len(masked)):
                if masked[i] == '{': depth += 1
                elif masked[i] == '}':
                    depth -= 1
                    if depth == 0: return i
            raise RuntimeError('Unclosed table literal near sortmethods')
        first_close = close_brace(first_open)
        second_open = masked.find('{', first_close + 1)
        second_close = close_brace(second_open)
        insertion = '''

local function screenPriorityDistance(entry, origin)
\tlocal ent = entry and entry.Entity
\tlocal root = ent and ent.RootPart
\tif not root then return math.huge end
\tlocal point, visible = gameCamera:WorldToViewportPoint(root.Position)
\tif not visible then return math.huge end
\treturn (Vector2.new(point.X, point.Y) - origin).Magnitude
end
sortmethods.None = function() return false end
sortmethods.Closest = function(a, b) return (a.Magnitude or math.huge) < (b.Magnitude or math.huge) end
sortmethods.Farthest = function(a, b) return (a.Magnitude or 0) > (b.Magnitude or 0) end
sortmethods['Lowest health'] = function(a, b) return (a.Entity.Health or math.huge) < (b.Entity.Health or math.huge) end
sortmethods['Highest health'] = function(a, b) return (a.Entity.Health or 0) > (b.Entity.Health or 0) end
sortmethods.Mouse = function(a, b)
\tlocal origin = inputService:GetMouseLocation()
\treturn screenPriorityDistance(a, origin) < screenPriorityDistance(b, origin)
end
sortmethods.Crosshair = function(a, b)
\tlocal origin = gameCamera.ViewportSize / 2
\treturn screenPriorityDistance(a, origin) < screenPriorityDistance(b, origin)
end
shared.AetherScreenSorts = {[sortmethods.Mouse] = 'Mouse', [sortmethods.Crosshair] = 'Crosshair'}
local sortlist = {}
for name in sortmethods do table.insert(sortlist, name) end
table.sort(sortlist)
getgenv().sortlist = sortlist
'''
        text = text[:second_close + 1] + insertion + text[second_close + 1:]
    write(path, text)

    # Every module gets the same stable target-mode ordering instead of hash-table iteration order.
    for lua in BED.rglob('*.lua'):
        if lua.name in ('main.lua', 'bundle.lua'):
            continue
        body = read(lua)
        replaced = body.replace('for i in sortmethods do', 'for _, i in sortlist do')
        if replaced != body:
            write(lua, replaced)

    # Screen-based modes must reject off-screen candidates before sorting, not merely push them last.
    text = read(ENTITY)
    if 'local screenSort = shared.AetherScreenSorts' not in text:
        text = text.replace(
            "\t\tlocal range, customSort = entitysettings.Range, entitysettings.Sort or entitysettings.Priority\n",
            "\t\tlocal range, customSort = entitysettings.Range, entitysettings.Sort or entitysettings.Priority\n\t\tlocal screenSort = shared.AetherScreenSorts and shared.AetherScreenSorts[entitysettings.Sort]\n",
            1
        )
        needle = "\t\t\tif not v.Targetable then continue end\n\t\t\tlocal delta = v[entitysettings.Part].Position - localPosition\n"
        replacement = "\t\t\tif not v.Targetable then continue end\n\t\t\tif screenSort then\n\t\t\t\tlocal _, visible = gameCamera:WorldToViewportPoint(v[entitysettings.Part].Position)\n\t\t\t\tif not visible then continue end\n\t\t\tend\n\t\t\tlocal delta = v[entitysettings.Part].Position - localPosition\n"
        text = text.replace(needle, replacement, 1)
    write(ENTITY, text)


def prompt_editor_block():
    return '''run(function()
\tlocal PromptEditor
\tlocal Range
\tlocal Hold
\tlocal Instant
\tlocal ThroughWalls
\tlocal originals = setmetatable({}, {__mode = 'k'})
\tlocal applying = setmetatable({}, {__mode = 'k'})

\tlocal function remember(prompt)
\t\tif originals[prompt] then return true end
\t\tlocal ok, state = pcall(function()
\t\t\treturn {
\t\t\t\tDistance = prompt.MaxActivationDistance,
\t\t\t\tDuration = prompt.HoldDuration,
\t\t\t\tSight = prompt.RequiresLineOfSight
\t\t\t}
\t\tend)
\t\tif ok then originals[prompt] = state end
\t\treturn ok
\tend

\tlocal function applyPrompt(prompt)
\t\tif typeof(prompt) ~= 'Instance' or not prompt:IsA('ProximityPrompt') or not remember(prompt) then return end
\t\tapplying[prompt] = true
\t\tpcall(function()
\t\t\tprompt.MaxActivationDistance = Range.Value
\t\t\tprompt.HoldDuration = Instant.Enabled and 0 or Hold.Value
\t\t\tprompt.RequiresLineOfSight = not ThroughWalls.Enabled
\t\tend)
\t\tapplying[prompt] = nil
\tend

\tlocal function restorePrompt(prompt, original)
\t\tif not prompt or not prompt.Parent or not original then return end
\t\tapplying[prompt] = true
\t\tpcall(function()
\t\t\tprompt.MaxActivationDistance = original.Distance
\t\t\tprompt.HoldDuration = original.Duration
\t\t\tprompt.RequiresLineOfSight = original.Sight
\t\tend)
\t\tapplying[prompt] = nil
\tend

\tlocal function refresh()
\t\tif not PromptEditor.Enabled then return end
\t\tfor prompt in originals do applyPrompt(prompt) end
\tend

\tPromptEditor = vape.Categories.World:CreateModule({
\t\tName = 'PromptEditor',
\t\tTooltip = 'Edits proximity prompt range, hold time and line-of-sight rules in one module',
\t\tFunction = function(callback)
\t\t\tif callback then
\t\t\t\tPromptEditor:Clean(workspace.DescendantAdded:Connect(applyPrompt))
\t\t\t\tPromptEditor:Clean(proximityPromptService.PromptShown:Connect(applyPrompt))
\t\t\t\tfor _, prompt in workspace:GetDescendants() do applyPrompt(prompt) end
\t\t\telse
\t\t\t\tfor prompt, original in originals do restorePrompt(prompt, original) end
\t\t\t\ttable.clear(originals)
\t\t\t\ttable.clear(applying)
\t\t\tend
\t\tend
\t})
\tRange = PromptEditor:CreateSlider({Name = 'Range', Min = 1, Max = 100, Default = 32, Suffix = ' studs', Function = refresh})
\tHold = PromptEditor:CreateSlider({Name = 'Hold duration', Min = 0, Max = 10, Default = 1, Decimal = 100, Suffix = 's', Function = refresh})
\tInstant = PromptEditor:CreateToggle({Name = 'Instant', Tooltip = 'Sets prompt hold duration to zero', Function = refresh})
\tThroughWalls = PromptEditor:CreateToggle({Name = 'Through walls', Tooltip = 'Removes prompt line-of-sight checks', Function = refresh})
end)'''


def patch_prompt_editor():
    text = read(UNIVERSAL)
    block = prompt_editor_block()
    if "Name = 'PromptEditor'" not in text:
        text = replace_run(text, "Name = 'InteractExtender'", block)
        # Recalculate spans after the first replacement before removing the duration module.
        if "Name = 'ProximityPromptDuration'" in text:
            pos = text.find("Name = 'ProximityPromptDuration'")
            containing = [span for span in run_spans(text) if span[0] <= pos < span[1]]
            if not containing:
                raise RuntimeError('Could not isolate ProximityPromptDuration')
            start, end = min(containing, key=lambda span: span[1] - span[0])
            text = text[:start] + text[end:]
    write(UNIVERSAL, text)


def patch_nofall_percentage():
    path = BED / 'blatant' / 'NoFallDamage.lua'
    text = read(path)
    if 'local DamagePercent\n' not in text:
        text = text.replace('    local HealthCheck\n', '    local HealthCheck\n    local DamagePercent\n', 1)
    text = text.replace('return estimatedDamage >= health', 'return estimatedDamage >= (health * ((DamagePercent and DamagePercent.Value or 100) / 100))', 1)
    if "DamagePercent = NoFall:CreateSlider" not in text:
        marker = "    HealthCheck = NoFall:CreateToggle({\n        Name = 'Health check',\n        Tooltip = 'Only clutches when the estimated fall damage would be lethal'\n    })\n"
        option = marker + "    DamagePercent = NoFall:CreateSlider({\n        Name = 'Damage threshold',\n        Min = 1,\n        Max = 100,\n        Default = 100,\n        Suffix = '%',\n        Tooltip = 'With Health check on, only clutches when estimated fall damage reaches this percentage of current health'\n    })\n"
        if marker in text:
            text = text.replace(marker, option, 1)
        else:
            raise RuntimeError('Could not locate NoFallDamage Health check option')
    write(path, text)


def validate():
    required = {
        BED / 'utility' / 'AntiEffect.lua': "Name = 'AntiEffect'",
        BED / 'utility' / 'MemoryFixer.lua': "Name = 'MemoryFixer'",
        BED / 'combat' / 'NoClickDelay.lua': "Name = 'NoClickDelay'",
        BED / 'render' / 'HitAccuracy.lua': "Name = 'Hit Accuracy'",
        UNIVERSAL: "Name = 'PromptEditor'"
    }
    for path, marker in required.items():
        if marker not in read(path):
            raise RuntimeError(f'{path.relative_to(ROOT)} is missing {marker}')
    universal = read(UNIVERSAL)
    if "Name = 'InteractExtender'" in universal or "Name = 'ProximityPromptDuration'" in universal:
        raise RuntimeError('Old prompt modules remain after PromptEditor merge')
    if "Name = 'InfiniteFly'" not in universal or "Name = 'MouseTP'" not in universal:
        raise RuntimeError('Existing InfiniteFly or MouseTP disappeared during patching')
    print('Validated remaining Aug 30 module changes')


def main():
    port_cv_modules()
    patch_hit_accuracy_shared()
    patch_projectile_aiming()
    patch_fpsboost()
    patch_target_priorities()
    patch_prompt_editor()
    patch_nofall_percentage()
    validate()


if __name__ == '__main__':
    main()

#!/usr/bin/env python3
from pathlib import Path
import json

ROOT = Path(__file__).resolve().parents[1]
BED = ROOT / 'games' / '6872274481'
MAIN = BED / 'main.lua'
GROUP = BED / 'mixed' / 'AutoWin__group3.lua'


def read(path): return path.read_text(encoding='utf-8')
def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(data, encoding='utf-8')

def mark(path): return '--[[AETHER_MODULE:' + path + ']]'

def between(text, start, end, start_at=0):
    a = text.index(start, start_at)
    b = text.index(end, a)
    return text[a:b], a, b

def occurrence(text, needle, n):
    pos = -1
    for _ in range(n): pos = text.index(needle, pos + 1)
    return pos

CONTEXT = '''local AetherRuntimeContext = {
    vape = vape,
    vapeEvents = vapeEvents,
    entitylib = entitylib,
    bedwars = bedwars,
    store = store,
    lplr = lplr,
    playersService = playersService,
    runService = runService,
    collectionService = collectionService,
    replicatedStorage = replicatedStorage,
    httpService = httpService,
    guiService = guiService,
    coreGui = coreGui,
    gameCamera = gameCamera,
    inputService = inputService,
    remotes = remotes,
    sortmethods = sortmethods,
    breakmethods = breakmethods,
    frictionTable = frictionTable,
    updateVelocity = updateVelocity,
    getItem = getItem,
    getWool = getWool,
    getBestArmor = getBestArmor,
    getPlacedBlock = getPlacedBlock,
    switchItem = switchItem,
    isnetworkowner = isnetworkowner,
    notif = notif,
    placeBlock = bedwars.placeBlock,
    breakBlock = bedwars.breakBlock,
    debug = debug,
    Knit = bedwars.Knit,
    kits = kits,
    canDebug = canDebug
}
'''

PORT_API = '''
local AetherPortContext = {Version = 2, Runtime = AetherMatchRuntime, Context = AetherRuntimeContext, Modules = {}, Diagnostics = {}}
AetherMatchRuntime.AlSploitPorts = AetherPortContext
AetherMatchRuntime.AlSploitPortsV2 = AetherPortContext

local function aetherPortSafe(label, fn, ...)
    if type(fn) ~= 'function' then return false, 'missing function' end
    local ok, result = pcall(fn, ...)
    if not ok then
        AetherPortContext.Diagnostics[label] = {At = tick(), Error = tostring(result)}
        return false, result
    end
    return true, result
end
local function aetherPortNotify(text, duration, kind)
    aetherPortSafe('notify', notif, 'AetherV2', text, duration or 3, kind)
end
local function aetherPortRoot()
    local char = entitylib.character
    if entitylib.isAlive and char and char.RootPart and char.RootPart.Parent then return char.RootPart, char, char.Humanoid end
    local character = lplr.Character
    local root = character and (character.PrimaryPart or character:FindFirstChild('HumanoidRootPart'))
    local humanoid = character and character:FindFirstChildOfClass('Humanoid')
    if root and humanoid and humanoid.Health > 0 then return root, character, humanoid end
end
local function aetherPortMatchRunning()
    local match = AetherMatchRuntime.BedWarsAPI and AetherMatchRuntime.BedWarsAPI.Match
    if not match then return store.matchState ~= 0 end
    return match:GetState() == match.States.RUNNING
end
local function aetherPortEquippedKit()
    local api = AetherMatchRuntime.BedWarsAPI and AetherMatchRuntime.BedWarsAPI.Kits
    if api then return select(1, api:GetEquipped()) end
    return store.equippedKit or lplr:GetAttribute('PlayingAsKit')
end
local function aetherPortHorizontalUnit(vector)
    if not vector then return nil end
    local flat = Vector3.new(vector.X, 0, vector.Z)
    return flat.Magnitude > 0.01 and flat.Unit or nil
end
local function aetherPortModule(name) return vape.Modules and vape.Modules[name] or nil end
local function aetherPortRegister(categoryName, name, definition)
    local existing = aetherPortModule(name)
    if existing then AetherPortContext.Modules[name] = existing; return existing, false end
    local category = vape.Categories and vape.Categories[categoryName]
    assert(category and type(category.CreateModule) == 'function', 'missing Aether category '..categoryName)
    definition.Name = name
    local module = category:CreateModule(definition)
    AetherPortContext.Modules[name] = module
    return module, true
end
local function aetherPortAbilityController()
    return bedwars.AbilityController or (bedwars.Knit and bedwars.Knit.Controllers and bedwars.Knit.Controllers.AbilityController)
end
local function aetherPortCanUseAbility(name)
    local controller = aetherPortAbilityController()
    if not controller then return false end
    if type(controller.canUseAbility) == 'function' then
        local ok, result = pcall(controller.canUseAbility, controller, name, {disableBlockedAbilityAlert = true})
        if ok then return result ~= false end
    end
    return true
end
local function aetherPortUseAbility(name)
    local controller = aetherPortAbilityController()
    if not controller or type(controller.useAbility) ~= 'function' then return false, 'missing AbilityController' end
    local ok, result = pcall(controller.useAbility, controller, name)
    return ok and result ~= false, result
end
local function aetherPortNearestTarget(range, includeNPCs)
    local root = aetherPortRoot(); if not root then return nil end
    local ok, target = pcall(entitylib.EntityPosition, {Origin = root.Position, Range = range, Part = 'RootPart', Players = true, NPCs = includeNPCs and true or false})
    return ok and target or nil
end
local function aetherPortWait(seconds, cancelled, step)
    local deadline = tick() + seconds
    repeat if cancelled and cancelled() then return false end; task.wait(step or 0.03) until tick() >= deadline
    return true
end
local function aetherPortAddMovementOwner(name)
    local movement = AetherMatchRuntime.Movement
    if movement and movement.ExternalNames and not table.find(movement.ExternalNames, name) then table.insert(movement.ExternalNames, name) end
end
local function aetherPortCreateDecoy(followHorizontal)
    local root, character, humanoid = aetherPortRoot(); if not root or not character or not humanoid then return nil end
    local oldArchivable = character.Archivable; character.Archivable = true
    local ok, clone = pcall(character.Clone, character); character.Archivable = oldArchivable
    if not ok or not clone then return nil end
    for _, object in clone:GetDescendants() do
        if object:IsA('Script') or object:IsA('LocalScript') then object:Destroy()
        elseif object:IsA('BasePart') then object.CanCollide = false; if object.Name == 'Cape' then object:Destroy() end end
    end
    clone.Name = 'AetherMovementDecoy'; clone.Parent = workspace
    local cloneRoot = clone.PrimaryPart or clone:FindFirstChild('HumanoidRootPart')
    local cloneHumanoid = clone:FindFirstChildOfClass('Humanoid')
    if not cloneRoot or not cloneHumanoid then clone:Destroy(); return nil end
    clone.PrimaryPart = cloneRoot; cloneRoot.Anchored = true; clone:PivotTo(character:GetPivot())
    local originalSubject = gameCamera.CameraSubject; gameCamera.CameraSubject = cloneHumanoid
    local decoy = {Model = clone, Root = cloneRoot, Humanoid = cloneHumanoid, OriginalSubject = originalSubject}
    if followHorizontal then
        decoy.Connection = runService.RenderStepped:Connect(function()
            local liveRoot = aetherPortRoot()
            if clone.Parent and liveRoot then cloneRoot.CFrame = CFrame.new(liveRoot.Position.X, cloneRoot.Position.Y, liveRoot.Position.Z) * liveRoot.CFrame.Rotation end
        end)
    end
    function decoy:Destroy()
        if self.Connection then self.Connection:Disconnect(); self.Connection = nil end
        if gameCamera.CameraSubject == self.Humanoid then local _, _, liveHumanoid = aetherPortRoot(); gameCamera.CameraSubject = (self.OriginalSubject and self.OriginalSubject.Parent and self.OriginalSubject) or liveHumanoid end
        if self.Model and self.Model.Parent then self.Model:Destroy() end
    end
    return decoy
end
'''

PREAMBLE = '''run(function()
    local Runtime = assert(AetherMatchRuntime, 'Aether BedWars runtime is unavailable')
    local ctx = AetherRuntimeContext
    local Ports = AetherPortContext
    local safe = aetherPortSafe
    local notify = aetherPortNotify
    local rootOfLocal = aetherPortRoot
    local matchRunning = aetherPortMatchRunning
    local equippedKit = aetherPortEquippedKit
    local horizontalUnit = aetherPortHorizontalUnit
    local moduleByName = aetherPortModule
    local register = aetherPortRegister
    local abilityController = aetherPortAbilityController
    local canUseAbility = aetherPortCanUseAbility
    local useAbility = aetherPortUseAbility
    local nearestTarget = aetherPortNearestTarget
    local waitCancelable = aetherPortWait
    local addMovementOwner = aetherPortAddMovementOwner
    local createDecoy = aetherPortCreateDecoy
    local workspaceService = workspace
'''

def module_file(section, before=''):
    return PREAMBLE + before + section.strip() + '\nend)\n'

def main():
    if not GROUP.exists():
        print('Final coupled runtime already split')
        return
    src = read(GROUP)

    # Trixie is self-contained once it can see the shared match context.
    trixie_start = src.index('    ----------------------------------------------------------------------------------------------\n    -- TrixieExploit (direct implementation)')
    runtime_heading = src.index('    ----------------------------------------------------------------------------------------------\n    -- AutoWin/Jade reactive runtime', trixie_start)
    trixie = src[trixie_start:runtime_heading]
    write(BED / 'kits/TrixieExploit.lua', "run(function()\n    local context = AetherRuntimeContext\n" + trixie + '\nend)\n')

    # Shared AutoWin/Jade infrastructure belongs in main.lua; module registration stays in files.
    runtime_start = src.index('local function registerAetherRuntime(context)')
    auto_hud = src.index('-- AutoWin HUD V2', runtime_start)
    runtime_base = src[runtime_start:auto_hud]
    runtime_base = runtime_base.replace('local function registerAetherRuntime(context)', 'local function registerAetherRuntimeBase(context)', 1)
    runtime_base += '''Runtime.MatchDirector = MatchDirector
Runtime.Safe = safe
Runtime.Now = now
Runtime.RootOfLocal = rootOfLocal
Runtime.ModuleByName = moduleByName
Runtime.CopyTable = copyTable
Runtime.Context = ctx
shared.AetherBedWarsRuntime = Runtime
return Runtime
end
local runtimeLoaded, runtimeResult = xpcall(function()
    return registerAetherRuntimeBase(AetherRuntimeContext)
end, debug and debug.traceback or tostring)
if not runtimeLoaded or type(runtimeResult) ~= 'table' then
    error('[AetherV2] AutoWin/Jade runtime failed: '..tostring(runtimeResult))
end
AetherMatchRuntime = runtimeResult
'''

    jik_heading = src.index('-- JadeInstaKill V2 state machine', auto_hud)
    auto_section = src[auto_hud:jik_heading]
    auto_file = "run(function()\n    local Runtime = assert(AetherMatchRuntime, 'Aether runtime missing')\n    local MatchDirector = assert(Runtime.MatchDirector, 'AutoWin director missing')\n" + auto_section + '\nend)\n'
    write(BED / 'world/AutoWin.lua', auto_file)

    longjump_heading = src.index('-- LongJump Jade integration marker', jik_heading)
    jik_section = src[jik_heading:longjump_heading]
    jik_file = '''run(function()
    local Runtime = assert(AetherMatchRuntime, 'Aether runtime missing')
    local Jade = assert(Runtime.Jade, 'Jade adapter missing')
    local Movement = assert(Runtime.Movement, 'movement coordinator missing')
    local ModuleLeases = assert(Runtime.ModuleLeases, 'module leases missing')
    local safe = Runtime.Safe
    local now = Runtime.Now
    local rootOfLocal = Runtime.RootOfLocal
    local moduleByName = Runtime.ModuleByName
    local copyTable = Runtime.CopyTable
''' + jik_section + '\nend)\n'
    write(BED / 'exploits/JadeInstaKill.lua', jik_file)

    shared_end = src.index('shared.AetherBedWarsRuntime=Runtime', longjump_heading)
    longjump_hook = src[longjump_heading:shared_end]
    longjump_hook = 'do\nlocal Runtime = AetherMatchRuntime\n' + longjump_hook + '\nend\n'

    patch_start = src.index('local function patchAetherRuntime(Runtime, ctx)', shared_end)
    ports_heading = src.index('    ----------------------------------------------------------------------------------------------\n    -- Additional BedWars modules', patch_start)
    hardening = src[patch_start:ports_heading]

    p1_start = src.index('local function registerAetherPorts(Runtime, ctx)', ports_heading)
    p2_start = src.index('local function registerAetherPortsV2(Runtime, ctx)', p1_start)
    p1 = src[p1_start:p2_start]
    yamini_a = p1.index('-- YaminiExploit')
    jade_a = p1.index('-- JadeExploit', yamini_a)
    decoy_a = p1.index('-- Shared visual decoy', jade_a)
    yamini = p1[yamini_a:jade_a]
    jade = p1[jade_a:decoy_a]
    write(BED / 'exploits/YaminiExploit.lua', module_file(yamini))
    write(BED / 'exploits/JadeExploit.lua', module_file(jade, '    addMovementOwner(\'JadeExploit\')\n'))

    ports_calls = src.index('    local portsLoaded, portsResult', p2_start)
    p2 = src[p2_start:ports_calls]
    anti_a = p2.index('-- AntiHitBETA')
    nofall_a = p2.index('-- NoFallDamageV2', anti_a)
    longjump_a = p2.index('run(function()\n    local Value', nofall_a)
    anti = p2[anti_a:nofall_a]
    nofall = p2[nofall_a:longjump_a]
    write(BED / 'blatant/AntiHitBETA.lua', module_file(anti, "    addMovementOwner('AntiHitBETA')\n"))
    write(BED / 'blatant/NoFallDamageV2.lua', module_file(nofall))

    balloon_a = p2.index('local BalloonDisabler', longjump_a)
    multi_a = p2.index('local MultiAction', balloon_a)
    sigrid_a = p2.index('-- InfiniteSigrid', multi_a)
    jadehammer_a = p2.index('-- JadeHammerExploit', sigrid_a)
    compat_a = p2.index('-- Compatibility exports', jadehammer_a)
    balloon = p2[balloon_a:multi_a]
    multi = p2[multi_a:sigrid_a]
    sigrid = p2[sigrid_a:jadehammer_a]
    jadehammer = p2[jadehammer_a:compat_a]
    write(BED / 'exploits/BalloonDisabler.lua', module_file(balloon))
    write(BED / 'exploits/MultiAction.lua', module_file(multi))
    write(BED / 'kits/InfiniteSigrid.lua', module_file(sigrid))
    write(BED / 'exploits/JadeHammerExploit.lua', module_file(jadehammer))

    common = CONTEXT + '\n' + runtime_base + '\n' + mark('world/AutoWin.lua') + '\n' + mark('exploits/JadeInstaKill.lua') + '\n' + longjump_hook + '\n' + hardening + '\n' + PORT_API + '\n'
    module_order = [
        'kits/TrixieExploit.lua',
        'exploits/YaminiExploit.lua',
        'exploits/JadeExploit.lua',
        'blatant/AntiHitBETA.lua',
        'blatant/NoFallDamageV2.lua',
        'exploits/BalloonDisabler.lua',
        'exploits/MultiAction.lua',
        'kits/InfiniteSigrid.lua',
        'exploits/JadeHammerExploit.lua'
    ]
    # Trixie should initialize before the shared runtime, matching the original order.
    common = CONTEXT + '\n' + mark('kits/TrixieExploit.lua') + '\n' + runtime_base + '\n' + mark('world/AutoWin.lua') + '\n' + mark('exploits/JadeInstaKill.lua') + '\n' + longjump_hook + '\n' + hardening + '\n' + PORT_API + '\n' + '\n'.join(mark(x) for x in module_order[1:]) + '''
AetherMatchRuntime.JadeHammerExploit = vape.Modules and vape.Modules.JadeHammerExploit or nil
'''

    main_text = read(MAIN)
    old_marker = mark('mixed/AutoWin__group3.lua')
    if old_marker not in main_text: raise RuntimeError('AutoWin group marker missing from main.lua')
    main_text = main_text.replace(old_marker, common, 1)
    write(MAIN, main_text)
    GROUP.unlink()
    mixed = GROUP.parent
    if mixed.exists() and not any(mixed.iterdir()): mixed.rmdir()

    structure = BED / 'structure.json'
    if structure.exists():
        data = json.loads(read(structure)); data['coupledGroups'] = 0; data['layout'] = 'one-module-per-file'; write(structure, json.dumps(data, indent=2) + '\n')
    print('Split final AutoWin/Jade coupled runtime into dedicated module files')

if __name__ == '__main__': main()

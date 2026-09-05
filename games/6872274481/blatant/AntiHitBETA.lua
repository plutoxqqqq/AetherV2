run(function()
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
    addMovementOwner('AntiHitBETA')
-- AntiHitBETA
--------------------------------------------------------------------------------
local AntiHitBETA
local antiHitCreated
local AntiHitOptions = {}
local antiHitGeneration = 0
local antiHitBusy = false
local antiHitDecoy

local function currentAttackDelay()
    local held = store.hand
    local meta = held and held.itemType and bedwars.ItemMeta and bedwars.ItemMeta[held.itemType]
    local sword = meta and meta.sword
    return sword and tonumber(sword.attackSpeed) or 0.3
end

local function antiHitCleanup()
    if antiHitDecoy then antiHitDecoy:Destroy(); antiHitDecoy = nil end
    antiHitBusy = false
    local movement = Runtime.Movement
    local current = movement and movement.Current
    if current and current.Owner == 'AntiHitBETA' then current:Release() end
end

local function executeAntiHit(generation)
    if antiHitBusy then return end
    local root = rootOfLocal()
    if not root then return end
    antiHitBusy = true
    local movement = Runtime.Movement
    local lease = movement and movement:Acquire('AntiHitBETA', movement.Priorities.Emergency, 1.5, antiHitCleanup, true) or nil
    if movement and not lease then antiHitBusy = false; return end
    local originalY = root.Position.Y
    antiHitDecoy = createDecoy(true)
    local delay = currentAttackDelay()
    local ok, err = xpcall(function()
        if generation ~= antiHitGeneration or not AntiHitBETA.Enabled then return end
        root = rootOfLocal()
        if not root then return end
        if (not movement or movement:CanWrite('AntiHitBETA')) and isnetworkowner(root) then
            root.CFrame = CFrame.new(root.Position + Vector3.new(0, 25, 0)) * root.CFrame.Rotation
        end
        if not waitCancelable(delay, function() return generation ~= antiHitGeneration or not AntiHitBETA.Enabled end) then return end
        root = rootOfLocal()
        if root and (not movement or movement:CanWrite('AntiHitBETA')) and isnetworkowner(root) then
            root.CFrame = CFrame.new(root.Position.X, originalY + 5, root.Position.Z) * root.CFrame.Rotation
        end
        waitCancelable(delay, function() return generation ~= antiHitGeneration or not AntiHitBETA.Enabled end)
    end, debug and debug.traceback or tostring)
    if not ok then Ports.Diagnostics.AntiHitBETA = {At = tick(), Error = tostring(err)} end
    if antiHitDecoy then antiHitDecoy:Destroy(); antiHitDecoy = nil end
    if lease then lease:Release() end
    antiHitBusy = false
end

AntiHitBETA, antiHitCreated = register('Blatant', 'AntiHitBETA', {
    Tooltip = 'BETA dodge port of AlSploit AntiHit using a short vertical displacement and decoy camera.',
    Function = function(callback)
        antiHitGeneration = antiHitGeneration + 1
        local generation = antiHitGeneration
        if not callback then antiHitCleanup(); return end
        AntiHitBETA:Clean(antiHitCleanup)
        task.spawn(function()
            while AntiHitBETA.Enabled and generation == antiHitGeneration do
                if entitylib.isAlive and matchRunning() and not antiHitBusy then
                    local target = nearestTarget(AntiHitOptions.Range.Value, AntiHitOptions.Entities.Enabled)
                    if target then task.spawn(executeAntiHit, generation) end
                end
                task.wait(0.04)
            end
        end)
    end
})
if antiHitCreated then
    AntiHitOptions.Entities = AntiHitBETA:CreateToggle({Name = 'Entities', Default = false})
    AntiHitOptions.Range = AntiHitBETA:CreateSlider({Name = 'Range', Min = 1, Max = 20, Default = 20, Suffix = ' studs'})
end

--------------------------------------------------------------------------------
end)

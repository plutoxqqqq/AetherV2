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
-- InfiniteSigrid
-- This module was removed even though its name did not identify it as an exploit.
-- Keep it in the Kits window and use the live Elk controller when available.
--------------------------------------------------------------------------------
local InfiniteSigrid
local sigridGeneration = 0

InfiniteSigrid = (function()
    local module, created = register('Kits', 'InfiniteSigrid', {
        Tooltip = 'Keeps the Elk mount active while the Elk Master kit is equipped.',
        Function = function(callback)
            sigridGeneration += 1
            local generation = sigridGeneration
            if not callback then return end

            task.spawn(function()
                local mount
                while module.Enabled and generation == sigridGeneration do
                    if not mount then
                        safe('sigrid.resolve', function()
                            if bedwars.Client and type(bedwars.Client.Get) == 'function' then
                                mount = bedwars.Client:Get('ElkKitMounted')
                            end
                        end)
                    end

                    local kit = tostring(equippedKit() or ''):lower()
                    if mount and entitylib.isAlive and matchRunning() and kit == 'elk_master'
                        and type(mount.SendToServer) == 'function' then
                        safe('sigrid.mount', mount.SendToServer, mount)
                    end
                    task.wait(0.1)
                end
            end)
        end
    })
    if created then return module end
    return module
end)()

--------------------------------------------------------------------------------
end)

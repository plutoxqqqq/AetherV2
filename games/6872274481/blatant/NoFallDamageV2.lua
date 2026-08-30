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
-- NoFallDamageV2
--------------------------------------------------------------------------------
local NoFallDamageV2
local noFallCreated
local noFallGeneration = 0
local noFallBusy = false
NoFallDamageV2, noFallCreated = register('Blatant', 'NoFallDamageV2', {
    Tooltip = 'AlSploit-style fall-damage prevention: briefly reports a landed state while preserving downward velocity.',
    Function = function(callback)
        noFallGeneration = noFallGeneration + 1
        local generation = noFallGeneration
        noFallBusy = false
        if not callback then return end
        local connection = runService.PostSimulation:Connect(function()
            if noFallBusy or generation ~= noFallGeneration or not NoFallDamageV2.Enabled then return end
            local highJump = moduleByName('HighJump')
            if highJump and highJump.Enabled then return end
            local root, _, humanoid = rootOfLocal()
            if not root or not humanoid then return end
            local velocity = root.AssemblyLinearVelocity
            if velocity.Y >= -45 then return end
            noFallBusy = true
            task.spawn(function()
                local oldY = velocity.Y
                root = rootOfLocal()
                if not root or generation ~= noFallGeneration or not NoFallDamageV2.Enabled then noFallBusy = false; return end
                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 44, root.AssemblyLinearVelocity.Z)
                safe('nofall.landed', humanoid.ChangeState, humanoid, Enum.HumanoidStateType.Landed)
                runService.PreSimulation:Wait()
                root = rootOfLocal()
                if root and generation == noFallGeneration and NoFallDamageV2.Enabled then
                    root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, oldY, root.AssemblyLinearVelocity.Z)
                end
                noFallBusy = false
            end)
        end)
        NoFallDamageV2:Clean(connection)
    end
})
end)

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
local BalloonDisabler, BalloonAutoDisable
local balloonControllerState
local balloonAutoConnection

local function stopBalloonAutoDisable()
    if balloonAutoConnection then
        pcall(balloonAutoConnection.Disconnect, balloonAutoConnection)
        balloonAutoConnection = nil
    end
end

local function restoreBalloonController()
    local state = balloonControllerState
    balloonControllerState = nil
    if not state or not state.Controller then return end
    pcall(function()
        if state.Controller.hookBalloon == state.Hook then
            state.Controller.hookBalloon = state.HookOriginal
        end
        if state.Controller.enableBalloonPhysics == state.Physics then
            state.Controller.enableBalloonPhysics = state.PhysicsOriginal
        end
        if state.Controller.deflateBalloon == state.Deflate then
            state.Controller.deflateBalloon = state.DeflateOriginal
        end
    end)
end

BalloonDisabler = (function()
    local module, created = register('Exploits', 'BalloonDisabler', {
        Tooltip = 'Disables the local balloon anticheat controller while a balloon is equipped.',
        Function = function(callback)
            restoreBalloonController()
            if not callback then return end

            local controller = bedwars.BalloonController
            local item = safe('balloon.inventory', getItem, 'balloon')
            if not item then
                notify('BalloonDisabler: no balloon is available.', 5, 'alert')
                return
            end
            if not controller or type(controller.hookBalloon) ~= 'function' then
                notify('BalloonDisabler: balloon controller is unavailable.', 5, 'warning')
                return
            end

            local state = {
                Controller = controller,
                HookOriginal = controller.hookBalloon,
                PhysicsOriginal = controller.enableBalloonPhysics,
                DeflateOriginal = controller.deflateBalloon
            }
            balloonControllerState = state

            state.Hook = function(self, player, attachment, balloon)
                if tostring(player) ~= lplr.Name then
                    if state.HookOriginal then
                        return state.HookOriginal(self, player, attachment, balloon)
                    end
                    return
                end

                safe('balloon.hide', function()
                    if not balloon then return end
                    local visual = balloon:FindFirstChild('Balloon') or balloon:WaitForChild('Balloon', 1)
                    if visual then
                        visual.CFrame = CFrame.new(0, -1995, 0)
                        visual:ClearAllChildren()
                    end
                end)
                restoreBalloonController()
                task.delay(0.5, function()
                    if module.Enabled then
                        notify('BalloonDisabler: local balloon controller disabled.', 5)
                    end
                end)
            end
            state.Physics = function() end
            state.Deflate = function() end

            local installed, errorMessage = pcall(function()
                if type(controller.inflateBalloon) == 'function' then
                    controller:inflateBalloon()
                end
                controller.enableBalloonPhysics = state.Physics
                controller.deflateBalloon = state.Deflate
                controller.hookBalloon = state.Hook
            end)
            if not installed then
                restoreBalloonController()
                notify('BalloonDisabler: controller setup failed.', 5, 'warning')
                Ports.Diagnostics.BalloonDisabler = {At = tick(), Error = tostring(errorMessage)}
            end
        end
    })
    if created then
        BalloonAutoDisable = module:CreateToggle({
            Name = 'AutoDisable',
            Default = false,
            Function = function(enabled)
                stopBalloonAutoDisable()
                if not enabled then return end
                local inventories = ctx.replicatedStorage and ctx.replicatedStorage:FindFirstChild('Inventories')
                if not inventories then
                    notify('BalloonDisabler: inventory controller is unavailable.', 5, 'warning')
                    return
                end
                local connected, connection = pcall(inventories.DescendantAdded.Connect, inventories.DescendantAdded, function(object)
                    if object.Parent and object.Parent.Name == lplr.Name and object.Name == 'balloon' then
                        task.spawn(function()
                            repeat task.wait() until getItem('balloon') or not BalloonAutoDisable.Enabled
                            if BalloonAutoDisable.Enabled and not module.Enabled then
                                module:Toggle()
                            end
                        end)
                    end
                end)
                if connected then
                    balloonAutoConnection = connection
                    BalloonAutoDisable:Clean(connection)
                end
            end
        })
        module:Clean(function()
            stopBalloonAutoDisable()
            restoreBalloonController()
        end)
    end
    return module
end)()
end)

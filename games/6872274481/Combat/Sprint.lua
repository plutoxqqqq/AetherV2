run(function()
    local Sprint
    local old

    -- isSprinting is only used to skip a call that would do nothing anyway: the controller can
    -- refuse to start sprinting while it is still pointed at the body it just lost, so every
    -- re-assert is cheap and safe to repeat until the new character is the one in charge.
    local function assertSprint()
        local controller = bedwars.SprintController
        if not controller or type(controller.startSprinting) ~= 'function' then return end
        if type(controller.isSprinting) == 'function' and controller:isSprinting() then return end
        controller:startSprinting()
    end

    Sprint = vape.Categories.Combat:CreateModule({
        Name = 'Sprint',
        Function = function(callback)
            if callback then
                if inputService.TouchEnabled then
                    pcall(function()
                        lplr.PlayerGui.MobileUI['4'].Visible = false
                    end)
                end
                old = bedwars.SprintController.stopSprinting
                bedwars.SprintController.stopSprinting = function(...)
                    local call = old(...)
                    bedwars.SprintController:startSprinting()
                    return call
                end
                Sprint:Clean(entitylib.Events.LocalAdded:Connect(function()
                    -- Respawn is not one moment: the controller can still be holding the old body
                    -- when the new one lands, and a blocked-sprint status effect can refuse the
                    -- first call outright. Re-assert across the second after the spawn instead of
                    -- firing once and hoping the controller was ready.
                    for _, pause in {0.1, 0.25, 0.5, 0.75, 1} do
                        task.delay(pause, function()
                            if Sprint.Enabled then
                                assertSprint()
                            end
                        end)
                    end
                end))
                bedwars.SprintController:stopSprinting()
                assertSprint()
            else
                if inputService.TouchEnabled then
                    pcall(function()
                        lplr.PlayerGui.MobileUI['4'].Visible = true
                    end)
                end
                bedwars.SprintController.stopSprinting = old
                bedwars.SprintController:stopSprinting()
            end
        end,
        Tooltip = 'Sets your sprinting to true'
    })
end)

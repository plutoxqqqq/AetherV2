run(function()
    local runtime = shared.AetherLongJumpRuntime
    if not runtime or not runtime.Module then warn('[AetherV2] LongJumpBypass requires LongJump runtime'); return end
    local LongJumpBypass, BypassBoost
    
    
    
    
    
    
    
    local function findBypassTool()
		local method, item, name = runtime.GetHeldMethod()
		if method then return name, item end
        for name in runtime.Methods do
            local item = getItem(name)
            if item or store.equippedKit == name then
                return name, item
            end
        end
    end

    LongJumpBypass = vape.Categories.Exploits:CreateModule({
        Name = 'LongJumpBypass',
        Function = function(callback)
            if callback then
                repeat task.wait() until (store.matchState ~= 0 and store.map and entitylib.isAlive) or not LongJumpBypass.Enabled
                if not LongJumpBypass.Enabled then return end

                
                
                local toolName, item = findBypassTool()
                if not toolName then
                    notif('LongJumpBypass', 'Hold or carry a compatible tool (dao, jade hammer, void axe, cannon, tnt, grappling hook).', 5)
                    return task.spawn(function() if LongJumpBypass.Enabled then LongJumpBypass:Toggle() end end)
                end

                
                
                
                
                if item and item.tool and not (store.hand and store.hand.tool == item.tool) then
                    switchItem(item.tool, 0.1)
                    local handDeadline = tick() + 0.6
                    repeat task.wait(0.05) until (store.hand and store.hand.tool == item.tool) or tick() > handDeadline or not LongJumpBypass.Enabled
                    if not LongJumpBypass.Enabled then return end
                end

                
                
                local longWasOn = runtime.Module.Enabled
                if not runtime.Module.Enabled then runtime.Module:Toggle() end
                
                if not runtime.Module.Enabled then
                    return task.spawn(function() if LongJumpBypass.Enabled then LongJumpBypass:Toggle() end end)
                end

                
                
                
                
                
                
                local bypassStart = tick()
                local boostStart
                local launchY = entitylib.character.RootPart.Position.Y
                local launched = false
                local direction
                repeat
                    runService.PreSimulation:Wait()
                    local boosting = runtime.GetJumpTick() > tick()
                    if boosting and not launched then
                        launched = true
                        boostStart = tick()
                        launchY = entitylib.character.RootPart.Position.Y
                    end
                    if entitylib.isAlive and (boosting or launched) then
                        local root = entitylib.character.RootPart
                        if root then
                            local velocity = root.AssemblyLinearVelocity
                            local flat = Vector3.new(velocity.X, 0, velocity.Z)
                            local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
                            direction = direction or (flat.Magnitude > 1 and flat.Unit) or (look.Magnitude > 0 and look.Unit) or Vector3.zAxis
                            
                            
                            
                            local lift = root.Position.Y - launchY < 65 and BypassBoost.Value or 0
                            root.AssemblyLinearVelocity = Vector3.new(direction.X * 37, lift, direction.Z * 37)
                        end
                    end
                until not LongJumpBypass.Enabled or (launched and tick() - boostStart >= 2) or tick() - bypassStart > 8

                
                if runtime.Module.Enabled and not longWasOn then runtime.Module:Toggle() end
                
                
                if launched and entitylib.isAlive then
                    entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.zero
                end
                return task.spawn(function() if LongJumpBypass.Enabled then LongJumpBypass:Toggle() end end)
            end
        end,
        Tooltip = 'Fires a compatible tool, flies forward and climbs briefly, then cancels velocity and free-falls'
    })
    BypassBoost = LongJumpBypass:CreateSlider({
        Name = 'Boost',
        Min = 5,
        Max = 42,
        Default = 30,
        Suffix = ' studs/s',
        Tooltip = 'Maximum upward speed maintained while LongJump boosts you'
    })
end)

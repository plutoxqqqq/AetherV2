run(function()
    local BoostAirJump
    local Boost
    BoostAirJump = vape.Categories.Blatant:CreateModule({
        Name = 'BoostAirJump',
        Function = function(callback)
            if callback then
                repeat
                    
                    
                    if entitylib.isAlive and not inputService:GetFocusedTextBox()
                        and (inputService:IsKeyDown(Enum.KeyCode.Space) or inputService:IsKeyDown(Enum.KeyCode.ButtonA)) then
                        local root = entitylib.character.RootPart
                        if root then
                            root.AssemblyLinearVelocity = root.AssemblyLinearVelocity + Vector3.new(0, Boost and Boost.Value or 35, 0)
                        end
                    end
                    task.wait(0.1)
                until not BoostAirJump.Enabled
            end
        end,
        Tooltip = 'Adds upward velocity while you hold jump/space to bypass jump-height detection'
    })
    Boost = BoostAirJump:CreateSlider({
        Name = 'Boost',
        Min = 5,
        Max = 60,
        Default = 35,
        Suffix = ' studs/s',
        Tooltip = 'Upward velocity added each tick while jump is held'
    })
end)

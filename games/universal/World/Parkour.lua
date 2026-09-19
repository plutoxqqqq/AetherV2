run(function()
    local Parkour
    local AutoJump

    local probe = RaycastParams.new()
    probe.FilterType = Enum.RaycastFilterType.Exclude
    probe.RespectCanCollide = true

    -- True when the run is heading into something worth jumping onto: a solid sits at knee height in front,
    -- and just past it there is a surface that is higher than the feet but still within a normal step. A
    -- wall that keeps going up never qualifies, so this does not turn into a jump button.
    local function hasStepAhead(root, direction)
        probe.FilterDescendantsInstances = {lplr.Character}
        if not workspace:Raycast(root.Position + Vector3.new(0, 0.6, 0), direction * 2.6, probe) then return false end
        local landing = workspace:Raycast(root.Position + direction * 2.6 + Vector3.new(0, 4, 0), Vector3.new(0, -9, 0), probe)
        if not landing then return false end
        local rise = landing.Position.Y - root.Position.Y
        return rise > 0.5 and rise <= 3.4
    end

    Parkour = vape.Categories.World:CreateModule({
        Name = 'Parkour',
        Function = function(callback)
            if callback then
                local oldfloor
                Parkour:Clean(runService.RenderStepped:Connect(function()
                    if entitylib.isAlive then
                        local humanoid = entitylib.character.Humanoid
                        local material = humanoid.FloorMaterial
                        if material == Enum.Material.Air and oldfloor ~= Enum.Material.Air then
                            humanoid.Jump = true
                        end
                        oldfloor = material

                        if AutoJump.Enabled and material ~= Enum.Material.Air then
                            local root = entitylib.character.RootPart
                            local direction = humanoid.MoveDirection
                            local state = humanoid:GetState()
                            if root and direction.Magnitude > 0.1
                                and state ~= Enum.HumanoidStateType.Jumping and state ~= Enum.HumanoidStateType.Freefall
                                and hasStepAhead(root, direction.Unit) then
                                humanoid.Jump = true
                            end
                        end
                    end
                end))
            end
        end,
        Tooltip = 'Automatically jumps after reaching the edge',
    })
    AutoJump = Parkour:CreateToggle({
        Name = 'Auto jump',
        Tooltip = 'Jumps on its own when you run at a higher platform, ledge or block you can step onto'
    })
end)

run(function()
    local Jesus
    local platform = Instance.new('Part')
    platform.Name = 'AetherJesusPlatform'
    platform.Anchored = true
    platform.CanCollide = true
    platform.CanQuery = false
    platform.CanTouch = false
    platform.Transparency = 1
    platform.Size = Vector3.new(6, 0.25, 6)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.IgnoreWater = false

    Jesus = vape.Categories.Blatant:CreateModule({
        Name = 'Jesus',
        Function = function(enabled)
            if enabled then
                platform.Parent = workspace
                Jesus:Clean(runService.PreSimulation:Connect(function()
                    if not entitylib.isAlive then
                        platform.CFrame = CFrame.new(0, -10000, 0)
                        return
                    end
                    local root = entitylib.character.RootPart
                    rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera, platform}
                    local result = workspace:Raycast(root.Position + Vector3.new(0, 2, 0), Vector3.new(0, -8, 0), rayParams)
                    if result and result.Material == Enum.Material.Water then
                        platform.CFrame = CFrame.new(root.Position.X, result.Position.Y - 0.15, root.Position.Z)
                    else
                        platform.CFrame = CFrame.new(0, -10000, 0)
                    end
                end))
            else
                platform.Parent = nil
            end
        end,
        Tooltip = 'Lets you walk on water'
    })
    vape:Clean(function() platform:Destroy() end)
end)

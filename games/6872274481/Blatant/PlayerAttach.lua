run(function()
    local PlayerAttach
    local Range
    local Targets

    local rayCheck = RaycastParams.new()
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude

    PlayerAttach = vape.Categories.Blatant:CreateModule({
        Name = 'PlayerAttach',
        Tooltip = 'Attachs you to the nearest target',
        Function = function(call)
            if call then
                repeat
                    if entitylib.isAlive then
                        local plr = entitylib.AllPosition({
                            Range = Range.Value,
                            Wallcheck = Targets.Walls.Enabled or nil,
                            Part = 'RootPart',
                            Players = Targets.Players.Enabled,
                            NPCs = Targets.NPCs.Enabled,
                            Limit = 1,
                            Sort = function(a, b)
                                return a.Entity.Health < b.Entity.Health
                            end
                        })[1]
                        if plr then
                            rayCheck.FilterDescendantsInstances = {plr.RootPart.Parent, lplr.Character}

                            entitylib.character.RootPart.AssemblyLinearVelocity = Vector3.new(0, entitylib.character.RootPart.Size.Y / 2 + entitylib.character.Humanoid.HipHeight + 0.25 * 3, 0)
                            entitylib.character.RootPart.CFrame = plr.RootPart.CFrame + (not workspace:Raycast(plr.RootPart.Position, plr.RootPart.CFrame.LookVector, rayCheck) and (plr.RootPart.CFrame.LookVector * 1.4) or Vector3.zero)
                        end
                    end
                    task.wait()
                until not PlayerAttach.Enabled
            end
        end
    })

    Targets = PlayerAttach:CreateTargets({
        Players = true,
        NPCs = true
    })

    Range = PlayerAttach:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 35,
        Default = 23,
        Suffix = function(val)
            return val <= 1 and 'stud' or 'studs'
        end
    })
end)

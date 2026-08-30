run(function()
    local TerraAimbot
    local Range
    local Mode

    local old

    TerraAimbot = kits:CreateModule({
        Name = 'TerraAimbot',
        Category = 'Aim',
        Function = function(callback)
            if callback then
                old = bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition
                bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = function(...)
                    local origin, dir = select(2, ...)
                    local plr = entitylib['Entity'.. Mode.Value]({
                        Part = 'RootPart',
                        Range = Range.Value,
                        Origin = origin,
                        Players = true,
                        Wallcheck = true
                    })

                    if plr then
                        local calc = prediction.SolveTrajectory(origin, 100, 20, plr.RootPart.Position, plr.RootPart.Velocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil)

                        if calc then
                            for i, v in debug.getstack(2) do
                                if v == dir then
                                    debug.setstack(2, i, CFrame.lookAt(origin, calc).LookVector)
                                end
                            end
                        end
                    end

                    return old(...)
                end
            end
        end,
        Tooltip = 'Silently adjusts where terra blocks are heading towards'
    })

    Mode = TerraAimbot:CreateDropdown({
        Name = 'Mode',
        List = {'Position', 'Mouse'},
        Default = 'Mouse'
    })
    Range = TerraAimbot:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 1000,
        Default = 1000,
        Suffix = function(val)
            return val <= 1 and 'studs' or 'stud'
        end
    })
end)
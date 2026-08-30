run(function()
    local OwlAura
    local Targets
    local Range

    local function getProjectileMeta()
        local meta = table.clone(bedwars.ProjectileMeta.owl_projectile)
        return meta
    end

    OwlAura = kits:CreateModule({
        Name = 'OwlAura',
        Category = 'Aim',
        Function = function(callback)
            if callback then
                local owls = collection('Owl', OwlAura, function(self, obj)
                    task.delay(1, function()
                        if obj and obj.Parent and obj:GetAttribute('Owner') == lplr.UserId then
                            table.insert(self, obj)
                        end
                    end)
                end)
                repeat
                    if store.equippedKit ~= 'owl' then
                        task.wait(3)
                        continue
                    end

                    if entitylib.isAlive then
                        local owl = owls[1]
                        if owl then
                            local origin = owl.Part.Position
                            local plr = entitylib.EntityPosition({
                                Origin = origin,
                                Range = Range.Value,
                                Part = 'RootPart',
                                Players = Targets.Players.Enabled,
                                NPCs = Targets.NPCs.Enabled,
                                Wallcheck = Targets.Walls.Enabled,
                                Sort = sortmethods.Health,
                            })

                            if plr then
                                local meta = getProjectileMeta()
                                local calc = prediction.SolveTrajectory(origin, meta.launchVelocity, meta.gravitationalAcceleration, plr.RootPart.Position, plr.RootPart.Velocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil)
                                if calc then
                                    local dir = CFrame.lookAt(origin, calc).LookVector * meta.launchVelocity
                                    bedwars.Client:Get('OwlAiming'):SendToServer({
                                        owl = owl.Part,
                                        starting = true,
                                    })
                                    bedwars.Client:Get('OwlFireProjectile'):SendToServer({
                                        ProjectileRefId = vape.Libraries.string:GenerateString(8),
                                        direction = dir,
                                        fromPosition = origin,
                                        initialVelocity = dir,
                                    })
                                    task.wait(lplr:GetNetworkPing())
                                end
                            end
                        end
                    end
                    task.wait(0.1)
                until not OwlAura.Enabled
            else
                bedwars.Client:Get('OwlAiming'):SendToServer({
                    starting = false,
                })
            end
        end,
        Tooltip = 'Automatically shoots projectiles with whisper kit'
    })

    Targets = OwlAura:CreateTargets({
        Players = true,
        Wallcheck = true,
    })
    Range = OwlAura:CreateSlider({
        Name = 'Range',
        Min = 1,
        Max = 50,
        Suffix = function(val)
            return val <= 0 and 'stud' or 'studs'
        end,
        Default = 50,
    })
end)
run(function()
    local SilentAura
    local Targets
    local Speed
    local Range
    local Angle
    local Mode
    local Area
    local LegitAura
    local Mouse
    local NoSwing
    local Limit
    local SilentAim
    local SwingTime
    local Perfect
    local FaceTarget
    local Dynamic

    local Show
    local Targetcolor
    local Attackcolor

    


    local lastHit = 0

    local function dynamicHitDelay(ent, meta)
        local delay = ((meta.displayName and meta.displayName:find(' Chainsaw')) and 0.11 or 0.29) + 0.03
        local distance = math.min(14.4, (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude)
        return delay * distance / 14.4
    end

    local function readyToHit(ent, sword, meta)
        if Dynamic.Enabled then
            return (tick() - lastHit) >= dynamicHitDelay(ent, meta)
        end
        local ok, remaining = pcall(function()
            return bedwars.SwordController:getRemainingSwingCooldown(sword.tool.Name)
        end)
        if ok and type(remaining) == 'number' then
            return remaining <= 0
        end
        
        
        return (tick() - lastHit) >= (Perfect.Enabled and ((meta.sword and meta.sword.attackSpeed) or 0.11) or math.max(SwingTime.Value, 0.11))
    end

    local function getAttackData()
        if not entitylib.isAlive then
            return false
        end
        if Mouse.Enabled then
            if not inputService:IsMouseButtonPressed(0) and (tick() - bedwars.SwordController.lastSwing) > 0.3 then
                return false
            end
        end
        if LegitAura.Enabled and (tick() - bedwars.SwordController.lastSwing) > 0.3 then
            return false
        end

        if (lplr.Character:GetAttribute('StunnedUntilTime') or 0) - workspace:GetServerTimeNow() > 0 then
            return false
        end
        if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
            return false
        end

        local sword = Limit.Enabled and store.hand or store.tools.sword
        if not sword or not sword.tool then
            return false
        end

        local meta = bedwars.ItemMeta[sword.tool.Name]
        if Limit.Enabled then
            if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then
                return false
            end
        end

        return sword, meta
    end

    local cache = {}
    local function getAim(ent)
        if Area.Value == 'Closest' then
            if not cache[ent.Character] then
                cache[ent.Character] = ent.Character:GetChildren()
            end
            local localPosition, magnitude, part = inputService.GetMouseLocation(inputService), 9e9, nil
            for _, v in cache[ent.Character] do
                if v and v.Parent and v:IsA('BasePart') then
                    local position, vis = gameCamera.WorldToViewportPoint(gameCamera, v.Position)

                    if vis then
                        local mag = (localPosition - Vector2.new(position.x, position.y)).Magnitude

                        if mag < magnitude then
                            magnitude = mag
                            part = v
                        end
                    end
                end
            end
            if part then
                return part.Position
            end
        end
        return ent.RootPart.Position
    end

    local function ease(t)
        return t < 0.5 and 4 * t * t * t or 1 - math.pow(-2 * t + 2, 3) / 2
    end

    local function findAim(localcframe, ent, fps, started)
        local prog, rng = ease(math.min((tick() - started) / (1 / (Speed.Value * 0.5)), 1)), Random.new()
        local speed = Speed.Value * prog
        return localcframe:Lerp(CFrame.lookAt(localcframe.p, getAim(ent) + Vector3.new((rng:NextNumber() - 0.5) * 15 * fps, (rng:NextNumber() - 0.5) * 15 * fps, (rng:NextNumber() - 0.5) * 15 * fps)), speed * fps), speed
    end

    local box = Instance.new('BoxHandleAdornment')
    box.Adornee = nil
    box.AlwaysOnTop = true
    box.Size = Vector3.new(3, 5, 3)
    box.CFrame = CFrame.new(0, -0.5, 0)
    box.ZIndex = 0
    box.Parent = vape.gui

    SilentAura = vape.Categories.Combat:CreateModule({
        Name = 'SilentAura',
        Function = function(callback)
            if callback then
                local lastent, lastfound = nil, 0
                local foundat = tick()
                local lastattacked = tick()

                SilentAura:Clean(runService.PostSimulation:Connect(function(dt)
                    
                    
                    
                    if entitylib.isAlive and tick() - lastfound < 0.5 and FaceTarget.Enabled then
                        targetinfo.Targets[lastent] = tick() + 0.5
                        entitylib.character.Humanoid.AutoRotate = not SilentAim.Enabled
                        local cframe, speed = findAim(gameCamera.CFrame, lastent, dt, foundat)
                        if SilentAim.Enabled then
                            entitylib.character.RootPart.CFrame = entitylib.character.RootPart.CFrame:Lerp(CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(lastent.RootPart.Position.X, entitylib.character.RootPart.Position.Y, lastent.RootPart.Position.Z)), (speed + 2) * dt)
                        else
                            gameCamera.CFrame = cframe
                        end
                    elseif entitylib.isAlive then
                        entitylib.character.Humanoid.AutoRotate = true
                    end
                end))

                local frames = 9e9
                repeat
                    task.wait()
                    local sword, meta = getAttackData()
                    if sword then
                        local localPosition = entitylib.character.RootPart.Position
                        local ent = entitylib.EntityPosition({
                            Origin = localPosition,
                            Range = bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE + Range.Value,
                            Wallcheck = Targets.Walls.Enabled or nil,
                            Part = 'RootPart',
                            Players = Targets.Players.Enabled,
                            NPCs = Targets.NPCs.Enabled,
                            Limit = 1,
                            Sort = sortmethods[Mode.Value or 'Distance'],
                        })
                        local Slider = tick() - lastattacked < 0.1 and Attackcolor or Targetcolor
                        box.Adornee = Show.Enabled and ent and ent.RootPart or nil
                        box.Transparency = 1 - Slider.Opacity
                        box.Color3 = Color3.fromHSV(Slider.Hue, Slider.Sat, Slider.Value)
                        if ent then
                            if not store.hand or store.hand.tool ~= sword.tool then
                                local hotbar = getHotbar(sword.tool)
                                if hotbar then
                                    hotbarSwitch(hotbar)
                                else
                                    continue
                                end
                            end
                            if frames > 50 then
                                frames = 0
                            end
                            frames += 1

                            local localfacing = (inputService.KeyboardEnabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector * Vector3.new(1, 0, 1)
                            local delta, flat = (ent.RootPart.Position - localPosition), ((ent.RootPart.Position - localPosition) * Vector3.new(1, 0, 1))
                            local facingdot = flat.Magnitude > 0 and localfacing.Magnitude > 0 and (localfacing / localfacing.Magnitude):Dot(flat / flat.Magnitude) or 0
                            if facingdot < math.cos(math.rad(Angle.Value) / 2) then
                                continue
                            end

                            if not LegitAura.Enabled and (tick() - bedwars.SwordController.lastSwing) >= (Perfect.Enabled and (meta.sword.attackSpeed or 0.11) or math.max(SwingTime.Value, 0.11)) then
                                bedwars.SwordController:playSwordEffect(meta, false)
                                bedwars.SwordController.lastSwing = tick()
                            end

                            if lastent ~= ent or facingdot < -0.5 then
                                foundat = tick()
                            end
                            lastent, lastfound = ent, tick()

                            if delta.Magnitude > bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE then
                                continue
                            end
                            lastattacked = tick()

                            if not readyToHit(ent, sword, meta) then
                                continue
                            end
                            lastHit = tick()

                            local dir = CFrame.lookAt(localPosition, ent.RootPart.Position).LookVector
                            local pos = localPosition + dir * math.max(delta.Magnitude - 14.4, 0)
                            bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
                            bedwars.Client:Get(remotes.AttackEntity):SendToServer({
                                weapon = sword.tool,
                                chargedAttack = {chargeRatio = 0},
                                entityInstance = ent.Character,
                                validate = {
                                    raycast = {
                                        cameraPosition = {value = pos},
                                        cursorDirection = {value = dir},
                                    },
                                    targetPosition = {
                                        
                                        
                                        
                                        value = ent.Character:GetPivot().Position,
                                    },
                                    selfPosition = {value = pos},
                                },
                            })
                        else
                            lastfound = 0
                            frames = 0
                        end
                    else
                        box.Adornee = nil
                        lastfound = 0
                        frames = 0
                    end
                until not SilentAura.Enabled
            else
                if entitylib.isAlive then
                    entitylib.character.Humanoid.AutoRotate = true
                end
                box.Adornee = nil
            end
        end,
        Tooltip = 'Automatically aims and attacks nearby target',
    })

    Targets = SilentAura:CreateTargets({
        Players = true,
        NPCs = true,
    })
    Speed = SilentAura:CreateSlider({
        Name = 'Aim speed',
        Min = 1,
        Max = 10,
        Default = 6,
        Decimal = 5,
        Tooltip = 'How fast the Aura is going to aim',
    })
    SwingTime = SilentAura:CreateSlider({
        Name = 'Swing time',
        Darker = true,
        Visible = false,
        Min = 0,
        Max = 0.5,
        Default = 0.42,
        Decimal = 100,
    })
    Range = SilentAura:CreateSlider({
        Name = 'Extra swing distance',
        Tooltip = 'Where you will start swinging, not attacking',
        Min = 0,
        Max = 6,
        Suffix = function(val)
            return val <= 1 and 'stud' or 'studs'
        end,
        Decimal = 5,
        Default = 3,
    })
    Angle = SilentAura:CreateSlider({
        Name = 'Max angle',
        Min = 1,
        Max = 360,
        Default = 180,
    })
    local methods = {'Damage', 'Distance'}
    for _, i in sortlist do
        if not table.find(methods, i) then
            table.insert(methods, i)
        end
    end
    Mode = SilentAura:CreateDropdown({
        Name = 'Target mode',
        List = methods,
        Tooltip = 'How Aura should prioritize targets',
        Default = 'Health',
    })
    Area = SilentAura:CreateDropdown({
        Name = 'Target area',
        Tooltip = 'Where the Aura will aim towards',
        List = {'Center', 'Closest'},
        Default = 'Center',
        Visible = false,
    })
    Perfect = SilentAura:CreateToggle({
        Name = 'Perfect Swing',
        Tooltip = 'Follows tool\'s swing time',
        Function = function(callback)
            SwingTime.Object.Visible = not callback
        end,
        Default = true,
    })
    Mouse = SilentAura:CreateToggle({Name = 'Require mouse down'})
    Dynamic = SilentAura:CreateToggle({
        Name = 'Dynamic hits',
        Tooltip = 'Times each hit off the range to the target instead of the swing cooldown, so the server keeps more of them'
    })
    LegitAura = SilentAura:CreateToggle({Name = 'Swing only'})
    SilentAim = SilentAura:CreateToggle({
        Name = 'Silent Aim',
        Tooltip = 'Silently aims while keeping natural-looking camera movement.',
        Default = true,
        Function = function(callback)
            Area.Object.Visible = not callback
        end,
    })
    FaceTarget = SilentAura:CreateToggle({
        Name = 'Face target',
        Tooltip = 'On - turns to face the target\nOff - never turns, though hits inside Max angle still land',
        Default = true,
    })
    Show = SilentAura:CreateToggle({
        Name = 'Show target',
        Default = true,
        Function = function(callback)
            pcall(function()
                Targetcolor.Object.Visible = callback
                Attackcolor.Object.Visible = callback
            end)
        end,
    })
    Targetcolor = SilentAura:CreateColorSlider({
        Name = 'Target color',
        Darker = true,
        DefaultOpacity = 0.5,
    })
    Attackcolor = SilentAura:CreateColorSlider({
        Name = 'Attack color',
        Darker = true,
        DefaultOpacity = 0.5,
    })
    Limit = SilentAura:CreateToggle({Name = 'Limit to items'})
end)

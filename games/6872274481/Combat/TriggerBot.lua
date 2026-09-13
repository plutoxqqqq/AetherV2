run(function()
    local TriggerBot
    local CPS
    local Projectile
    local ProjectileRange
    local ProjectileBlacklist
    local Targets
    local Range, Angle, Limit, Region, Mouse, GUI, ShowTarget, BoxColor, BoxTween, BoxSpeed
    local box
    local rayParams = RaycastParams.new()
    local projectileRemote = {InvokeServer = function() end}
    local nextFire = 0
    task.spawn(function()
        projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
    end)

    local function meleeTarget(origin, range)
        if Angle.Value > 0 then
            local ent = entitylib.EntityMouse({Part = 'RootPart', Range = Angle.Value, MouseOrigin = gameCamera.ViewportSize / 2,
                Players = Targets.Players.Enabled, NPCs = Targets.NPCs.Enabled, Wallcheck = Targets.Walls.Enabled, Origin = origin})
            return ent and (origin - ent.RootPart.Position).Magnitude <= range and ent or nil
        end
        local unit = lplr:GetMouse().UnitRay
        rayParams.FilterDescendantsInstances = {lplr.Character}
        local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * 200, rayParams)
        if not ray then return end
        for _, ent in entitylib.List do
            if ent.Targetable and ray.Instance:IsDescendantOf(ent.Character) and (origin - ent.RootPart.Position).Magnitude <= range
                and (Targets.Players.Enabled and ent.Player or Targets.NPCs.Enabled and not ent.Player)
                and (not Targets.Walls.Enabled or not entitylib.Wallcheck(origin, ent.RootPart.Position, true, ent)) then return ent end
        end
    end

    local function getAmmo(source)
        for _, item in store.inventory.inventory.items do
            if source.ammoItemTypes and table.find(source.ammoItemTypes, item.itemType) then
                return item.itemType
            end
        end
    end

    
    
    
    local function fireProjectileAt(ent)
        if tick() < nextFire then return false end
        local hand = store.hand.tool
        local meta = hand and bedwars.ItemMeta[hand.Name]
        local source = meta and meta.projectileSource
        if not (entitylib.isAlive and source and ent and ent.RootPart) then return false end

        local ammo = getAmmo(source) or (source.ammoItemTypes and source.ammoItemTypes[1]) or hand.Name
        local projectile = type(source.projectileType) == 'function' and source.projectileType(ammo) or source.projectileType or ammo
        if table.find(ProjectileBlacklist.ListEnabled, hand.Name) or table.find(ProjectileBlacklist.ListEnabled, ammo) or table.find(ProjectileBlacklist.ListEnabled, projectile) then return false end
        local projmeta = bedwars.ProjectileMeta[projectile] or bedwars.ProjectileMeta[ammo]
        if not projmeta then return false end

        local root = entitylib.character.RootPart
        local selfpos = root.Position
        local speed = projmeta.launchVelocity or source.launchVelocity or 100
        local gravity = projmeta.gravitationalAcceleration or 196.2
        rayParams.FilterDescendantsInstances = {lplr.Character, gameCamera}
        local target = prediction.SolveTrajectory(selfpos, speed, gravity, ent.RootPart.Position, ent.RootPart.AssemblyLinearVelocity, workspace.Gravity, ent.HipHeight, ent.Jumping and 42.6 or nil, rayParams, nil, lplr:GetNetworkPing())
        if not target then return false end

        local dir = CFrame.lookAt(selfpos, target).LookVector
        local shootPosition = (CFrame.new(selfpos, target) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ))).Position

        switchItem(hand)
        local id = httpService:GenerateGUID(true)
        local success = pcall(function()
            
            
            
            bedwars.ProjectileController:createLocalProjectile(projmeta, ammo, projectile, shootPosition, id, dir * speed, {drawDurationSeconds = projmeta.drawDurationSeconds or 1})
            projectileRemote:InvokeServer(hand, ammo, projectile, shootPosition, selfpos, dir * speed, id, {
                drawDurationSeconds = projmeta.drawDurationSeconds or 1,
                shotId = httpService:GenerateGUID(false)
            }, workspace:GetServerTimeNow() - 0.045)
        end)
        if success then
            nextFire = tick() + (source.fireDelaySec or 0.25)
            local shoot = source.launchSound
            shoot = shoot and shoot[math.random(1, #shoot)] or nil
            if shoot then pcall(function() bedwars.SoundManager:playSound(shoot) end) end
            
            
            
            
            
            
            local fp = resolveAnimation({'FP_BOW_SHOOT', 'FP_CROSSBOW_SHOOT', 'FP_SHOOT', 'FP_THROW'})
                or matchAnimation('fp_projectile', {
                    {'fp', 'bow', 'shoot'}, {'fp', 'bow', 'release'}, {'fp', 'bow', 'fire'},
                    {'fp', 'shoot'}, {'fp', 'fire'}, {'fp', 'throw'}, {'fp', 'launch'}, {'fp', 'bow'}
                }, {'charge', 'draw', 'pull', 'idle', 'equip', 'hold', 'walk', 'run', 'reload'})
                
                
                or resolveAnimation({'FP_USE_ITEM'})
            local body = resolveAnimation({'BOW_SHOOT', 'CROSSBOW_SHOOT', 'SHOOT', 'THROW'})
                or matchAnimation('body_projectile', {
                    {'bow', 'shoot'}, {'bow', 'release'}, {'bow', 'fire'},
                    {'shoot'}, {'throw'}, {'launch'}
                }, {'fp', 'charge', 'draw', 'pull', 'idle', 'equip', 'hold', 'walk', 'run', 'reload'})
            if fp then
                pcall(function()
                    bedwars.ViewmodelController:playAnimation(fp)
                end)
            end
            if body then
                pcall(function()
                    bedwars.GameAnimationUtil:playAnimation(lplr.Character, body)
                end)
            end
        end
        return success
    end

    TriggerBot = vape.Categories.Combat:CreateModule({
        Name = 'TriggerBot',
        Function = function(callback)
            if callback then
				if ShowTarget and ShowTarget.Enabled and not box then box = Instance.new('BoxHandleAdornment'); box.AlwaysOnTop = true; box.Size = Vector3.zero; box.CFrame = CFrame.new(0, -0.5, 0); box.Parent = vape.gui end
                repeat
                    local doAttack
                    if not GUI.Enabled or not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
                        local ent
                        if entitylib.isAlive and (not Mouse.Enabled or inputService:IsMouseButtonPressed(0)) and (not Limit.Enabled or store.hand.toolType == 'sword') and bedwars.DaoController.chargingMaid == nil then
                            local heldMeta = store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name]
                            local reach = heldMeta and heldMeta.sword and heldMeta.sword.attackRange or 14.4
                            local attackRange = math.clamp(Range.Value, 0, reach * 2)
                            ent = meleeTarget(entitylib.character.RootPart.Position, attackRange)
                            doAttack = ent ~= nil or (Region.Enabled and bedwars.SwordController:getTargetInRegion(attackRange, 0) ~= nil)
                            if ent then targetinfo.Targets[ent] = tick() + 1 end
                            if doAttack then
                                bedwars.SwordController:swingSwordAtMouse()
                            end
                        end
						if box then
							box.Adornee = ent and ent.RootPart or nil
							tweenService:Create(box, TweenInfo.new(BoxSpeed.Value, Enum.EasingStyle[BoxTween.Value]), {Size = ent and Vector3.new(4, 6, 4) or Vector3.zero}):Play()
							if ent then box.Color3 = Color3.fromHSV(BoxColor.Hue, BoxColor.Sat, BoxColor.Value); box.Transparency = 1 - BoxColor.Opacity end
						end

                        if entitylib.isAlive and Projectile.Enabled and store.hand.tool then
                            local unit = lplr:GetMouse().UnitRay
                            rayParams.FilterDescendantsInstances = {lplr.Character}
                            local ray = bedwars.QueryUtil:raycast(unit.Origin, unit.Direction * ProjectileRange.Value, rayParams)
                            if ray then
                                for _, ent in entitylib.List do
                                    if ent.Targetable and (Targets.Players.Enabled or not ent.Player) and (Targets.NPCs.Enabled or ent.Player) and ray.Instance:IsDescendantOf(ent.Character) then
                                        if fireProjectileAt(ent) then
                                            doAttack = true
                                        end
                                        break
                                    end
                                end
                            end
                        end
                    end

                    task.wait(doAttack and 1 / CPS.GetRandomValue() or 0.016)
                until not TriggerBot.Enabled
			elseif box then
				box:Destroy()
				box = nil
            end
        end,
        Tooltip = 'Automatically swings when hovering over a entity'
    })
    Targets = TriggerBot:CreateTargets({Players = true, NPCs = true, Walls = true})
    Range = TriggerBot:CreateSlider({Name = 'Range', Min = 1, Max = 18, Default = 18, Decimal = 10, Suffix = ' studs', Tooltip = 'Clamped by held weapon reach.'})
    Angle = TriggerBot:CreateSlider({Name = 'Angle', Min = 0, Max = 1000, Default = 0, Tooltip = 'Targets near screen center instead of only the cursor ray.'})
    CPS = TriggerBot:CreateTwoSlider({
        Name = 'CPS',
        Min = 1,
        Max = 9,
        DefaultMin = 7,
        DefaultMax = 7
    })
    Limit = TriggerBot:CreateToggle({Name = 'Limit to items', Default = true})
    Region = TriggerBot:CreateToggle({Name = 'Region check', Default = true})
    Mouse = TriggerBot:CreateToggle({Name = 'Require mouse down'})
    GUI = TriggerBot:CreateToggle({Name = 'GUI check'})
    Projectile = TriggerBot:CreateToggle({
        Name = 'Projectiles',
        Function = function(call)
            pcall(function()
                ProjectileRange.Object.Visible = call
                ProjectileBlacklist.Object.Visible = call
            end)
        end,
    })
    ProjectileRange = TriggerBot:CreateSlider({Name = 'Projectile Range', Min = 10, Max = 120, Default = 60, Suffix = 'studs', Visible = false})
    ProjectileBlacklist = TriggerBot:CreateTextList({Name = 'Projectile Blacklist', Default = {'telepearl', 'fireball'}, Visible = false})
    ShowTarget = TriggerBot:CreateToggle({Name = 'Show target', Function = function(enabled)
        if BoxColor then BoxColor.Object.Visible = enabled; BoxTween.Object.Visible = enabled; BoxSpeed.Object.Visible = enabled end
        if box then box:Destroy(); box = nil end
        if enabled then box = Instance.new('BoxHandleAdornment'); box.AlwaysOnTop = true; box.Size = Vector3.zero; box.CFrame = CFrame.new(0, -0.5, 0); box.Parent = vape.gui end
    end})
    local animations = {'Bounce'}
    for _, style in Enum.EasingStyle:GetEnumItems() do if not table.find(animations, style.Name) then table.insert(animations, style.Name) end end
    BoxTween = TriggerBot:CreateDropdown({Name = 'Box Animation', List = animations, Visible = false})
    BoxSpeed = TriggerBot:CreateSlider({Name = 'Animation Speed', Min = 0, Max = 10, Default = 0.9, Decimal = 30, Visible = false})
    BoxColor = TriggerBot:CreateColorSlider({Name = 'Target Color', DefaultHue = 0.6, DefaultOpacity = 0.5, Visible = false})
end)

run(function()
    local Killaura
    local Targets
    local Sort
    local SwingRange
    local AttackRange
    local SwingTime
	local Sync
	local HitRegCalculator
	local hitRegLastUpdate
	local hitRegAttackCooldown
	local hitRegAnimationTime
	local hitRegUpdateInterval
	local hitRegWeapon
	local hitRegPing
	local hitRegFury
	local furyAttribute
	local furyBalance
    local AngleSlider
	local ChanceSlider
    local MaxTargets
    local Mouse
	local Attackable
    local Swing
    local GUI
    local BoxSwingColor
    local BoxAttackColor
    local ParticleTexture
    local ParticleColor1
    local ParticleColor2
    local ParticleSize
    local Face
    local Animation
    local AnimationMode
    local AnimationSpeed
    local AnimationTween
    local Limit
    local LegitAura
    local TargetSkilled
    local AttackMode
	local Particles, Boxes = {}, {}
    local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
	local AttackRemote
	local lastRemoteRefresh = 0
	local function refreshAttackRemote()
		local ok, remote = pcall(function()
			return bedwars.Client:Get(remotes.AttackEntity).instance
		end)
		if ok and remote and type(remote.FireServer) == 'function' then
			AttackRemote = remote
			lastRemoteRefresh = tick()
			return true
		end
		return false
	end
	task.spawn(refreshAttackRemote)

    
    
    
    
    
    
    local function analyserReady()
        local analyser = getgenv().EntityAnalyser
        return analyser ~= nil and analyser.Enabled == true
    end

    
    
    
    
    local skillCache = {}
    local function skillBucket(ent)
        local plr = ent.Player
        if not plr then return -1 end
        local cached = skillCache[plr]
        if cached then return cached end

        local bucket = -1
        local analyser = getgenv().EntityAnalyser
        if analyser then
            local analysis = analyser.Analyse(plr)
            
            
            if analysis.Rating ~= 'Unknown' then
                bucket = math.floor(analysis.OverallSkill / 10)
            end
        end
        skillCache[plr] = bucket
        return bucket
    end

    local function targetSort()
        local base = sortmethods[Sort.Value]
        if not (TargetSkilled and TargetSkilled.Enabled and analyserReady()) then
            return base
        end
        
        
        
        table.clear(skillCache)
        return function(a, b)
            
            
            
            local targetA = a.Entity.Target and true or false
            local targetB = b.Entity.Target and true or false
            if targetA ~= targetB then
                return targetA
            end
            local skillA, skillB = skillBucket(a.Entity), skillBucket(b.Entity)
            if skillA ~= skillB then
                return skillA > skillB
            end
            
            
            if base then
                return base(a, b)
            end
            return a.Magnitude < b.Magnitude
        end
    end

    local function getAttackData()
		
		
		if not entitylib.isAlive or not entitylib.character or not entitylib.character.RootPart then return false end
        if Mouse.Enabled then
            
            
            
            if not inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
                and (tick() - bedwars.SwordController.lastSwing) > 0.15 then return false end
        end

		if GUI.Enabled then
			if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
		end

        if Attackable.Enabled then
            if not entitylib.isAlive then return false end
            if (lplr.Character:GetAttribute('StunnedUntilTime') or 0) > workspace:GetServerTimeNow() then return false end
            if lplr.Character:FindFirstChild('elk') then return false end
            if bedwars.StatusEffectUtil:isActive(lplr.Character, 'frozen') then return false end
        end

		local sword = Limit.Enabled and store.hand or store.tools.sword
		if not sword or not sword.tool or not sword.tool.Parent then return false end

		local meta = bedwars.ItemMeta[sword.tool.Name]
		if type(meta) ~= 'table' then return false end
        if Limit.Enabled then
            if store.hand.toolType ~= 'sword' or bedwars.DaoController.chargingMaid then return false end
        end

        if LegitAura.Enabled then
			if (tick() - bedwars.SwordController.lastSwing) > 0.2 then return false end
        end

        return sword, meta
    end

	local lastvelos = setmetatable({}, {
		__index = function(self, index)
			self[index] = {}
			return self[index]
		end
	})
	local function getMultiplier(ent, root)
		if #lastvelos[ent] > 18 then
			table.remove(lastvelos[ent], 1)
		end

		local newvelo, velo = root.AssemblyLinearVelocity, Vector3.zero
		for _, v in lastvelos[ent] do
			velo += v
		end
		local samples = lastvelos[ent]
		table.insert(lastvelos[ent], newvelo)
		if #samples < 2 then
			return Vector3.zero
		end
		return newvelo - (velo / (#samples - 1))
	end
	local function getPosition(ent, root)
		local multi, pos = getMultiplier(ent, root), root.Position + (root.AssemblyLinearVelocity * (lplr:GetNetworkPing()))
		if #lastvelos[ent] > 1 then
			pos = pos + (0.5 * multi * (lplr:GetNetworkPing() * lplr:GetNetworkPing()))
		end
		return pos
	end

	
	
	
	local function furyType()
		return bedwars.StatusEffectMeta.FURY_POTION or 'fury_potion'
	end
	local function hasFuryPotion()
		local character = lplr.Character
		if not character then return false end
		local effect = furyType()
		if bedwars.StatusEffectUtil:isActive(character, effect) then
			return true
		end
		local ok, attribute = pcall(bedwars.StatusEffectUtil.getAttributeName, bedwars.StatusEffectUtil, effect)
		furyAttribute = ok and attribute or furyAttribute
		return furyAttribute ~= nil and character:GetAttribute(furyAttribute) ~= nil
	end
	local function getFuryMultiplier()
		if furyBalance then return furyBalance.FURY_POTION_ATTACK_SPEED_MULTIPLIER or 1 end
		for _, module in replicatedStorage:GetDescendants() do
			if module:IsA('ModuleScript') and module.Name:lower():find('black%-marketeer%-balance') then
				local ok, balance = pcall(require, module)
				if ok and type(balance) == 'table' then
					furyBalance = balance
					break
				end
			end
		end
		return furyBalance and furyBalance.FURY_POTION_ATTACK_SPEED_MULTIPLIER or 1
	end
	local function calculateAttackDelay(meta)
		local base = Sync.Enabled and SwingTime.Value or ((meta.sword and meta.sword.attackSpeed) or 0.292)
		local fury = hasFuryPotion()
		if fury then base *= getFuryMultiplier() end
		if HitRegCalculator.Enabled then
			local ping = math.clamp(lplr:GetNetworkPing(), 0, 1)
			base = math.clamp(base - math.min(ping * 0.5, base * 0.35), 0.05, 2)
		end
		return math.clamp(base, 0.05, 2), fury
	end

    Killaura = vape.Categories.Blatant:CreateModule({
        Name = 'Killaura',
        Function = function(callback)
            if callback then
				if Animation.Enabled and not (identifyexecutor and table.find({'Argon', 'Delta'}, ({identifyexecutor()})[1])) then
                    local fake = {
                        Controllers = {
                            ViewmodelController = {
                                isVisible = function()
                                    return not Attacking
                                end,
                                playAnimation = function(...)
                                    if not Attacking then
                                        bedwars.ViewmodelController:playAnimation(select(2, ...))
                                    end
                                end
                            }
                        }
                    }
					debug.setupvalue(oldSwing or bedwars.SwordController.playSwordEffect, 7, fake)
                    debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, fake)

                    task.spawn(function()
                        local started = false
                        repeat
                            if Attacking then
                                if not armC0 then
                                    armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
                                end
                                local first = not started
                                started = true

                                if AnimationMode.Value == 'Random' then
                                    anims.Random = {{CFrame = CFrame.Angles(math.rad(math.random(1, 360)), math.rad(math.random(1, 360)), math.rad(math.random(1, 360))), Time = 0.12}}
                                end

                                for _, v in anims[AnimationMode.Value] do
									AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(first and (AnimationTween.Enabled and 0.001 or 0.1) or (hitRegAnimationTime or v.Time) / AnimationSpeed.Value, Enum.EasingStyle.Linear), {
                                        C0 = armC0 * v.CFrame
                                    })
                                    AnimTween:Play()
                                    AnimTween.Completed:Wait()
                                    first = false
                                    if (not Killaura.Enabled) or (not Attacking) then break end
                                end
                            elseif started then
                                started = false
                                AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
                                    C0 = armC0
                                })
                                AnimTween:Play()
                            end

                            if not started then
                                task.wait()
                            end
                        until (not Killaura.Enabled) or (not Animation.Enabled)
                    end)
                end

				local swingCooldown = tick()
                
                local singleTarget, switchIndex = nil, 0
                repeat
                    local attacked, sword, meta = {}, getAttackData()
                    Attacking = false
                    store.KillauraTarget = nil
                    if sword then
                        do
                            local ping = math.clamp(lplr:GetNetworkPing(), 0, 1)
                            local weapon = sword.tool.Name
                            local fury = hasFuryPotion()
                            if weapon ~= hitRegWeapon or fury ~= hitRegFury or not hitRegPing or math.abs(ping - hitRegPing) >= 0.005
                                or not hitRegLastUpdate or tick() - hitRegLastUpdate >= 1 then
                                hitRegLastUpdate, hitRegWeapon, hitRegPing, hitRegFury = tick(), weapon, ping, fury
								hitRegAttackCooldown, hitRegFury = calculateAttackDelay(meta)
								hitRegAnimationTime = hitRegAttackCooldown
                                hitRegUpdateInterval = math.clamp(math.min(hitRegAttackCooldown / 4, 1 / 30), 1 / 60, 0.1)
                            end
                        end
						
						
						
						local found, plrs = pcall(entitylib.AllPosition, {
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Limit = MaxTargets.Value,
							Sort = targetSort()
						})
						if not found or type(plrs) ~= 'table' then plrs = {} end

                        if #plrs > 0 then
                            switchItem(sword.tool, 0)
							local selfpos = entitylib.character.RootPart.Position
							local localfacing = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
							if localfacing.Magnitude > 0.001 then localfacing = localfacing.Unit end

                            
                            
                            
                            local inrange, hittable = {}, {}
							for _, v in plrs do
								if not v.RootPart or not v.RootPart.Parent then continue end
								local delta = (v.RootPart.Position - selfpos)
								local flatDelta = delta * Vector3.new(1, 0, 1)
								local angle = flatDelta.Magnitude > 0.001 and math.acos(math.clamp(localfacing:Dot(flatDelta.Unit), -1, 1)) or 0
								if angle > (math.rad(AngleSlider.Value) / 2) then continue end

                                local entry = {Entity = v, Delta = delta}
                                table.insert(inrange, entry)
                                if delta.Magnitude <= AttackRange.Value then
                                    table.insert(hittable, entry)
                                end
                            end

                            
                            
                            
                            local focus
                            if AttackMode.Value == 'Single' then
                                for _, v in hittable do
                                    if v.Entity == singleTarget then
                                        focus = v
                                        break
                                    end
                                end
                                focus = focus or hittable[1]
                                singleTarget = focus and focus.Entity or nil
                            else
                                singleTarget = nil
                                if #hittable > 0 then
                                    focus = hittable[(switchIndex % #hittable) + 1]
                                end
                            end

							for _, entry in inrange do
                                local v, delta = entry.Entity, entry.Delta

                                table.insert(attacked, {
                                    Entity = v,
                                    Check = delta.Magnitude > AttackRange.Value and BoxSwingColor or BoxAttackColor
                                })
                                targetinfo.Targets[v] = tick() + 1

                                if not Attacking then
                                    Attacking = true
                                    store.KillauraTarget = focus and focus.Entity or v
								if not Swing.Enabled and AnimDelay < tick() and not LegitAura.Enabled then
										AnimDelay = tick() + math.max(hitRegAnimationTime or SwingTime.Value, 0.05)
										pcall(function()
											bedwars.SwordController:playSwordEffect(meta, false)
											if type(meta.displayName) == 'string' and meta.displayName:find(' Scythe') then
												bedwars.ScytheController:playLocalAnimation()
											end
										end)

                                        if vape.ThreadFix then
                                            setthreadidentity(8)
                                        end
                                    end
                                end

                                if entry ~= focus then continue end

								local actualRoot = (v.Character and v.Character.PrimaryPart) or v.RootPart
								local attackDelay = calculateAttackDelay(meta)
								if actualRoot and actualRoot.Parent and v.Character and v.Character.Parent and (tick() - swingCooldown) >= (attackDelay or 0.292) then
                                    switchIndex += 1
									local dir = CFrame.lookAt(selfpos, actualRoot.Position).LookVector
									local pos = selfpos + dir * math.max(delta.Magnitude - 14.399, 0)
									if not AttackRemote or tick() - lastRemoteRefresh > 15 then refreshAttackRemote() end
									if not AttackRemote then continue end
									local sent = pcall(AttackRemote.FireServer, AttackRemote, {
										weapon = sword.tool,
										chargedAttack = {chargeRatio = 0},
										entityInstance = v.Character,
										validate = {
											raycast = {
												cameraPosition = {value = pos},
												cursorDirection = {value = dir}
                                                        },
											targetPosition = {value = getPosition(v.Character, actualRoot)},
											selfPosition = {value = pos}
										}
									})
									if sent then
										bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
										store.attackReach = (delta.Magnitude * 100) // 1 / 100
										swingCooldown = tick()
										store.attackReachUpdate = tick() + 1
									else
										
										
										refreshAttackRemote()
									end
                                    end
                            end
                        end
                    end

                    for i, v in Boxes do
						v.Adornee = attacked[i] and attacked[i].Entity.RootPart or nil
                        if v.Adornee then
                            v.Color3 = Color3.fromHSV(attacked[i].Check.Hue, attacked[i].Check.Sat, attacked[i].Check.Value)
                            v.Transparency = 1 - attacked[i].Check.Opacity
                        end
                    end

                    for i, v in Particles do
                        v.Position = attacked[i] and attacked[i].Entity.RootPart.Position or Vector3.new(9e9, 9e9, 9e9)
                        v.Parent = attacked[i] and gameCamera or nil
                    end

                    if Face.Enabled and attacked[1] then
                        local vec = attacked[1].Entity.RootPart.Position * Vector3.new(1, 0, 1)
                        entitylib.character.RootPart.CFrame = CFrame.lookAt(entitylib.character.RootPart.Position, Vector3.new(vec.X, entitylib.character.RootPart.Position.Y + 0.001, vec.Z))
                    end

                    task.wait(HitRegCalculator.Enabled and hitRegUpdateInterval or nil)
                until not Killaura.Enabled
            else
                store.KillauraTarget = nil
                for _, v in Boxes do
                    v.Adornee = nil
                end
                for _, v in Particles do
                    v.Parent = nil
                end
                debug.setupvalue(oldSwing or bedwars.SwordController.playSwordEffect, 7, bedwars.Knit)
                debug.setupvalue(bedwars.ScytheController.playLocalAnimation, 3, bedwars.Knit)
                Attacking = false
                if armC0 then
                    AnimTween = tweenService:Create(gameCamera.Viewmodel.RightHand.RightWrist, TweenInfo.new(AnimationTween.Enabled and 0.001 or 0.3, Enum.EasingStyle.Exponential), {
                        C0 = armC0
                    })
                    AnimTween:Play()
                end
            end
        end,
		Tooltip = 'Attack players around you\nwithout aiming at them.'
    })
    Targets = Killaura:CreateTargets({
        Players = true,
        NPCs = true
    })
    local methods = {'Damage', 'Distance'}
    for _, i in sortlist do
        if not table.find(methods, i) then
            table.insert(methods, i)
        end
    end
    SwingRange = Killaura:CreateSlider({
        Name = 'Swing range',
        Min = 1,
		Max = 28,
		Default = 18,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    AttackRange = Killaura:CreateSlider({
        Name = 'Attack range',
        Min = 1,
		Max = 20,
		Default = 18,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    AngleSlider = Killaura:CreateSlider({
        Name = 'Max angle',
        Min = 1,
        Max = 360,
        Default = 360
    })
	ChanceSlider = Killaura:CreateSlider({
		Name = 'Air hit chance',
		Min = 1,
	Max = 100,
	Default = 100,
	Suffix = '%'
    })
    SwingTime = Killaura:CreateSlider({
        Name = 'Swing time',
        Min = 0,
        Max = 2,
	Decimal = 1000,
		Default = 0.11,
		Suffix = 'seconds'
	})
	Sync = Killaura:CreateToggle({
		Name = 'Sync with hitreg',
	Darker = true,
		Tooltip = 'Syncs ur hitreg with the swing time'
    })
    HitRegCalculator = Killaura:CreateToggle({
        Name = 'HitReg calculator',
        Tooltip = 'Calculates an attack cooldown from weapon speed and ping',
        Function = function()
            hitRegLastUpdate, hitRegWeapon, hitRegPing, hitRegFury = nil, nil, nil, nil
            hitRegAttackCooldown, hitRegAnimationTime, hitRegUpdateInterval = nil, nil, nil
        end
    })
    Killaura.ExtraText = function()
        return string.format('Fury %s%s', hitRegFury and 'ON' or 'OFF', hitRegAttackCooldown and string.format(' | %.3fs', hitRegAttackCooldown) or '')
    end
    MaxTargets = Killaura:CreateSlider({
        Name = 'Max targets',
        Min = 1,
        Max = 5,
        Default = 5
    })
    Sort = Killaura:CreateDropdown({
        Name = 'Target Mode',
        List = methods
    })
    AttackMode = Killaura:CreateDropdown({
        Name = 'Attack Mode',
        List = {'Single', 'Switch'},
        Default = 'Single',
        Tooltip = 'Single - stays on one target until they are gone\nSwitch - passes each swing to the next target'
    })
    TargetSkilled = Killaura:CreateToggle({
        Name = 'Target skilled',
        Darker = true,
        Tooltip = 'Hit whoever is playing best first, using EntityAnalyser. Your Targets list still comes first'
    })
    
    
    
    
    if TargetSkilled.Object then
        TargetSkilled.Object.Visible = analyserReady()
    end
    vape:Clean(vapeEvents.EntityAnalyserState.Event:Connect(function(enabled)
        if TargetSkilled.Object then
            TargetSkilled.Object.Visible = enabled and true or false
        end
    end))
    Mouse = Killaura:CreateToggle({Name = 'Require mouse down'})
	Attackable = Killaura:CreateToggle({Name = 'Attackable check'})
    Swing = Killaura:CreateToggle({Name = 'No Swing'})
    GUI = Killaura:CreateToggle({Name = 'GUI check'})
    Killaura:CreateToggle({
        Name = 'Show target',
        Function = function(callback)
            BoxSwingColor.Object.Visible = callback
            BoxAttackColor.Object.Visible = callback
            if callback then
                for i = 1, 10 do
                    local box = Instance.new('BoxHandleAdornment')
                    box.Adornee = nil
                    box.AlwaysOnTop = true
                    box.Size = Vector3.new(3, 5, 3)
                    box.CFrame = CFrame.new(0, -0.5, 0)
                    box.ZIndex = 0
                    box.Parent = vape.gui
                    Boxes[i] = box
                end
            else
                for _, v in Boxes do
                    v:Destroy()
                end
                table.clear(Boxes)
            end
        end
    })
    BoxSwingColor = Killaura:CreateColorSlider({
        Name = 'Target Color',
        Darker = true,
        DefaultOpacity = 0.5,
        Visible = false
    })
    BoxAttackColor = Killaura:CreateColorSlider({
        Name = 'Attack Color',
        Darker = true,
        DefaultOpacity = 0.5,
        Visible = false
    })
    Killaura:CreateToggle({
        Name = 'Target particles',
        Function = function(callback)
            ParticleTexture.Object.Visible = callback
            ParticleColor1.Object.Visible = callback
            ParticleColor2.Object.Visible = callback
            ParticleSize.Object.Visible = callback
            if callback then
                for i = 1, 10 do
                    local part = Instance.new('Part')
                    part.Size = Vector3.new(2, 4, 2)
                    part.Anchored = true
                    part.CanCollide = false
                    part.Transparency = 1
                    part.CanQuery = false
                    part.Parent = Killaura.Enabled and gameCamera or nil
                    local particles = Instance.new('ParticleEmitter')
                    particles.Brightness = 1.5
                    particles.Size = NumberSequence.new(ParticleSize.Value)
                    particles.Shape = Enum.ParticleEmitterShape.Sphere
                    particles.Texture = ParticleTexture.Value
                    particles.Transparency = NumberSequence.new(0)
                    particles.Lifetime = NumberRange.new(0.4)
                    particles.Speed = NumberRange.new(16)
                    particles.Rate = 128
                    particles.Drag = 16
                    particles.ShapePartial = 1
                    particles.Color = ColorSequence.new({
                        ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
                        ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
                    })
                    particles.Parent = part
                    Particles[i] = part
                end
            else
                for _, v in Particles do
                    v:Destroy()
                end
                table.clear(Particles)
            end
        end
    })
    ParticleTexture = Killaura:CreateTextBox({
        Name = 'Texture',
        Default = 'rbxassetid://14736249347',
        Function = function()
            for _, v in Particles do
                v.ParticleEmitter.Texture = ParticleTexture.Value
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleColor1 = Killaura:CreateColorSlider({
        Name = 'Color Begin',
        Function = function(hue, sat, val)
            for _, v in Particles do
                v.ParticleEmitter.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(hue, sat, val)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(ParticleColor2.Hue, ParticleColor2.Sat, ParticleColor2.Value))
                })
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleColor2 = Killaura:CreateColorSlider({
        Name = 'Color End',
        Function = function(hue, sat, val)
            for _, v in Particles do
                v.ParticleEmitter.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromHSV(ParticleColor1.Hue, ParticleColor1.Sat, ParticleColor1.Value)),
                    ColorSequenceKeypoint.new(1, Color3.fromHSV(hue, sat, val))
                })
            end
        end,
        Darker = true,
        Visible = false
    })
    ParticleSize = Killaura:CreateSlider({
        Name = 'Size',
        Min = 0,
        Max = 1,
        Default = 0.2,
        Decimal = 100,
        Function = function(val)
            for _, v in Particles do
                v.ParticleEmitter.Size = NumberSequence.new(val)
            end
        end,
        Darker = true,
        Visible = false
    })
    Face = Killaura:CreateToggle({Name = 'Face target'})
    Animation = Killaura:CreateToggle({
        Name = 'Custom Animation',
        Function = function(callback)
            AnimationMode.Object.Visible = callback
            AnimationTween.Object.Visible = callback
            AnimationSpeed.Object.Visible = callback
            if Killaura.Enabled then
                Killaura:Toggle()
                Killaura:Toggle()
            end
        end
    })
    local animnames = {}
    for i in anims do
        table.insert(animnames, i)
    end
    AnimationMode = Killaura:CreateDropdown({
        Name = 'Animation Mode',
        List = animnames,
        Darker = true,
        Visible = false
    })
    AnimationSpeed = Killaura:CreateSlider({
        Name = 'Animation Speed',
        Min = 0,
        Max = 2,
        Default = 1,
        Decimal = 10,
        Darker = true,
        Visible = false
    })
    AnimationTween = Killaura:CreateToggle({
        Name = 'No Tween',
        Darker = true,
        Visible = false
    })
    Limit = Killaura:CreateToggle({
        Name = 'Limit to items',
		Function = function(callback)
			if inputService.TouchEnabled and Killaura.Enabled then
				pcall(function()
					lplr.PlayerGui.MobileUI['2'].Visible = callback
				end)
			end
		end,
        Tooltip = 'Only attacks when the sword is held'
    })
    LegitAura = Killaura:CreateToggle({
        Name = 'Swing only',
        Tooltip = 'Only attacks while swinging manually'
    })
end)

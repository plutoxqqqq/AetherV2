run(function()
    local Runtime = assert(AetherMatchRuntime, 'Aether BedWars runtime is unavailable')
    local ctx = AetherRuntimeContext
    local Ports = AetherPortContext
    local safe = aetherPortSafe
    local notify = aetherPortNotify
    local rootOfLocal = aetherPortRoot
    local matchRunning = aetherPortMatchRunning
    local equippedKit = aetherPortEquippedKit
    local horizontalUnit = aetherPortHorizontalUnit
    local moduleByName = aetherPortModule
    local register = aetherPortRegister
    local abilityController = aetherPortAbilityController
    local canUseAbility = aetherPortCanUseAbility
    local useAbility = aetherPortUseAbility
    local nearestTarget = aetherPortNearestTarget
    local waitCancelable = aetherPortWait
    local addMovementOwner = aetherPortAddMovementOwner
    local createDecoy = aetherPortCreateDecoy
    local workspaceService = workspace


local InfiniteSigrid
local sigridGeneration = 0

InfiniteSigrid = (function()
    local module, created = register('Kits', 'InfiniteSigrid', {
        Tooltip = 'Keeps the Elk mount active while the Elk Master kit is equipped.',
        Function = function(callback)
            sigridGeneration += 1
            local generation = sigridGeneration
            if not callback then return end

            task.spawn(function()
                local mount
                while module.Enabled and generation == sigridGeneration do
                    if not mount then
                        safe('sigrid.resolve', function()
                            if bedwars.Client and type(bedwars.Client.Get) == 'function' then
                                mount = bedwars.Client:Get('ElkKitMounted')
                            end
                        end)
                    end

                    local kit = tostring(equippedKit() or ''):lower()
                    if mount and entitylib.isAlive and matchRunning() and kit == 'elk_master'
                        and type(mount.SendToServer) == 'function' then
                        safe('sigrid.mount', mount.SendToServer, mount)
                    end
                    task.wait(0.1)
                end
            end)
        end
    })
    if created then return module end
    return module
end)()


end)

run(function()
	local JadeExtender
	local Multiplier

	local old

	JadeExtender = kits:CreateModule({
		Name = 'JadeExtender',
		Function = function(callback)
			if callback then
				old = bedwars.JadeHammerController.useJadeHammer
				bedwars.JadeHammerController.useJadeHammer = function(self)
					local jumped = bedwars.AbilityController:canUseAbility('jade_hammer_jump', {disableBlockedAbilityAlert = true})
					local call = old(self)

					if jumped and store.equippedKit == 'jade' and entitylib.isAlive then
						local root = entitylib.character.RootPart
						root:ApplyImpulse(Vector3.new(0, root.AssemblyMass * (Multiplier.Value - 1) * 20.5, 0))
					end
					return call
				end
			else
				bedwars.JadeHammerController.useJadeHammer = old
			end
		end,
		Tooltip = 'Extends how far the Jade Hammer jump launches you'
	})
	Multiplier = JadeExtender:CreateSlider({
		Name = 'Multiplier',
		Min = 1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 'x'
	})
end)

run(function()
    local KitDisplay

    local function getKitMeta(player)
	local kit = player:GetAttribute('PlayingAsKits') or player:GetAttribute('PlayingAsKit') or 'none'
	return bedwars.BedwarsKitMeta[kit] or bedwars.BedwarsKitMeta.none
    end

    local function getPlayerFromDraft(render, name)
	local id = render and render:match('id=(%d+)')
	if id then
		local player = playersService:GetPlayerByUserId(tonumber(id))
		if player then
			return player
		end
	end

	for _, v in playersService:GetPlayers() do
		if render and render:find('id=' .. v.UserId, 1, true) then
			return v
		end

		if name and (v.Name == name or v.DisplayName == name or v:GetAttribute('DisguiseDisplayName') == name) then
			return v
		end

		local displayName
		pcall(function()
			displayName = bedwars.StreamerModeController:getDisplayName(v)
		end)
		if name and displayName == name then
			return v
		end
	end
	return nil
    end

    local waitForChild = function(start, ...)
	local parent = start
	for _, v in {...} do
		parent = parent and parent:WaitForChild(v, 5)
		if not parent then
			break
		end
	end
	return parent
    end

    local function getPlayerName(card)
	local textbar = card and card:FindFirstChild('TextBackgroundBar')
	local label = textbar and textbar:FindFirstChild('PlayerName') or card and card:FindFirstChild('PlayerName', true)
	return label and label.Text or ''
    end

    local function getDraftCard(container)
	if not container then
		return
	end
	return container.Name == 'MatchDraftPlayerCard' and container or container:FindFirstChild('MatchDraftPlayerCard', true)
    end

    local function callback5v5(v, plr)
	if not v then
		return
	end
	local render = v:FindFirstChild('PlayerRender', true)
	local player = plr or getPlayerFromDraft(render and render.Image or '', getPlayerName(v))

	if player then
		local kitImage = getKitMeta(player)
		local roact = v:FindFirstChild('KitImage')

		if not roact then
			roact = Instance.new('ImageLabel', v)
			roact.BackgroundTransparency = 1
			roact.AnchorPoint = Vector2.new(1, 0.5)
			roact.Position = UDim2.fromScale(1.05, 0.5)
			roact.Name = 'KitImage'
			roact.Size = UDim2.fromScale(1.5, 1.5)
			roact.ZIndex = 1
			roact.ImageTransparency = 0.4
			roact.SliceCenter = Rect.new(0, 0, 0, 0)
			roact.SliceScale = 1
			roact.ScaleType = Enum.ScaleType.Crop

			KitDisplay:Clean(roact)

			local ratio = Instance.new('UIAspectRatioConstraint', roact)
			ratio.Name = '1'
			ratio.AspectRatio = 1
			ratio.AspectType = Enum.AspectType.FitWithinMaxSize
			ratio.DominantAxis = Enum.DominantAxis.Width
		end

		roact.Image = kitImage.renderImage
		roact.Position = UDim2.fromScale(1.05, 0)
		tweenService:Create(roact, TweenInfo.new(0.2, Enum.EasingStyle.Cubic, Enum.EasingDirection.Out), {Position = UDim2.fromScale(1.05, 0.4)}):Play()

		local function update()
			kitImage = getKitMeta(player)
			roact.Image = kitImage.renderImage
		end

		KitDisplay:Clean(player:GetAttributeChangedSignal('PlayingAsKits'):Connect(update))
		KitDisplay:Clean(player:GetAttributeChangedSignal('PlayingAsKit'):Connect(update))
	end
    end

    local function callbacksquad(v)
	if not v then
		return
	end
	local render = v:FindFirstChild('PlayerRender', true)
	local player = render and getPlayerFromDraft(render.Image, '') or nil

	if player then
		local kitImage = getKitMeta(player)
		local Roact = v:FindFirstChild('Kitcvrender')

		if not Roact then
			local base = v:FindFirstChild('3') or v:WaitForChild('3', 5)
			if not base then
				return
			end
			Roact = base:Clone()
			Roact.Parent = v
			Roact.Name = 'Kitcvrender'
			KitDisplay:Clean(Roact)
		end

		Roact.Image = kitImage.renderImage

		KitDisplay:Clean(render:GetPropertyChangedSignal('Image'):Connect(function()
			local newplayer = getPlayerFromDraft(render.Image, '')
			if newplayer then
				player = newplayer
				kitImage = getKitMeta(player)
				Roact.Image = kitImage.renderImage
			end
		end))

		local function update()
			kitImage = getKitMeta(player)
			Roact.Image = kitImage.renderImage
		end

		KitDisplay:Clean(player:GetAttributeChangedSignal('PlayingAsKits'):Connect(update))
		KitDisplay:Clean(player:GetAttributeChangedSignal('PlayingAsKit'):Connect(update))
	end
    end

    local function setup5v5(DraftApp)
	local Background = DraftApp:FindFirstChild('DraftAppBackground')
	local BodyContainer = Background and Background:FindFirstChild('1') and Background['1']:FindFirstChild('BodyContainer')
	local hooked = false

	for i = 1, 2 do
		local dtc = BodyContainer and BodyContainer:FindFirstChild('Team' .. i .. 'Column')
		if dtc then
			hooked = true
			KitDisplay:Clean(dtc.ChildAdded:Connect(function(child)
				task.delay(0.2, function()
					if KitDisplay.Enabled then
						callback5v5(getDraftCard(child))
					end
				end)
			end))

			for _, v in dtc:GetChildren() do
				if v:IsA('Frame') then
					callback5v5(getDraftCard(v))
				end
			end
		end
	end

	if not hooked then
		for _, label in DraftApp:GetDescendants() do
			if label:IsA('TextLabel') and label.Name == 'PlayerName' then
				local container = label.Parent
				for _ = 1, 3 do
					container = container and container.Parent
				end
				if container then
					callback5v5(getDraftCard(container))
				end
			end
		end

		KitDisplay:Clean(DraftApp.DescendantAdded:Connect(function(child)
			if child:IsA('TextLabel') and child.Name == 'PlayerName' then
				task.delay(0.2, function()
					local container = child.Parent
					for _ = 1, 3 do
						container = container and container.Parent
					end
					if KitDisplay.Enabled and container then
						callback5v5(getDraftCard(container))
					end
				end)
			end
		end))
	end

	return hooked
    end

    local function setupSquad(DraftApp)
	local Background = DraftApp:FindFirstChild('DraftAppBackground')
	local BodyContainer = Background and Background:FindFirstChild('1') and Background['1']:FindFirstChild('BodyContainer')
	local TeamsColumn = BodyContainer and BodyContainer:FindFirstChild('TeamsColumn')
	if not TeamsColumn then
		return
	end

	for _, v: Instance in TeamsColumn:GetChildren() do
		if v:IsA('Frame') then
			local plrframe = waitForChild(v, '1', '2', '4')
			if plrframe then
				for _, plr in plrframe:GetChildren() do
					callbacksquad(plr)
				end

				KitDisplay:Clean(plrframe.ChildAdded:Connect(function(plr)
					KitDisplay:Toggle()
					KitDisplay:Toggle()
				end))
			end
		end
	end
    end

    KitDisplay = kits:CreateModule({
	Name = 'KitDisplay',
	Category = 'Visual',
	Function = function(call)
		if call then
			local DraftApp = lplr.PlayerGui:WaitForChild('MatchDraftApp', 9e9)
			setup5v5(DraftApp)
			setupSquad(DraftApp)
		end
	end,
	Tooltip = 'Allows you to see the other opponent kits'
    })
end)

run(function()
    local KitESP
    local Background
    local Color = {}
    local Reference = {}
    local kitGeneration = 0
    local Folder = Instance.new('Folder')
    Folder.Parent = vape.gui

    local ESPKits = {
	alchemist = {'alchemist_ingedients', 'wild_flower'},
	beekeeper = {'bee', 'bee'},
	bigman = {'treeOrb', 'natures_essence_1'},
	ghost_catcher = {'ghost', 'ghost_orb'},
	metal_detector = {'hidden-metal', 'iron'},
	sheep_herder = {'SheepModel', 'purple_hay_bale'},
	sorcerer = {'alchemy_crystal', 'wild_flower'},
	star_collector = {'stars', 'crit_star'},
    }

    local function Added(v, icon)
	local billboard = Instance.new('BillboardGui')
	billboard.Parent = Folder
	billboard.Name = icon
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	billboard.Size = UDim2.fromOffset(36, 36)
	billboard.AlwaysOnTop = true
	billboard.ClipsDescendants = false
	billboard.Adornee = v
	local blur = addBlur(billboard)
	blur.Visible = Background.Enabled
	local image = Instance.new('ImageLabel')
	image.Size = UDim2.fromOffset(36, 36)
	image.Position = UDim2.fromScale(0.5, 0.5)
	image.AnchorPoint = Vector2.new(0.5, 0.5)
	image.BackgroundColor3 = Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
	image.BackgroundTransparency = 1 - (Background.Enabled and Color.Opacity or 0)
	image.BorderSizePixel = 0
	image.Image = bedwars.getIcon({ itemType = icon }, true)
	image.Parent = billboard
	local uicorner = Instance.new('UICorner')
	uicorner.CornerRadius = UDim.new(0, 4)
	uicorner.Parent = image
	Reference[v] = billboard
    end

    local function addKit(kitName, tag, icon)
	KitESP:Clean(collectionService:GetInstanceAddedSignal(tag):Connect(function(v)
		if store.equippedKit == kitName and v.PrimaryPart then Added(v.PrimaryPart, icon) end
	end))
	KitESP:Clean(collectionService:GetInstanceRemovedSignal(tag):Connect(function(v)
		if v.PrimaryPart and Reference[v.PrimaryPart] then
			Reference[v.PrimaryPart]:Destroy()
			Reference[v.PrimaryPart] = nil
		end
	end))
    end
	local function refreshKit()
		Folder:ClearAllChildren()
		table.clear(Reference)
		local kit = ESPKits[store.equippedKit]
		if not kit then return end
		for _, object in collectionService:GetTagged(kit[1]) do if object.PrimaryPart then Added(object.PrimaryPart, kit[2]) end end
	end

    KitESP = kits:CreateModule({
	Name = 'KitESP',
	Category = 'Visual',
	Function = function(callback)
		kitGeneration += 1
		if callback then
			local generation = kitGeneration
			for kitName, kit in ESPKits do addKit(kitName, kit[1], kit[2]) end
			local activeKit = store.equippedKit
			refreshKit()
			
			
			task.spawn(function()
				while KitESP.Enabled and kitGeneration == generation do
					task.wait(0.25)
					if kitGeneration ~= generation then break end
					if store.equippedKit ~= activeKit then activeKit = store.equippedKit; refreshKit() end
				end
			end)
		else
			Folder:ClearAllChildren()
			table.clear(Reference)
		end
	end,
	Tooltip = 'ESP for certain kit related objects'
    })
    Background = KitESP:CreateToggle({
	Name = 'Background',
	Function = function(callback)
		if Color.Object then
			Color.Object.Visible = callback
		end
		for _, v in Reference do
			v.ImageLabel.BackgroundTransparency = 1 - (callback and Color.Opacity or 0)
			v.Blur.Visible = callback
		end
	end,
	Default = true,
    })
    Color = KitESP:CreateColorSlider({
	Name = 'Background Color',
	DefaultValue = 0,
	DefaultOpacity = 0.5,
	Function = function(hue, sat, val, opacity)
		for _, v in Reference do
			v.ImageLabel.BackgroundColor3 = Color3.fromHSV(hue, sat, val)
			v.ImageLabel.BackgroundTransparency = 1 - opacity
		end
	end,
	Darker = true,
    })
end)

run(function()
	local KrystalDisabler
	local Momentum
	local SuppressCorrections
	local oldUpdateMomentum, hookedUpdateMomentum
	local patchedSignals = setmetatable({}, {__mode = 'k'})
	local lastRemoteReport = 0

	local function getController()
		return bedwars and bedwars.GlacialSkaterController
	end

	
	
	
	
	local function reportMomentum(target)
		local handler = bedwars and bedwars.Handler
		if not handler then return end
		local now = tick()
		if now - lastRemoteReport < 0.1 then return end
		lastRemoteReport = now
		pcall(function()
			local remote = handler:Get('MomentumUpdate')
			if remote and remote.Remote then
				remote:Fire('SendToServer', {momentumValue = target})
			end
		end)
	end

	
	
	
	local function setKrystalMomentum(controller, report)
		controller = controller or getController()
		if not controller then return end
		local target = Momentum and Momentum.Value or 1000
		controller.momentum = target
		controller.lastMomentumReport = target
		if report then
			reportMomentum(target)
		end
	end

	local function patchMovementSignal(signal)
		if not signal or not getconnections or not hookfunction then return end
		for _, connection in getconnections(signal) do
			local func = connection and connection.Function
			if func and patchedSignals[func] == nil then
				
				
				
				local ok, original = pcall(hookfunction, func, function() end)
				patchedSignals[func] = (ok and original) or false
			end
		end
	end

	
	
	local function restoreSignals()
		for func, original in pairs(patchedSignals) do
			if type(original) == 'function' then
				pcall(hookfunction, func, original)
			end
		end
		table.clear(patchedSignals)
	end

	local function patchCharacter(character)
		if not SuppressCorrections or not SuppressCorrections.Enabled then return end
		local root = character and character.RootPart
		if not root then return end
		patchMovementSignal(root:GetPropertyChangedSignal('CFrame'))
		patchMovementSignal(root:GetPropertyChangedSignal('Velocity'))
		patchMovementSignal(root:GetPropertyChangedSignal('AssemblyLinearVelocity'))
	end

	KrystalDisabler = kits:CreateModule({
		Name = 'KrystalDisabler',
		Category = 'Ability',
		Function = function(callback)
			local controller = getController()
			if callback then
				if not controller or type(controller.updateMomentum) ~= 'function' then
					notif('KrystalDisabler', 'Krystal controller is unavailable.', 5, 'warning')
					KrystalDisabler:Toggle()
					return
				end

				lastRemoteReport = 0
				if not oldUpdateMomentum then
					
					
					
					local original = controller.updateMomentum
					oldUpdateMomentum = original
					
					
					hookedUpdateMomentum = function(self, ...)
						if not KrystalDisabler.Enabled then
							return original(self, ...)
						end
						setKrystalMomentum(self, false)
						local result = original(self, ...)
						setKrystalMomentum(self, true)
						return result
					end
					controller.updateMomentum = hookedUpdateMomentum
				end

				KrystalDisabler:Clean(runService.PreSimulation:Connect(function()
					setKrystalMomentum(nil, true)
				end))

				KrystalDisabler:Clean(entitylib.Events.LocalAdded:Connect(patchCharacter))
				if entitylib.isAlive then
					patchCharacter(entitylib.character)
				end
				setKrystalMomentum(controller, true)
				pcall(controller.updateMomentum, controller)
			else
				
				
				if controller and oldUpdateMomentum and controller.updateMomentum == hookedUpdateMomentum then
					controller.updateMomentum = oldUpdateMomentum
				end
				oldUpdateMomentum, hookedUpdateMomentum = nil, nil
				restoreSignals()
			end
		end,
		Tooltip = 'Removes Krystal lagbacks by keeping momentum maxed and muting the correction listeners'
	})

	Momentum = KrystalDisabler:CreateSlider({
		Name = 'Momentum',
		Min = 100,
		Max = 10000,
		Default = 1000
	})

	SuppressCorrections = KrystalDisabler:CreateToggle({
		Name = 'Suppress corrections',
		Default = true,
		Function = function(callback)
			if callback then
				if KrystalDisabler and KrystalDisabler.Enabled and entitylib.isAlive then
					patchCharacter(entitylib.character)
				end
			else
				restoreSignals()
			end
		end,
		Tooltip = 'Silences the listeners the server corrects you through. Needs getconnections and hookfunction'
	})
end)

run(function()
    local MissileTP

    MissileTP = kits:CreateModule({
        Name = 'MissileTP',
        Category = 'Ability',
        Function = function(callback)
            if callback then
                MissileTP:Toggle()
                local plr = entitylib.EntityMouse({
                    Range = 1000,
                    Players = true,
                    Part = 'RootPart'
                })

                if getItem('guided_missile') and plr then
                    local projectile = bedwars.RuntimeLib.await(bedwars.GuidedProjectileController.fireGuidedProjectile:CallServerAsync('guided_missile'))
                    if projectile then
                        local projectilemodel = projectile.model
                        if not projectilemodel.PrimaryPart then
                            projectilemodel:GetPropertyChangedSignal('PrimaryPart'):Wait()
                        end

                        local bodyforce = Instance.new('BodyForce')
                        bodyforce.Force = Vector3.new(0, projectilemodel.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
                        bodyforce.Name = 'AntiGravity'
                        bodyforce.Parent = projectilemodel.PrimaryPart

                        repeat
                            projectile.model:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.CFrame.p, gameCamera.CFrame.LookVector))
                            task.wait(0.1)
                        until not projectile.model or not projectile.model.Parent
                    else
                        notif('MissileTP', 'Missile on cooldown.', 3)
                    end
                end
            end
        end,
        Tooltip = 'Spawns and teleports a missile to a player\nnear your mouse'
    })
end)

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

run(function()
	local RavenTP

	RavenTP = kits:CreateModule({
		Name = 'RavenTP',
		Function = function(callback)
			if callback then
				RavenTP:Toggle()
				local plr = entitylib.EntityMouse({
					Range = 1000,
					Players = true,
					Part = 'RootPart'
				})

				if getItem('raven') and plr then
					bedwars.Handler:Get('SpawnRaven'):Fire('CallServerAsync'):andThen(function(projectile)
						if projectile then
							local bodyforce = Instance.new('BodyForce')
							bodyforce.Force = Vector3.new(0, projectile.PrimaryPart.AssemblyMass * workspace.Gravity, 0)
							bodyforce.Parent = projectile.PrimaryPart

							if plr then
								task.spawn(function()
									for _ = 1, 20 do
										if plr.RootPart and projectile then
											projectile:SetPrimaryPartCFrame(CFrame.lookAlong(plr.RootPart.Position, gameCamera.CFrame.LookVector))
										end
										task.wait(0.05)
									end
								end)
								task.wait(0.3)
								bedwars.RavenController:detonateRaven()
							end
						end
					end)
				end
			end
		end,
		Tooltip = 'Spawns and teleports a raven to a player\nnear your mouse.'
	})
end)

run(function()
    local ReaperFix
    local ReaperSpeed

    local function getCharacterParts()
        local character = lplr.Character
        if not character then
            return
        end

        local humanoid = character:FindFirstChildOfClass("Humanoid")
        local root = character:FindFirstChild("HumanoidRootPart")

        return character, humanoid, root
    end

    local function inSoulForm(character)
        if not character then
            return false
        end

        return character:GetAttribute("GrimReaperChannel") == true
    end

    ReaperFix = kits:CreateModule({
        Name = "ReaperBypass",
        Category = 'Ability',
        Function = function(callback)
            if not callback then
                return
            end

            local success, result = pcall(function()
                local event = replicatedStorage
                    .rbxts_include
                    .node_modules["@rbxts"]
                    .net
                    .out
                    ._NetManaged
                    .ConsumeGrimReaperSoul

                return event:InvokeServer({
                    secret = "a058cfb5-a4c9-4cc6-84e5-863108f23a89"
                })
            end)

            if not success then
                notif(
                    "ReaperBypass",
                    "Could not invoke ConsumeGrimReaperSoul: " .. tostring(result),
                    5,
                    "warning"
                )
            end

            ReaperFix:Clean(runService.PostSimulation:Connect(function()
                local character, humanoid, root = getCharacterParts()

                if not character or not humanoid or not root then
                    return
                end

                if humanoid.Health <= 0 or not inSoulForm(character) then
                    return
                end

                if not isnetworkowner(root) then
                    return
                end

                local direction = humanoid.MoveDirection
                direction = Vector3.new(direction.X, 0, direction.Z)

                if direction.Magnitude <= 0.05 then
                    return
                end

                local targetSpeed = tonumber(ReaperSpeed.Value) or 37
                local horizontalVelocity = direction.Unit * targetSpeed
                local currentVelocity = root.AssemblyLinearVelocity

                root.AssemblyLinearVelocity = Vector3.new(
                    horizontalVelocity.X,
                    currentVelocity.Y,
                    horizontalVelocity.Z
                )
            end))
        end,
        Tooltip = "Bypasses anticheat while consuming souls"
    })

    ReaperSpeed = ReaperFix:CreateSlider({
        Name = "Speed",
        Min = 1,
        Max = 80,
        Default = 37,
        Suffix = " studs/s"
    })
end)

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

run(function()
    local TritonClutch
    local Legit
    local Back
    local LandCheck
    local BackDelay
    local Limit
    local Recall
    local NoCamera

    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    rayCheck.FilterType = Enum.RaycastFilterType.Include
    local projectileRemote = {InvokeServer = function() end}
    task.spawn(function()
	projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
    end)

    local harpoonAbilities = {'harpoon', 'HARPOON', 'harpoon_throw', 'HARPOON_THROW', 'triton_harpoon', 'TRITON_HARPOON'}
    local virtualInputManager = cloneref(game:GetService('VirtualInputManager'))

    local function isHarpoonTool(tool)
	local name = tool and tool.Name and tool.Name:lower()
	return name == 'harpoon' or name == 'trident' or name == 'triton_harpoon'
    end

    local function clickHeldHarpoon(target)
	local camera = workspace.CurrentCamera
	if not camera then
		return false
	end

	local before = #store.selfProjectiles
	local viewport = camera.ViewportSize
	local original = camera.CFrame
	pcall(function()
		camera.CFrame = CFrame.lookAt(original.Position, target)
	end)
	virtualInputManager:SendMouseButtonEvent(viewport.X / 2, viewport.Y / 2, 0, true, game, 0)
	task.wait()
	virtualInputManager:SendMouseButtonEvent(viewport.X / 2, viewport.Y / 2, 0, false, game, 0)
	camera.CFrame = original

	local started = tick()
	repeat
		if #store.selfProjectiles > before then
			return true
		end
		task.wait()
	until tick() - started > 0.25
	return false
    end

    local function waitForHarpoonClutch()
	local started = tick()
	repeat
		task.wait()
		local root = entitylib.isAlive and entitylib.character.RootPart
		if root and root.Velocity.Y > -10 then
			return true
		end
	until not TritonClutch.Enabled or tick() - started > 3
	return false
    end

    task.spawn(function()
	local success, abilityIds = pcall(function()
		return require(replicatedStorage.TS.ability['ability-id']).AbilityId
	end)
	if success then
		for _, ability in abilityIds do
			local lowered = tostring(ability):lower()
			if lowered:find('harpoon', 1, true) then
				table.insert(harpoonAbilities, ability)
			end
		end
	end
    end)

    local function useAbility(list, payloads)
	for _, ability in list do
		local allowed = true
		pcall(function()
			allowed = not bedwars.AbilityController.canUseAbility or bedwars.AbilityController:canUseAbility(ability)
		end)

		if allowed then
			for _, data in payloads do
				local success, result = pcall(function()
					return bedwars.AbilityController:useAbility(ability, newproxy(true), data)
				end)
				if success and result ~= false then
					return true
				end

				success, result = pcall(function()
					return bedwars.AbilityController:useAbility(ability, data)
				end)
				if success and result ~= false then
					return true
				end

				pcall(function()
					bedwars.Client:Get(remotes.UseAbility).instance:FireServer(ability, data)
				end)
			end
		end
	end
	return false
    end

    local function fireHarpoonProjectile(pos, spot, item)
	local projectileType = 'harpoon_projectile'
	local meta = bedwars.ProjectileMeta[projectileType]
	if not meta then
		return false
	end

	local launchVelocity = meta.launchVelocity or 160
	local gravity = meta.gravitationalAcceleration or 0
	local calc = prediction.SolveTrajectory(pos, launchVelocity, gravity, spot, Vector3.zero, workspace.Gravity, 0, 0) or spot
	local dir = CFrame.lookAt(pos, calc).LookVector * launchVelocity
	local shotId = httpService:GenerateGUID(false)
	local landed = false
	local projectile

	pcall(function()
		projectile = bedwars.ProjectileController:createLocalProjectile(meta, projectileType, projectileType, pos, nil, dir, {drawDurationSeconds = 1})
	end)

	if projectile then
		task.spawn(function()
			repeat
				task.wait()
			until not projectile or not projectile.Parent
			landed = true
		end)
	end

	local success, result = pcall(function()
		return projectileRemote:InvokeServer(
			item.tool,
			projectileType,
			projectileType,
			pos,
			pos,
			dir,
			httpService:GenerateGUID(true),
			{
				drawDurationSeconds = 1,
				shotId = shotId
			},
			workspace:GetServerTimeNow() - 0.045
		)
	end)

	return success and result ~= nil, function()
		local started = tick()
		repeat
			task.wait()
		until landed or not TritonClutch.Enabled or tick() - started > 3
		return landed
	end
    end

    local function useHarpoon(pos, spot, item)
	local hotbar, old = getHotbar(item.tool), store.hand
	switchItem(item.tool)
	if Legit.Enabled and hotbar then
		hotbarSwitch(hotbar)
	end

	local used, clutchCheck, recallWait
	if not NoCamera.Enabled and clickHeldHarpoon(spot) then
		clutchCheck = waitForHarpoonClutch
		used = true
	else
		used, clutchCheck = fireHarpoonProjectile(pos, spot, item)
	end

	if not used then
		used = useAbility(harpoonAbilities, {
			{target = spot, origin = pos},
			{targetPosition = spot, position = pos},
			{position = spot},
			spot
		})
		clutchCheck = waitForHarpoonClutch
	end

	if used and Recall.Enabled then
		recallWait = function()
			task.wait(1.25)
			virtualInputManager:SendKeyEvent(true, Enum.KeyCode.C, false, game)
			task.wait()
			virtualInputManager:SendKeyEvent(false, Enum.KeyCode.C, false, game)

			local started, lastPosition, stable = tick(), nil, 0
			repeat
				task.wait(0.1)
				local root = entitylib.isAlive and entitylib.character.RootPart
				if root then
					local currentPosition = root.Position
					local moved = lastPosition and (currentPosition - lastPosition).Magnitude or math.huge
					if tick() - started > 0.75 and moved < 1 and root.Velocity.Magnitude < 8 then
						stable += 0.1
						if stable >= 0.3 then
							return true
						end
					else
						stable = 0
					end
					lastPosition = currentPosition
				end
			until not TritonClutch.Enabled or tick() - started > 7
			return false
		end
	end

	if Back.Enabled and LandCheck.Enabled and clutchCheck then
		clutchCheck()
	end
	if Back.Enabled and old and old.tool then
		if recallWait then
			recallWait()
		else
			task.wait(BackDelay:GetRandomValue())
		end
		switchItem(old.tool)
		if Legit.Enabled and getHotbar(old.tool) then
			hotbarSwitch(getHotbar(old.tool))
		end
	elseif recallWait then
		task.spawn(recallWait)
	end
    end

    local function findNearGround(origin, root)
	local best, bestScore
	local originPosition = origin.Position
	local velocity = root and root.Velocity or Vector3.zero
	local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	local fallSpeed = math.max(-velocity.Y, 0)
	local samples = {}

	local function addSample(position)
		table.insert(samples, position)
	end

	local function getAimPoint(ray, predictedPosition)
		local hit = ray.Position + (ray.Normal * 0.35)
		local part = ray.Instance
		if part and part:IsA('BasePart') then
			local size = part.Size
			local localPredicted = part.CFrame:PointToObjectSpace(predictedPosition)
			local edgeMargin = math.min(0.45, math.max(math.min(size.X, size.Z) * 0.2, 0.08))
			local xLimit = math.max((size.X * 0.5) - edgeMargin, 0)
			local zLimit = math.max((size.Z * 0.5) - edgeMargin, 0)
			localPredicted = Vector3.new(math.clamp(localPredicted.X, -xLimit, xLimit), size.Y * 0.5 + 0.25, math.clamp(localPredicted.Z, -zLimit, zLimit))
			hit = part.CFrame:PointToWorldSpace(localPredicted)
		end
		return hit
	end

	addSample(originPosition)
	for time = 0.15, 2.4, 0.15 do
		local predictedPosition = originPosition + (horizontalVelocity * time) + Vector3.new(0, (velocity.Y * time) - (workspace.Gravity * time * time * 0.5), 0)
		local center = Vector3.new(predictedPosition.X, originPosition.Y, predictedPosition.Z)
		addSample(center)
		for radius = 1, 12, 1 do
			for angle = 0, 315, 45 do
				local radians = math.rad(angle)
				addSample(center + Vector3.new(math.cos(radians) * radius, 0, math.sin(radians) * radius))
			end
		end
	end

	for radius = 16, 72, 4 do
		for angle = 0, 315, 45 do
			local radians = math.rad(angle)
			addSample(originPosition + (horizontalVelocity * 0.65) + Vector3.new(math.cos(radians) * radius, 0, math.sin(radians) * radius))
		end
	end

	for _, sample in samples do
		local ray = workspace:Raycast(sample + Vector3.new(0, 128, 0), Vector3.new(0, -420, 0), rayCheck)
		if ray then
			local drop = math.max(originPosition.Y - ray.Position.Y, 1)
			local timeToPlatform = math.clamp((math.sqrt((fallSpeed * fallSpeed) + (2 * workspace.Gravity * drop)) - fallSpeed) / workspace.Gravity, 0.05, 2.5)
			local predictedPosition = originPosition + (horizontalVelocity * timeToPlatform)
			local aimPoint = getAimPoint(ray, predictedPosition)
			local horizontalDistance = (Vector3.new(aimPoint.X, originPosition.Y, aimPoint.Z) - Vector3.new(originPosition.X, originPosition.Y, originPosition.Z)).Magnitude
			local predictedDistance = (Vector3.new(aimPoint.X, predictedPosition.Y, aimPoint.Z) - Vector3.new(predictedPosition.X, predictedPosition.Y, predictedPosition.Z)).Magnitude
			local score = (predictedDistance * 1.35) + (horizontalDistance * 0.25) + (drop * 0.015)
			if not bestScore or score < bestScore then
				best, bestScore = aimPoint, score
			end
		end
	end
	return best
    end


    TritonClutch = kits:CreateModule({
	Name = 'TritonClutch',
	Category = 'Ability',
	Function = function(callback)
		if callback then
			local lasty, attempted
			repeat
				if entitylib.isAlive and (not Limit.Enabled or isHarpoonTool(store.hand.tool)) then
					local root = entitylib.character.RootPart
					local harpoon = getItem('harpoon') or getItem('triton_harpoon') or getItem('trident')
					rayCheck.FilterDescendantsInstances = {store.map}
					rayCheck.CollisionGroup = root.CollisionGroup

					local onGround = entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air
					if onGround then
						lasty = root.CFrame
						attempted = false
					end

					if not onGround and not attempted and harpoon and root.Velocity.Y < -60 and not workspace:Raycast(root.Position, Vector3.new(0, -140, 0), rayCheck) then
						attempted = true
						local ground = findNearGround(root.CFrame, root) or findNearGround(lasty and lasty + Vector3.new(0, 5, 0) or root.CFrame, root)
						if ground then
							useHarpoon(root.Position, ground, harpoon)
						end
					end
				end
				task.wait(0.03)
			until not TritonClutch.Enabled
		end
	end,
	Tooltip = 'Automatically throws Triton\'s harpoon onto nearby ground after falling a certain distance'
    })

    Legit = TritonClutch:CreateToggle({
	Name = 'Legit Switch',
	Tooltip = 'Visualizes the switching clientside',
	Default = true
    })
    Back = TritonClutch:CreateToggle({
	Name = 'Switch back',
	Default = true,
	Function = function(callback)
		if BackDelay then
			BackDelay.Object.Visible = callback
		end
		if LandCheck then
			LandCheck.Object.Visible = callback
		end
	end,
	Tooltip = 'Switches back to the previous slot after Recall finishes, or after the clutch delay when Recall is off'
    })
    LandCheck = TritonClutch:CreateToggle({
	Name = 'Only after clutch',
	Tooltip = 'Waits for the harpoon clutch before switching back; Recall still waits until the recall finishes',
	Darker = true
    })
    BackDelay = TritonClutch:CreateTwoSlider({
	Name = 'Switch Back Delay',
	Min = 0,
	Max = 2,
	DefaultMin = 0.1,
	DefaultMax = 0.2,
	Darker = true
    })
    Limit = TritonClutch:CreateToggle({
	Name = 'Limit to items',
	Tooltip = "Only throws Triton's harpoon when holding the harpoon or trident"
    })
    NoCamera = TritonClutch:CreateToggle({
	Name = 'Prevent Camera Movement',
	Tooltip = 'Uses server projectile logic instead of moving your camera for the click fallback',
	Default = true
    })
    Recall = TritonClutch:CreateToggle({
	Name = 'Recall',
	Tooltip = 'Presses C to activate Recall / Go to base after clutching'
    })
end)

run(function()
    local context = AetherRuntimeContext
    
    
    


local function registerTrixie(context)
    local vape = context and context.vape
    local lplr = context and context.lplr
    local Knit = context and context.Knit
    local canDebug = context and context.canDebug
    local dbg = context and context.debug
    local notif = context and context.notif

    local function notify(message)
        if type(notif) == 'function' then
            pcall(notif, 'TrixieExploit', message, 6, 'warning')
        else
            warn('[AetherV2] TrixieExploit: '..tostring(message))
        end
    end

    if not vape then
        warn('[AetherV2] TrixieExploit: vape unavailable during registration')
        return
    end

    
    
    
    local kits = context and context.kits
    if not kits then
        kits = vape.Categories and (vape.Categories.Kits or vape.Categories.Minigames)
    end

    if not (kits and type(kits.CreateModule) == 'function') then
        warn('[AetherV2] TrixieExploit: active kit category is unavailable')
        notify('The active kit category is unavailable; TrixieExploit could not be registered.')
        return
    end

    
    if vape.Modules and vape.Modules.TrixieExploit then
        return vape.Modules.TrixieExploit
    end

    local TrixieExploit, Distance
    local patched = {}

    local function currentKit()
        if not lplr then return '' end
        return tostring(lplr:GetAttribute('PlayingAsKits') or lplr:GetAttribute('PlayingAsKit') or ''):lower()
    end

    local function isTrixie()
        return currentKit():find('trixie', 1, true) ~= nil
    end

    local function restore()
        if not (dbg and type(dbg.setconstant) == 'function') then
            table.clear(patched)
            return
        end

        for i = #patched, 1, -1 do
            local record = patched[i]
            pcall(dbg.setconstant, record.fn, record.index, record.original)
        end
        table.clear(patched)
    end

    local function inspectFunction(fn, label, seenFunctions, studCandidates, blockCandidates)
        if type(fn) ~= 'function' or seenFunctions[fn] then return end
        seenFunctions[fn] = true

        local ok, constants = pcall(dbg.getconstants, fn)
        if not ok or type(constants) ~= 'table' then return end

        local loweredLabel = tostring(label):lower()
        local marked = loweredLabel:find('trixie', 1, true) ~= nil or loweredLabel:find('rift', 1, true) ~= nil
        if not marked then
            for _, constant in ipairs(constants) do
                if type(constant) == 'string' then
                    local lowered = constant:lower()
                    if lowered:find('trixie', 1, true) or lowered:find('rift', 1, true) then
                        marked = true
                        break
                    end
                end
            end
        end

        if marked then
            for index, constant in ipairs(constants) do
                if type(constant) == 'number' then
                    if math.abs(constant - 27) < 0.001 then
                        table.insert(studCandidates, {fn = fn, index = index, original = constant, label = label})
                    elseif math.abs(constant - 9) < 0.001 then
                        table.insert(blockCandidates, {fn = fn, index = index, original = constant, label = label})
                    end
                end
            end
        end

        if type(dbg.getprotos) == 'function' then
            local protoOk, protos = pcall(dbg.getprotos, fn)
            if protoOk and type(protos) == 'table' then
                for index, proto in ipairs(protos) do
                    inspectFunction(proto, tostring(label)..'.proto'..index, seenFunctions, studCandidates, blockCandidates)
                end
            end
        end
    end

    local function inspectContainer(container, label, seenContainers, seenFunctions, studCandidates, blockCandidates)
        if type(container) ~= 'table' or seenContainers[container] then return end
        seenContainers[container] = true

        for memberName, member in pairs(container) do
            if type(member) == 'function' then
                inspectFunction(member, tostring(label)..'.'..tostring(memberName), seenFunctions, studCandidates, blockCandidates)
            end
        end

        
        
        local mt = getmetatable(container)
        if type(mt) == 'table' then
            for memberName, member in pairs(mt) do
                if type(member) == 'function' then
                    inspectFunction(member, tostring(label)..'.metatable.'..tostring(memberName), seenFunctions, studCandidates, blockCandidates)
                end
            end
            if type(mt.__index) == 'table' then
                inspectContainer(mt.__index, tostring(label)..'.__index', seenContainers, seenFunctions, studCandidates, blockCandidates)
            end
        end
    end

    local function discover()
        local studCandidates, blockCandidates = {}, {}
        local seenFunctions, seenContainers = {}, {}
        local controllers = Knit and Knit.Controllers
        if type(controllers) ~= 'table' then return studCandidates, blockCandidates end

        for controllerName, controller in pairs(controllers) do
            inspectContainer(controller, controllerName, seenContainers, seenFunctions, studCandidates, blockCandidates)
        end

        return studCandidates, blockCandidates
    end

    local function reportFailure(message)
        notify(message)
        return false
    end

    local function apply()
        restore()

        if not (TrixieExploit and TrixieExploit.Enabled) then return false end
        if not isTrixie() then
            return reportFailure('Equip Trixie before using this module.')
        end
        if not (canDebug and dbg and type(dbg.getconstants) == 'function' and type(dbg.setconstant) == 'function') then
            return reportFailure('Your executor cannot patch the Rift Warp range calculation.')
        end

        local studCandidates, blockCandidates = discover()
        
        
        local candidates = #studCandidates > 0 and studCandidates or blockCandidates
        if #candidates == 0 then
            return reportFailure('No live Rift Warp range constant was found; BedWars may now validate it server-side.')
        end

        local desiredBlocks = Distance.Value
        for _, record in ipairs(candidates) do
            local replacement = math.abs(record.original - 27) < 0.001 and desiredBlocks * 3 or desiredBlocks
            local ok = pcall(dbg.setconstant, record.fn, record.index, replacement)
            if ok then
                table.insert(patched, record)
            end
        end

        if #patched == 0 then
            return reportFailure('Rift Warp was found but its range could not be patched.')
        end

        return true
    end

    local created, moduleOrError = pcall(kits.CreateModule, kits, {
        Name = 'TrixieExploit',
        Function = function(enabled)
            if enabled then
                task.defer(apply)
            else
                restore()
            end
        end,
        Tooltip = 'Extends Trixie Rift Warp by patching its live client range calculation. Server validation can still clamp unsupported distances.'
    })

    if not created or not moduleOrError then
        warn('[AetherV2] TrixieExploit registration failed: '..tostring(moduleOrError))
        notify('TrixieExploit failed to register. Check the developer console.')
        return
    end
    TrixieExploit = moduleOrError

    Distance = TrixieExploit:CreateSlider({
        Name = 'Warp distance',
        Min = 9,
        Max = 30,
        Default = 18,
        Suffix = ' blocks',
        Function = function()
            if TrixieExploit.Enabled then task.defer(apply) end
        end
    })

    TrixieExploit:Clean(function()
        restore()
    end)

    return TrixieExploit
end

    local trixieLoaded, trixieResult = xpcall(function()
        return registerTrixie(context)
    end, debug and debug.traceback or tostring)
    if not trixieLoaded then warn('[AetherV2] TrixieExploit failed to load: '..tostring(trixieResult)) end


end)

run(function()
	local VoidRegentAutoClutch
	local Range
	local Depth
	local FallSpeed
	local FaceGround
	local lastClutch = 0

	VoidRegentAutoClutch = kits:CreateModule({
		Name = 'VoidRegentAutoClutch',
		Function = function(callback)
			if callback then
				VoidRegentAutoClutch:Clean(runService.Heartbeat:Connect(function()
					if entitylib.isAlive and store.equippedKit == 'regent' and store.airRay and tick() >= lastClutch and bedwars.VoidAxeController then
						local root = entitylib.character.RootPart
						if root.Velocity.Y < -FallSpeed.Value and not entitylib.Raycast(root.Position, Vector3.new(0, -Depth.Value, 0), store.airRay) and bedwars.AbilityController:canUseAbility('void_axe_jump', {disableBlockedAbilityAlert = true}) then
							local ground = getNearGround(Range.Value / 3)
							local delta = ground and (ground - root.Position) * Vector3.new(1, 0, 1)
							if delta and delta.Magnitude > 0 then
								lastClutch = tick() + 0.5
								if FaceGround.Enabled then
									root.CFrame = CFrame.lookAt(root.Position, root.Position + delta.Unit)
								end
								bedwars.VoidAxeController:useVoidAxe()
							end
						end
					end
				end))
			end
		end,
		Tooltip = 'Dashes the void axe back towards solid ground when you fall off the map'
	})
	Range = VoidRegentAutoClutch:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 60,
		Default = 45,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far to look for ground to dash back to'
	})
	Depth = VoidRegentAutoClutch:CreateSlider({
		Name = 'Depth',
		Min = 10,
		Max = 150,
		Default = 60,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'Nothing beneath you within this counts as the void'
	})
	FallSpeed = VoidRegentAutoClutch:CreateSlider({
		Name = 'Fall speed',
		Min = 0,
		Max = 100,
		Default = 10,
		Tooltip = 'Only clutches once you are dropping this fast'
	})
	FaceGround = VoidRegentAutoClutch:CreateToggle({
		Name = 'Face ground',
		Default = true,
		Tooltip = 'Turns you towards the ground first, the dash always goes where you face'
	})
end)

run(function()
	local VoidRegentExtender
	local Multiplier

	local old

	VoidRegentExtender = kits:CreateModule({
		Name = 'VoidRegentExtender',
		Function = function(callback)
			if callback then
				old = bedwars.VoidAxeController.useVoidAxe
				bedwars.VoidAxeController.useVoidAxe = function(self)
					local dashed = bedwars.AbilityController:canUseAbility('void_axe_jump', {disableBlockedAbilityAlert = true})
					local call = old(self)

					if dashed and store.equippedKit == 'regent' and entitylib.isAlive then
						local root = entitylib.character.RootPart
						root:ApplyImpulse(root.CFrame.LookVector * Vector3.new(1, 0, 1) * root.AssemblyMass * (Multiplier.Value - 1) * 70)
					end
					return call
				end
			else
				bedwars.VoidAxeController.useVoidAxe = old
			end
		end,
		Tooltip = 'Extends how far the Void Regent axe dash launches you'
	})
	Multiplier = VoidRegentExtender:CreateSlider({
		Name = 'Multiplier',
		Min = 1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 'x'
	})
end)

run(function()
	local VulcanAssist
	local Targets
	local Range
	local Sort

	VulcanAssist = kits:CreateModule({
		Name = 'VulcanAssist',
		Function = function(callback)
			if callback then
				repeat
					local turret = entitylib.isAlive and bedwars.Store:getState().Game.selectedTurret
					if turret then
						local origin = turret.Rotate.Position
						local ent = entitylib.EntityMouse({
							Range = Range.Value,
							Origin = origin,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods[Sort.Value]
						})
						local pos = ent and prediction.SolveTrajectory(origin, 320, 10, ent.RootPart.Position, ent.RootPart.AssemblyLinearVelocity, workspace.Gravity, ent.HipHeight, nil, store.airRay, ent.Humanoid.FloorMaterial == Enum.Material.Air or math.abs(ent.RootPart.AssemblyLinearVelocity.Y) > 0.01, ent.RootPart.Position, ent.RootPart)

						if pos then
							local delta = pos - origin
							bedwars.TurretCameraController.angleX = math.atan2(-delta.X, -delta.Z)
							bedwars.TurretCameraController.angleY = math.clamp(math.atan2(delta.Y, math.sqrt(delta.X ^ 2 + delta.Z ^ 2)), -0.8, 0.8)
						end
					end
					task.wait(0.1)
				until not VulcanAssist.Enabled
			end
		end,
		Tooltip = 'Automatically aims turret camera toward opponents'
	})
	Targets = VulcanAssist:CreateTargets({Walls = true, Players = true})

	local methods = {'Distance', 'Damage'}
	for _, i in sortlist do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end

	Sort = VulcanAssist:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = methods[1]
	})
	Range = VulcanAssist:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 1000,
		Default = 500
	})
end)

run(function()
	local YaminiExtender
	local Multiplier

	local old

	YaminiExtender = kits:CreateModule({
		Name = 'YaminiExtender',
		Function = function(callback)
			if callback then
				old = bedwars.CatController.leap
				bedwars.CatController.leap = function(self, character, direction)
					local call = old(self, character, direction)
					local horizontal = direction and direction * Vector3.new(1, 0, 1) or Vector3.zero
					local root = character and character:FindFirstChild('HumanoidRootPart')

					if store.equippedKit == 'cat' and root and horizontal.Magnitude > 0 then
						root:ApplyImpulse(horizontal.Unit * root.AssemblyMass * (Multiplier.Value - 1) * 70)
					end
					return call
				end
			else
				bedwars.CatController.leap = old
			end
		end,
		Tooltip = 'Extends how far the Cat/Yamini pounce launches you'
	})
	Multiplier = YaminiExtender:CreateSlider({
		Name = 'Multiplier',
		Min = 1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 'x'
	})
end)

run(function()
	local YuziExtender
	local Multiplier

	local old

	YuziExtender = kits:CreateModule({
		Name = 'YuziExtender',
		Function = function(callback)
			if callback then
				old = bedwars.DaoController.dashForward
				bedwars.DaoController.dashForward = function(self, direction)
					local call = old(self, direction)
					local horizontal = direction and direction * Vector3.new(1, 0, 1) or Vector3.zero

					if store.equippedKit == 'dasher' and entitylib.isAlive and horizontal.Magnitude > 0 then
						local root = entitylib.character.RootPart
						root:ApplyImpulse(horizontal.Unit * root.AssemblyMass * (Multiplier.Value - 1) * 70)
					end
					return call
				end
			else
				bedwars.DaoController.dashForward = old
			end
		end,
		Tooltip = 'Extends how far the yuzi dash launches you.'
	})
	Multiplier = YuziExtender:CreateSlider({
		Name = 'Multiplier',
		Min = 1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 'x'
	})
end)

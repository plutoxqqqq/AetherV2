run(function()
	local SilentAim
	local Targets
	local TargetPart
	local SortMethod
	local Prediction
	local Range
	local FOV
	local SAFOVCircle
	local RandomHeadPercent
	local RandomTorsoPercent
	local OtherProjectiles
	local Blacklist
	local AutoCharge
	local skidChargePercent

	local rayCheck = RaycastParams.new()
	rayCheck.FilterType = Enum.RaycastFilterType.Include

	local Debug
	local namecall
	local namecallHooked = false
	local lockedRandomPart
	local _saVelHistory = {}
	local _saVelStamp = {}
	local fovConn
	local fovDrawing
	local lastWarn = 0
	local diagReason = ''
	local diagTarget = nil
	local nextDiag = 0
	local fireRemote, fireRemoteChecked

	-- ProjectileFire(tool, ammo, projectile, shootPosition, rootPosition, velocity, shotId, draw, timestamp)
	-- - the order every caller in the pack itself uses (see fireProjectile in base.lua, and the
	-- kit modules that fire directly). The namecall hook drops the remote that starts the vararg
	-- list, so the packed table lines up one-to-one with that call: 1 tool, 2 ammo,
	-- 3 projectile, 4 shoot position, 5 root position, 6 velocity, 7 shotId, 8 draw. Off-by-one
	-- reads here are what left shots unredirected or sent a position where a velocity belongs.
	local function locateLaunch(args)
		local projType, origin, velocity, velocityIndex = args[3], args[4], args[6], 6
		if type(projType) == 'string' and typeof(origin) == 'Vector3' and typeof(velocity) == 'Vector3' then
			return projType, origin, velocity, velocityIndex
		end
		-- Changed layout: find the pieces by type instead of by position. The launch vectors
		-- always arrive in order - shoot position, root position, velocity - so the third one is
		-- the velocity. The projectile name is the nearest known meta name *before* the shoot
		-- position, walked backwards so an ammo name sitting one slot earlier cannot win.
		local vectors = {}
		for index = 1, args.n do
			if typeof(args[index]) == 'Vector3' then table.insert(vectors, index) end
		end
		if #vectors < 3 then return end
		velocityIndex = vectors[3]
		origin, velocity = args[vectors[1]], args[velocityIndex]
		for index = vectors[1] - 1, 1, -1 do
			local value = args[index]
			if type(value) == 'string' and bedwars.ProjectileMeta[value] then
				projType = value
				break
			end
		end
		if type(projType) ~= 'string' then return end
		return projType, origin, velocity, velocityIndex
	end

	local function getMousePosition()
		if inputService.TouchEnabled then
			return gameCamera.ViewportSize / 2
		end
		return inputService:GetMouseLocation()
	end

	local function getClosestPart(char, mousePos)
		local magnitude, part = 9e9, nil
		for _, v in char:GetChildren() do
			if v:IsA('BasePart') then
				local position, vis = gameCamera:WorldToViewportPoint(v.Position)
				if vis then
					local mag = (mousePos - Vector2.new(position.X, position.Y)).Magnitude
					if mag < magnitude then
						magnitude = mag
						part = v
					end
				end
			end
		end
		return part
	end

	local function pickRandomPart(char)
		local roll = math.random(1, 100)
		local head = char:FindFirstChild('Head')
		local torso = char:FindFirstChild('HumanoidRootPart') or char.PrimaryPart
		if head and roll <= RandomHeadPercent.Value then
			return head
		elseif torso and roll <= (RandomHeadPercent.Value + RandomTorsoPercent.Value) then
			return torso
		end
		return torso or head
	end

	local function getTargetPart(plr)
		local val = TargetPart.Value
		if val == 'Dynamic' then
			local tool = store.hand and store.hand.tool
			local itemType = tostring(tool and tool.Name or ''):lower()
			if itemType:find('headhunter', 1, true) and plr.Character and plr.Character:FindFirstChild('Head') then
				return plr.Character.Head
			end
			return plr.RootPart
		elseif val == 'Head' then
			return (plr.Character and plr.Character:FindFirstChild('Head')) or plr.RootPart
		elseif val == 'Closest' then
			return (plr.Character and getClosestPart(plr.Character, getMousePosition())) or plr.RootPart
		elseif val == 'Randomize' then
			-- The random part stays locked while it is still inside the same body, so one target
			-- keeps the lead it was solved against instead of re-rolling on every projectile.
			if lockedRandomPart and lockedRandomPart.Parent ~= plr.Character then
				lockedRandomPart = nil
			end
			if plr.Character and (not lockedRandomPart or not lockedRandomPart.Parent) then
				lockedRandomPart = pickRandomPart(plr.Character)
			end
			return lockedRandomPart or plr.RootPart
		end
		return plr.RootPart
	end

	-- The trap projectiles are named glue_trap/glue_projectile but are blacklisted as 'gloop', the
	-- name the game and the users know them by.
	local function isBlacklisted(projType)
		local key = (projType == 'glue_trap' or projType == 'glue_projectile') and 'gloop' or projType
		local list = Blacklist and (Blacklist.ListEnabled or Blacklist.Value) or {}
		return table.find(list, key) ~= nil
	end

	-- The remote is matched against the instance the pack itself resolved for ProjectileFire and
	-- only falls back to the name when that lookup is unavailable, so a build that renames the
	-- remote cannot leave every shot unredirected.
	local function isFireRemote(remote)
		if typeof(remote) ~= 'Instance' then return false end
		if remote.Name == 'ProjectileFire' then return true end
		if not fireRemoteChecked then
			fireRemoteChecked = true
			local resolved = getgenv().remotes and getgenv().remotes.FireProjectile
			if resolved then
				pcall(function()
					fireRemote = bedwars.Client:Get(resolved).instance
				end)
			end
		end
		return fireRemote ~= nil and remote == fireRemote
	end

	local function isHoldingProjectile()
		local tool = store.hand and store.hand.tool
		local itemType = tool and tool.Name or ''
		local itemMeta = bedwars.ItemMeta and bedwars.ItemMeta[itemType]
		if not (itemMeta and itemMeta.projectileSource) then return false end

		local ammoTypes = itemMeta.projectileSource.ammoItemTypes
		if type(ammoTypes) == 'table' and table.find(ammoTypes, 'arrow') then return true end
		if itemType:find('headhunter', 1, true) then return true end
		if not (OtherProjectiles and OtherProjectiles.Enabled) then return false end

		return true
	end

	local function runFOVCircle(state)
		if fovConn then
			fovConn:Disconnect()
			fovConn = nil
		end
		if fovDrawing then
			fovDrawing:Destroy()
			fovDrawing = nil
		end
		if not state then return end

		fovDrawing = Instance.new('Frame')
		fovDrawing.Name = 'SAFOVCircle'
		fovDrawing.BackgroundTransparency = 1
		fovDrawing.AnchorPoint = Vector2.new(0.5, 0.5)
		fovDrawing.Visible = false
		local stroke = Instance.new('UIStroke')
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(255, 255, 255)
		stroke.Parent = fovDrawing
		local corner = Instance.new('UICorner')
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = fovDrawing
		fovDrawing.Parent = vape.gui

		fovConn = runService.RenderStepped:Connect(function()
			if not fovDrawing or not FOV or not FOV.Value then return end
			local shouldShow = SilentAim and SilentAim.Enabled and SAFOVCircle and SAFOVCircle.Enabled and isHoldingProjectile()
			fovDrawing.Visible = shouldShow
			if shouldShow then
				local mousePos = getMousePosition()
				fovDrawing.Position = UDim2.fromOffset(mousePos.X, mousePos.Y)
				fovDrawing.Size = UDim2.fromOffset(FOV.Value * 2, FOV.Value * 2)
			end
		end)
	end

	-- Returns the velocity to send and the slot it belongs in, or nothing when the shot should be
	-- left exactly as the game fired it.
	local function solveSilent(args)
		diagReason, diagTarget = '', nil
		local projType, origin, velocity, velocityIndex = locateLaunch(args)
		if not projType or typeof(origin) ~= 'Vector3' or typeof(velocity) ~= 'Vector3' then
			diagReason = 'the launch arguments did not line up'
			return
		end

		if (not OtherProjectiles.Enabled) and not projType:find('arrow', 1, true) then
			diagReason = projType..' is not an arrow and Other Projectiles is off'
			return
		end
		if isBlacklisted(projType) then
			diagReason = projType..' is blacklisted'
			return
		end

		local meta = bedwars.ProjectileMeta[projType]
		if not meta then
			diagReason = 'no projectile meta for '..tostring(projType)
			return
		end

		local projSpeed = velocity.Magnitude
		if projSpeed <= 0 then
			diagReason = 'the shot carries no speed'
			return
		end
		local gravity = tonumber(meta.gravitationalAcceleration)
		if gravity == nil then gravity = 196.2 end
		if gravity < 1 then gravity = 0 end

		local map = workspace:FindFirstChild('Map')
		if map ~= rayCheck.FilterDescendantsInstances[1] then
			rayCheck.FilterDescendantsInstances = map and {map} or {}
		end

		local plr = entitylib.EntityMouse({
			Part = 'RootPart',
			Range = FOV.Value,
			Players = Targets.Players.Enabled,
			NPCs = (Targets.NPCs and Targets.NPCs.Enabled) or false,
			Priority = Targets.Priority and Targets.Priority.Value,
			Wallcheck = Targets.Walls.Enabled,
			Sort = sortmethods[SortMethod.Value or 'Cursor'],
			MouseOrigin = gameCamera.ViewportSize / 2,
			Origin = origin
		})
		if not plr then
			diagReason = 'no target inside the FOV circle'
			return
		end

		local targetPart = getTargetPart(plr)
		if not targetPart then
			diagReason = 'the target has no '..tostring(TargetPart.Value)..' part'
			return
		end
		diagTarget = (plr.Player and plr.Player.Name) or 'the entity'

		local dist = (targetPart.Position - origin).Magnitude
		if dist > Range.Value then
			diagReason = string.format('%s is %.0f studs away, past Range', diagTarget, dist)
			return
		end

		local playerGravity = workspace.Gravity
		local balloons = plr.Character and plr.Character:GetAttribute('InflatedBalloons')
		if balloons and balloons > 0 then
			playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
		end
		if plr.Character and plr.Character.PrimaryPart and plr.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
			playerGravity = 6
		end
		if plr.Player and plr.Player:GetAttribute('IsOwlTarget') then
			for _, owl in collectionService:GetTagged('Owl') do
				if owl:GetAttribute('Target') == plr.Player.UserId and owl:GetAttribute('Status') == 2 then
					playerGravity = 0
					break
				end
			end
		end

		local pearl = projType == 'telepearl'
		local rawVel = pearl and Vector3.zero or (plr.RootPart.AssemblyLinearVelocity or plr.RootPart.Velocity or Vector3.zero)
		-- A target that changes direction between shots is led by a blend of the last few frames,
		-- which is steadier than the single frame of velocity the network hands us.
		local _velKey = tostring(plr)
		local _velNow = tick()
		if not _saVelHistory[_velKey] or (_velNow - (_saVelStamp[_velKey] or 0)) > 0.15 then
			_saVelHistory[_velKey] = rawVel
		else
			_saVelHistory[_velKey] = _saVelHistory[_velKey]:Lerp(rawVel, 0.35)
		end
		_saVelStamp[_velKey] = _velNow

		local calc, _, travelTime = prediction.SolveTrajectory(
			origin,
			projSpeed * (Prediction and Prediction.Value or 1),
			gravity,
			targetPart.Position,
			rawVel,
			playerGravity,
			plr.HipHeight,
			plr.Jumping and 42.6 or nil,
			rayCheck,
			nil,
			targetPart.Position,
			plr.RootPart,
			nil,
			true
		)
		if not calc then
			diagReason = 'no ballistic solution to '..diagTarget
			return
		end

		local lifetime = tonumber(meta.predictionLifetimeSec) or tonumber(meta.lifetimeSec) or (projSpeed > 0 and math.min(3, 120 / projSpeed) or 3)
		if travelTime and travelTime > lifetime then
			diagReason = string.format('the %.2fs flight is longer than the %.2fs lifetime', travelTime, lifetime)
			return
		end

		if targetinfo and targetinfo.Targets then
			targetinfo.Targets[plr] = tick() + 1
		end
		if travelTime then
			store.hitchance.SilentAim = {Value = getHitChance(plr, travelTime), Clock = tick()}
		end

		diagReason = 'redirected at '..tostring(diagTarget)
		-- Only the direction is redirected; the launch speed stays the one the shot actually has,
		-- so the server sees a normal-strength shot that happens to fly at the target.
		return CFrame.lookAt(origin, calc).LookVector * projSpeed, velocityIndex
	end

	SilentAim = vape.Categories.Combat:CreateModule({
		Name = 'SilentAim',
		Tooltip = 'Redirects only the projectile values sent to the server, so enemies get hit while your shot flies exactly where you aimed on your own screen',
		Function = function(callback)
			if callback then
				local ProjectileAimbot = vape.Modules and vape.Modules.ProjectileAimbot
				if ProjectileAimbot and ProjectileAimbot.Enabled then
					ProjectileAimbot:Toggle(false)
					notif('SilentAim', 'turned off ProjectileAimbot, they cant both run at once gng', 4)
				end

				if SAFOVCircle and SAFOVCircle.Enabled then
					runFOVCircle(true)
				end

				-- The hook is installed once and stays: it re-checks SilentAim.Enabled on every call,
				-- so unhooking on disable would only add a window where a shot is not redirected.
				-- The shot is taken on its own merits - the remote, the method, and whether a target can
				-- be solved - rather than on who called it. An identity gate is the one condition that
				-- can silently leave every shot alone, and the pack's own aiming modules already fire
				-- at a target, so letting their shots through costs nothing.
				if not namecallHooked then
					namecallHooked = true
					namecall = hookmetamethod(game, '__namecall', newcclosure(function(...)
						if not SilentAim.Enabled then return namecall(...) end
						local remote = ...
						if not isFireRemote(remote) then
							-- A remote whose name reads like a shot but is not the one being matched is the
							-- one case the reason strings can never explain, because no solve is reached.
							if Debug and Debug.Enabled and typeof(remote) == 'Instance' and tick() > nextDiag then
								local name = remote.Name
								if name:find('rojectile') or name:find('Fire') then
									nextDiag = tick() + 3
									task.defer(notif, 'SilentAim', 'saw '..name..' called as '..tostring(getnamecallmethod())..', which is not the shot remote', 4, 'warning')
								end
							end
							return namecall(...)
						end

						-- The method is taken from the call rather than required to be a fixed name: the shot is
						-- identified by the remote it lands on, and nothing is rewritten unless a solution was
						-- actually solved for the arguments that arrived, so a differently named invoke can no
						-- longer turn every shot away before it is looked at.
						local method = getnamecallmethod()
						local self = ...
						local args = table.pack(select(2, ...))
						local ok, newVelocity, velocityIndex = pcall(solveSilent, args)
						if ok and typeof(newVelocity) == 'Vector3' and velocityIndex then
							args[velocityIndex] = newVelocity

							-- AutoCharge rewrites the draw duration the server is told about, which
							-- is what shortens the charge-up before the shot is released.
							if AutoCharge and AutoCharge.Enabled and typeof(args[8]) == 'table' then
								local projType = args[3]
								local dur
								if type(projType) == 'string' and projType:find('arrow', 1, true) then
									dur = 0.58
								else
									local meta = bedwars.ProjectileMeta[projType]
									dur = (meta and meta.maxDrawDurationSeconds) or 0.8
								end
								args[8].drawDurationSec = dur * (skidChargePercent.Value / 100)
							end
							if Debug and Debug.Enabled and tick() > nextDiag then
								nextDiag = tick() + 1
								task.defer(notif, 'SilentAim', 'sent the '..tostring(args[3])..' at '..tostring(diagTarget), 4)
							end
						else
							if not ok then
								diagReason = tostring(newVelocity)
							end
							if shared.VapeDeveloper and tick() > lastWarn then
								lastWarn = tick() + 5
								warn('[AetherV2] silentaim left a projectile alone: '..tostring(diagReason))
							end
							if Debug and Debug.Enabled and tick() > nextDiag then
								nextDiag = tick() + 1
								task.defer(notif, 'SilentAim', 'left the shot alone: '..tostring(diagReason), 4, 'warning')
							end
						end

						local invoke = self[method] or self.InvokeServer
						return invoke(self, table.unpack(args, 1, args.n))
					end))
				end
			else
				lockedRandomPart = nil
				table.clear(_saVelHistory)
				table.clear(_saVelStamp)
				runFOVCircle(false)
			end
		end
	})

	Targets = SilentAim:CreateTargets({
		Players = true,
		NPCs = true,
		Walls = true
	})

	TargetPart = SilentAim:CreateDropdown({
		Name = 'Part',
		List = {'Dynamic', 'RootPart', 'Head', 'Closest', 'Randomize'},
		Default = 'RootPart',
		Function = function()
			lockedRandomPart = nil
		end
	})

	SortMethod = SilentAim:CreateDropdown({
		Name = 'Sort Method',
		List = getSortList({'Distance', 'Damage', 'Cursor'}),
		Default = 'Cursor'
	})

	Prediction = SilentAim:CreateSlider({
		Name = 'Prediction',
		Min = 0.1,
		Max = 2,
		Default = 1,
		Decimal = 10
	})

	Range = SilentAim:CreateSlider({
		Name = 'Range',
		Min = 10,
		Max = 500,
		Default = 100
	})

	FOV = SilentAim:CreateSlider({
		Name = 'FOV',
		Min = 1,
		Max = 1000,
		Default = 300
	})

	SAFOVCircle = SilentAim:CreateToggle({
		Name = 'FOV Circle',
		Function = function(call)
			if SilentAim.Enabled then
				runFOVCircle(call)
			end
		end
	})

	-- Both chances only mean anything while the random part is selected, so the menu hides them with
	-- a visibility predicate (the GUI re-runs those whenever any option changes) rather than an
	-- imperative refresh that nothing would trigger.
	RandomHeadPercent = SilentAim:CreateSlider({
		Name = 'Head Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Darker = true,
		Visible = function()
			return TargetPart.Value == 'Randomize'
		end
	})

	RandomTorsoPercent = SilentAim:CreateSlider({
		Name = 'Torso Chance',
		Min = 0,
		Max = 100,
		Default = 50,
		Darker = true,
		Visible = function()
			return TargetPart.Value == 'Randomize'
		end,
		Function = function(val)
			if RandomHeadPercent and (RandomHeadPercent.Value + val) > 100 then
				notif('SilentAim', 'head or torso chance is more than 100% so root part will never be picked..', 3)
			end
		end
	})

	OtherProjectiles = SilentAim:CreateToggle({
		Name = 'Other Projectiles',
		Default = true,
		Function = function(call)
			if Blacklist then Blacklist.Object.Visible = call end
		end
	})

	Blacklist = SilentAim:CreateTextList({
		Name = 'Blacklist',
		Darker = true,
		Default = {'telepearl', 'gloop'},
		Placeholder = 'projectile'
	})

	AutoCharge = SilentAim:CreateToggle({
		Name = 'AutoCharge',
		Default = true,
		Function = function(v)
			if skidChargePercent and skidChargePercent.Object then
				skidChargePercent.Object.Visible = v
			end
		end
	})

	skidChargePercent = SilentAim:CreateSlider({
		Name = 'Charge Percent',
		Min = 1,
		Max = 100,
		Default = 100
	})

	Debug = SilentAim:CreateToggle({
		Name = 'Debug',
		Tooltip = 'Reports what each shot did - which target it was sent to, or why it was left alone'
	})
end)

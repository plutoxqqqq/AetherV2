run(function()
	local JadeInstantKill
	local Targets
	local Range
	local LimitItems
	local nextUse = 0
	local sequence = 0
	local tracking = false
	local cameraBound = false
	local anchor
	local lockedY

	local HAMMER_ORDER = {'jade_hammer_3', 'jade_hammer_2', 'jade_hammer_1'}
	local COOLDOWN_ID = 'jade_hammer'
	local COOLDOWN_FALLBACK = 6

	local function normalizeName(value)
		return tostring(value or ''):lower():gsub('[%s%-]+', '_')
	end

	local function isJadeHammer(item)
		local name = normalizeName(item and (item.itemType or (item.tool and item.tool.Name)) or '')
		return name == 'jade_hammer' or name == 'jade_hammer_jump' or name:match('^jade_hammer_%d+$') ~= nil
	end

	local function heldHammer()
		local hand = store.hand
		if hand and hand.tool and isJadeHammer(hand) then
			return {itemType = hand.itemType or hand.tool.Name, tool = hand.tool, amount = hand.amount or 1}
		end
		return nil
	end

	local function inventoryHammer()
		for _, name in ipairs(HAMMER_ORDER) do
			local item = getItem(name)
			if item then return item end
		end
		return nil
	end

	local function isAliveTarget(target)
		if not target or not target.RootPart or not target.RootPart.Parent then return false end
		local health = target.Health
		if type(health) == 'number' and health <= 0 then return false end
		local humanoid = target.Humanoid
		if humanoid and (humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead) then return false end
		local character = target.Character
		if character then
			local attributeHealth = character:GetAttribute('Health')
			if type(attributeHealth) == 'number' and attributeHealth <= 0 then return false end
		end
		return true
	end

	local function findTarget()
		local settings = {
			Range = Range.Value,
			Part = 'RootPart',
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled,
			Priority = Targets.Priority.Value,
			Sort = sortmethods.Distance
		}
		local picked = entitylib.EntityPosition(table.clone(settings))
		if isAliveTarget(picked) then return picked end

		-- EntityPosition can hand back a corpse when it is the closest candidate, so fall
		-- back to a scan and take the first living entity instead.
		local allSettings = table.clone(settings)
		allSettings.Sort = sortmethods.Distance
		for _, entity in ipairs(entitylib.AllPosition(allSettings)) do
			if isAliveTarget(entity) then return entity end
		end
		return nil
	end

	local function ensureAnchor()
		if anchor and anchor.Parent then return anchor end
		anchor = Instance.new('Part')
		anchor.Name = 'JadeInstantKillAnchor'
		anchor.Size = Vector3.new(0.1, 0.1, 0.1)
		anchor.Transparency = 1
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.CastShadow = false
		anchor.Parent = workspace.CurrentCamera or workspace
		return anchor
	end

	local function flatLook(cframe)
		local flat = cframe.LookVector * Vector3.new(1, 0, 1)
		if flat.Magnitude <= 0.001 then return nil end
		return flat.Unit
	end

	-- The camera is pinned to an invisible part that rides the camera horizontally but
	-- never moves on Y, so the view can still turn and slide side to side while its height
	-- stays locked for the whole slam.
	local function lockCamera()
		if cameraBound then return end
		local camera = workspace.CurrentCamera
		if not camera then return end
		cameraBound = true
		lockedY = camera.CFrame.Position.Y
		local part = ensureAnchor()
		part.Position = Vector3.new(camera.CFrame.Position.X, lockedY, camera.CFrame.Position.Z)
		runService:BindToRenderStep('JadeInstantKillCamera', Enum.RenderPriority.Camera.Value + 1, function()
			if not tracking or not JadeInstantKill.Enabled then return end
			local currentCamera = workspace.CurrentCamera
			local anchorPart = anchor
			if not currentCamera or not anchorPart or not anchorPart.Parent then return end
			local look = flatLook(currentCamera.CFrame)
			if not look then return end
			anchorPart.Position = Vector3.new(currentCamera.CFrame.Position.X, lockedY, currentCamera.CFrame.Position.Z)
			currentCamera.CFrame = CFrame.lookAt(anchorPart.Position, anchorPart.Position + look)
		end)
	end

	local function unlockCamera()
		if not cameraBound then return end
		cameraBound = false
		pcall(runService.UnbindFromRenderStep, runService, 'JadeInstantKillCamera')
		if anchor then
			anchor:Destroy()
			anchor = nil
		end
	end

	local function equipHammer(hammer)
		if heldHammer() then return true end
		if not hammer or not hammer.tool or not hammer.tool.Parent then return false end
		pcall(switchItem, hammer.tool, 0.05)
		local hotbar = getHotbar(hammer.tool)
		if hotbar then
			pcall(hotbarSwitch, hotbar)
		end
		local deadline = tick() + 0.5
		repeat
			task.wait()
		until heldHammer() or tick() >= deadline
		return heldHammer() ~= nil
	end

	-- Find the game's own cooldown checks first: the ability controller owns a cooldown
	-- controller with getRemainingCooldown/isOnCooldown, and the Jade controller publishes
	-- readyTime on the server clock. Only when both are missing do we fall back to a timer.
	local function cooldownRemaining()
		local abilityController = bedwars.AbilityController
		local cooldownController = abilityController and abilityController.cooldownController
		if cooldownController then
			local ok, remaining = pcall(function()
				return cooldownController:getRemainingCooldown(COOLDOWN_ID)
			end)
			if ok and type(remaining) == 'number' then
				return math.max(remaining, 0)
			end
			local ok2, onCooldown = pcall(function()
				return cooldownController:isOnCooldown(COOLDOWN_ID)
			end)
			if ok2 and type(onCooldown) == 'boolean' then
				return onCooldown and COOLDOWN_FALLBACK or 0
			end
		end

		local jadeController = bedwars.JadeHammerController
		if jadeController and type(jadeController.readyTime) == 'number' and jadeController.readyTime > 0 then
			return math.max(jadeController.readyTime - workspace:GetServerTimeNow(), 0)
		end
		return nil
	end

	local function fireRawAbility()
		local events = replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events']
		if not events or not events.useAbility then return false end
		local root = entitylib.character and entitylib.character.RootPart
		events.useAbility:FireServer('jade_hammer_jump', {
			direction = root and root.CFrame.LookVector or Vector3.zAxis,
			origin = root and root.Position or Vector3.zero
		})
		return true
	end

	-- The tool cooldown is deliberately ignored. The normal client call is made even when
	-- the ability gate reports blocked, and when a cooldown is detected the ability event is
	-- also fired directly, which skips the client-side check.
	local function callJadeJump()
		local called = false
		pcall(function()
			bedwars.AbilityController:useAbility('jade_hammer_jump')
			called = true
		end)
		if not called then
			pcall(function()
				if bedwars.JadeHammerController and bedwars.JadeHammerController.useJadeHammer then
					bedwars.JadeHammerController:useJadeHammer()
					called = true
				end
			end)
		end
		local remaining = cooldownRemaining()
		if remaining and remaining > 0 then
			pcall(function()
				called = fireRawAbility() or called
			end)
		end
		return called
	end

	local function moveOverTarget(root, targetPart)
		local targetPosition = targetPart and targetPart.Position
		if not targetPosition then return end
		root.CFrame = CFrame.new(Vector3.new(targetPosition.X, root.Position.Y, targetPosition.Z)) * (root.CFrame - root.Position)
	end

	local function runSequence(token)
		local hammer = heldHammer() or inventoryHammer()
		if not hammer then return false end
		if LimitItems.Enabled and not heldHammer() then return false end
		if not equipHammer(hammer) then return false end

		local target = findTarget()
		if not target then return false end

		local root = entitylib.character.RootPart
		local humanoid = entitylib.character.Humanoid
		if not root or not humanoid then return end

		tracking = true
		lockCamera()

		moveOverTarget(root, target.RootPart)
		root.CFrame = CFrame.new(root.Position + Vector3.new(0, 200, 0)) * (root.CFrame - root.Position)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		task.wait(0.05)
		if token ~= sequence or not JadeInstantKill.Enabled then return end

		local jumpDeadline = tick() + 0.5
		while JadeInstantKill.Enabled and token == sequence and tick() < jumpDeadline do
			if callJadeJump() then break end
			task.wait(0.05)
		end

		local deadline = tick() + 8
		local airborne = false
		while JadeInstantKill.Enabled and token == sequence and entitylib.isAlive do
			local character = entitylib.character
			local currentRoot = character and character.RootPart
			local currentHumanoid = character and character.Humanoid
			if not currentRoot or not currentHumanoid then break end
			if not isAliveTarget(target) then break end

			local floor = currentHumanoid.FloorMaterial
			if floor == Enum.Material.Air then
				airborne = true
			end

			moveOverTarget(currentRoot, target.RootPart)
			currentRoot.AssemblyLinearVelocity = Vector3.new(0, currentRoot.AssemblyLinearVelocity.Y, 0)

			if airborne and floor ~= Enum.Material.Air then break end
			if tick() >= deadline then break end
			task.wait()
		end

		local remaining = cooldownRemaining()
		nextUse = tick() + (type(remaining) == 'number' and math.max(remaining, 0.2) or COOLDOWN_FALLBACK)
		return true
	end

	JadeInstantKill = kits:CreateModule({
		Name = 'JadeInstantKill',
		Function = function(callback)
			sequence += 1
			local token = sequence
			if callback then
				nextUse = 0
				task.spawn(function()
					while JadeInstantKill.Enabled and token == sequence do
						if entitylib.isAlive and store.equippedKit == 'jade' and tick() >= nextUse then
							if heldHammer() or inventoryHammer() then
								nextUse = math.huge
								local ran = runSequence(token)
								if not ran then
									nextUse = tick() + 0.5
								elseif nextUse == math.huge then
									nextUse = tick() + COOLDOWN_FALLBACK
								end
							end
						end
						task.wait(0.1)
					end
					tracking = false
					unlockCamera()
				end)
			else
				tracking = false
				unlockCamera()
			end
		end,
		Tooltip = 'Teleports above the target, ignores the Jade Hammer cooldown and rides the slam down onto them'
	})

	Targets = JadeInstantKill:CreateTargets({
		Players = true,
		Walls = true
	})
	Range = JadeInstantKill:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 200,
		Default = 100,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'How far away a target can be before the slam starts'
	})
	LimitItems = JadeInstantKill:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only slams while you are already holding a Jade Hammer, instead of equipping one for you'
	})
end)

run(function()
	local JadeInstantKill
	local Targets
	local Range
	local LimitItems
	local nextUse = 0
	local sequence = 0
	local tracking = false
	local cameraBound = false

	local HAMMER_ORDER = {'jade_hammer_3', 'jade_hammer_2', 'jade_hammer_1'}

	local function normalizeName(value)
		return tostring(value or ''):lower():gsub('[%s%-]+', '_')
	end

	local function isJadeHammer(item)
		local name = normalizeName(item and (item.itemType or (item.tool and item.tool.Name)) or '')
		return name == 'jade_hammer' or name:match('^jade_hammer_%d+$') ~= nil
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

	local function lockCamera()
		if cameraBound then return end
		cameraBound = true
		runService:BindToRenderStep('JadeInstantKillCamera', Enum.RenderPriority.Camera.Value + 1, function()
			if not tracking or not JadeInstantKill.Enabled then return end
			local camera = workspace.CurrentCamera
			if not camera then return end
			local cframe = camera.CFrame
			local flat = cframe.LookVector * Vector3.new(1, 0, 1)
			if flat.Magnitude > 0.001 then
				camera.CFrame = CFrame.lookAt(cframe.Position, cframe.Position + flat.Unit)
			end
		end)
	end

	local function unlockCamera()
		if not cameraBound then return end
		cameraBound = false
		pcall(runService.UnbindFromRenderStep, runService, 'JadeInstantKillCamera')
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

	local function callJadeJump()
		local called = false
		pcall(function()
			if bedwars.AbilityController:canUseAbility('jade_hammer_jump', {disableBlockedAbilityAlert = true}) then
				bedwars.AbilityController:useAbility('jade_hammer_jump')
				called = true
			end
		end)
		if not called then
			pcall(function()
				if bedwars.JadeHammerController and bedwars.JadeHammerController.useJadeHammer then
					bedwars.JadeHammerController:useJadeHammer()
					called = true
				end
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
		if not hammer then return end
		if LimitItems.Enabled and not heldHammer() then return end
		if not equipHammer(hammer) then return end

		local target = entitylib.EntityPosition({
			Range = Range.Value,
			Part = 'RootPart',
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled,
			Priority = Targets.Priority.Value,
			Sort = sortmethods.Distance
		})
		if not target or not target.RootPart then return end

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
			local targetPart = target.RootPart
			if not currentRoot or not currentHumanoid or not targetPart or not targetPart.Parent then break end
			if target.Health and target.Health <= 0 then break end

			local floor = currentHumanoid.FloorMaterial
			if floor == Enum.Material.Air then
				airborne = true
			end

			moveOverTarget(currentRoot, targetPart)
			currentRoot.AssemblyLinearVelocity = Vector3.new(0, currentRoot.AssemblyLinearVelocity.Y, 0)

			if airborne and floor ~= Enum.Material.Air then break end
			if tick() >= deadline then break end
			task.wait()
		end
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
								local target = entitylib.EntityPosition({
									Range = Range.Value,
									Part = 'RootPart',
									Players = Targets.Players.Enabled,
									NPCs = Targets.NPCs.Enabled,
									Wallcheck = Targets.Walls.Enabled,
									Priority = Targets.Priority.Value,
									Sort = sortmethods.Distance
								})
								if target then
									nextUse = tick() + 1
									runSequence(token)
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
		Tooltip = 'Teleports above the target, jumps with the Jade Hammer and rides the slam down onto them'
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

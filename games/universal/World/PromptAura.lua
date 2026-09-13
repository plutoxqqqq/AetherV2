run(function()
	local PromptAura
	local Range
	local ShopPrompts
	local RepeatPrompt
	local localPlayer = cloneref(game:GetService('Players')).LocalPlayer
	local collectionService = cloneref(game:GetService('CollectionService'))
	local proximPromptService = cloneref(game:GetService('ProximityPromptService'))
	local SHOP_TAGS = {'BedwarsItemShop', 'TeamUpgradeShopkeeper'}
	local running = false
	local completed = setmetatable({}, {__mode = 'k'})
	local nextAttempt = {}
	local COOLDOWN = 0.2
	local REPEAT_COOLDOWN = 1

	local function rootPart()
		local character = localPlayer.Character
		return character and (character:FindFirstChild('HumanoidRootPart') or character:FindFirstChild('UpperTorso'))
	end

	local function isShopPrompt(prompt)
		local node = prompt
		for _ = 1, 6 do
			if not node then break end
			for _, tag in SHOP_TAGS do
				if collectionService:HasTag(node, tag) then return true end
			end
			node = node.Parent
		end
		return false
	end

	local function promptPosition(prompt)
		local parent = prompt.Parent
		if typeof(parent) ~= 'Instance' then return nil end
		if parent:IsA('BasePart') then return parent.Position end
		if parent:IsA('Model') and parent.PrimaryPart then return parent.PrimaryPart.Position end
		if parent:IsA('Attachment') then
			local part = parent.Parent
			if part and part:IsA('BasePart') then return parent.WorldPosition end
		end
		local ok, position = pcall(function() return parent:GetPivot().Position end)
		return ok and position or nil
	end

	local function prompts()
		local ok, list = pcall(function() return proximPromptService:GetPrompts() end)
		if ok and type(list) == 'table' then return list end
		local found = {}
		for _, object in workspace:GetDescendants() do
			if object:IsA('ProximityPrompt') then table.insert(found, object) end
		end
		return found
	end

	local function fire(prompt)
		return pcall(function()
			if type(fireproximityprompt) == 'function' then
				fireproximityprompt(prompt)
			else
				prompt:InputHoldBegin()
				task.delay(math.max(prompt.HoldDuration, 0.05), function()
					pcall(function() prompt:InputHoldEnd() end)
				end)
			end
		end)
	end

	local function scan()
		local root = rootPart()
		if not root then return end
		local now = os.clock()
		local maxDistance = Range.Value
		for _, prompt in prompts() do
			if typeof(prompt) == 'Instance' and prompt:IsA('ProximityPrompt') and prompt.Enabled then
				if not (not ShopPrompts.Enabled and isShopPrompt(prompt)) then
					local position = promptPosition(prompt)
					if position and (position - root.Position).Magnitude <= maxDistance then
						local repeatable = RepeatPrompt.Enabled
						if repeatable or not completed[prompt] then
							local last = nextAttempt[prompt] or 0
							if now - last >= (repeatable and REPEAT_COOLDOWN or COOLDOWN) then
								nextAttempt[prompt] = now
								if fire(prompt) then completed[prompt] = true end
							end
						end
					end
				end
			end
		end
	end

	local function stop()
		running = false
		table.clear(nextAttempt)
	end

	PromptAura = vape.Categories.World:CreateModule({
		Name = 'PromptAura',
		Tooltip = 'Automatically activates nearby proximity prompts, such as shops and interactables',
		Function = function(callback)
			if not callback then stop(); return end
			if running then return end
			running = true
			task.spawn(function()
				while running and PromptAura.Enabled do
					pcall(scan)
					task.wait(0.5)
				end
			end)
		end
	})
	Range = PromptAura:CreateSlider({Name = 'Range', Min = 5, Max = 100, Default = 30, Suffix = ' studs', Tooltip = 'How far away a prompt can be and still activate'})
	ShopPrompts = PromptAura:CreateToggle({Name = 'Shop prompts', Default = true, Tooltip = 'Also activates BedWars shop and team-upgrade prompts'})
	RepeatPrompt = PromptAura:CreateToggle({Name = 'Repeat same prompt', Default = false, Tooltip = 'Keeps retrying the same prompt instead of activating it once'})
	PromptAura:Clean(stop)
end)

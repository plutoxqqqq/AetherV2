run(function()
	local PromptEditor
	local Range
	local Hold
	local Instant
	local ThroughWalls
	local originals = setmetatable({}, {__mode = 'k'})
	local applying = setmetatable({}, {__mode = 'k'})
	local environment = (getgenv and getgenv()) or _G
	local api = environment.AetherInteractExtender or {}

	local function remember(prompt)
		if originals[prompt] then return true end
		local ok, state = pcall(function()
			return {
				Distance = prompt.MaxActivationDistance,
				Duration = prompt.HoldDuration,
				Sight = prompt.RequiresLineOfSight
			}
		end)
		if ok then originals[prompt] = state end
		return ok
	end

	local function applyPrompt(prompt)
		if typeof(prompt) ~= 'Instance' or not prompt:IsA('ProximityPrompt') or not remember(prompt) then return end
		applying[prompt] = true
		pcall(function()
			prompt.MaxActivationDistance = Range.Value
			prompt.HoldDuration = Instant.Enabled and 0 or Hold.Value
			prompt.RequiresLineOfSight = not ThroughWalls.Enabled
		end)
		applying[prompt] = nil
	end

	local function restorePrompt(prompt, original)
		if not prompt or not prompt.Parent or not original then return end
		applying[prompt] = true
		pcall(function()
			prompt.MaxActivationDistance = original.Distance
			prompt.HoldDuration = original.Duration
			prompt.RequiresLineOfSight = original.Sight
		end)
		applying[prompt] = nil
	end

	local function refresh()
		if not PromptEditor.Enabled then return end
		for prompt in originals do applyPrompt(prompt) end
	end


	api.IsEnabled = function()
		return PromptEditor and PromptEditor.Enabled == true
	end
	api.Activate = function(prompt)
		if not api.IsEnabled() then return false, 'PromptEditor is disabled' end
		if typeof(prompt) ~= 'Instance' or not prompt:IsA('ProximityPrompt') then return false, 'invalid prompt' end
		applyPrompt(prompt)
		if type(fireproximityprompt) ~= 'function' then return false, 'fireproximityprompt unavailable' end
		local ok, result = pcall(fireproximityprompt, prompt)
		return ok and result ~= false, ok and nil or tostring(result)
	end
	environment.AetherInteractExtender = api
	vape:Clean(function()
		if environment.AetherInteractExtender == api then environment.AetherInteractExtender = nil end
	end)

	PromptEditor = vape.Categories.World:CreateModule({
		Name = 'PromptEditor',
		Tooltip = 'Edits proximity prompt range, hold time and line-of-sight rules in one module',
		Function = function(callback)
			if callback then
				PromptEditor:Clean(workspace.DescendantAdded:Connect(applyPrompt))
				PromptEditor:Clean(proximityPromptService.PromptShown:Connect(applyPrompt))
				for _, prompt in workspace:GetDescendants() do applyPrompt(prompt) end
			else
				for prompt, original in originals do restorePrompt(prompt, original) end
				table.clear(originals)
				table.clear(applying)
			end
		end
	})
	Range = PromptEditor:CreateSlider({Name = 'Range', Min = 1, Max = 100, Default = 32, Suffix = ' studs', Function = refresh})
	Hold = PromptEditor:CreateSlider({Name = 'Hold duration', Min = 0, Max = 10, Default = 1, Decimal = 100, Suffix = 's', Function = refresh})
	Instant = PromptEditor:CreateToggle({Name = 'Instant', Tooltip = 'Sets prompt hold duration to zero', Function = refresh})
	ThroughWalls = PromptEditor:CreateToggle({Name = 'Through walls', Tooltip = 'Removes prompt line-of-sight checks', Function = refresh})
end)
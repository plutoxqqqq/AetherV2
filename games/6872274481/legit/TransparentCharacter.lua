run(function()
	local TransparentCharacter
	local Amount
	local originals = setmetatable({}, {__mode = 'k'})
	local watchedCharacter
	local descendantConnection

	local function desiredTransparency()
		return Amount.Value / 100
	end

	local function applyTransparency(char)
		if not char or char ~= watchedCharacter or not Amount then return end
		for _, obj in char:GetDescendants() do
			if obj:IsA('BasePart') then
				if originals[obj] == nil then originals[obj] = obj.Transparency end
				obj.Transparency = desiredTransparency()
			end
		end
	end

	local function restoreTransparency()
		for obj, value in originals do
			if obj.Parent then obj.Transparency = value end
		end
		table.clear(originals)
	end
	local function watchCharacter(char)
		if descendantConnection then
			descendantConnection:Disconnect()
			descendantConnection = nil
		end
		restoreTransparency()
		watchedCharacter = char
		applyTransparency(char)
		if char then
			descendantConnection = char.DescendantAdded:Connect(function(obj)
				if obj:IsA('BasePart') and char == watchedCharacter and TransparentCharacter.Enabled then
					task.defer(function()
						if obj.Parent and char == watchedCharacter and TransparentCharacter.Enabled then
							if originals[obj] == nil then originals[obj] = obj.Transparency end
							obj.Transparency = desiredTransparency()
						end
					end)
				end
			end)
		end
	end

	TransparentCharacter = vape.Categories.Legit:CreateModule({
		Name = 'TransparentCharacter',
		Tooltip = 'Makes your entire character locally transparent',
		Function = function(callback)
			if callback then
				watchCharacter(lplr.Character)
				TransparentCharacter:Clean(lplr.CharacterAdded:Connect(watchCharacter))
				-- Use Transparency rather than fighting Roblox's camera controller over
				-- LocalTransparencyModifier every render step. The camera can now interpolate its
				-- own first-person fade normally, so scroll zoom remains smooth.
			else
				if descendantConnection then descendantConnection:Disconnect(); descendantConnection = nil end
				restoreTransparency()
				watchedCharacter = nil
			end
		end
	})
	Amount = TransparentCharacter:CreateSlider({
		Name = 'Transparency',
		Min = 0,
		Max = 100,
		Default = 50,
		Suffix = '%',
		Function = function()
			if TransparentCharacter.Enabled then applyTransparency(lplr.Character) end
		end
	})
end)
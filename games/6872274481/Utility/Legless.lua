run(function()
	local Legless
	local Side
	local RemoveAccessories
	local originals = {}
	local legAttachments = {
		LeftAnkleAttachment = 'Left', LeftFootAttachment = 'Left', LeftKneeAttachment = 'Left',
		RightAnkleAttachment = 'Right', RightFootAttachment = 'Right', RightKneeAttachment = 'Right'
	}

	local function selected(name)
		return Side.Value == 'Both' or name:sub(1, #Side.Value) == Side.Value
	end

	local function hide(obj)
		if originals[obj] == nil then originals[obj] = obj.Transparency end
		obj.Transparency = 1
	end

	local function applyLegless(char)
		if not char then return end
		for _, obj in char:GetDescendants() do
			if obj:IsA('BasePart') and (selected(obj.Name) and obj.Name:find('Leg') or selected(obj.Name) and obj.Name:find('Foot')) then
				hide(obj)
			end
		end
		if RemoveAccessories.Enabled then
			for _, acc in char:GetChildren() do
				if acc:IsA('Accessory') then
					local handle = acc:FindFirstChild('Handle')
					if handle then
						for _, attachment in handle:GetChildren() do
							if attachment:IsA('Attachment') and legAttachments[attachment.Name] and selected(legAttachments[attachment.Name]) then
								hide(handle)
								for _, texture in handle:GetChildren() do
									if texture:IsA('Decal') or texture:IsA('Texture') then hide(texture) end
								end
								break
							end
						end
					end
				end
			end
		end
	end

	local function restoreLegs()
		for obj, value in originals do
			if obj.Parent then obj.Transparency = value end
		end
		table.clear(originals)
	end
	local function watchCharacter(char)
		applyLegless(char)
		if char then
			Legless:Clean(char.DescendantAdded:Connect(function()
				task.defer(applyLegless, char)
			end))
		end
	end

	Legless = vape.Categories.Utility:CreateModule({
		PerformanceModeBlacklisted = true,
		Name = 'Legless',
		Tooltip = 'Hides either or both legs',
		Function = function(callback)
			if callback then
				watchCharacter(lplr.Character)
				Legless:Clean(lplr.CharacterAdded:Connect(watchCharacter))
			else
				restoreLegs()
			end
		end
	})
	Side = Legless:CreateDropdown({
		Name = 'Legs',
		List = {'Both', 'Left', 'Right'},
		Function = function()
			if Legless.Enabled then restoreLegs(); applyLegless(lplr.Character) end
		end
	})
	RemoveAccessories = Legless:CreateToggle({
		Name = 'Remove Accessories',
		Function = function()
			if Legless.Enabled then restoreLegs(); applyLegless(lplr.Character) end
		end
	})
end)

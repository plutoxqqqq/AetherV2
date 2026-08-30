run(function()
	local GrimReaperFix
	GrimReaperFix = kits:CreateModule({
		Name = 'GrimReaperFix',
		Category = 'Ability',
		Function = function(callback)
			if callback then
				local function watch(character)
					local humanoid = character and character:FindFirstChildOfClass('Humanoid')
					if not humanoid then return end
					local applying = false
					local function correct()
						if applying or not GrimReaperFix.Enabled or not humanoid.Parent then return end
						if humanoid.HipHeight > 2.1 then
							applying = true
							humanoid.HipHeight = 2.05
							applying = false
						end
					end
					correct()
					GrimReaperFix:Clean(humanoid:GetPropertyChangedSignal('HipHeight'):Connect(correct))
				end
				watch(lplr.Character)
				GrimReaperFix:Clean(lplr.CharacterAdded:Connect(function(character) task.defer(watch, character) end))
			end
		end,
		Tooltip = 'fixes grim height (prevents being too tall)'
	})
end)
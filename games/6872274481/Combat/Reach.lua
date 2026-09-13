run(function()
	local BlockReach
		local BlockRange
		local BreakReach
		local BreakRange
		local SwordReach
		local SwordRange

		local old

		Reach = vape.Categories.Combat:CreateModule({
			Name = 'Reach',
			Tooltip = 'Allows you to place, attack, and break further',
			Function = function(callback)
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = callback and SwordReach.Enabled and SwordRange.Value + 2 or 14.4
				if callback then
					old = bedwars.BlockSelector.getMouseInfo
					bedwars.BlockSelector.getMouseInfo = function(...)
						local Self, Select, Args = ...
						if not Args then
							Args = {}
						end
						if Select == 0 then
							Args.range = BlockReach.Enabled and BlockRange.Value or 24
						elseif Select == 1 then
							Args.range = BreakReach.Enabled and BreakRange.Value or 18
						end
						return old(Self, Select, Args)
					end
				else
					bedwars.BlockSelector.getMouseInfo = old
					old = nil
				end
			end,
		})
		SwordReach = Reach:CreateToggle({
			Name = 'Sword Reach',
			Default = true,
			Function = function(callback)
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and callback and SwordRange.Value + 2 or 14.4
				pcall(function()
					SwordRange.Object.Visible = callback
				end)
			end,
		})
		SwordRange = Reach:CreateSlider({
			Name = 'Sword Range',
			Min = 1,
			Max = 18,
			Default = 18,
			Decimal = 5,
			Darker = true,
			Suffix = function(val)
				return val <= 1 and 'stud' or 'studs'
			end,
			Function = function(val)
				bedwars.CombatConstant.RAYCAST_SWORD_CHARACTER_DISTANCE = Reach.Enabled and SwordReach.Enabled and val or 14.4
			end,
		})
		BlockReach = Reach:CreateToggle({
			Name = 'Placement Reach',
			Function = function(callback)
				BlockRange.Object.Visible = callback
			end,
		})
		BlockRange = Reach:CreateSlider({
			Name = 'Placement Range',
			Min = 1,
			Max = 60,
			Default = 18,
			Darker = true,
			Suffix = function(val)
				return val <= 1 and 'stud' or 'studs'
			end,
			Visible = false,
		})
		BreakReach = Reach:CreateToggle({
			Name = 'Break Reach',
			Function = function(callback)
				BreakRange.Object.Visible = callback
			end,
		})
		BreakRange = Reach:CreateSlider({
			Name = 'Break Range',
			Min = 1,
			Max = 30,
			Default = 30,
			Decimal = 5,
			Darker = true,
			Suffix = function(val)
				return val <= 1 and 'stud' or 'studs'
			end,
			Visible = false,
		})
		Reach:CreateButton({
			Name = 'Reset to default reach',
			Tooltip = 'Resets every range back to default',
			Function = function()
				BreakRange:SetValue(18)
				BlockRange:SetValue(24)
				SwordRange:SetValue(12.4)
			end,
		})
	end)

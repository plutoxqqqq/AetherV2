run(function()
	local AutoGingerbread
	local Range
	local Delay
	local Break
	local Jump
	local Switch
	local OwnOnly
	local SuccessfulOnly

	local old

	local function legitSwitch(block)
		local itemmeta = bedwars.ItemMeta[block.Name]
		local breaktype = itemmeta and itemmeta.block and itemmeta.block.breakType
		local tool = breaktype and store.tools[breaktype] or store.tools.sword
		local slot = tool and getHotbar(tool.tool)

		if slot then
			hotbarSwitch(slot)
		elseif tool then
			switchItem(tool.tool)
		end
	end

	AutoGingerbread = kits:CreateModule({
		Name = 'AutoGingerbreadMan',
		Function = function(callback)
			if callback then
				old = bedwars.LaunchPadController.attemptLaunch
				bedwars.LaunchPadController.attemptLaunch = function(self, block, ...)
					local lastLaunch = self and self.lastLaunch or 0
					local call = old(self, block, ...)

					if not SuccessfulOnly.Enabled or self and self.lastLaunch and self.lastLaunch ~= lastLaunch then
						if Break.Enabled and entitylib.isAlive and store.equippedKit == 'gingerbread_man' and block and block:IsA('BasePart') and (not OwnOnly.Enabled or block:GetAttribute('PlacedByUserId') == lplr.UserId) and (block.Position - entitylib.character.RootPart.Position).Magnitude <= Range.Value then
							task.delay(Delay.Value, function()
								if AutoGingerbread.Enabled and block.Parent then
									if Switch.Enabled then
										legitSwitch(block)
									end
									bedwars.breakBlock(block, false, nil, nil, Switch.Enabled)
								end
							end)
						end

						if Jump.Enabled and entitylib.isAlive then
							entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
						end
					end
					return call
				end
			else
				bedwars.LaunchPadController.attemptLaunch = old
			end
		end,
		Tooltip = 'Automatically handles Gingerbread Man launch pads.'
	})
	Break = AutoGingerbread:CreateToggle({
		Name = 'Break launch pad',
		Default = true,
		Function = function(call)
			if Range then
				Range.Object.Visible = call
				Delay.Object.Visible = call
				Switch.Object.Visible = call
				OwnOnly.Object.Visible = call
			end
		end
	})
	Jump = AutoGingerbread:CreateToggle({Name = 'Jump after launch'})

	Switch = AutoGingerbread:CreateToggle({
		Name = 'Legit switch',
		Darker = true
	})
	OwnOnly = AutoGingerbread:CreateToggle({
		Name = 'Own pads only',
		Default = true,
		Darker = true
	})
	SuccessfulOnly = AutoGingerbread:CreateToggle({
		Name = 'Successful launch only',
		Default = true
	})
	Range = AutoGingerbread:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoGingerbread:CreateSlider({
		Name = 'Break delay',
		Min = 0,
		Max = 1,
		Default = 0.05,
		Decimal = 100,
		Darker = true,
		Suffix = function(val)
			return val == 1 and 'sec' or 'secs'
		end
	})
end)

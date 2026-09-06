run(function()
	local AutoDavey
	local Switch
	local Break
	local Jump
	local LimitItem

	local old, oldAim

	local function canBreak()
		if not LimitItem.Enabled then return true end
		local itemmeta = store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name]
		return itemmeta ~= nil and itemmeta.breakBlock ~= nil
	end

	local function breakCannon(block, keepLast)
		local deadline = tick() + 0.6 + (store.ping.total or 0)
		local hits = keepLast and math.max(math.ceil(getBlockHits(block, block.Position)) - 1, 0) or math.huge

		repeat
			if not AutoDavey.Enabled or not entitylib.isAlive or not canBreak() or hits <= 0 then return end
			if (block.Position - entitylib.character.RootPart.Position).Magnitude > 30 then return end
			bedwars.breakBlock(block, true, true, nil, Switch.Enabled)
			hits -= 1
			task.wait(0.1)
		until not block.Parent or tick() > deadline
	end

	AutoDavey = kits:CreateModule({
		Name = 'AutoDavey',
		Function = function(callback)
			if callback then
				oldAim = bedwars.CannonController.startAiming
				bedwars.CannonController.startAiming = function(self, block, ...)
					local call = oldAim(self, block, ...)

					if Break.Enabled and block and block.Parent and entitylib.isAlive and canBreak() and getBlockHits(block, block.Position) > 1 then
						task.spawn(breakCannon, block, true)
					end

					return call
				end

				old = bedwars.CannonHandController.launchSelf
				bedwars.CannonHandController.launchSelf = function(self, block, ...)
					if Break.Enabled and block and block.Parent and entitylib.isAlive and (block.Position - entitylib.character.RootPart.Position).Magnitude <= 30 and canBreak() then
						task.spawn(breakCannon, block)
					end

					local call = old(self, block, ...)

					if Jump.Enabled and entitylib.isAlive then
						entitylib.character.Humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
					end
					return call
				end
			else
				bedwars.CannonHandController.launchSelf = old
				bedwars.CannonController.startAiming = oldAim
			end
		end,
		Tooltip = 'Automatically breaks cannon/jump on launch'
	})
	Jump = AutoDavey:CreateToggle({Name = 'Jump on impact'})

	Break = AutoDavey:CreateToggle({Name = 'Break on impact'})

	Switch = AutoDavey:CreateToggle({Name = 'Legit switch'})

	LimitItem = AutoDavey:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only breaks when tools are held'
	})
end)

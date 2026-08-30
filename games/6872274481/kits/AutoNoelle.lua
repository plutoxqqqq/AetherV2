run(function()
	local AutoNoelle
	local Notify
	local FrostySlime
	local HealSlime
	local StickySlime
	local VoidSlime
	local Limit

	local function getSlimes()
		local slimes = {}
		local folder = workspace:FindFirstChild('SlimeModelFolder')
		for _, v in folder and folder:GetChildren() or {} do
			local data = v:FindFirstChild('SlimeData')
			data = data and data.Value

			if data and data.Tamer.Value == lplr.UserId then
				table.insert(slimes, {
					Data = data,
					RootPart = v,
					Name = v.Name:gsub(`_{lplr.Name}`, ''):gsub('Slime', ' Slime')
				})
			end
		end
		return slimes
	end

	local function getPlayer(name)
		for _, v in playersService:GetPlayers() do
			if `{v.DisplayName} ({v.Name})` == name then
				return v
			end
		end
		return
	end

	AutoNoelle = kits:CreateModule({
		Name = 'AutoNoelle',
		Function = function(call)
			if call then
				repeat
					if entitylib.isAlive and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'slime_tamer_flute') then
						for _, v in getSlimes() do
							local dropdown = AutoNoelle.Options[`{v.Name} Target`]
							local player = dropdown and getPlayer(dropdown.Value)

							if player and v.Data.Following.Value ~= player.UserId then
								bedwars.Handler:Get('RequestMoveSlime'):Fire('CallServerAsync', {
									slimeId = v.Data:GetAttribute('Id'),
									targetPlayerUserId = player.UserId
								}):andThen(function(suc)
									if suc then
										v.Data.Following.Value = player.UserId

										if Notify.Enabled then
											notif('AutoNoelle', `Directed {v.Name} to {player.DisplayName} ({player.Name})`, 5, 'info')
										end
									end
								end)
							end
						end
					end
					task.wait(0.5)
				until not AutoNoelle.Enabled
			end
		end,
		Tooltip = 'Automatically directs the slimes to the selected player\'s'
	})
	local friends = {'None'}

	local function addConnection(plr, connected)
		if not connected then
			vape:Clean(plr:GetAttributeChangedSignal('Team'):Connect(function()
				addConnection(plr, true)
			end))
		end

		local name = `{plr.DisplayName} ({plr.Name})`
		if plr:GetAttribute('Team') == lplr:GetAttribute('Team') and not table.find(friends, name) then
			table.insert(friends, name)
			FrostySlime:Change(friends)
			HealSlime:Change(friends)
			StickySlime:Change(friends)
			VoidSlime:Change(friends)
		end
	end

	Notify = AutoNoelle:CreateToggle({Name = 'Notify on direct'})

	Limit = AutoNoelle:CreateToggle({Name = 'Limit to item'})

	FrostySlime = AutoNoelle:CreateDropdown({
		Name = 'Frosty Slime Target',
		List = {},
		Tooltip = 'Player to direct frost slimes to'
	})
	HealSlime = AutoNoelle:CreateDropdown({
		Name = 'Heal Slime Target',
		List = {},
		Tooltip = 'Player to direct heal slimes to'
	})
	StickySlime = AutoNoelle:CreateDropdown({
		Name = 'Sticky Slime Target',
		List = {},
		Tooltip = 'Player to direct sticky slimes to'
	})
	VoidSlime = AutoNoelle:CreateDropdown({
		Name = 'Void Slime Target',
		List = {},
		Tooltip = 'Player to direct void slimes to'
	})
	for _, v in playersService:GetPlayers() do
		addConnection(v)
	end
	vape:Clean(playersService.PlayerAdded:Connect(addConnection))
end)
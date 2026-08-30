run(function()
	local AutoFish
	local Show
	local Blacklist
	local Minigame
	local CompleteDelay = {}
	local Cast
	local CastDelay = {}

	local old, newMinigame
	local function getBait()
		for _, v in workspace:GetChildren() do
			if v.Name == 'fisherman_bobber' and v:GetAttribute('ProjectileShooter') == lplr.UserId then
				return v
			end
		end
		return nil
	end

	local function castRod()
		local item = bedwars.FishingRodController:getHandItem()
		if item and not bedwars.FishingRodController.projectileHandler and bedwars.FishingRodController:canLaunch() then
			bedwars.FishingRodController:beginHolding(item, nil, bedwars.FishingRodController.aimingMaid, false)
			task.wait()
			bedwars.FishingRodController:releaseChargeInput(bedwars.FishingRodController.aimingMaid, function()
				return true
			end, nil)
		end
	end

	AutoFish = vape.Categories.Inventory:CreateModule({
		Name = 'AutoFish',
		Function = function(call)
			if call then
				old = bedwars.FishingMinigameController.startMinigame
				bedwars.FishingMinigameController.startMinigame = function(...)
	                if Minigame.Enabled then
	                    task.wait(CompleteDelay:GetRandomValue())
	                    return select(3, ...)({win = true})
	                end
	                return (old or bedwars.FishingMinigameController.startMinigame)(...)
				end

				AutoFish:Clean(bedwars.Handler:Get('FishFound').Remote:Connect(function(data)
					local reroll = #Blacklist.ListEnabled > 0
					for _, v in data.dropData.drops do
						local amount = tonumber(v.amount) or 0
						if Show.Enabled then
							local itemDisplay = bedwars.ItemMeta[v.itemType] and bedwars.ItemMeta[v.itemType].displayName or v.itemType
							notif('AutoFish', `You can get {amount} {itemDisplay:lower()}{amount >= 2 and 's' or ''} on ur next fish`, 20, 'info')
						end
						if not table.find(Blacklist.ListEnabled, v.itemType) then
							reroll = false
						end
					end

					if reroll and entitylib.isAlive then
						lplr.Character.Humanoid.Jump = true
					end
				end))
				repeat
					if entitylib.isAlive and Cast.Enabled and (store.hand.tool and store.hand.tool.Name == 'fishing_rod') then
						local ray = cloneref(lplr:GetMouse()).UnitRay
						if not getBait() and not workspace:Raycast(entitylib.character.Head.Position + (ray.Direction * 6), Vector3.new(0, -20, 0)) then
							task.wait(CastDelay:GetRandomValue())
							if AutoFish.Enabled then
								castRod()
							end
							task.wait(0.1)
						end
					end
					task.wait(0.1)
				until not AutoFish.Enabled
			elseif old then
	            bedwars.FishingMinigameController.startMinigame = old
	            old = nil
			end
		end,
		Tooltip = 'Automatically fishes with fishing rod'
	})

	Blacklist = AutoFish:CreateTextList({
		Name = 'Blacklisted loot',
		Default = {'iron'},
		Tooltip = 'Jumps to cancel the catch when every item the fish drops is blacklisted'
	})
	Show = AutoFish:CreateToggle({
		Name = 'Show loot drops',
		Tooltip = 'Notifies ur next lootdrops'
	})
	Minigame = AutoFish:CreateToggle({
		Name = 'Auto Minigame',
		Function = function(callback)
			if CompleteDelay.Object then
				CompleteDelay.Object.Visible = callback
			end
		end,
	    Default = true,
	    Tooltip = 'Automatically completes the minigame'
	})
	CompleteDelay = AutoFish:CreateTwoSlider({
		Name = 'Complete delay',
		Min = 0,
		Max = 25,
		Decimal = 5,
		DefaultMin = 0.1,
		DefaultMax = 0.9,
		Darker = true
	})
	Cast = AutoFish:CreateToggle({
		Name = 'Auto Cast',
		Function = function(callback)
			if CastDelay.Object then
				CastDelay.Object.Visible = callback
			end
		end,
	    Tooltip = 'Automatically casts ur fishng rod'
	})
	CastDelay = AutoFish:CreateTwoSlider({
		Name = 'Cast delay',
		Min = 0,
		Max = 5,
		Decimal = 5,
		DefaultMin = 0.3,
		DefaultMax = 1.2,
		Darker = true,
		Visible = false
	})
end)
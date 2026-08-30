run(function()
    local BedAlarm
    local Range
    local Volume
    local Highlight

    local bedcache, cachedelay = nil, 0
    local function getBed()
        if bedcache and bedcache.Parent and cachedelay > tick() then
            return bedcache
        end

	if entitylib.isAlive then
		local id = lplr.Character:GetAttribute('Team')
		for i, v in collectionService:GetTagged('bed') do
			if tonumber(id) == tonumber(v:GetAttribute('TeamId')) then
                    bedcache, cachedelay = v, tick() + 10
				return v
			end
		end
	end

	return
    end

    BedAlarm = vape.Categories.Legit:CreateModule({
	Name = 'BedAlarm',
	Function = function(callback)
		if callback then
			local Notifytick = os.clock()
			local highlight = {}

			repeat
				local bed, localpos = getBed(), nil
				if bed then
					localpos = bed:GetPivot().Position
				end

				if localpos then
					local ent = localpos
						and entitylib.AllPosition({
							Origin = localpos,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
						})

					if ent and #ent > 0 and os.clock() > Notifytick then
						Notifytick = os.clock() + 3.05
						if Highlight.Enabled then
							for _, v in ent do
								if not highlight[v.Character] then
									highlight[v.Character] = true
									bedwars.BedAlarmController:addIntruderPlayerHighlight(v.Player)
								end
							end
						end
						bedwars.NotificationController:sendInfoNotification({
							message = '[Bed Alarm]: An intruder is near your bed!',
						})
						bedwars.SoundManager:playSound(bedwars.SoundList.BED_ALARM, {
							volumeMultiplier = Volume.Value,
						})
					end
				end
				task.wait(0.1)
			until not BedAlarm.Enabled
		end
	end,
	Tooltip = 'Notifies when there is an enemy near bed',
    })

    Highlight = BedAlarm:CreateToggle({
	Name = 'Highlight intruders',
	Tooltip = "Shows where the intruders are\n(just like BedWars' bed alarm)",
	Default = true,
    })
    Range = BedAlarm:CreateSlider({
	Name = 'Range',
	Min = 1,
	Max = 100,
	Default = 70,
	Suffix = function(val)
		return val <= 1 and 'stud' or 'studs'
	end,
    })
    Volume = BedAlarm:CreateSlider({
	Name = 'Volume multiplier',
	Min = 0.1,
	Max = 2,
	Default = 1.4,
	Decimal = 100,
    })
end)
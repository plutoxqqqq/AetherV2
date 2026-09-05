run(function()
	local AutoBuilder
	local Animation
	local Blacklist
	local BedCheck
	local Limit

	local function getBed(pos)
		local bed, lastmag = nil, math.huge
		for _, v in collectionService:GetTagged('bed') do
			local mag = (pos - v.Position).Magnitude
			if mag < lastmag and v:GetAttribute(`Team{lplr:GetAttribute('Team') or -1}NoBreak`) then
				bed, lastmag = v, mag
			end
		end
		return bed
	end

	AutoBuilder = kits:CreateModule({
		Name = 'AutoBuilder',
		Function = function(callback)
			if callback then
				repeat
					task.wait()
				until store.matchState ~= 0 and store.equippedKit == 'builder' or not AutoBuilder.Enabled
				if not AutoBuilder.Enabled then
					return
				end

				local blocks = collection('block', AutoBuilder, function(tab, obj)
					task.delay(0, function()
						if not obj:GetAttribute('NoBreak') and obj:GetAttribute('PlacedByUserId') then
							table.insert(tab, obj)
						end
					end)
				end)

				repeat
					if entitylib.isAlive and (not Limit.Enabled and getItem('hammer') or Limit.Enabled and store.hand.tool and store.hand.tool.Name == 'hammer') then
						local bed = getBed(entitylib.character.RootPart.Position)

						for _, v in blocks do
							if not BedCheck.Enabled or bed and (bed.Position - v.Position).Magnitude <= 30 then
								local name = v.Name:find('wool_') and 'wool' or v.Name
								if not table.find(Blacklist.ListEnabled, name) and not v:FindFirstChild('BuilderFortify') then
									bedwars.Handler:Get('FortifyBlock'):Fire('SendToServer', ({getPlacedBlock(v.Position)})[2])

									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr, bedwars.GameAnimationUtil:getAssetId(bedwars.AnimationType.BUILDER_HAMMER_HIT), {
											fadeInTime = 0.02
										})
										bedwars.AudioManager:playAudio(bedwars.SoundList.FORTIFY_BLOCK, {
											position = entitylib.character.RootPart.Position
										})
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoBuilder.Enabled
			end
		end,
		Tooltip = 'Automatically fortifies your blocks with the builder hammer'
	})
	BedCheck = AutoBuilder:CreateToggle({
		Name = 'Bed Check',
		Tooltip = 'Checks if the block is near your bed'
	})
	Animation = AutoBuilder:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays builder visuals (sfx and anim)'
	})
	Limit = AutoBuilder:CreateToggle({
		Name = 'Limit to items',
		Default = true
	})
	Blacklist = AutoBuilder:CreateTextList({
		Name = 'Blacklists',
		Placeholder = 'block',
		Default = {'cannon', 'wool'}
	})
end)
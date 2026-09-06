run(function()
	local AutoZola
	local Mode
	local Range
	local links = {}
	local nextLink = 0

	local function isLinked(char)
		local expiry = links[char]
		if expiry and expiry > tick() then
			return true
		end
		links[char] = nil
		return false
	end

	local function countLinks()
		local count = 0
		for char in links do
			if isLinked(char) then
				count += 1
			end
		end
		return count
	end

	local function attemptLink(char)
		if not char or tick() < nextLink or isLinked(char) then return end
		if countLinks() >= bedwars.SoulBrokerConstants.MAX_SOUL_LINKS then return end

		links[char] = tick() + 1
		nextLink = tick() + 1
		bedwars.Handler:Get('AttemptSoulLink'):Fire('CallServerAsync', char)
	end

	AutoZola = kits:CreateModule({
		Name = 'AutoZola',
		Function = function(callback)
			if callback then
				AutoZola:Clean(bedwars.Handler:Get('SoulLinkFormed').Remote:Connect(function(linkTable)
					if linkTable.broker == lplr and not linkTable.guard then
						links[linkTable.target] = tick() + bedwars.SoulBrokerConstants.SOUL_LINK_DURATION
					end
				end))

				AutoZola:Clean(bedwars.Handler:Get('SoulLinkRemoved').Remote:Connect(function(linkTable)
					if linkTable.broker == lplr and not linkTable.guard then
						links[linkTable.target] = nil
					end
				end))

				AutoZola:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if Mode.Value ~= 'On Hit' or damageTable.fromEntity ~= lplr.Character then return end
					if not entitylib.isAlive or store.equippedKit ~= 'soul_broker' then return end

					local target = entitylib.getEntity(damageTable.entityInstance)
					if target and target.Player and target.Targetable and (entitylib.character.RootPart.Position - target.RootPart.Position).Magnitude <= Range.Value then
						attemptLink(target.Character)
					end
				end))

				repeat
					if Mode.Value == 'On See' and tick() >= nextLink and entitylib.isAlive and store.equippedKit == 'soul_broker' then
						for _, target in entitylib.AllPosition({
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						}) do
							if not isLinked(target.Character) then
								attemptLink(target.Character)
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoZola.Enabled
			end
		end,
		Tooltip = 'Automatically soul links enemies'
	})
	Mode = AutoZola:CreateDropdown({
		Name = 'Mode',
		List = {'On See', 'On Hit'},
		Tooltip = 'On See - Links enemies as soon as you can see them\nOn Hit - Links enemies whenever you hit them',
		Default = 'On See'
	})
	Range = AutoZola:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 50,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
end)

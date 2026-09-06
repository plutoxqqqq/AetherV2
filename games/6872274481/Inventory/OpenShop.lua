run(function()
	local runtime = shared.AetherShopRuntime

	local OpenShop
	OpenShop = vape.Categories.Inventory:CreateModule({
		Name = 'OpenShop',
		Function = function(callback)
			runtime.activateShop(runtime.nearestItemShop())

			task.defer(function()
				OpenShop:Toggle()
			end)
		end,
		Tooltip = 'Opens the nearest item shop'
	})
end)

run(function()
	local AutoAdetunde
	local GUI

	AutoAdetunde = kits:CreateModule({
		Name = 'AutoAdetunde',
		Function = function(callback)
			if callback then
				repeat
					if not GUI.Enabled or bedwars.AppController:isAppOpen('FrostyHammerApp') then
						for i, v in bedwars.AdetundeUtil.getUpgradesFromHammer(lplr) do
							local crystal = getItem('frost_crystal')
							if not crystal then
								break
							end

							local nextUpgrade = AutoAdetunde.Options[`Buy {i}`].Enabled and bedwars.AdetundeUpgradeMeta[i].tiers[v + 1]
							if nextUpgrade and crystal.amount >= nextUpgrade.price then
								bedwars.Handler:Get('UpgradeFrostyHammer'):Fire('CallServer', i)
								task.wait(0.1)
							end
						end
					end
					task.wait(0.5)
				until not AutoAdetunde.Enabled
			end
		end,
		Tooltip = 'Automatically upgrades ur frosty hammer'
	})
	for i in bedwars.AdetundeUpgradeMeta do
		AutoAdetunde:CreateToggle({
			Name = `Buy {i}`,
			Default = true
		})
	end

	GUI = AutoAdetunde:CreateToggle({
		Name = 'GUI Check',
		Tooltip = 'Only upgrades while the frosty hammer menu is open'
	})
end)

run(function()
	local AutoAgni
	local Targets, Range, OnlySwinging, Clutch
	local swingMarker, swingSeenAt = nil, -math.huge
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.RespectCanCollide = true

	local function updateSwing()
		local value = bedwars.SwordController and bedwars.SwordController.lastSwing or 0
		if value ~= swingMarker then
			swingMarker, swingSeenAt = value, os.clock()
		end
	end

	local function voidFall(root)
		if not root or root.AssemblyLinearVelocity.Y >= -2 then return false end
		ray.FilterDescendantsInstances = lplr.Character and {lplr.Character} or {}
		return workspace:Raycast(root.Position, Vector3.new(0, -80, 0), ray) == nil
	end

	local function activate()
		local ok, ready = pcall(bedwars.AbilityController.canUseAbility, bedwars.AbilityController, 'rocket_detonate', {disableBlockedAbilityAlert = true})
		if not ok or not ready then return false end
		local used, result = pcall(bedwars.AbilityController.useAbility, bedwars.AbilityController, 'rocket_detonate')
		return used and result ~= false
	end

	AutoAgni = kits:CreateModule({
		Name = 'AutoAgni',
		Category = 'Auto',
		Function = function(callback)
			if not callback then return end
			swingMarker, swingSeenAt = bedwars.SwordController and bedwars.SwordController.lastSwing or 0, -math.huge
			local nextUse = 0
			repeat
				if entitylib.isAlive and store.equippedKit == 'agni' then
					local root = entitylib.character.RootPart
					updateSwing()
					if Clutch.Enabled and voidFall(root) then
						if os.clock() >= nextUse and activate() then nextUse = os.clock() + 0.35 end
						local land = getNearGround(30)
						local humanoid = entitylib.character.Humanoid
						if land and humanoid then
							local delta = Vector3.new(land.X - root.Position.X, 0, land.Z - root.Position.Z)
							if delta.Magnitude > 0.05 then humanoid:Move(delta.Unit, false) end
						end
					elseif not OnlySwinging.Enabled or os.clock() - swingSeenAt <= 0.3 then
						local target = entitylib.EntityPosition({
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled or nil,
							Sort = sortmethods.Distance
						})
						if target and os.clock() >= nextUse and activate() then nextUse = os.clock() + 0.35 end
					end
				end
				task.wait(0.03)
			until not AutoAgni.Enabled
		end,
		Tooltip = 'Automatically uses Agni rocket boost around selected targets; Clutch saves void falls'
	})
	Targets = AutoAgni:CreateTargets({Players = true, NPCs = true, Walls = true})
	Range = AutoAgni:CreateSlider({Name = 'Range', Min = 1, Max = 40, Default = 12, Suffix = ' studs'})
	OnlySwinging = AutoAgni:CreateToggle({Name = 'Only while swinging'})
	Clutch = AutoAgni:CreateToggle({Name = 'Clutch', Default = true, Tooltip = 'Uses Agni while falling into the void and walks toward nearby land'})
end)

run(function()
	local AutoBee
	local Collect
	local CollectRange
	local CollectDelay
	local LimitCollect
	local Deposit
	local DepositRange
	local DepositDelay

	AutoBee = kits:CreateModule({
		Name = 'AutoBeekeeper',
		Function = function(callback)
			if callback then
				local hives = collection('beehive', AutoBee)

				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position

						if Collect.Enabled and (not LimitCollect.Enabled or store.hand.tool and store.hand.tool.Name == 'bee_net') then
							for _, v in collectionService:GetTagged('bee') do
								if v.PrimaryPart and (localPosition - v.PrimaryPart.Position).Magnitude <= CollectRange.Value then
									bedwars.Handler:Get('PickUpBee'):Fire('SendToServer', {
										beeId = v:GetAttribute('BeeId')
									})

									if CollectDelay.Value > 0 then
										task.wait(CollectDelay.Value)
									end
								end
							end
						end

						if Deposit.Enabled and getItem('bee') then
							for _, v in hives do
								if not getItem('bee') then
									break
								end

								local prompt = v:FindFirstChildWhichIsA('ProximityPrompt')
								if prompt and (v:GetAttribute('Level') or 0) < 10 and v:GetAttribute('PlacedByUserId') == lplr.UserId and (localPosition - v.Position).Magnitude <= DepositRange.Value then
									task.spawn(fireproximityprompt, prompt)

									if DepositDelay.Value > 0 then
										task.wait(DepositDelay.Value)
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoBee.Enabled
			end
		end,
		Tooltip = 'Automatically deposit bees, and collects nearby bees'
	})
	Collect = AutoBee:CreateToggle({
		Name = 'Collect bees',
		Default = true,
		Function = function(call)
			if CollectRange then
				CollectRange.Object.Visible = call
				CollectDelay.Object.Visible = call
				LimitCollect.Object.Visible = call
			end
		end
	})
	CollectRange = AutoBee:CreateSlider({
		Name = 'Collect Range',
		Min = 1,
		Max = 22,
		Default = 20,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	CollectDelay = AutoBee:CreateSlider({
		Name = 'Collect delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Darker = true
	})
	LimitCollect = AutoBee:CreateToggle({
		Name = 'Limit to item',
		Darker = true
	})
	Deposit = AutoBee:CreateToggle({
		Name = 'Deposit bees',
		Function = function(call)
			if DepositRange then
				DepositRange.Object.Visible = call
				DepositDelay.Object.Visible = call
			end
		end,
		Tooltip = 'Automatically puts the bees into a beehive'
	})
	DepositRange = AutoBee:CreateSlider({
		Name = 'Deposit Range',
		Min = 1,
		Max = 14,
		Default = 14,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	DepositDelay = AutoBee:CreateSlider({
		Name = 'Deposit Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Darker = true,
		Visible = false
	})
end)

run(function()
	local AutoBountyHunter
	local Track
	local Reroll
	local RerollRange
	local Delay

	local trackCooldown, rerollCooldown = 0, 0
	local trackAbilities = {'bounty_hunter_4', 'bounty_hunter_3', 'bounty_hunter_2', 'bounty_hunter_1'}

	local function getTarget()
		local kit = bedwars.Store:getState().Kit
		return kit and kit.bountyHunterTarget
	end

	local function getTrackAbility()
		local enabled = bedwars.AbilityController.enabledAbilities
		for _, ability in trackAbilities do
			if enabled and enabled[ability] then
				return ability
			end
		end

		local level = bedwars.BountyHunterUtil and bedwars.BountyHunterUtil.getBountyHunterLevel(lplr) or 0
		return 'bounty_hunter_'..math.clamp(level + 1, 1, 4)
	end

	local function useAbility(ability)
		if not bedwars.AbilityController:canUseAbility(ability, {disableBlockedAbilityAlert = true}) then
			return false
		end
		bedwars.AbilityController:useAbility(ability)
		return true
	end

	AutoBountyHunter = kits:CreateModule({
		Name = 'AutoBountyHunter',
		Function = function(callback)
			if callback then
				trackCooldown, rerollCooldown = 0, 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'bounty_hunter' then
						local target = getTarget()
						local ent = target and entitylib.getEntity(target)

						if Track.Enabled and target and tick() >= trackCooldown and useAbility(getTrackAbility()) then
							trackCooldown = tick() + Delay.Value
						end

						if Reroll.Enabled and tick() >= rerollCooldown then
							local distance = ent and ent.RootPart and (ent.RootPart.Position - entitylib.character.RootPart.Position).Magnitude or math.huge
							if distance > RerollRange.Value and useAbility('bounty_hunter_reroll') then
								rerollCooldown = tick() + 1
							end
						end
					end
					task.wait(0.1)
				until not AutoBountyHunter.Enabled
			end
		end,
		Tooltip = 'Keeps the bounty tracker up on your target and rerolls bounties you cannot reach'
	})
	Track = AutoBountyHunter:CreateToggle({
		Name = 'Auto track',
		Default = true,
		Tooltip = 'Uses the tracking ability whenever it comes off cooldown, the marker lasts 15 seconds'
	})
	Delay = AutoBountyHunter:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Suffix = 'seconds'
	})
	Reroll = AutoBountyHunter:CreateToggle({
		Name = 'Auto reroll',
		Tooltip = 'Rerolls the bounty when your target is dead, gone or further away than the range below'
	})
	RerollRange = AutoBountyHunter:CreateSlider({
		Name = 'Reroll range',
		Min = 10,
		Max = 500,
		Default = 250,
		Darker = true,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})

end)

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

run(function()
	local AutoCaitlyn
	local Mode
	local Range
	local MinHP
	local TargetPriorities
	local activeSession

	local function getEntity(value)
		return typeof(value) == 'Instance' and entitylib.getEntity(value) or nil
	end

	local function getContract(contracts, ent)
		for _, v in contracts do
			if v.target == ent.Player or v.target and v.target.Name == ent.Player.Name then
				return v
			end
		end
		return nil
	end

	local function getValidTargets(wallcheck)
		local targets = {}
		for _, ent in entitylib.AllPosition({
			Part = 'RootPart',
			Players = true,
			Range = Range.Value,
			Wallcheck = wallcheck
		}) do
			if not (ent.Player.Team and ent.Player.Team.Name == 'Spectators') then
				targets[ent.Player] = ent
				targets[ent.Character] = ent
			end
		end
		return targets
	end

	local function hasBed(session, plr)
		local suc, team = pcall(bedwars.TeamController.getPlayerTeam, bedwars.TeamController, plr)
		local teamId = suc and team and team.id or plr:GetAttribute('Team')
		if teamId == nil then
			return true
		end

		local cached = session.beds[teamId]
		if cached and cached[2] > tick() then
			return cached[1]
		end

		suc, team = pcall(bedwars.BedwarsController.getTeamBed, bedwars.BedwarsController, teamId)
		local result = not suc or team and team.Parent
		session.beds[teamId] = {result, tick() + 1}
		return result
	end

	local function getScore(session, contract, targets)
		local ent = targets[contract.target]
		if not ent then
			return nil
		end

		local health = ent.Humanoid.Health
		local distance = (entitylib.character.RootPart.Position - ent.RootPart.Position).Magnitude
		local score = 30 + ((tonumber(contract.rewardValue) or 0) * 35)
		score += (1 - math.clamp(health / math.max(ent.Humanoid.MaxHealth, 1), 0, 1)) * 35
		score += math.max(1 - (distance / Range.Value), 0) * 20

		if health <= MinHP.Value then
			score += 20
		end
		if (session.threats[ent.Player] or 0) > tick() then
			score += 30
		end
		if ent.Character:GetAttribute('BleedSource') == lplr.UserId then
			score += 25
		end
		if not hasBed(session, ent.Player) then
			score += 20
		end

		local reward = contract.rewardExplanation
		if type(reward) == 'table' then
			score += (reward.assassin and 10 or 0) + (reward.kitClass and 8 or 0) + (reward.gear and 6 or 0)
		end
		return score, ent
	end

	local function getPriorityContract(session, contracts)
		local bounty = false
		for _, v in contracts do
			if v.rewardValue or v.rewardUpgrade then
				bounty = true
				break
			end
		end
		if not bounty then
			return nil, false
		end

		local targets = getValidTargets(true)
		local current, currentScore
		if session.priorityId then
			for _, v in contracts do
				if v.id == session.priorityId then
					current, currentScore = v, getScore(session, v, targets)
					break
				end
			end
		end

		local best, bestScore
		for _, v in contracts do
			local score = getScore(session, v, targets)
			if score and (not bestScore or score > bestScore) then
				best, bestScore = v, score
			end
		end

		if current and currentScore and best ~= current and bestScore < currentScore + 15 then
			best = current
		end

		session.priorityId = best and best.id or nil
		return best, true
	end

	local function getNormalContract(session, contracts)
		local hit = session.lastHit
		if hit and hit[2] > tick() then
			local ent = getValidTargets(false)[hit[1].Player]
			if ent == hit[1] then
				if Mode.Value == 'On Low' and ent.Humanoid.Health >= MinHP.Value then
					return nil
				end
				return getContract(contracts, ent)
			end
		end

		session.lastHit = nil
		return nil
	end

	local function selectContract(session, contract)
		if contract and not (session.pendingId == contract.id and session.pendingUntil > tick()) then
			bedwars.Handler:Get('BloodAssassinSelectContract'):Fire('SendToServer', {
				contractId = contract.id
			})
			session.pendingId = contract.id
			session.pendingUntil = tick() + 1
		end
	end

	local function updateCaitlyn(session)
		if not entitylib.isAlive or store.matchState ~= 1 or store.equippedKit ~= 'blood_assassin' then
			session.lastHit = nil
			session.pendingId = nil
			session.priorityId = nil
			return
		end

		local kit = bedwars.Store:getState().Kit
		if not kit or kit.activeContract then
			session.pendingId = nil
			session.priorityId = kit and kit.activeContract and kit.activeContract.id or nil
			return
		end

		if session.pendingId and session.pendingUntil > tick() then
			return
		end
		session.pendingId = nil

		local contracts = kit.availableContracts
		if not contracts or #contracts == 0 then
			return
		end

		local contract
		if TargetPriorities.Enabled then
			local available
			contract, available = getPriorityContract(session, contracts)
			if not available then
				contract = getNormalContract(session, contracts)
			end
		else
			session.priorityId = nil
			contract = getNormalContract(session, contracts)
		end
		selectContract(session, contract)
	end

	AutoCaitlyn = kits:CreateModule({
		Name = 'AutoCaitlyn',
		Function = function(callback)
			if callback then
				local session = {
					beds = {},
					nextUpdate = 0,
					pendingUntil = 0,
					threats = {}
				}
				activeSession = session

				AutoCaitlyn:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if activeSession ~= session then
						return
					end

					local source = getEntity(damageTable.fromEntity)
					if damageTable.entityInstance == lplr.Character and source and source.Player then
						session.threats[source.Player] = tick() + 3
					elseif damageTable.fromEntity == lplr.Character or damageTable.fromEntity == lplr then
						local victim = getEntity(damageTable.entityInstance)
						if victim then
							session.lastHit = {victim, tick() + 1}
						end
					end
				end))

				AutoCaitlyn:Clean(vapeEvents.BedwarsBedBreak.Event:Connect(function()
					table.clear(session.beds)
				end))

				AutoCaitlyn:Clean(entitylib.Events.LocalAdded:Connect(function()
					session.lastHit = nil
					session.pendingId = nil
				end))

				AutoCaitlyn:Clean(entitylib.Events.LocalRemoved:Connect(function()
					session.lastHit = nil
					session.pendingId = nil
					session.priorityId = nil
				end))

				repeat
					if tick() >= session.nextUpdate then
						session.nextUpdate = tick() + 0.2
						updateCaitlyn(session)
					end
					task.wait(0.05)
				until not AutoCaitlyn.Enabled or activeSession ~= session

				if activeSession == session then
					activeSession = nil
				end
			else
				activeSession = nil
			end
		end,
		Tooltip = 'Automatically assigns a player\'s contract when a specific action happens'
	})
	Mode = AutoCaitlyn:CreateDropdown({
		Name = 'Contract mode',
		List = {'On Hit', 'On Low'},
		Tooltip = 'On Hit - Contracts them whenever u start hitting them\nOn Low - When they\'re low',
		Function = function(val)
			if MinHP then
				MinHP.Object.Visible = val == 'On Low'
			end
		end,
		Default = 'On Low'
	})
	MinHP = AutoCaitlyn:CreateSlider({
		Name = 'Minimum Health',
		Tooltip = 'How low they have to be before contracting',
		Min = 1,
		Max = 100,
		Default = 30,
		Darker = true,
		Visible = false
	})
	Range = AutoCaitlyn:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 50,
		Default = 50,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	TargetPriorities = AutoCaitlyn:CreateToggle({
		Name = 'Target Priorities',
		Function = function()
			if activeSession then
				activeSession.priorityId = nil
			end
		end
	})
end)

run(function()
	local AutoCard
	local Range
	local Delay
	local nextThrow = 0

	AutoCard = kits:CreateModule({
		Name = 'AutoCard',
		Function = function(callback)
			if callback then
				nextThrow = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'card' and tick() >= nextThrow and bedwars.AbilityController:canUseAbility('CARD_THROW', {disableBlockedAbilityAlert = true}) then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						})

						if target then
							nextThrow = tick() + Delay.Value
							bedwars.AbilityController:useAbility('CARD_THROW')
						end
					end
					task.wait(0.1)
				until not AutoCard.Enabled
			end
		end,
		Tooltip = 'Automatically throws Fortuna cards at whoever is near you'
	})
	Range = AutoCard:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 100,
		Default = 60,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoCard:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.4,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)

run(function()
	local AutoCrocowolf
	local Range
	local Targets

	AutoCrocowolf = kits:CreateModule({
		Name = 'AutoCrocowolf',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'beast' and bedwars.AbilityController:canUseAbility('beast_form', {disableBlockedAbilityAlert = true}) then
						local origin = entitylib.character.RootPart.Position
						local found = 0
						for _, v in entitylib.List do
							if v.Targetable and (v.RootPart.Position - origin).Magnitude <= Range.Value then
								found += 1
							end
						end

						if found >= Targets.Value then
							bedwars.AbilityController:useAbility('beast_form')
						end
					end
					task.wait(0.1)
				until not AutoCrocowolf.Enabled
			end
		end,
		Tooltip = 'Automatically goes into beast form once enough enemies are around you'
	})
	Range = AutoCrocowolf:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Targets = AutoCrocowolf:CreateSlider({
		Name = 'Targets',
		Min = 1,
		Max = 8,
		Default = 1,
		Tooltip = 'Enemies in range before transforming'
	})
end)

run(function()
	local AutoCyber
	local Mode
	local Whitelist
	local Visual
	local Steal
	local Target
	local Limit

	local teamCache, cacheExpire = nil, 0
	local function getTeamGenerator()
		if cacheExpire > tick() and teamCache and teamCache.Parent then
			return teamCache
		end
		teamCache, cacheExpire = collectionService:GetTagged(lplr:GetAttribute('Team').. '_TeamOreGenerator')[1], tick() + 5
		return teamCache
	end
	local cache = nil
	local function getDrone()
		if Limit.Enabled and (not store.hand.tool or store.hand.tool.Name ~= 'drone') then
			return nil
		end
		if cache and cache.Parent then
			return cache
		end
		for _, v in collectionService:GetTagged('Drone') do
			if v:GetAttribute('PlayerUserId') == lplr.UserId then
				local Changed = function()
					if v:GetAttribute('HeldItem') then
						repeat
							bedwars.Handler:Get('DropDroneItem'):Fire('SendToServer', {
								direction = Vector3.new(1000, 10, 0),
								position = v.PrimaryPart.Position
							})
							task.wait(0.1)
						until not v:GetAttribute('HeldItem') or not AutoCyber.Enabled
					end
				end
				AutoCyber:Clean(v:GetAttributeChangedSignal('HeldItem'):Connect(Changed))
				AutoCyber:Clean(v:GetAttributeChangedSignal('HeldItemAmount'):Connect(Changed))
				cache = v
				return v
			end
		end
		if getItem('drone') and bedwars.Handler:Get('FireGuidedProjectile'):Fire('CallServer', 'drone') then
			task.wait(0.1)
			return getDrone()
		end
		return nil
	end
	local function getGenerator(drone, item)
		local children = collectionService:GetTagged(item.. '_OreGenerator')
		local pos = drone.PrimaryPart.Position
		table.sort(children, function(a, b)
			return (pos - a.PrimaryPart.Position).Magnitude < (pos - b.PrimaryPart.Position).Magnitude
		end)
		return children[1] and children[1].PrimaryPart or nil
	end
	local blacklist = {}
	local function getItemDrop(drone)
		local generator = getTeamGenerator()
		generator = generator and generator.PrimaryPart.Position or Vector3.zero
		local children = workspace.ItemDrops:GetChildren()
		local pos = drone.PrimaryPart.Position
		table.sort(children, function(a, b)
			return (pos - a.Position).Magnitude < (pos - b.Position).Magnitude
		end)
		for _, v in children do
			if tick() > (blacklist[v] or 0) and table.find(Whitelist.ListEnabled, v.Name) and v.Position.Y > 0 and math.abs(v.Velocity.Y) <= 0 and (not Steal.Enabled or (v.Position - generator).Magnitude > 20) and (not Target.Enabled or not entitylib.EntityPosition({
				Origin = pos,
				Range = 60,
				Part = 'RootPart',
				Players = true
			})) then
				return v
			end
		end
		return nil
	end
	AutoCyber = kits:CreateModule({
		Name = 'AutoCyber',
		Function = function(callback)
			if callback then
				AutoCyber:Clean(workspace.ItemDrops.ChildAdded:Connect(function(v)
					task.wait()
					if v.Velocity.X > 100 then
						blacklist[v] = tick() + 5
						local Amount = v:GetAttribute('Amount')
						local LastParent = v.Parent
						if Mode.Value == 'Player' then
							notif('AutoCyber', 'Collecting '.. tostring(Amount).. ' '.. v.Name, 4, 'info')
							repeat
								v.Velocity = Vector3.zero
								v.CFrame = entitylib.character.RootPart.CFrame - Vector3.new(0, 4, 0)
								task.spawn(function()
									bedwars.Handler:Get('PickupItemDrop'):Fire('CallServerAsync', {
										itemDrop = v
									}):andThen(function(suc)
										if suc and bedwars.SoundList then
											bedwars.AudioManager:playAudio(bedwars.SoundList.PICKUP_ITEM_DROP)
											local sound = bedwars.ItemMeta[v.Name].pickUpOverlaySound
											if sound then
												bedwars.AudioManager:playAudio(sound, {
													position = v.Position,
													volumeMultiplier = 0.9
												})
											end
										end
									end)
								end)
								task.wait(0.02)
							until not v or v.Parent ~= LastParent

							notif('AutoCyber', `Collected {Amount} {v.Name}{Amount > 1 and 's' or ''}`, 4, 'info')
						else
							local start = tick()
							local generator = getTeamGenerator()
							if generator then
								repeat
									v.Velocity = Vector3.zero
									v.CFrame = generator.PrimaryPart.CFrame
									task.wait()
								until (tick() - start) >= 1 or not v or v.Parent ~= LastParent
								notif('AutoCyber', 'Dropped '.. tostring(Amount).. ' '.. v.Name, 8, 'info')
							else
								notif('AutoCyber', 'Generator not found', 20, 'alert')
							end
						end
					end
				end))

				repeat
					local drone = getDrone()
					if drone then
						local v = getItemDrop(drone)
						if v then
							task.wait(0.3)
							local highlight
							if Visual.Enabled then
								highlight = Instance.new('Highlight')
								highlight.FillColor = Color3.new(1, 1, 1)
								highlight.FillTransparency = 0
								highlight.OutlineTransparency = 0.5
								highlight.OutlineColor = Color3.new()
							end
							drone.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
							drone.PrimaryPart.CFrame = CFrame.new(drone.PrimaryPart.CFrame.X, 10000, drone.PrimaryPart.CFrame.Z)
							local magnitude, lastmag = 0, 9e9
							local pos = v.Position
							repeat
								if drone and drone.Parent then
									pos = v.Position
									local multi = drone:GetAttribute('SpeedBoost')
									multi = multi == 0 or multi == '' or not multi and true or false
									drone.PrimaryPart.CanCollide = false
									drone.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
									drone.PrimaryPart.AssemblyLinearVelocity = CFrame.lookAt(drone.PrimaryPart.Position * Vector3.new(1, 0, 1), pos * Vector3.new(1, 0, 1)).LookVector * 30
									magnitude = ((drone.PrimaryPart.Position * Vector3.new(1, 0, 1)) - (pos * Vector3.new(1, 0, 1))).Magnitude
									if (lastmag - magnitude) >= 25 then
										lastmag = magnitude
										notif('AutoCyber', `Drone is {math.floor(magnitude)} studs away from {v.Name}.`, 1, 'info')
									end
								else
									break
								end
								task.wait()
							until not v or v.Parent ~= workspace.ItemDrops or not AutoCyber.Enabled or magnitude <= 2
							if not AutoCyber.Enabled then
								if highlight and highlight.Parent then
									highlight:Destroy()
								end
								break
							end

							if magnitude <= 5 then
								local start = tick()
								if Visual.Enabled then
									notif('AutoCyber', 'Attempting to collect '.. v.Name, 4, 'info')
								end
								repeat
									if drone and drone.Parent then
										drone.PrimaryPart.AssemblyLinearVelocity = Vector3.zero
										drone.PrimaryPart.AssemblyAngularVelocity = Vector3.new(0, -30, 0)
										drone.PrimaryPart.CFrame = CFrame.new(pos - Vector3.new(0, drone.Hitbox.Size.Y, 0))
									end
									task.wait(0.02)
								until (tick() - start) >= 1.25
							elseif Visual.Enabled then
								notif('AutoCyber', `Too far away to collect {v.Name} ({magnitude} studs).`, 8, 'info')
							end
							if highlight and highlight.Parent then
								highlight:Destroy()
							end
						else
							drone.PrimaryPart.CFrame = CFrame.new(drone.PrimaryPart.CFrame.X, 10000, drone.PrimaryPart.CFrame.Z)
							drone.PrimaryPart.Velocity = Vector3.zero
							for _, v2 in Whitelist.ListEnabled do
								local gen = getGenerator(drone, v2)
								if gen then
									local magnitude = 0
									repeat
										if drone and drone.Parent then
											if getItemDrop(drone) then break end
											drone.PrimaryPart.CanCollide = false
											drone.PrimaryPart.AssemblyAngularVelocity = Vector3.zero
											drone.PrimaryPart.AssemblyLinearVelocity = CFrame.lookAt(drone.PrimaryPart.Position * Vector3.new(1, 0, 1), gen.Position * Vector3.new(1, 0, 1)).LookVector * 30
											magnitude = ((drone.PrimaryPart.Position * Vector3.new(1, 0, 1)) - (gen.Position * Vector3.new(1, 0, 1))).Magnitude
										else
											break
										end
										task.wait()
									until not v or v.Parent ~= workspace.ItemDrops or not AutoCyber.Enabled or magnitude <= 5
								end
							end
						end
					end
					task.wait()
				until not AutoCyber.Enabled
			else
				local drone = getDrone()
				if drone then
					drone.PrimaryPart.CFrame = CFrame.new(drone.PrimaryPart.CFrame.X, 500, drone.PrimaryPart.CFrame.Z)
				end
			end
		end,
		Tooltip = 'Allows you to steal other\'s opponent resources via drone.'
	})
	Mode = AutoCyber:CreateDropdown({
		Name = 'Drop mode',
		List = {'Player', 'Generator'},
		Default = 'Player',
		Tooltip = 'Where cyber items gets dropped to.'
	})
	Whitelist = AutoCyber:CreateTextList({
		Name = 'Whitelist',
		Default = {'emerald', 'diamond'}
	})
	Visual = AutoCyber:CreateToggle({
		Name = 'Visualize',
		Default = true,
		Tooltip = 'Shows what item the drone is targeting and updates\non where how far the drone is to the item.'
	})
	Steal = AutoCyber:CreateToggle({
		Name = 'Steal split',
		Default = true,
		Tooltip = 'Steals other opponent team\'s generator split.'
	})
	Target = AutoCyber:CreateToggle({Name = 'Target check'})
	Limit = AutoCyber:CreateToggle({Name = 'Limit to item'})
end)

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

run(function()
	local AutoDragonSword
	local Range
	local Targets

	AutoDragonSword = kits:CreateModule({
		Name = 'AutoDragonSword',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'dragon_sword' and bedwars.AbilityController:canUseAbility('dragon_sword_ult', {disableBlockedAbilityAlert = true}) then
						local origin = entitylib.character.RootPart.Position
						local found = 0
						for _, v in entitylib.List do
							if v.Targetable and (v.RootPart.Position - origin).Magnitude <= Range.Value then
								found += 1
							end
						end

						if found >= Targets.Value then
							bedwars.AbilityController:useAbility('dragon_sword_ult')
						end
					end
					task.wait(0.1)
				until not AutoDragonSword.Enabled
			end
		end,
		Tooltip = 'Automatically uses Lian ultimate once enough enemies are around you'
	})
	Range = AutoDragonSword:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Targets = AutoDragonSword:CreateSlider({
		Name = 'Targets',
		Min = 1,
		Max = 8,
		Default = 1,
		Tooltip = 'Enemies in range before using the ultimate'
	})
end)

run(function()
	local AutoDrill
	local AutoCollect
	local Notify
	local AutoAttack
	local Legit
	local Range
	local AttackDelay
	local CollectDelay
	local Targets
	local Sort
	local currentDrill
	local attackDebounce = {}
	local collectDebounce = {}

	local function getDrillPart(drill)
		return drill and (drill.PrimaryPart or drill:FindFirstChild('RootPart') or drill:FindFirstChildWhichIsA('BasePart'))
	end

	local function addDrill(drills, added, drill)
		if typeof(drill) ~= 'Instance' or added[drill] or drill:GetAttribute('PlacedByUserId') ~= lplr.UserId then
			return
		end
		if getDrillPart(drill) then
			added[drill] = true
			table.insert(drills, drill)
		end
	end

	local function getDrills(tagged)
		local drills, added = {}, {}
		for _, drill in tagged do
			addDrill(drills, added, drill)
		end

		for _, drill in (bedwars.DrillTabletController and bedwars.DrillTabletController.drillList or {}) do
			addDrill(drills, added, drill)
		end

		return drills
	end

	local function useDrill(drill)
		if currentDrill == drill then
			return true
		end

		if bedwars.Handler:Get('PlayerUseDrillController'):Fire('CallServer', {drill = drill}) ~= false then
			currentDrill = drill
			return true
		end
		return false
	end

	local function updateAttackControls()
		if Legit then
			local enabled = AutoAttack.Enabled
			Legit.Object.Visible = enabled
			Range.Object.Visible = enabled and not Legit.Enabled
			AttackDelay.Object.Visible = enabled
			Targets.Object.Visible = enabled
			Sort.Object.Visible = enabled
		end
	end

	AutoDrill = kits:CreateModule({
		Name = 'AutoDrill',
		Function = function(callback)
			if callback then
				local tagged = collection('Drill', AutoDrill)
				repeat
					task.wait()
				until store.matchState ~= 0 and store.equippedKit == 'drill' or not AutoDrill.Enabled

				repeat
					if entitylib.isAlive and store.equippedKit == 'drill' then
						local now = tick()
						for _, drill in getDrills(tagged) do
							local part = getDrillPart(drill)
							if not part then
								continue
							end

							if AutoCollect.Enabled and ((drill:GetAttribute('diamond') or 0) + (drill:GetAttribute('emerald') or 0)) > 0 and now > (collectDebounce[drill] or 0) then
								bedwars.Handler:Get('ExtractFromDrill'):Fire('SendToServer', {drill = drill})
								collectDebounce[drill] = now + CollectDelay.Value

								if Notify.Enabled then
									notif('Auto Drill', 'Collected drill resources', 4, 'info')
								end
							end

							if AutoAttack.Enabled and now > (attackDebounce[drill] or 0) then
								local target = entitylib.EntityPosition({
									Origin = part.Position,
									Range = Legit.Enabled and 10 or Range.Value,
									Part = 'RootPart',
									Players = Targets.Players.Enabled,
									NPCs = Targets.NPCs.Enabled,
									Sort = sortmethods[Sort.Value]
								})

								if target and useDrill(drill) then
									targetinfo.Targets[target] = tick() + 1
									bedwars.Handler:Get('DrillAttack'):Fire('SendToServer', {targetPosition = target.RootPart.Position})
									attackDebounce[drill] = now + AttackDelay.Value
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoDrill.Enabled
			else
				currentDrill = nil
				table.clear(attackDebounce)
				table.clear(collectDebounce)
			end
		end,
		Tooltip = 'Automatically collects resources and attacks with placed drills.'
	})
	AutoCollect = AutoDrill:CreateToggle({
		Name = 'Auto collect',
		Default = true,
		Function = function(callback)
			if Notify then
				Notify.Object.Visible = callback
				CollectDelay.Object.Visible = callback
			end
		end
	})
	Notify = AutoDrill:CreateToggle({
		Name = 'Notify on collect',
		Darker = true
	})
	AutoAttack = AutoDrill:CreateToggle({
		Name = 'Auto attack',
		Default = true,
		Function = updateAttackControls
	})
	Range = AutoDrill:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 10,
		Default = 10,
		Suffix = function(value)
			return value == 1 and 'stud' or 'studs'
		end
	})
	Legit = AutoDrill:CreateToggle({
		Name = 'Legit Range',
		Default = true,
		Function = updateAttackControls
	})
	AttackDelay = AutoDrill:CreateSlider({
		Name = 'Attack delay',
		Min = 0.1,
		Max = 1,
		Default = 0.3,
		Decimal = 100,
		Suffix = function(value)
			return value == 1 and 'sec' or 'secs'
		end
	})
	CollectDelay = AutoDrill:CreateSlider({
		Name = 'Collect delay',
		Min = 0.1,
		Max = 3,
		Default = 0.5,
		Decimal = 10,
		Suffix = function(value)
			return value == 1 and 'sec' or 'secs'
		end
	})
	Targets = AutoDrill:CreateTargets({
		Players = true,
		NPCs = false
	})
	local methods = {'Distance', 'Health', 'Damage'}
	for name in sortmethods do
		if not table.find(methods, name) then
			table.insert(methods, name)
		end
	end
	Sort = AutoDrill:CreateDropdown({
		Name = 'Sort',
		List = methods,
		Default = 'Distance'
	})
	updateAttackControls()
end)

run(function()
	local AutoElder
	local Streamer
	local Range
	local Animation
	local Delay

	local Legit = getFunctionRange(bedwars.EldertreeController.createTreeOrbInteraction) or 10
	local cooldowns = {}

	AutoElder = kits:CreateModule({
		Name = 'AutoElder',
		Function = function(call)
			if call then
				AutoElder:Clean(proximityPromptService.PromptShown:Connect(function(prompt)
					if Streamer.Enabled and prompt.Name == 'treeOrb' then
						task.delay(0.1, prompt.InputHoldBegin, prompt)
					end
				end))

				repeat
					if not Streamer.Enabled and entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('treeOrb') do
							if tick() > (cooldowns[v] or 0) and (localPosition - v.Spirit.Position).Magnitude <= Range.Value then
								if Delay.Value > 0 then
									task.wait(Delay.Value)
								end

								if (localPosition - v.Spirit.Position).Magnitude <= Range.Value then
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
										bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
										bedwars.AudioManager:playAudio(bedwars.SoundList.CROP_HARVEST)
									end

									if bedwars.Handler:Get('ConsumeTreeOrb'):Fire('CallServer', {treeOrbSecret = v:GetAttribute('TreeOrbSecret')}) then
										v:Destroy()
									end
									cooldowns[v] = tick() + 1
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoElder.Enabled
			else
				table.clear(cooldowns)
			end
		end,
		Tooltip = 'Automatically collects tree orbs'
	})
	Streamer = AutoElder:CreateToggle({
		Name = 'Streamer mode',
		Function = function(call)
			if Delay then
				Delay.Object.Visible = not call
				Range.Object.Visible = not call
				Animation.Object.Visible = not call
			end
		end,
		Tooltip = 'Useful for when ur screensharing'
	})
	Animation = AutoElder:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays the collect animation'
	})
	Range = AutoElder:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 12,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end
	})
	AutoElder:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Delay = AutoElder:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Suffix = function(val)
			return val > 1 and 'secs' or 'sec'
		end
	})
end)

run(function()
	local AutoEldric
	local Targets
	local Range
	local Priority
	local Allies
	local Health
	local linked

	local Link = bedwars.Handler:Get('WarlockLinkTarget')

	local function getHurtAlly(origin)
		local best, bestHealth
		for _, v in entitylib.List do
			if not v.Targetable and v.Player and v ~= entitylib.character and (v.RootPart.Position - origin).Magnitude <= Range.Value then
				local ratio = v.Health / v.MaxHealth
				if ratio <= (Health.Value / 100) and (not bestHealth or ratio < bestHealth) then
					best, bestHealth = v, ratio
				end
			end
		end
		return best
	end

	local function link(target)
		if bedwars.AbilityController:canUseAbility('WARLOCK_LINK', {disableBlockedAbilityAlert = true}) then
			bedwars.AbilityController:useAbility('WARLOCK_LINK')
			task.wait(store.ping.total or 0.1)
		end

		if not AutoEldric.Enabled or not target.Character or not target.Character.Parent then return end
		linked = target.Character
		Link:Fire('CallServer', {target = target.Character})
	end

	AutoEldric = kits:CreateModule({
		Name = 'AutoEldric',
		Function = function(callback)
			if callback then
				linked = nil

				repeat
					if entitylib.isAlive and store.equippedKit == 'warlock' and store.hand.tool and store.hand.tool.Name == 'warlock_staff' then
						local origin = entitylib.character.RootPart.Position
						local target

						if Priority.Value == 'Teammates' and Allies.Enabled then
							target = getHurtAlly(origin)
						end

						if not target then
							target = entitylib.EntityPosition({
								Origin = origin,
								Range = Range.Value,
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Wallcheck = Targets.Walls.Enabled
							})
						end

						if not target and Allies.Enabled then
							target = getHurtAlly(origin)
						end

						if target and target.Character ~= linked then
							link(target)
						elseif not target then
							linked = nil
						end
					end
					task.wait(0.1)
				until not AutoEldric.Enabled
			end
		end,
		Tooltip = 'Automatically links the warlock staff to enemies or hurt teammates'
	})
	Targets = AutoEldric:CreateTargets({
		Players = true,
		Walls = true
	})
	Range = AutoEldric:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 24,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoEldric:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(bedwars.WarlockBalance and bedwars.WarlockBalance.SELECTOR_RANGE or 24)
		end
	})
	Priority = AutoEldric:CreateDropdown({
		Name = 'Priority',
		List = {'Enemies', 'Teammates'},
		Tooltip = 'Which side the staff links first when both are in range'
	})
	Allies = AutoEldric:CreateToggle({
		Name = 'Heal teammates',
		Default = true,
		Tooltip = 'Links a hurt teammate when no enemy is in range'
	})
	Health = AutoEldric:CreateSlider({
		Name = 'Ally health',
		Min = 1,
		Max = 100,
		Default = 70,
		Darker = true,
		Suffix = function()
			return '%'
		end
	})

end)

run(function()
	local AutoEmber
	local Targets
	local Range
	local Delay
	local Limit

	AutoEmber = kits:CreateModule({
		Name = 'AutoEmber',
		Function = function(call)
			if call then
				local clock = os.clock()

				repeat
					local tool = entitylib.isAlive and getItem('infernal_saber')
					if tool and (not Limit.Enabled or store.hand.tool == tool) and (Delay.Value <= 0 or os.clock() - clock >= Delay.Value) and entitylib.EntityPosition({
						Range = Range.Value,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled
					}) then
						bedwars.Handler:Get('HellBladeRelease'):Fire('SendToServer', {
							chargeTime = 1,
							weapon = tool,
							player = lplr
						})
						clock = os.clock()
					end
					task.wait()
				until not AutoEmber.Enabled
			end
		end,
		Tooltip = 'Automatically releases the infernal saber charge when a target is in range'
	})
	Targets = AutoEmber:CreateTargets({
		Players = true,
		NPCs = false
	})
	Delay = AutoEmber:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100
	})
	Range = AutoEmber:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 22,
		Default = 22,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Limit = AutoEmber:CreateToggle({Name = 'Limit to item'})
end)

run(function()
	local AutoEquipKit
	local Kit

	local kits, list = {}, {}

	for i, v in bedwars.BedwarsKitMeta do
		if v.name ~= 'None' then
			table.insert(list, v.name)
		end
		kits[v.name] = i
	end
	table.sort(list)
	table.insert(list, 1, 'None')

	AutoEquipKit = kits:CreateModule({
		Name = 'AutoEquipKit',
		Function = function(callback)
			if callback then
				local last

				repeat
					if store.matchState == 2 and last == 1 and Kit.Value ~= 'None' then
						bedwars.Handler:Get('BedwarsActivateKit'):Fire('CallServer', {kit = kits[Kit.Value]})
						notif('AutoEquipKit', `Equipped {Kit.Value} for the next round.`, 10, 'info')
					end

					last = store.matchState
					task.wait(0.5)
				until not AutoEquipKit.Enabled
			end
		end,
		Tooltip = 'Equips a kit automatically when a round ends'
	})
	Kit = AutoEquipKit:CreateDropdown({
		Name = 'Equip kit',
		List = list,
		Default = 'None'
	})
end)

run(function()
	local AutoEvelynn
	local Delay, OnlyFalling, OnlySwinging, FaceTarget
	local EVELYNN_RANGE = 120
	local SWING_WINDOW = 0.3
	local ATTEMPT_COOLDOWN = 0.35
	local ray = RaycastParams.new()
	ray.FilterType = Enum.RaycastFilterType.Exclude
	ray.RespectCanCollide = true
	local rayCharacter
	local swingMarker, swingSeenAt = nil, -math.huge

	local function soulPosition(soul)
		if not soul or not soul.Parent then return nil end
		if soul:IsA('BasePart') then return soul.Position end
		if soul:IsA('Model') then
			local ok, pivot = pcall(soul.GetPivot, soul)
			if ok then return pivot.Position end
		end
		local part = soul:FindFirstChildWhichIsA('BasePart', true)
		return part and part.Position or nil
	end

	local function fallingIntoVoid(root)
		if not root or root.AssemblyLinearVelocity.Y >= -2 then return false end
		if rayCharacter ~= lplr.Character then
			rayCharacter = lplr.Character
			ray.FilterDescendantsInstances = rayCharacter and {rayCharacter} or {}
		end
		return workspace:Raycast(root.Position, Vector3.new(0, -80, 0), ray) == nil
	end

	local function updateSwing()
		local value = bedwars.SwordController and bedwars.SwordController.lastSwing or 0
		if value ~= swingMarker then swingMarker, swingSeenAt = value, os.clock() end
	end

	local function findNearestTarget()
		if not entitylib.isAlive then return end
		local root, nearest, distance = entitylib.character.RootPart, nil, math.huge
		for _, entity in entitylib.List do
			if entity.Targetable and entity.Player and entity.RootPart and entity.RootPart.Parent then
				local magnitude = (entity.RootPart.Position - root.Position).Magnitude
				if magnitude < distance then nearest, distance = entity, magnitude end
			end
		end
		return nearest
	end

	local function faceNearestTarget()
		if not FaceTarget.Enabled or not entitylib.isAlive then return end
		local root, nearest = entitylib.character.RootPart, findNearestTarget()
		if nearest then
			root.CFrame = CFrame.lookAt(root.Position, Vector3.new(nearest.RootPart.Position.X, root.Position.Y, nearest.RootPart.Position.Z))
		end
	end

	local function faceAfterRecall(startPosition)
		if not FaceTarget.Enabled then return end
		task.spawn(function()
			local deadline = os.clock() + 0.4
			repeat
				task.wait()
				if not AutoEvelynn.Enabled or not entitylib.isAlive then return end
				local root = entitylib.character.RootPart
				if root and (root.Position - startPosition).Magnitude > 3 then break end
			until os.clock() >= deadline
			if AutoEvelynn.Enabled then faceNearestTarget() end
		end)
	end

	local function findNearestSoul(souls, root)
		local nearest, distance = nil, math.huge
		for _, soul in souls do
			local position = soulPosition(soul)
			if position then
				local magnitude = (position - root.Position).Magnitude
				if magnitude <= EVELYNN_RANGE and magnitude < distance then nearest, distance = soul, magnitude end
			end
		end
		return nearest
	end

	AutoEvelynn = kits:CreateModule({
		Name = 'AutoEvelynn',
		Category = 'Auto',
		Function = function(callback)
			if not callback then return end
			swingMarker, swingSeenAt = bedwars.SwordController and bedwars.SwordController.lastSwing or 0, -math.huge
			local souls = collection('EvelynnSoul', AutoEvelynn)
			task.spawn(function()
				repeat task.wait() until store.matchState ~= 0 or not AutoEvelynn.Enabled
				if not AutoEvelynn.Enabled then return end

				local pendingSoul, pendingSince, lastAttempt
				lastAttempt = 0
				repeat
					
					if entitylib.isAlive and store.equippedKit == 'spirit_assassin'
						and bedwars.SpiritAssassinController and not ((vape.Modules.AutoKit or {}).Enabled) then
						local root = entitylib.character.RootPart
						updateSwing()
						local soul = findNearestSoul(souls, root)
						if soul then
							local now = os.clock()
							if pendingSoul ~= soul then pendingSoul, pendingSince = soul, now end
							local swinging = store.hand.toolType == 'sword' and now - swingSeenAt <= SWING_WINDOW
							local conditionsReady = (not OnlyFalling.Enabled or fallingIntoVoid(root))
								and (not OnlySwinging.Enabled or swinging)
							if pendingSince and now - pendingSince >= Delay.Value and conditionsReady and soul.Parent
								and now - lastAttempt >= ATTEMPT_COOLDOWN then
								lastAttempt = now
								
								
								if (not OnlyFalling.Enabled or fallingIntoVoid(root))
									and (not OnlySwinging.Enabled or (store.hand.toolType == 'sword' and os.clock() - swingSeenAt <= SWING_WINDOW)) then
									local previous = root.Position
									local controller = bedwars.SpiritAssassinController
									local success = controller and pcall(controller.useSpirit, controller, lplr, soul)
									if success then faceAfterRecall(previous) end
								end
								pendingSoul, pendingSince = nil, nil
							end
						else
							pendingSoul, pendingSince = nil, nil
						end
					else
						pendingSoul, pendingSince = nil, nil
					end
					task.wait(0.03)
				until not AutoEvelynn.Enabled
			end)
		end,
		Tooltip = 'Conditionally recalls to Evelynn spirit orbs; AutoKit must be off'
	})
	Delay = AutoEvelynn:CreateSlider({Name = 'Delay', Min = 0, Max = 2, Default = 0.1, Decimal = 10, Suffix = 'seconds'})
	OnlyFalling = AutoEvelynn:CreateToggle({Name = 'Only when falling', Tooltip = 'Only recalls while falling into the void'})
	OnlySwinging = AutoEvelynn:CreateToggle({Name = 'Only while swinging', Tooltip = 'Only recalls while manually swinging'})
	FaceTarget = AutoEvelynn:CreateToggle({Name = 'Face target', Default = true, Tooltip = 'Faces the nearest enemy after recalling'})
end)

run(function()
	local AutoFarmer
	local Range
	local Switch
	local Delay
	local nextHarvest = 0

	AutoFarmer = kits:CreateModule({
		Name = 'AutoFarmer',
		Function = function(callback)
			if callback then
				nextHarvest = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'farmer_cletus' and tick() >= nextHarvest then
						local origin = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('HarvestableCrop') do
							if v:IsA('BasePart') and (v.Position - origin).Magnitude <= Range.Value then
								nextHarvest = tick() + Delay.Value
								bedwars.breakBlock(v, true, true, nil, Switch.Enabled)
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoFarmer.Enabled
			end
		end,
		Tooltip = 'Automatically harvests your crops once they are ripe'
	})
	Range = AutoFarmer:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoFarmer:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.3,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
	Switch = AutoFarmer:CreateToggle({
		Name = 'Auto Switch',
		Default = true,
		Tooltip = 'Swaps to the right tool before harvesting'
	})
end)

run(function()
	local AutoFarmerCletus
	local Range
	local Delay
	local nextPickup = 0

	local crops = {
		carrot = true,
		carrot_seeds = true,
		melon = true,
		melon_seeds = true,
		watermelon = true,
		pumpkin = true,
		pumpkin_block = true,
		pumpkin_seeds = true
	}

	local Pickup = bedwars.Handler:Get('PickupItemDrop')

	AutoFarmerCletus = kits:CreateModule({
		Name = 'AutoFarmerCletus',
		Function = function(callback)
			if callback then
				nextPickup = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'farmer_cletus' and tick() >= nextPickup then
						local origin = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('ItemDrop') do
							if crops[v.Name] and (v:GetAttribute('PickupReadyTime') or math.huge) < workspace:GetServerTimeNow() and (v.Position - origin).Magnitude <= Range.Value then
								nextPickup = tick() + Delay.Value
								Pickup:Fire('CallServerAsync', {itemDrop = v})
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoFarmerCletus.Enabled
			end
		end,
		Tooltip = 'Automatically collects the crops and seeds your farm drops'
	})
	Range = AutoFarmerCletus:CreateSlider({
		Name = 'Collect Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoFarmerCletus:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(6)
		end
	})
	Delay = AutoFarmerCletus:CreateSlider({
		Name = 'Delay',
		Min = 0.05,
		Max = 2,
		Default = 0.15,
		Decimal = 100,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)

run(function()
	local AutoFreiya
	local Range
	local Stacks
	local Delay

	local cooldown = 0

	AutoFreiya = kits:CreateModule({
		Name = 'AutoFreiya',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'ice_queen' and tick() >= cooldown and bedwars.AbilityController:canUseAbility('ice_queen', {disableBlockedAbilityAlert = true}) then
						local origin = entitylib.character.RootPart.Position
						for _, v in entitylib.List do
							if v.Targetable and (v.Character:GetAttribute('IceQueenStacks') or 0) >= Stacks.Value and (v.RootPart.Position - origin).Magnitude <= Range.Value then
								cooldown = tick() + Delay.Value
								bedwars.AbilityController:useAbility('ice_queen')
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoFreiya.Enabled
			end
		end,
		Tooltip = 'Automatically detonates ice stacks once enemies are frozen enough'
	})
	Range = AutoFreiya:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 40,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoFreiya:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0,
		Decimal = 100,
		Suffix = 'seconds'
	})
	Stacks = AutoFreiya:CreateSlider({
		Name = 'Stacks',
		Min = 1,
		Max = 10,
		Default = 3,
		Tooltip = 'Ice stacks an enemy needs before detonating'
	})
end)

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

run(function()
	local AutoGrim
	local Range
	local Health
	local Delay

	local Legit = getFunctionRange(bedwars.GrimReaperController.registerSoulInteractions) or 0

	AutoGrim = kits:CreateModule({
		Name = 'AutoGrim',
		Function = function(callback)
			if callback then
				local souls = collection(bedwars.GrimReaperController.soulsByPosition, AutoGrim)
				local cooldown = 0

				repeat
					if entitylib.isAlive and lplr.Character:GetAttribute('Health') <= (lplr.Character:GetAttribute('MaxHealth') * (Health.Value / 100)) and not lplr.Character:GetAttribute('GrimReaperChannel') and (Delay.Value <= 0 or tick() - cooldown >= Delay.Value) then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in souls do
							if (localPosition - v.Position).Magnitude <= Range.Value then
								bedwars.Handler:Get('ConsumeGrimReaperSoul'):Fire('CallServer', {
									secret = v:GetAttribute('GrimReaperSoulSecret')
								})
								cooldown = tick()
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoGrim.Enabled
			end
		end,
		Tooltip = 'Automatically consumes nearby souls when your health drops low'
	})
	Range = AutoGrim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 120,
		Default = 12,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoGrim:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Health = AutoGrim:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 25,
		Suffix = function()
			return '%'
		end,
		Tooltip = 'Only eats a soul once your health drops to this share of your maximum'
	})
	Delay = AutoGrim:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 10,
		Suffix = 'seconds'
	})
end)

run(function()
	local AutoGrove
	local Delay
	local nextWater = 0

	AutoGrove = kits:CreateModule({
		Name = 'AutoGrove',
		Function = function(callback)
			if callback then
				nextWater = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'spirit_gardener' and tick() >= nextWater and bedwars.AbilityController:canUseAbility('spirit_gardener_water', {disableBlockedAbilityAlert = true}) then
						nextWater = tick() + Delay.Value
						bedwars.AbilityController:useAbility('spirit_gardener_water')
					end
					task.wait(0.1)
				until not AutoGrove.Enabled
			end
		end,
		Tooltip = 'Automatically feeds spirit energy to your flowers so they never wither'
	})
	Delay = AutoGrove:CreateSlider({
		Name = 'Delay',
		Min = 0.5,
		Max = 20,
		Default = 3,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)

run(function()
	local AutoHannah
	local Targets
	local Sort
	local Range
	local AuraTarget
	local attempted = setmetatable({}, {__mode = 'k'})

	AutoHannah = kits:CreateModule({
		Name = 'AutoHannah',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'hannah' and not bedwars.StatusEffectUtil:isActive(lplr.Character, 'grounded') and not bedwars.StatusEffectUtil:isActive(lplr.Character, 'frosted') then
						local threshold = bedwars.BalanceFile.HANNAH_BASE_EXECUTE_THRESHOLD + (bedwars.BalanceFile.HANNAH_MAX_COMBO * bedwars.BalanceFile.HANNAH_COMBO_EXECUTE_BOOST)

						for _, ent in entitylib.AllPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods[Sort.Value]
						}) do
							if ent.Character:HasTag('HannahExecuteInteraction') and ent.Health <= ent.MaxHealth * threshold and (not AuraTarget.Enabled or (targetinfo.Targets[ent] or 0) > tick()) and (not attempted[ent.Character] or tick() - attempted[ent.Character] >= 0.3) then
								attempted[ent.Character] = tick()

								if bedwars.Handler:Get('HannahPromptTrigger'):Fire('CallServer', {
									user = lplr,
									victimEntity = ent.Character
								}) then
									local billboard = ent.Character:FindFirstChild('Hannah Execution Icon')
									if billboard then
										billboard:Destroy()
									end
								end

								break
							end
						end
					end
					task.wait(0.1)
				until not AutoHannah.Enabled
				table.clear(attempted)
			end
		end,
		Tooltip = 'Automatically executes low health players with Hannah.'
	})
	Targets = AutoHannah:CreateTargets({Players = true})
	local methods = {'Health', 'Distance'}
	for _, i in sortlist do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sort = AutoHannah:CreateDropdown({
		Name = 'Target mode',
		List = methods,
		Default = 'Health'
	})
	Range = AutoHannah:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AuraTarget = AutoHannah:CreateToggle({
		Name = 'Only killaura target',
		Tooltip = 'Only executes targets that are being attacked by killaura'
	})
end)

run(function()
	local AutoHephaestus
	local Summon
	local lastRepair, lastSummon = 0, 0

	AutoHephaestus = kits:CreateModule({
		Name = 'AutoHephaestus',
		Function = function(callback)
			if callback then
				AutoHephaestus:Clean(runService.Heartbeat:Connect(function()
					if store.equippedKit ~= 'tinker' then return end

					if bedwars.TinkerKitController.mounted then
						if tick() >= lastRepair and bedwars.AbilityController:canUseAbility('tinker_self_repair', {disableBlockedAbilityAlert = true}) and (workspace:GetServerTimeNow() - bedwars.SwordController.lastAttack) > 1 then
							lastRepair = tick() + 0.5
							bedwars.AbilityController:useAbility('tinker_self_repair')
						end
					elseif Summon.Enabled and tick() >= lastSummon and bedwars.AbilityController:canUseAbility('tinker_summon', {disableBlockedAbilityAlert = true}) then
						lastSummon = tick() + 1
						bedwars.AbilityController:useAbility('tinker_summon')
					end
				end))
			end
		end,
		Tooltip = 'Automatically repairs your Tinker machine whenever the self repair ability is available'
	})
	Summon = AutoHephaestus:CreateToggle({
		Name = 'Summon tinker',
		Tooltip = 'Calls the machine back whenever you are not mounted on it'
	})
end)

run(function()
	local AutoKaida
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local Spell
	local SpellMode
	local SpellCharge
	local SpellRange
	local Swing
	local Limit
	local Mouse
	local GUI

	local casting = 0

	local function getClaw()
		if Limit.Enabled then
			return store.hand.tool and bedwars.IsItemClaw(store.hand.tool.Name) and store.hand or nil
		end

		for _, item in store.inventory.inventory.items do
			if bedwars.IsItemClaw(item.itemType) then
				return item
			end
		end
		return nil
	end

	local function getSpellTarget()
		local localPosition = entitylib.character.RootPart.Position
		if SpellMode.Value == 'Camera' then
			local point = bedwars.AbilityIndicatorUtil:calculateBlockTargetPoint(gameCamera.CFrame.Position, gameCamera.CFrame.LookVector, 300, nil, {allowArenaBarrierTarget = false})
			return point and (point - localPosition).Magnitude <= SpellRange.Value and point or nil
		end

		local ent = entitylib.EntityPosition({
			Range = SpellRange.Value,
			Part = 'RootPart',
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Sort = sortmethods[Sort.Value]
		})
		if not ent then return nil end

		local point = bedwars.AbilityIndicatorUtil:calculateBlockTargetPoint(ent.RootPart.Position + Vector3.new(0, 3, 0), Vector3.new(0, -1, 0), 30, nil, {allowArenaBarrierTarget = false})
		return point and (point - localPosition).Magnitude <= SpellRange.Value and point or ent.RootPart.Position
	end

	local function castSpell()
		local target = getSpellTarget()
		if not target or not bedwars.AbilityController:canUseAbility('summoner_start_charging', {disableBlockedAbilityAlert = true}) then return end

		casting = tick() + 6
		bedwars.AbilityController:useAbility('summoner_start_charging', nil, {targetPosition = target})

		local level = bedwars.SummonerUtil.summoner_getPlayerSpellLevel(lplr) or 1
		local charge = math.max(bedwars.SummonerUtil.summoner_getTotalCastTimeRequired(level) * (SpellCharge.Value / 100), bedwars.SummonerKitBalance.SPELL_MINIMUM_CAST_TIME)
		local deadline = tick() + charge

		repeat task.wait() until tick() >= deadline or not AutoKaida.Enabled or not entitylib.isAlive or not bedwars.SummonerKitController:isPlayerCastingSpell(lplr)

		if AutoKaida.Enabled and entitylib.isAlive and bedwars.SummonerKitController:isPlayerCastingSpell(lplr) then
			bedwars.AbilityController:useAbility('summoner_finish_charging')
		end
		casting = 0
	end

	AutoKaida = kits:CreateModule({
		Name = 'AutoKaida',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'summoner' then
						if Spell.Enabled and tick() > casting and not bedwars.SummonerKitController:isPlayerCastingSpell(lplr) then
							task.spawn(castSpell)
						end

						local claw = (not Mouse.Enabled or inputService:IsMouseButtonPressed(0)) and (not GUI.Enabled or not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN)) and getClaw()
						local ent = claw and (workspace:GetServerTimeNow() - bedwars.SummonerClawHandController.lastAttackTime) > bedwars.SummonerKitBalance.CLAW_COOLDOWN and (Swing.Enabled or not bedwars.SummonerKitController:isPlayerCastingSpell(lplr)) and entitylib.EntityPosition({
							Range = SwingRange.Value,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods[Sort.Value]
						})

						if ent then
							local selfpos = entitylib.character.RootPart.Position
							local delta = ent.RootPart.Position - selfpos
							local dir = CFrame.lookAt(selfpos, ent.RootPart.Position).LookVector
							targetinfo.Targets[ent] = tick() + 1
							switchItem(claw.tool, 0)
							if delta.Magnitude <= AttackRange.Value then
								bedwars.Handler:Get('SummonerClawAttackRequest'):Fire(nil, {
									position = selfpos + dir * math.max(delta.Magnitude - 16.399, 0),
									direction = dir,
									clientTime = workspace:GetServerTimeNow()
								})
							end
							bedwars.SummonerClawHandController.lastAttackTime = workspace:GetServerTimeNow()
							bedwars.SummonerClawController:clawAttack(lplr, selfpos, dir, claw.tool.Name)
						end
					end

					task.wait(0.1)
				until not AutoKaida.Enabled
			else
				casting = 0
			end
		end,
		Tooltip = 'Automatically attacks with the Kaida claw and casts her summon circle'
	})
	Targets = AutoKaida:CreateTargets({Players = true})
	local methods = {'Distance', 'Damage'}
	for _, i in sortlist do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	Sort = AutoKaida:CreateDropdown({
		Name = 'Target mode',
		List = methods
	})
	SwingRange = AutoKaida:CreateSlider({
		Name = 'Swing Range',
		Min = 1,
		Max = 32,
		Default = 32,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AttackRange = AutoKaida:CreateSlider({
		Name = 'Attack Range',
		Min = 1,
		Max = 32,
		Default = 32,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Spell = AutoKaida:CreateToggle({
		Name = 'Auto summon',
		Function = function(callback)
			if SpellMode then
				SpellMode.Object.Visible = callback
				SpellCharge.Object.Visible = callback
				SpellRange.Object.Visible = callback
			end
		end,
		Tooltip = 'Charges and drops the summon circle on its own'
	})
	SpellMode = AutoKaida:CreateDropdown({
		Name = 'Summon at',
		List = {'Target', 'Camera'},
		Darker = true,
		Visible = false,
		Tooltip = 'Target drops the circle on the closest enemy, Camera drops it where you are looking'
	})
	SpellCharge = AutoKaida:CreateSlider({
		Name = 'Charge',
		Min = 1,
		Max = 100,
		Default = 100,
		Darker = true,
		Visible = false,
		Suffix = '%',
		Tooltip = 'How far to charge before releasing, 100% is the full radius for your spell level'
	})
	SpellRange = AutoKaida:CreateSlider({
		Name = 'Summon Range',
		Min = 1,
		Max = 39,
		Default = 39,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end,
		Tooltip = 'The game refuses anything past 39 studs'
	})
	Swing = AutoKaida:CreateToggle({
		Name = 'Swing during ability',
		Default = true,
		Tooltip = 'Continue claw attacks while the ability is charging'
	})
	Limit = AutoKaida:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only attacks while the claw is held'
	})
	Mouse = AutoKaida:CreateToggle({Name = 'Require mouse down'})
	GUI = AutoKaida:CreateToggle({Name = 'GUI check'})
end)

run(function()
	local AutoKaliyah
	local Range
	local Stacks
	local Delay
	local NoSlow

	local Legit = getFunctionRange(bedwars.DragonSlayerController.hasEligiblePunchTarget) or 14.4
	local modifier, old
	local noSlowUntil = 0

	local function punch()
		if NoSlow.Enabled then
			if not old then
				modifier = bedwars.SprintController:getMovementStatusModifier()
				old = modifier.addModifier
				modifier.addModifier = function(self, tab)
					if NoSlow.Enabled and tick() < noSlowUntil and tab and tab.moveSpeedMultiplier == 0 then
						tab.moveSpeedMultiplier = 1
					end
					return old(self, tab)
				end

				AutoKaliyah:Clean(function()
					modifier.addModifier = old
					modifier, old = nil, nil
					noSlowUntil = 0
				end)
			end
			noSlowUntil = math.max(noSlowUntil, tick() + Delay.Value + 0.1)
		end

		task.wait(Delay.Value)
		bedwars.AbilityController:useAbility('dragon_slayer_punch')
	end

	AutoKaliyah = kits:CreateModule({
		Name = 'AutoKaliyah',
		Function = function(call)
			if call then
				repeat
					if entitylib.isAlive and store.equippedKit == 'dragon_slayer' and bedwars.AbilityController:canUseAbility('dragon_slayer_punch', {disableBlockedAbilityAlert = true}) then
						local localPosition = entitylib.character.RootPart.Position
						for target, v in bedwars.DragonSlayerController.dragonEmblems do
							if v.stackCount >= Stacks.Value and target.PrimaryPart and (target.PrimaryPart.Position - localPosition).Magnitude <= Range.Value then
								punch()
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoKaliyah.Enabled
			end
		end,
		Tooltip = 'Automatically uses the "punch" ability from kaliyah'
	})
	NoSlow = AutoKaliyah:CreateToggle({
		Name = 'No Slow',
		Default = true,
		Tooltip = 'Prevents you from being slowed down after using the "Punch" ability'
	})
	Range = AutoKaliyah:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 18,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoKaliyah:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Stacks = AutoKaliyah:CreateSlider({
		Name = 'Stacks',
		Min = 1,
		Max = 3,
		Default = 1,
		Suffix = function(val)
			return val <= 1 and 'stack' or 'stacks'
		end,
		Tooltip = 'How many emblems a target needs before the punch fires, 3 stacks deals 25 damage against a wall instead of 10'
	})
	Delay = AutoKaliyah:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100
	})
end)

run(function()
	local AutoKit
	local Legit
	local Toggles = {}

	local function kitCollection(id, func, range, specific)
		local objs = type(id) == 'table' and id or collection(id, AutoKit)
		repeat
			if entitylib.isAlive then
				local localPosition = entitylib.character.RootPart.Position
				for _, v in objs do
					if (vape.Modules.InfiniteFly or {}).Enabled or not AutoKit.Enabled then break end
					local part = not v:IsA('Model') and v or (v.PrimaryPart or v:FindFirstChildWhichIsA('BasePart', true))
					if part and (part.Position - localPosition).Magnitude <= (not Legit.Enabled and specific and math.huge or range) then
						func(v)
					end
				end
			end
			task.wait(0.1)
		until not AutoKit.Enabled
	end

	local AutoKitFunctions = {
		battery = function()
			repeat
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for i, v in bedwars.BatteryEffectsController.liveBatteries do
						if (v.position - localPosition).Magnitude <= 10 then
							local BatteryInfo = bedwars.BatteryEffectsController:getBatteryInfo(i)
							if not BatteryInfo or BatteryInfo.activateTime >= workspace:GetServerTimeNow() or BatteryInfo.consumeTime + 0.1 >= workspace:GetServerTimeNow() then continue end
							BatteryInfo.consumeTime = workspace:GetServerTimeNow()
							bedwars.Handler:Get('ConsumeBattery'):Fire('SendToServer', {batteryId = i})
						end
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		beekeeper = function()
			kitCollection('bee', function(v)
				bedwars.Handler:Get('PickUpBee'):Fire('SendToServer', {beeId = v:GetAttribute('BeeId')})
			end, 18, false)
		end,
		bigman = function()
			kitCollection('treeOrb', function(v)
				if bedwars.Handler:Get('ConsumeTreeOrb'):Fire('CallServer', {treeOrbSecret = v:GetAttribute('TreeOrbSecret')}) then
					v:Destroy()
				end
			end, 12, false)
		end,
		block_kicker = function()
			local old = bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition
			bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = function(...)
				local origin, dir = select(2, ...)
				local plr = entitylib.EntityMouse({
					Part = 'RootPart',
					Range = 1000,
					Origin = origin,
					Players = true,
					Wallcheck = true
				})

				if plr then
					local calc = prediction.SolveTrajectory(origin, 100, 20, plr.RootPart.Position, plr.RootPart.Velocity, workspace.Gravity, plr.HipHeight, plr.Jumping and 42.6 or nil)

					if calc then
						for i, v in debug.getstack(2) do
							if v == dir then
								debug.setstack(2, i, CFrame.lookAt(origin, calc).LookVector)
							end
						end
					end
				end

				return old(...)
			end

			AutoKit:Clean(function()
				bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = old
			end)
		end,
		cat = function()
			local old = bedwars.CatController.leap
			bedwars.CatController.leap = function(...)
				vapeEvents.CatPounce:Fire()
				return old(...)
			end

			AutoKit:Clean(function()
				bedwars.CatController.leap = old
			end)
		end,
		davey = function()
			local old = bedwars.CannonHandController.launchSelf
			bedwars.CannonHandController.launchSelf = function(...)
				local res = {old(...)}
				local self, block = ...

				if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
					task.spawn(bedwars.breakBlock, block, false)
				end

				return unpack(res)
			end

			AutoKit:Clean(function()
				bedwars.CannonHandController.launchSelf = old
			end)
		end,
		dragon_slayer = function()
			kitCollection('KaliyahPunchInteraction', function(v)
				bedwars.DragonSlayerController:deleteEmblem(v)
				bedwars.DragonSlayerController:playPunchAnimation(Vector3.zero)
				bedwars.Handler:Get('RequestDragonPunch'):Fire('SendToServer', {
					target = v
				})
			end, 18, true)
		end,
		farmer_cletus = function()
			kitCollection('HarvestableCrop', function(v)
				if bedwars.Handler:Get('HarvestCrop'):Fire('CallServer', {position = bedwars.BlockController:getBlockPosition(v.Position)}) then
					bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
					bedwars.AudioManager:playAudio(bedwars.SoundList.CROP_HARVEST)
				end
			end, 10, false)
		end,
		fisherman = function()
			local old = bedwars.FishingMinigameController.startMinigame
			bedwars.FishingMinigameController.startMinigame = function(_, _, result)
				result({win = true})
			end

			AutoKit:Clean(function()
				bedwars.FishingMinigameController.startMinigame = old
			end)
		end,
		gingerbread_man = function()
			local old = bedwars.LaunchPadController.attemptLaunch
			bedwars.LaunchPadController.attemptLaunch = function(...)
				local res = {old(...)}
				local self, block = ...

				if (workspace:GetServerTimeNow() - self.lastLaunch) < 0.4 then
					if block:GetAttribute('PlacedByUserId') == lplr.UserId and (block.Position - entitylib.character.RootPart.Position).Magnitude < 30 then
						task.spawn(bedwars.breakBlock, block, false)
					end
				end

				return unpack(res)
			end

			AutoKit:Clean(function()
				bedwars.LaunchPadController.attemptLaunch = old
			end)
		end,
		hannah = function()
			kitCollection('HannahExecuteInteraction', function(v)
				local billboard = bedwars.Handler:Get('HannahPromptTrigger'):Fire('CallServer', {
					user = lplr,
					victimEntity = v
				}) and v:FindFirstChild('Hannah Execution Icon')

				if billboard then
					billboard:Destroy()
				end
			end, 30, true)
		end,
		jailor = function()
			kitCollection('jailor_soul', function(v)
				bedwars.JailorController:collectEntity(lplr, v, 'JailorSoul')
			end, 20, false)
		end,
		grim_reaper = function()
			kitCollection(bedwars.GrimReaperController.soulsByPosition, function(v)
				if entitylib.isAlive and lplr.Character:GetAttribute('Health') <= (lplr.Character:GetAttribute('MaxHealth') / 4) and (not lplr.Character:GetAttribute('GrimReaperChannel')) then
					bedwars.Handler:Get('ConsumeGrimReaperSoul'):Fire('CallServer', {
						secret = v:GetAttribute('GrimReaperSoulSecret')
					})
				end
			end, 120, false)
		end,
		melody = function()
			repeat
				local mag, hp, ent = 30, math.huge
				if entitylib.isAlive then
					local localPosition = entitylib.character.RootPart.Position
					for _, v in entitylib.List do
						if v.Player and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') then
							local newmag = (localPosition - v.RootPart.Position).Magnitude
							if newmag <= mag and v.Health < hp and v.Health < v.MaxHealth then
								mag, hp, ent = newmag, v.Health, v
							end
						end
					end
				end

				if ent and getItem('guitar') then
					bedwars.Handler:Get('GuitarHeal'):Fire('SendToServer', {
						healTarget = ent.Character
					})
				end

				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		metal_detector = function()
			kitCollection('hidden-metal', function(v)
				bedwars.Handler:Get('CollectCollectableEntity'):Fire('SendToServer', {
					id = v:GetAttribute('Id')
				})
			end, 20, false)
		end,
		miner = function()
			kitCollection('petrified-player', function(v)
				bedwars.Handler:Get('DestroyPetrifiedPlayer'):Fire('SendToServer', {
					petrifyId = v:GetAttribute('PetrifyId')
				})
			end, 6, true)
		end,
		pinata = function()
			kitCollection(lplr.Name..':pinata', function(v)
				if getItem('candy') then
					bedwars.Handler:Get('DepositCoins'):Fire('CallServer', v)
				end
			end, 6, true)
		end,
		spirit_assassin = function()
			kitCollection('EvelynnSoul', function(v)
				bedwars.SpiritAssassinController:useSpirit(lplr, v)
			end, 120, true)
		end,
		star_collector = function()
			kitCollection('stars', function(v)
				bedwars.StarCollectorController:collectEntity(lplr, v, v.Name)
			end, 20, false)
		end,
		summoner = function()
			repeat
				local plr = entitylib.EntityPosition({
					Range = 31,
					Part = 'RootPart',
					Players = true,
					Sort = sortmethods.Health
				})

				if plr and (not Legit.Enabled or (lplr.Character:GetAttribute('Health') or 0) > 0) then
					local localPosition = entitylib.character.RootPart.Position
					local shootDir = CFrame.lookAt(localPosition, plr.RootPart.Position).LookVector
					localPosition += shootDir * math.max((localPosition - plr.RootPart.Position).Magnitude - 16, 0)

					bedwars.Handler:Get('SummonerClawAttackRequest'):Fire('SendToServer', {
						position = localPosition,
						direction = shootDir,
						clientTime = workspace:GetServerTimeNow()
					})
				end

				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		void_dragon = function()
			local oldflap = bedwars.VoidDragonController.flapWings
			local flapped

			bedwars.VoidDragonController.flapWings = function(self)
				if not flapped and bedwars.Handler:Get('DragonFlap'):Fire('CallServer') then
					local modifier = bedwars.SprintController:getMovementStatusModifier():addModifier({
						blockSprint = true,
						constantSpeedMultiplier = 2
					})
					self.SpeedMaid:GiveTask(modifier)
					self.SpeedMaid:GiveTask(function()
						flapped = false
					end)
					flapped = true
				end
			end

			AutoKit:Clean(function()
				bedwars.VoidDragonController.flapWings = oldflap
			end)

			repeat
				if bedwars.VoidDragonController.inDragonForm then
					local plr = entitylib.EntityPosition({
						Range = 30,
						Part = 'RootPart',
						Players = true
					})

					if plr then
						bedwars.Handler:Get('DragonBreath'):Fire('SendToServer', {
							player = lplr,
							targetPoint = plr.RootPart.Position
						})
					end
				end
				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		warlock = function()
			local lastTarget
			repeat
				if store.hand.tool and store.hand.tool.Name == 'warlock_staff' then
					local plr = entitylib.EntityPosition({
						Range = 30,
						Part = 'RootPart',
						Players = true,
						NPCs = true
					})

					if plr and plr.Character ~= lastTarget then
						if not bedwars.Handler:Get('WarlockLinkTarget'):Fire('CallServer', {
							target = plr.Character
						}) then
							plr = nil
						end
					end

					lastTarget = plr and plr.Character
				else
					lastTarget = nil
				end

				task.wait(0.1)
			until not AutoKit.Enabled
		end,
		wizard = function()
			repeat
				local ability = lplr:GetAttribute('WizardAbility')
				if ability and bedwars.AbilityController:canUseAbility(ability, {disableBlockedAbilityAlert = true}) then
					local plr = entitylib.EntityPosition({
						Range = 50,
						Part = 'RootPart',
						Players = true,
						Sort = sortmethods.Health
					})

					if plr then
						bedwars.AbilityController:useAbility(ability, newproxy(true), {target = plr.RootPart.Position})
					end
				end

				task.wait(0.1)
			until not AutoKit.Enabled
		end
	}

	AutoKit = kits:CreateModule({
		Name = 'AutoKit',
		Function = function(callback)
			if callback then
				repeat task.wait() until store.equippedKit ~= '' and store.matchState ~= 0 or (not AutoKit.Enabled)
				if AutoKit.Enabled and AutoKitFunctions[store.equippedKit] and Toggles[store.equippedKit].Enabled then
					AutoKitFunctions[store.equippedKit]()
				end
			end
		end,
		Tooltip = 'Automatically uses kit abilities.'
	})
	Legit = AutoKit:CreateToggle({Name = 'Legit Range'})
	local function kitName(kit)
		local meta = bedwars.BedwarsKitMeta[kit]
		return meta and meta.name or kit
	end

	local sortTable = {}
	for i in AutoKitFunctions do
		table.insert(sortTable, i)
	end
	table.sort(sortTable, function(a, b)
		return kitName(a) < kitName(b)
	end)
	for _, v in sortTable do
		Toggles[v] = AutoKit:CreateToggle({
			Name = kitName(v),
			Default = true
		})
	end
end)

run(function()
	local AutoKrystal

	local function getBed()
		local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
		for _, v in collectionService:GetTagged('bed') do
			if (localPosition - v.Position).Magnitude <= 22 and not v:GetAttribute(`Team{lplr:GetAttribute('Team') or -1}NoBreak`) then
				return v
			end
		end
		return
	end

	AutoKrystal = kits:CreateModule({
		Name = 'AutoKrystal',
		Function = function(callback)
			if callback then
				repeat
					local bed = entitylib.isAlive and store.equippedKit == 'glacial_skater' and bedwars.AbilityController:canUseAbility('skating_freeze', {disableBlockedAbilityAlert = true}) and getBed()
					if bed then
						for _, v in store.blocks do
							if (bed.Position - v.Position).Magnitude <= 20 and v:GetAttribute('PlacedByUserId') then
								bedwars.AbilityController:useAbility('skating_freeze')
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoKrystal.Enabled
			end
		end,
		Tooltip = 'Automatically uses freeze ability when near\nopponent\'s bed defense.'
	})
end)

run(function()
	local AutoLani
	local Delay
	local UseEnemy
	local Enemy
	local Player

	local Request = bedwars.Handler:Get('PaladinAbilityRequest')

	AutoLani = kits:CreateModule({
		Name = 'AutoLani',
		Function = function(call)
			if call then
				local oldstart

				repeat
					local start = lplr:GetAttribute('PaladinStartTime')
					if oldstart and oldstart ~= start then
						local player = UseEnemy.Enabled and playersService:FindFirstChild(Enemy.Value) or not UseEnemy.Enabled and playersService:FindFirstChild(Player.Value) or nil

						if player then
							task.delay(Delay.Value, function()
								Request:Fire('SendToServer', {target = player})
							end)
						end
					end
					oldstart = start
					task.wait(0.1)
				until not AutoLani.Enabled
			end
		end,
		Tooltip = 'Automatically uses the "scepter of light" ability'
	})
	local friends, enemies = {'None'}, {'None'}

	local function addConnection(plr, connected)
		local friendly = plr:GetAttribute('Team') == lplr:GetAttribute('Team')

		if not connected then
			vape:Clean(plr:GetAttributeChangedSignal('Team'):Connect(function()
				addConnection(plr, true)
			end))
		end

		if friendly and not table.find(friends, plr.Name) then
			table.insert(friends, plr.Name)
			Player:Change(friends)
		elseif not friendly and plr.Team and plr.Team.Name ~= 'Spectators' and not table.find(enemies, plr.Name) then
			table.insert(enemies, plr.Name)
			Enemy:Change(enemies)
		end
	end

	Player = AutoLani:CreateDropdown({
		Name = 'Selected Player',
		List = {},
		Tooltip = 'Player to use the ability on'
	})
	Enemy = AutoLani:CreateDropdown({
		Name = 'Selected Enemy',
		List = {},
		Visible = false,
		Tooltip = 'Target to use the ability on'
	})
	UseEnemy = AutoLani:CreateToggle({
		Name = 'Use enemy',
		Function = function(call)
			Enemy.Object.Visible = call
			Player.Object.Visible = not call
		end,
		Tooltip = 'Uses the ability on other people instead of your teammates'
	})
	Delay = AutoLani:CreateSlider({
		Name = 'Delay',
		Min = 1,
		Max = 20,
		Default = 5,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end,
		Tooltip = 'Delay between triggers'
	})
	for _, v in playersService:GetPlayers() do
		addConnection(v)
	end
	vape:Clean(playersService.PlayerAdded:Connect(addConnection))
end)

run(function()
	local AutoLasso
	local Targets
	local Range
	local FireRate
	local SwitchDelay
	local VoidClutch
	local ClutchFallSpeed
	local nextFire = 0
	local voidRay = RaycastParams.new()
	voidRay.RespectCanCollide = true
	voidRay.FilterType = Enum.RaycastFilterType.Exclude

	local function findClutchTarget()
		local root = entitylib.character.RootPart
		local velocity = root.AssemblyLinearVelocity
		if velocity.Y > -ClutchFallSpeed.Value then return end
		voidRay.FilterDescendantsInstances = {lplr.Character, gameCamera}
		local fallTime = math.clamp((-velocity.Y + math.sqrt(velocity.Y * velocity.Y + 2 * workspace.Gravity * 45)) / workspace.Gravity, 0.25, 1.35)
		local predicted = root.Position + velocity * fallTime + Vector3.new(0, -0.5 * workspace.Gravity * fallTime * fallTime, 0)
		if workspace:Raycast(root.Position, predicted - root.Position, voidRay) then return end

		return entitylib.EntityPosition({
			Origin = root.Position,
			Range = Range.Value,
			Part = 'RootPart',
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled or nil,
			Sort = sortmethods.Distance
		})
	end

	local function throwLasso(target)
		local item = getItem('lasso')
		local source = item and bedwars.ItemMeta.lasso.projectileSource or nil
		target = target or (source and getFacingEntity({
			Part = 'RootPart',
			Range = Range.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled,
			Limit = 10
		}) or nil)
		if not source or not target then return end

		local hotbar = store.hand.tool and getHotbar(store.hand.tool) or nil
		if hotbarSwitch(getHotbar(item.tool)) then
			task.wait(store.ping.total or 0)
			if fireProjectile(item, 'lasso', source.projectileType('lasso'), target) then
				nextFire = tick() + source.fireDelaySec + FireRate:GetRandomValue()
				task.wait(SwitchDelay.Value)
			end
			hotbarSwitch(hotbar)
		end
	end

	AutoLasso = kits:CreateModule({
		Name = 'AutoLasso',
		Function = function(callback)
			if callback then
				nextFire = 0

				repeat
					if entitylib.isAlive and tick() >= nextFire then
						if store.equippedKit == 'cowgirl' and store.hand.toolType == 'sword' and (tick() - bedwars.SwordController.lastSwing) < 0.2 then
							throwLasso()
						elseif VoidClutch.Enabled then
							local target = findClutchTarget()
							if target then throwLasso(target) end
						end
					end
					task.wait(0.1)
				until not AutoLasso.Enabled
			end
		end,
		Tooltip = 'Automatically throws Lassy\'s lasso at whoever you\'re meleeing, with an optional void clutch'
	})
	Targets = AutoLasso:CreateTargets({
		Players = true,
		NPCs = false
	})
	Range = AutoLasso:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 22,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	FireRate = AutoLasso:CreateTwoSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 1,
		DefaultMin = 0.05,
		DefaultMax = 0.12,
		Decimal = 100
	})
	SwitchDelay = AutoLasso:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = 'seconds',
		Default = 0.02
	})
	VoidClutch = AutoLasso:CreateToggle({
		
		
		Name = 'Void',
		Tooltip = 'Uses the lasso on a nearby target during a genuine void fall'
	})
	ClutchFallSpeed = AutoLasso:CreateSlider({
		Name = 'Clutch fall speed',
		Min = 1,
		Max = 100,
		Default = 18,
		Tooltip = 'Only attempts a clutch after falling at this speed'
	})
end)

run(function()
	local AutoLumen
	local Targets
	local Range
	local FullCharge
	local Delay

	local Balance = bedwars.LumenBalance or {MIN_CHARGE_TIME = 0.65, MAX_CHARGE_TIME = 1.25}
	local Sword = 'light_sword'
	local cooldown = 0

	local function getChargeTime()
		local itemmeta = bedwars.ItemMeta[Sword]
		local charged = itemmeta and itemmeta.sword and itemmeta.sword.chargedAttack
		local minimum = charged and charged.minChargeTimeSec or Balance.MIN_CHARGE_TIME
		local maximum = charged and charged.maxChargeTimeSec or Balance.MAX_CHARGE_TIME
		return FullCharge.Enabled and maximum or minimum
	end

	local function chargedSwing()
		local charge = bedwars.SwordChargeController
		if charge:getChargeState() ~= bedwars.ChargeState.Idle then return end

		charge:startCharging(Sword)
		local started = charge:getChargeStartTime()
		if started == 0 then return end

		local target = getChargeTime() + 0.05
		repeat task.wait() until not AutoLumen.Enabled or not entitylib.isAlive or (tick() - started) >= target

		local chargeTime = tick() - started
		charge:stopCharging(Sword)
		if not AutoLumen.Enabled or not entitylib.isAlive then return end

		local tool = store.hand.tool
		if not tool or tool.Name ~= Sword then return end

		local charged = bedwars.ItemMeta[Sword].sword.chargedAttack
		if not (charged.skipSwingDamage and chargeTime > (charged.minChargeTimeSec or Balance.MIN_CHARGE_TIME)) then
			bedwars.SwordController:swingSwordAtMouse(chargeTime)
		end

		bedwars.SyncEvents.SwordChargedSwing:fire(lplr, tool, {chargeTime = chargeTime})
		cooldown = tick() + Delay.Value
	end

	AutoLumen = kits:CreateModule({
		Name = 'AutoLumen',
		Function = function(callback)
			if callback then
				cooldown = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'lumen' and store.hand.tool and store.hand.tool.Name == Sword and tick() >= cooldown then
						local target = entitylib.EntityMouse({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Wallcheck = Targets.Walls.Enabled
						})

						if target then
							chargedSwing()
						end
					end
					task.wait(0.1)
				until not AutoLumen.Enabled
			end
		end,
		Tooltip = 'Charges the sword of light and releases a wave whenever an enemy is in front of you, Killaura skips this sword because it has a charged attack'
	})
	Targets = AutoLumen:CreateTargets({
		Players = true,
		Walls = true
	})
	Range = AutoLumen:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 120,
		Default = 60,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	FullCharge = AutoLumen:CreateToggle({
		Name = 'Full charge',
		Default = true,
		Tooltip = 'Holds the swing to the maximum charge, an upgraded lumen only fires the multi beam at full charge'
	})
	Delay = AutoLumen:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Suffix = 'seconds'
	})

end)

run(function()
	local AutoMarina
	local Range

	AutoMarina = kits:CreateModule({
		Name = 'AutoMarina',
		Function = function(call)
			if call then
				local jellies = collection('jellyfish', AutoMarina, function(tab, obj)
					task.delay(0, function()
						if obj:GetAttribute('PlacedByUserId') == lplr.UserId then
							table.insert(tab, obj)
						end
					end)
				end)

				repeat
					if entitylib.isAlive and bedwars.AbilityController:canUseAbility('electrify_jellyfish', {disableBlockedAbilityAlert = true}) then
						for _, v in jellies do
							if v.PrimaryPart and entitylib.EntityPosition({
								Origin = v.PrimaryPart.Position,
								Range = Range.Value,
								Part = 'RootPart',
								Players = true
							}) then
								bedwars.AbilityController:useAbility('electrify_jellyfish')
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoMarina.Enabled
			end
		end,
		Tooltip = 'Automatically uses "electrify" ability when enemies are near jellies.'
	})
	Range = AutoMarina:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 65,
		Default = 50,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local AutoMartin
	local Targets
	local Range
	local Delay

	local cooldown = 0

	AutoMartin = kits:CreateModule({
		Name = 'AutoMartin',
		Function = function(callback)
			if callback then
				cooldown = 0

				repeat
					if tick() >= cooldown and entitylib.EntityPosition({
						Range = Range.Value,
						Part = 'RootPart',
						Wallcheck = Targets.Walls.Enabled,
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled,
						Sort = sortmethods.Distance
					}) and bedwars.AbilityController:canUseAbility('cactus_fire', {disableBlockedAbilityAlert = true}) then
						cooldown = tick() + Delay.Value
						bedwars.AbilityController:useAbility('cactus_fire')
					end
					task.wait(0.1)
				until not AutoMartin.Enabled
			end
		end,
		Tooltip = 'Automatically uses "Wild growth" ability when within range.'
	})
	Targets = AutoMartin:CreateTargets({
		Players = true,
		Walls = true
	})
	Range = AutoMartin:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 22,
		Default = 22,
		Suffix = function(val)
			return val <= 0 and 'stud' or 'studs'
		end
	})
	Delay = AutoMartin:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0,
		Decimal = 100,
		Suffix = 'seconds'
	})
end)

run(function()
	local AutoMelody
	local Range
	local SelfHeal
	local TeammateHeal
	local UseHotbar
	local SwitchBack

	AutoMelody = kits:CreateModule({
		Name = 'AutoMelody',
		Function = function(callback)
			if callback then
				repeat
					local mag, hp, ent = Range.Value, math.huge, nil
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in entitylib.List do
							if v.Player and (SelfHeal.Enabled or v.Player ~= lplr) and (TeammateHeal.Enabled and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') or not TeammateHeal.Enabled and SelfHeal.Enabled and v.Player == lplr) then
								local newmag = (localPosition - v.RootPart.Position).Magnitude
								if newmag <= mag and v.Health < hp and v.Health < v.MaxHealth then
									mag, hp, ent = newmag, v.Health, v
								end
							end
						end
					end

					local guitar = ent and getItem('guitar')
					if guitar then
						local previousSlot, previousTool = store.inventory.hotbarSlot, store.hand.tool

						if UseHotbar.Enabled then
							local slot = getHotbar(guitar.tool)
							if slot then
								hotbarSwitch(slot)
							end
						end

						bedwars.Handler:Get('GuitarHeal'):Fire('SendToServer', {
							healTarget = ent.Character
						})

						if UseHotbar.Enabled and SwitchBack.Enabled then
							if previousSlot and previousSlot ~= store.inventory.hotbarSlot then
								hotbarSwitch(previousSlot)
							elseif previousTool then
								switchItem(previousTool)
							end
						end
					end
					task.wait(0.1)
				until not AutoMelody.Enabled
			end
		end,
		Tooltip = 'Automatically uses the guitar to heal ur teammates/urself'
	})
	SelfHeal = AutoMelody:CreateToggle({
		Name = 'Self Heal',
		Default = true
	})
	TeammateHeal = AutoMelody:CreateToggle({
		Name = 'Teammate Heal',
		Default = true
	})
	Range = AutoMelody:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 30,
		Decimal = 4
	})
	UseHotbar = AutoMelody:CreateToggle({
		Name = 'Use hotbar',
		Function = function(callback)
			if SwitchBack then
				SwitchBack.Object.Visible = callback
			end
		end,
		Tooltip = 'Visibly swaps onto the guitar slot before healing instead of playing it silently'
	})
	SwitchBack = AutoMelody:CreateToggle({
		Name = 'Switch back',
		Default = true,
		Darker = true,
		Visible = false,
		Tooltip = 'Returns to whatever you were holding after the heal'
	})
end)

run(function()
	local AutoMetal
	local Limit
	local StreamerMode
	local Duration
	local Range
	local Animation

	local Legit = getFunctionRange(bedwars.HiddenMetalController.onKitLocalActivated) or 0
	local cooldowns = {}

	AutoMetal = kits:CreateModule({
		Name = 'AutoMetal',
		Function = function(call)
			if call then
				AutoMetal:Clean(proximityPromptService.PromptShown:Connect(function(prompt)
					if StreamerMode.Enabled and prompt.Name == 'hidden-metal-prompt' and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'metal_detector') then
						task.wait(0.1)
						prompt:InputHoldBegin()
					end
				end))

				repeat
					if not StreamerMode.Enabled and entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('hidden-metal') do
							if tick() > (cooldowns[v] or 0) and (localPosition - v.Part.Position).Magnitude <= Range.Value and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'metal_detector') then
								if Duration.Value > 0 then
									task.wait(Duration.Value)
								end

								if (localPosition - v.Part.Position).Magnitude <= Range.Value then
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.SHOVEL_DIG)
										bedwars.AudioManager:playAudio(bedwars.SoundList.SNAP_TRAP_CONSUME_MARK)
									end

									bedwars.Handler:Get('CollectCollectableEntity'):Fire('SendToServer', {
										id = v:GetAttribute('Id')
									})
									cooldowns[v] = tick() + 1
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoMetal.Enabled
			else
				table.clear(cooldowns)
			end
		end,
		Tooltip = 'Automatically uses the metal kit'
	})
	Limit = AutoMetal:CreateToggle({Name = 'Limit to item'})

	StreamerMode = AutoMetal:CreateToggle({
		Name = 'Streamer mode',
		Function = function(call)
			if Duration then
				Duration.Object.Visible = not call
				Range.Object.Visible = not call
				Animation.Object.Visible = not call
			end
		end,
		Tooltip = 'Actually does the metal prompt thing for you'
	})
	Animation = AutoMetal:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays the metal collect animation'
	})
	Range = AutoMetal:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = Legit,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end
	})
	AutoMetal:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Duration = AutoMetal:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 5,
		Suffix = function(val)
			return val > 1 and 'secs' or 'sec'
		end
	})
end)

run(function()
	local AutoMushroom
	local Ingredient
	local Delay
	local nextAdd = 0

	local ingredients = {
		Mushrooms = 'alchemist_add_mushrooms',
		Flowers = 'alchemist_add_flower',
		Thorns = 'alchemist_add_thorns'
	}

	AutoMushroom = kits:CreateModule({
		Name = 'AutoMushroom',
		Function = function(callback)
			if callback then
				nextAdd = 0

				repeat
					local ability = ingredients[Ingredient.Value]
					if entitylib.isAlive and store.equippedKit == 'alchemist' and tick() >= nextAdd and bedwars.AbilityController:canUseAbility(ability, {disableBlockedAbilityAlert = true}) then
						nextAdd = tick() + Delay.Value
						bedwars.AbilityController:useAbility(ability)
					end
					task.wait(0.1)
				until not AutoMushroom.Enabled
			end
		end,
		Tooltip = 'Automatically tops the alchemist flask up with an ingredient'
	})
	Ingredient = AutoMushroom:CreateDropdown({
		Name = 'Ingredient',
		List = {'Mushrooms', 'Flowers', 'Thorns'}
	})
	Delay = AutoMushroom:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 0.5,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)

run(function()
	local AutoNahila
	local Health
	local Range
	local Allies

	AutoNahila = kits:CreateModule({
		Name = 'AutoNahila',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'oasis' and bedwars.AbilityController:canUseAbility('oasis_heal_veil', {disableBlockedAbilityAlert = true}) then
						local character = entitylib.character
						local hurt = (character.Health / character.MaxHealth) <= (Health.Value / 100)

						if not hurt and Allies.Enabled then
							local origin = character.RootPart.Position
							for _, v in entitylib.List do
								if not v.Targetable and v.Player and v ~= character and (v.RootPart.Position - origin).Magnitude <= Range.Value and (v.Health / v.MaxHealth) <= (Health.Value / 100) then
									hurt = true
									break
								end
							end
						end

						if hurt then
							bedwars.AbilityController:useAbility('oasis_heal_veil')
						end
					end
					task.wait(0.1)
				until not AutoNahila.Enabled
			end
		end,
		Tooltip = 'Automatically drops the heal veil when you or a teammate is hurt'
	})
	Health = AutoNahila:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 60,
		Suffix = function()
			return '%'
		end,
		Tooltip = 'Heals at or below this much health'
	})
	Allies = AutoNahila:CreateToggle({
		Name = 'Heal teammates',
		Default = true
	})
	Range = AutoNahila:CreateSlider({
		Name = 'Ally range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local AutoNazar
	local Consume
	local Health
	local Force
	local Empower
	local Range
	local empowered = false

	AutoNazar = kits:CreateModule({
		Name = 'AutoNazar',
		Function = function(callback)
			if callback then
				empowered = false
				AutoNazar:Clean(lplr.CharacterAdded:Connect(function()
					empowered = false
				end))

				repeat
					if entitylib.isAlive and store.equippedKit == 'nazar' then
						local character = entitylib.character
						local lifeForce = lplr:GetAttribute('LifeForce') or 0

						if Consume.Enabled and lifeForce >= Force.Value and (character.Health / character.MaxHealth) <= (Health.Value / 100) and bedwars.AbilityController:canUseAbility('consume_life_foce', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('consume_life_foce')
						end

						if Empower.Enabled then
							local wanted = entitylib.EntityPosition({
								Origin = character.RootPart.Position,
								Range = Range.Value,
								Part = 'RootPart',
								Players = true
							}) and true or false
							if wanted ~= empowered then
								local ability = wanted and 'enable_life_force_attack' or 'disable_life_force_attack'
								if bedwars.AbilityController:canUseAbility(ability, {disableBlockedAbilityAlert = true}) then
									bedwars.AbilityController:useAbility(ability)
									empowered = wanted
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoNazar.Enabled
			end
		end,
		Tooltip = 'Automatically spends life force to heal and empowers attacks near enemies'
	})
	Health = AutoNazar:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 70,
		Suffix = function()
			return '%'
		end,
		Tooltip = 'Consumes once your health drops below this'
	})
	Force = AutoNazar:CreateSlider({
		Name = 'Life force',
		Min = 1,
		Max = 150,
		Default = 35,
		Tooltip = 'Life force you need stored before consuming'
	})
	Range = AutoNazar:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Consume = AutoNazar:CreateToggle({
		Name = 'Consume life force',
		Default = true,
		Function = function(callback)
			Health.Object.Visible = callback
			Force.Object.Visible = callback
		end,
		Tooltip = 'Converts stored life force into health when hurt'
	})
	Empower = AutoNazar:CreateToggle({
		Name = 'Empower attacks',
		Default = true,
		Function = function(callback)
			Range.Object.Visible = callback
		end,
		Tooltip = 'Enables empowered attacks while an enemy is close and disables them after'
	})
end)

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

run(function()
	local AutoNyx
	local Targets

	AutoNyx = kits:CreateModule({
		Name = 'AutoNyx',
		Function = function(call)
			if call then
				AutoNyx:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
					if damageTable.damageType == 0 and damageTable.fromEntity and damageTable.fromEntity.Name == lplr.Name and entitylib.EntityPosition({
						Range = 14.4,
						Part = 'RootPart',
						Players = Targets.Players.Enabled,
						NPCs = Targets.NPCs.Enabled
					}) and bedwars.AbilityController:canUseAbility('midnight', {disableBlockedAbilityAlert = true}) then
						bedwars.AbilityController:useAbility('midnight')
					end
				end))
			end
		end,
		Tooltip = 'Automatically uses the "midnight" ability when meleeing a target'
	})
	Targets = AutoNyx:CreateTargets({
		Players = true,
		NPCs = false
	})
end)

run(function()
	local AutoPickpocket
	local Targets
	local Range
	local Hidden

	local Legit = getFunctionRange(bedwars.MimicController.onKitLocalActivated) or 25
	local mimicPickPocket = bedwars.Handler:Get('MimicBlockPickPocketPlayer')
	local sounds = {bedwars.SoundList.MIMIC_PICKPOCKET_1, bedwars.SoundList.MIMIC_PICKPOCKET_2, bedwars.SoundList.MIMIC_PICKPOCKET_3}
	local random = Random.new()

	AutoPickpocket = kits:CreateModule({
		Name = 'AutoPickpocket',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						local targets = entitylib.AllPosition({
							Range = Range.Value,
							Origin = localPosition,
							Wallcheck = Targets.Walls.Enabled or nil,
							Part = 'RootPart',
							Players = true,
							Sort = sortmethods.Distance
						})

						for _, v in targets do
							if mimicPickPocket:Fire('CallServer', v.Player) then
								bedwars.AudioManager:playAudio(sounds[random:NextInteger(1, #sounds)], {
									playbackSpeedMultiplier = 1.27,
									position = localPosition
								})
							end
						end

						if #targets <= 0 and Hidden.Enabled and store.equippedKit == 'mimic' and bedwars.AbilityController:canUseAbility('MIMIC_BLOCK_HIDDEN', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('MIMIC_BLOCK_HIDDEN')
						end
					end
					task.wait(0.1)
				until not AutoPickpocket.Enabled
			end
		end,
		Tooltip = 'Automatically pickpockets with milo kit.'
	})
	Targets = AutoPickpocket:CreateTargets({Players = true, Walls = true})

	Range = AutoPickpocket:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = Legit,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	AutoPickpocket:CreateButton({
		Name = 'Sync to legit range',
		Function = function()
			Range:SetValue(Legit)
		end
	})
	Hidden = AutoPickpocket:CreateToggle({
		Name = 'Hide when clear',
		Tooltip = 'Goes back into the block once nobody is in range'
	})
end)

run(function()
	local AutoPyro
	local Delay

	local list = {'Range', 'Heat', 'Power'}

	AutoPyro = kits:CreateModule({
		Name = 'AutoPyro',
		Function = function(callback)
			if callback then
				repeat
					local flamethrower = getItem('flamethrower')
					if flamethrower then
						for _, v in list do
							local upgrade = v:lower()
							local value = flamethrower.tool:GetAttribute(upgrade) or -1
							local nextUpgrade = AutoPyro.Options[`Buy {v}`].Enabled and value < 3 and bedwars.PyroUpgradeMeta[upgrade].tiers[value + 2]

							if nextUpgrade then
								local currency = getItem(nextUpgrade.currency)
								if currency and currency.amount >= nextUpgrade.price then
									bedwars.Handler:Get('UpgradeFlamethrower'):Fire('CallServer', upgrade)
									task.wait(Delay.Value)
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoPyro.Enabled
			end
		end,
		Tooltip = 'Automatically upgrades flamethrower'
	})
	Delay = AutoPyro:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 2,
		Default = 0.1,
		Decimal = 100,
		Suffix = 'seconds',
		Tooltip = 'Wait between each upgrade it buys'
	})
	for _, v in list do
		AutoPyro:CreateToggle({
			Name = `Buy {v}`,
			Default = true
		})
	end
end)

run(function()
	local AutoRagnar

	local function getBed()
		local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
		for _, v in collectionService:GetTagged('bed') do
			if (localPosition - v.Position).Magnitude <= 22 and not v:GetAttribute(`Team{lplr:GetAttribute('Team') or -1}NoBreak`) then
				return v
			end
		end
		return
	end

	AutoRagnar = kits:CreateModule({
		Name = 'AutoRagnar',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'berserker' and bedwars.AbilityController:canUseAbility('berserker_rage', {disableBlockedAbilityAlert = true}) and getBed() then
						bedwars.AbilityController:useAbility('berserker_rage')
					end
					task.wait(0.1)
				until not AutoRagnar.Enabled
			end
		end,
		Tooltip = 'Automatically uses "Berserker Rage" ability when near\nopponent\'s bed.'
	})
end)

run(function()
	local AutoRamil
	local Range
	local Sorts
	local Targets
	local UseTornado
	local TornadoRange

	AutoRamil = kits:CreateModule({
		Name = 'AutoRamil',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'airbender' then
						local localPosition = entitylib.character.RootPart.Position
						local ent = entitylib.EntityPosition({
							Origin = localPosition,
							Range = UseTornado.Enabled and TornadoRange.Value > Range.Value and TornadoRange.Value or Range.Value,
							Wallcheck = Targets.Walls.Enabled,
							Players = Targets.Players.Enabled,
							NPCs = Targets.NPCs.Enabled,
							Sort = sortmethods[Sorts.Value]
						})
						local mag = ent and (localPosition - ent.RootPart.Position).Magnitude or math.huge

						if mag <= Range.Value and bedwars.AbilityController:canUseAbility('airbender_tornado', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('airbender_tornado')
						end

						if UseTornado.Enabled and mag <= TornadoRange.Value and bedwars.AbilityController:canUseAbility('airbender_moving_tornado', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('airbender_moving_tornado')
						end
					end
					task.wait()
				until not AutoRamil.Enabled
			end
		end,
		Tooltip = 'Automatically use ramil abilities on certain conditions.'
	})
	Targets = AutoRamil:CreateTargets({
		Players = true,
		NPCs = false
	})
	local methods = {'Damage', 'Distance'}
	for _, i in sortlist do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end

	Sorts = AutoRamil:CreateDropdown({
		Name = 'Target Mode',
		List = methods,
		Default = 'Distance'
	})
	Range = AutoRamil:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 25,
		Default = 25,
		Suffix = function(val)
			return val >= 1 and 'studs' or 'stud'
		end
	})
	UseTornado = AutoRamil:CreateToggle({
		Name = 'Use Moving Tornado',
		Function = function(call)
			if TornadoRange then
				TornadoRange.Object.Visible = call
			end
		end
	})
	TornadoRange = AutoRamil:CreateSlider({
		Name = 'Tornado Range',
		Min = 1,
		Max = 35,
		Default = 25,
		Darker = true,
		Visible = false,
		Suffix = function(val)
			return val >= 1 and 'studs' or 'stud'
		end
	})
end)

run(function()
	local AutoSheep
	local Delay
	local Range
	local Infinite

	AutoSheep = kits:CreateModule({
		Name = 'AutoSheepHerder',
		Function = function(callback)
			if callback then
				local tameSheep = bedwars.Client:GetNamespace('SheepHerder'):Get('TameSheep')

				repeat
					local model = workspace:FindFirstChild('SheepModel')
					if entitylib.isAlive and model then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in model:GetChildren() do
							if v.PrimaryPart and (Infinite.Enabled or (localPosition - v.PrimaryPart.Position).Magnitude <= Range.Value) then
								if Delay.Value > 0 then
									task.wait(Delay.Value)
								end
								tameSheep:SendToServer(v.SheepData.Value)
							end
						end
					end
					task.wait(0.1)
				until not AutoSheep.Enabled
			end
		end,
		Tooltip = 'Automatically tames sheep within range.'
	})
	Range = AutoSheep:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 200,
		Default = 20,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Infinite = AutoSheep:CreateToggle({
		Name = 'Infinite range',
		Tooltip = 'Tames every sheep on the map, the server may still reject far ones'
	})
	Delay = AutoSheep:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.1,
		Decimal = 100
	})
end)

run(function()
	local AutoShielderUlt
	local Range
	local Targets
	local Delay
	local nextUlt = 0

	AutoShielderUlt = kits:CreateModule({
		Name = 'AutoShielderUlt',
		Function = function(callback)
			if callback then
				nextUlt = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'shielder' and tick() >= nextUlt then
						local origin = entitylib.character.RootPart.Position
						local found = 0
						for _, v in entitylib.List do
							if v.Targetable and (v.RootPart.Position - origin).Magnitude <= Range.Value then
								found += 1
							end
						end

						if found >= Targets.Value then
							nextUlt = tick() + Delay.Value
							bedwars.InfernalShieldController:useUlt()
						end
					end
					task.wait(0.1)
				until not AutoShielderUlt.Enabled
			end
		end,
		Tooltip = 'Automatically slams the infernal shield once enough enemies are around you'
	})
	Range = AutoShielderUlt:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Targets = AutoShielderUlt:CreateSlider({
		Name = 'Targets',
		Min = 1,
		Max = 8,
		Default = 1,
		Tooltip = 'Enemies in range before slamming'
	})
	Delay = AutoShielderUlt:CreateSlider({
		Name = 'Delay',
		Min = 0.5,
		Max = 10,
		Default = 2,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)

run(function()
	local AutoSilas
	local SwapAura
	local PressAttack
	local Range
	local aura = ''

	local function getHurtAlly(origin)
		for _, v in entitylib.List do
			if v.Player and v.Player:GetAttribute('Team') == lplr:GetAttribute('Team') and v.Health < v.MaxHealth and (v.RootPart.Position - origin).Magnitude <= Range.Value then
				return v
			end
		end
		return nil
	end

	AutoSilas = kits:CreateModule({
		Name = 'AutoSilas',
		Function = function(callback)
			if callback then
				aura = ''
				AutoSilas:Clean(bedwars.Handler:Get('UpdateRebellionAura').Remote:Connect(function(data)
					if data.player == lplr then
						aura = data.newAura
					end
				end))

				repeat
					if entitylib.isAlive and store.equippedKit == 'rebellion_leader' then
						local origin = entitylib.character.RootPart.Position
						local enemy = entitylib.EntityPosition({
							Origin = origin,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true
						})

						if PressAttack.Enabled and enemy and bedwars.AbilityController:canUseAbility('rebellion_shield', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('rebellion_shield')
						end

						if SwapAura.Enabled then
							local wanted = enemy and 'damage' or getHurtAlly(origin) and 'healing' or nil
							if wanted and aura ~= '' and aura ~= wanted and bedwars.AbilityController:canUseAbility('rebellion_aura_swap', {disableBlockedAbilityAlert = true}) then
								bedwars.AbilityController:useAbility('rebellion_aura_swap')
							end
						end
					end
					task.wait(0.1)
				until not AutoSilas.Enabled
			end
		end,
		Tooltip = 'Automatically swaps your aura and rallies your team'
	})
	Range = AutoSilas:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	SwapAura = AutoSilas:CreateToggle({
		Name = 'Swap aura',
		Default = true,
		Tooltip = 'Uses the damage aura near enemies and the healing aura near hurt allies'
	})
	PressAttack = AutoSilas:CreateToggle({
		Name = 'Press the attack',
		Default = true,
		Tooltip = 'Uses the shield ability when an enemy gets close'
	})
end)

run(function()
	local AutoSmoke
	local Range
	local Health
	local Delay
	local nextBomb = 0

	AutoSmoke = kits:CreateModule({
		Name = 'AutoSmoke',
		Function = function(callback)
			if callback then
				nextBomb = 0

				repeat
					local bomb = entitylib.isAlive and store.equippedKit == 'smoke' and tick() >= nextBomb and getItem('smoke_bomb') or nil
					if bomb and entitylib.character.Health <= (entitylib.character.MaxHealth * (Health.Value / 100)) then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true
						})

						if target then
							nextBomb = tick() + Delay.Value
							bedwars.Handler:Get('ConsumeItem'):Fire('CallServer', {item = bomb.tool})
						end
					end
					task.wait(0.1)
				until not AutoSmoke.Enabled
			end
		end,
		Tooltip = 'Automatically pops a smoke bomb when you are low with enemies nearby'
	})
	Range = AutoSmoke:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Health = AutoSmoke:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 50,
		Suffix = function()
			return '%'
		end,
		Tooltip = 'Pops the bomb at or below this much health'
	})
	Delay = AutoSmoke:CreateSlider({
		Name = 'Delay',
		Min = 0.5,
		Max = 15,
		Default = 5,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)

run(function()
	local AutoSophia
	local Targets
	local Range
	local FireRate
	local SwitchDelay
	local nextFire = 0
	local nextSwap = 0

	local staffs = {'frost_staff_3', 'frost_staff_2', 'frost_staff_1'}

	local function getStaff()
		for _, itemType in staffs do
			local item = getItem(itemType)
			if item then
				return item, itemType
			end
		end
		return nil
	end

	local function shootStaff()
		local item, itemType = getStaff()
		local source = item and bedwars.ItemMeta[itemType].projectileSource or nil
		local target = source and getFacingEntity({
			Part = 'RootPart',
			Range = Range.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled,
			Limit = 10
		}) or nil
		if not target then return end

		local ready = bedwars.FrostyGunController.projectileMode == bedwars.FrostyGunMode.PROJECTILE
		local swapping = not ready and tick() >= nextSwap and bedwars.AbilityController:canUseAbility('frosty_gun_swap', {disableBlockedAbilityAlert = true})
		if not ready and not swapping then return end

		local hotbar = store.hand.tool and getHotbar(store.hand.tool) or nil
		if hotbarSwitch(getHotbar(item.tool)) then
			task.wait(store.ping.total or 0)
			if ready then
				if fireProjectile(item, itemType, source.projectileType(itemType), target) then
					nextFire = tick() + source.fireDelaySec + FireRate:GetRandomValue()
					task.wait(SwitchDelay.Value)
				end
			else
				nextSwap = tick() + 1
				bedwars.AbilityController:useAbility('frosty_gun_swap')
				task.wait(SwitchDelay.Value)
			end
			hotbarSwitch(hotbar)
		end
	end

	AutoSophia = kits:CreateModule({
		Name = 'AutoSophia',
		Function = function(callback)
			if callback then
				nextFire, nextSwap = 0, 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'winter_lady' and store.hand.toolType == 'sword' and (tick() - bedwars.SwordController.lastSwing) < 0.2 and tick() >= nextFire then
						shootStaff()
					end
					task.wait(0.1)
				until not AutoSophia.Enabled
			end
		end,
		Tooltip = 'Automatically shoots Sophia\'s frost staff at whoever you\'re meleeing, swapping it out of mist mode when needed'
	})
	Targets = AutoSophia:CreateTargets({
		Players = true,
		NPCs = false
	})
	Range = AutoSophia:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 22,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	FireRate = AutoSophia:CreateTwoSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 1,
		DefaultMin = 0.05,
		DefaultMax = 0.12,
		Decimal = 100
	})
	SwitchDelay = AutoSophia:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = 'seconds',
		Default = 0.02
	})
end)

run(function()
	local AutoStar
	local Streamer
	local Range
	local Animation
	local Delay

	local cooldowns = {}

	AutoStar = kits:CreateModule({
		Name = 'AutoStarCollector',
		Function = function(callback)
			if callback then
				AutoStar:Clean(proximityPromptService.PromptShown:Connect(function(prompt)
					if Streamer.Enabled and prompt.Name == 'stars_ProximityPrompt' then
						task.wait(0.1)
						prompt:InputHoldBegin()
					end
				end))

				repeat
					if not Streamer.Enabled and entitylib.isAlive then
						local localPosition = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('stars') do
							if tick() > (cooldowns[v] or 0) and v.PrimaryPart and (localPosition - v.PrimaryPart.Position).Magnitude <= Range.Value then
								if Delay.Value > 0 then
									task.wait(Delay.Value)
								end

								if (localPosition - v.PrimaryPart.Position).Magnitude <= Range.Value then
									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.PUNCH)
										bedwars.ViewmodelController:playAnimation(bedwars.AnimationType.FP_USE_ITEM)
									end

									bedwars.StarCollectorController:collectEntity(lplr, v, v.Name)
									cooldowns[v] = tick() + 1
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoStar.Enabled
			else
				table.clear(cooldowns)
			end
		end,
		Tooltip = 'Automatically collects stars'
	})
	Streamer = AutoStar:CreateToggle({
		Name = 'Streamer mode',
		Function = function(call)
			if Delay then
				Delay.Object.Visible = not call
				Range.Object.Visible = not call
				Animation.Object.Visible = not call
			end
		end,
		Tooltip = 'Useful for when ur screensharing'
	})
	Animation = AutoStar:CreateToggle({
		Name = 'Animation',
		Default = true,
		Tooltip = 'Plays the collect animation'
	})
	Range = AutoStar:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 20,
		Default = 12,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end
	})
	Delay = AutoStar:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 1,
		Default = 0.2,
		Decimal = 100,
		Suffix = function(val)
			return val > 1 and 'secs' or 'sec'
		end
	})
end)

run(function()
	local AutoTaliyah
	local Emerald
	local Diamond
	local Iron
	local Amount

	local function getShopId()
		if entitylib.isAlive then
			local localPosition = entitylib.character.RootPart.Position
			for _, v in store.shop do
				if v.Shop and (v.RootPart.Position - localPosition).Magnitude <= 20 then
					return v.Id
				end
			end
		end
		return
	end

	AutoTaliyah = kits:CreateModule({
		Name = 'AutoTaliyah',
		Function = function(callback)
			if callback then
				local item = bedwars.Shop.getShopItem('chicken_shop_item', lplr)

				repeat
					local id = getShopId()
					if id then
						local chickenData = bedwars.TaliyahUtil:getPrice()
						if (chickenData.currency == 'emerald' and Emerald.Enabled or chickenData.currency == 'iron' and Iron.Enabled or chickenData.currency == 'diamond' and Diamond.Enabled) and chickenData.price >= Amount.Value then
							bedwars.Handler:Get('BedwarsPurchaseItem'):Fire('CallServerAsync', {
								shopItem = item,
								shopId = id
							}):andThen(function(suc)
								if suc then
									bedwars.AudioManager:playAudio(bedwars.SoundList.BEDWARS_PURCHASE_ITEM)
									bedwars.Store:dispatch({
										type = 'BedwarsAddItemPurchased',
										itemType = item.itemType
									})
									bedwars.BedwarsShopController.alreadyPurchasedMap[item.itemType] = true
								end
							end)
						end
					end
					task.wait(0.1)
				until not AutoTaliyah.Enabled
			end
		end,
		Tooltip = 'Automatically buy chickens when it sells for emerald'
	})
	Iron = AutoTaliyah:CreateToggle({
		Name = 'Iron',
		Default = true,
		Tooltip = 'Sells ur chicken when the currency is iron'
	})
	Emerald = AutoTaliyah:CreateToggle({
		Name = 'Emerald',
		Default = true,
		Tooltip = 'Sells ur chicken when the currency is emerald'
	})
	Diamond = AutoTaliyah:CreateToggle({
		Name = 'Diamond',
		Default = true,
		Tooltip = 'Sells ur chicken when the currency is diamond'
	})
	Amount = AutoTaliyah:CreateSlider({
		Name = 'Amount',
		Min = 1,
		Max = 1000,
		Default = 2,
		Tooltip = 'Only sells if the currency is selling for the selected amount'
	})
end)

run(function()
	local AutoTriton
	local Legit
	local Back
	local BackDelay
	local Limit

	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	rayCheck.FilterType = Enum.RaycastFilterType.Include
	local projectileRemote = {InvokeServer = function(self, ...) end}
	task.spawn(function()
		projectileRemote = bedwars.Handler:Get('ProjectileFire').Remote.instance
	end)

	local function firePearl(pos, spot, item)
		local hotbar, old = getHotbar(item.tool), store.hand

		switchItem(item.tool)
		if Legit.Enabled and hotbar then
			hotbarSwitch(hotbar)
		end

		local meta = bedwars.ProjectileMeta.harpoon_projectile
		local calc = prediction.SolveTrajectory(pos, meta.launchVelocity, meta.gravitationalAcceleration, spot, Vector3.zero, workspace.Gravity, 0, 0)
		local landed = false

		if calc then
			local dir = CFrame.lookAt(pos, calc).LookVector * meta.launchVelocity
			local projectile = bedwars.ProjectileController:createLocalProjectile(meta, 'harpoon_projectile', 'harpoon_projectile', pos, nil, dir, {drawDurationSeconds = 1})
			local res = projectileRemote:InvokeServer(
				item.tool,
				'harpoon_projectile',
				'harpoon_projectile',
				pos,
				pos,
				dir,
				httpService:GenerateGUID(true),
				{
					drawDurationSeconds = 1,
					shotId = httpService:GenerateGUID(false)
				},
				workspace:GetServerTimeNow() - 0.045
			)
			task.spawn(function()
				local timeout = tick() + 10
				repeat
					task.wait()
				until not AutoTriton.Enabled or not projectile or not projectile.Parent or tick() >= timeout
				landed = true
			end)
			if res then
				pcall(function()
					res.Parent = replicatedStorage
				end)
			end
		else
			landed = true
		end

		repeat
			task.wait()
		until landed or not AutoTriton.Enabled
		if Back.Enabled and old and old.tool then
			task.wait(BackDelay:GetRandomValue())
			switchItem(old.tool)
			if Legit.Enabled and getHotbar(old.tool) then
				hotbarSwitch(getHotbar(old.tool))
			end
		end
	end

	local function findNearGround(origin)
		for _, v in {Vector3.new(1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(-1, 0, 0), Vector3.new(0, 0, -1)} do
			for i = 1, 24 do
				local ray = workspace:Raycast((origin.Position + (Vector3.yAxis * 3)) + (v * i), Vector3.new(0, -60, 0), rayCheck)
				if ray then
					return ray.Position
				end
			end
		end
		return nil
	end

	AutoTriton = kits:CreateModule({
		Name = 'AutoTriton',
		Function = function(callback)
			if callback then
				local check, lasty
				repeat
					if entitylib.isAlive and (not Limit.Enabled or store.hand.tool and store.hand.tool.Name == 'harpoon') then
						local root = entitylib.character.RootPart
						local pearl = getItem('harpoon')
						rayCheck.FilterDescendantsInstances = {store.map}
						rayCheck.CollisionGroup = root.CollisionGroup

						if entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air then
							lasty = root.CFrame
						end

						if pearl and root.Velocity.Y < -60 and not workspace:Raycast(root.Position, Vector3.new(0, -200, 0), rayCheck) then
							if not check then
								check = true
								local ground = findNearGround(root.CFrame + Vector3.new(0, 40, 0)) or findNearGround(lasty and lasty + Vector3.new(0, 5, 0) or root.CFrame)
								if ground then
									firePearl(root.Position, ground, pearl)
								end
							end
						else
							check = false
						end
					end
					task.wait(0.1)
				until not AutoTriton.Enabled
			end
		end,
		Tooltip = 'Automatically throws triton trident onto nearby ground after\nfalling a certain distance.'
	})
	Legit = AutoTriton:CreateToggle({
		Name = 'Legit Switch',
		Tooltip = 'Visualizes the switching clientside',
		Default = true
	})
	Back = AutoTriton:CreateToggle({
		Name = 'Switch back',
		Default = true,
		Function = function(callback)
			if BackDelay then
				BackDelay.Object.Visible = callback
			end
		end,
		Tooltip = 'Switches back to the last slot before pearl'
	})
	BackDelay = AutoTriton:CreateTwoSlider({
		Name = 'Switch Back Delay',
		Min = 0,
		Max = 2,
		DefaultMin = 0.1,
		DefaultMax = 0.2,
		Darker = true
	})
	Limit = AutoTriton:CreateToggle({
		Name = 'Limit to item',
		Tooltip = 'Only throws pearl when holding a pearl'
	})
end)

run(function()
	local AutoUma
	local Range
	local Limit
	local Animation
	local AutoSummon
	local HealSpirit
	local AttackSpirit
	local TargetItemDrops
	local Diamond
	local Emerald

	local function getAttackData()
		if Limit.Enabled then
			local tool = (store.hand.tool and store.hand.tool.Name == 'spirit_staff') and store.hand.tool or nil
			return tool, tool and getHotbar(tool) or nil
		end
		for i, v in store.inventory.inventory.items do
			if v.itemType == 'spirit_staff' then
				switchItem(v, 0)
				return v, i
			end
		end
		return
	end

	local function getDrops(localPosition, ItemDrops)
		local drop, lastmag = nil, Range.Value + 1
		for i, v in ItemDrops do
			if v.Name == 'emerald' and Emerald.Enabled or v.Name == 'diamond' and Diamond.Enabled then
				local magnitude = (localPosition - v.Position).Magnitude
				if magnitude <= lastmag and not entitylib.Wallcheck(localPosition, v.Position, {gameCamera, lplr.Character, v}) then
					drop, lastmag = v, magnitude
				end
			end
		end
		return drop
	end

	AutoUma = kits:CreateModule({
		Name = 'AutoUma',
		Function = function(call)
			if call then
				local items = collection('ItemDrop', AutoUma)
				repeat
					local staff = getAttackData()
					if staff then
						if TargetItemDrops.Enabled then
							local attackSpirits = (lplr:GetAttribute('ReadySummonedAttackSpirits') or 0)
							local healSpirits = (lplr:GetAttribute('ReadySummonedHealSpirits') or 0)

							if AutoSummon.Enabled then
								if AttackSpirit.Enabled and attackSpirits < 1 and getItem('summon_stone') then
									bedwars.AbilityController:useAbility('summon_attack_spirit')
								end

								if HealSpirit.Enabled and healSpirits < 1 and getItem('summon_stone') then
									bedwars.AbilityController:useAbility('summon_heal_spirit')
								end
							end

							if (healSpirits + attackSpirits) > 0 then
								local localPosition = entitylib.character.RootPart.Position
								local drop = getDrops(localPosition, items)

								if drop then
									local shootpos = localPosition + Vector3.new(0, 2, 0)
									local dir = CFrame.lookAt(localPosition, drop.Position + Vector3.new(0, (localPosition - drop.Position).Magnitude / 5, 0)).LookVector * 100

									bedwars.Handler:Get('ProjectileFire').Remote.instance:InvokeServer(
										staff,
										nil,
										attackSpirits > 0 and 'attack_spirit' or 'heal_spirit',
										shootpos,
										localPosition,
										dir,
										httpService:GenerateGUID(),
										{
											drawDurationSeconds = 1,
											shotId = httpService:GenerateGUID(false),
										},
										workspace:GetServerTimeNow() - 0.045
									)

									if Animation.Enabled then
										bedwars.GameAnimationUtil:playAnimation(lplr.Character, bedwars.AnimationType.WIZARD_BALL_CAST)
										bedwars.AudioManager:playAudio(bedwars.SoundList.SPIRIT_SUMMONER_CHANGE_AFFINITY, {})
									end

									task.wait(1.5)
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoUma.Enabled
			end
		end,
		Tooltip = 'Automatically throw spirits at item drops and opponents.'
	})
	Range = AutoUma:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 80,
		Default = 50,
		Decimal = 5,
		Suffix = function(val)
			return val >= 2 and 'studs' or 'stud'
		end
	})
	Animation = AutoUma:CreateToggle({
		Name = 'Animation',
		Default = true
	})
	Limit = AutoUma:CreateToggle({
		Name = 'Limit to item',
		Default = true
	})
	AutoSummon = AutoUma:CreateToggle({
		Name = 'Auto Summon',
		Function = function(call)
			if AttackSpirit then
				AttackSpirit.Object.Visible = call
				HealSpirit.Object.Visible = call
			end
		end,
		Tooltip = 'Automattically summons spirit for you'
	})
	HealSpirit = AutoUma:CreateToggle({
		Name = 'Use heal spirit',
		Default = true,
		Visible = false,
		Darker = true
	})
	AttackSpirit = AutoUma:CreateToggle({
		Name = 'Use attack spirit',
		Default = true,
		Visible = false,
		Darker = true
	})
	TargetItemDrops = AutoUma:CreateToggle({
		Name = 'Target item drops',
		Default = true,
		Function = function(call)
			if Emerald then
				Emerald.Object.Visible = call
				Diamond.Object.Visible = call
			end
		end
	})
	Emerald = AutoUma:CreateToggle({
		Name = 'Emerald',
		Darker = true,
		Default = true
	})
	Diamond = AutoUma:CreateToggle({
		Name = 'Diamond',
		Darker = true,
		Default = true
	})
end)

run(function()
	local old, overcharge

	kits:CreateModule({
		Name = 'AutoVanessa',
		Function = function(callback)
			if callback then
				old = bedwars.TripleShotProjectileController.getChargeTime
				overcharge = bedwars.TripleShotProjectileController.overchargeStartTime
				bedwars.TripleShotProjectileController.getChargeTime = function()
					return 0
				end
				bedwars.TripleShotProjectileController.overchargeStartTime = tick()
			else
				bedwars.TripleShotProjectileController.getChargeTime = old
				bedwars.TripleShotProjectileController.overchargeStartTime = overcharge
			end
		end,
		Tooltip = 'Fully charges your bow instantly and enables triple shot as Vanessa'
	})
end)

run(function()
	local AutoVoidHunter
	local Range
	local Detonate

	AutoVoidHunter = kits:CreateModule({
		Name = 'AutoVoidHunter',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'void_hunter' then
						if Detonate.Enabled and bedwars.AbilityController:canUseAbility('void_hunter_detonate', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('void_hunter_detonate')
						elseif bedwars.AbilityController:canUseAbility('void_hunter_mark', {disableBlockedAbilityAlert = true}) then
							local target = entitylib.EntityPosition({
								Origin = entitylib.character.RootPart.Position,
								Range = Range.Value,
								Part = 'RootPart',
								Players = true,
								Wallcheck = true
							})

							if target then
								bedwars.AbilityController:useAbility('void_hunter_mark')
							end
						end
					end
					task.wait(0.1)
				until not AutoVoidHunter.Enabled
			end
		end,
		Tooltip = 'Automatically marks whoever is near you and sets the mark off'
	})
	Range = AutoVoidHunter:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 100,
		Default = 50,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Detonate = AutoVoidHunter:CreateToggle({
		Name = 'Auto detonate',
		Default = true,
		Tooltip = 'Sets the mark off as soon as the game lets you'
	})
end)

run(function()
	local AutoVoidKnight
	local Iron
	local Emeralds
	local Keep
	local Ascend
	local Range

	local function feed(itemType, ability)
		local item = getItem(itemType)
		if item and item.amount > Keep.Value and bedwars.AbilityController:canUseAbility(ability, {disableBlockedAbilityAlert = true}) then
			bedwars.AbilityController:useAbility(ability)
		end
	end

	AutoVoidKnight = kits:CreateModule({
		Name = 'AutoVoidKnight',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'void_knight' then
						if Iron.Enabled then
							feed('iron', 'void_knight_consume_iron')
						end

						if Emeralds.Enabled then
							feed('emerald', 'void_knight_consume_emerald')
						end

						if Ascend.Enabled and bedwars.AbilityController:canUseAbility('void_knight_ascend', {disableBlockedAbilityAlert = true}) then
							local near = entitylib.EntityPosition({
								Origin = entitylib.character.RootPart.Position,
								Range = Range.Value,
								Part = 'RootPart',
								Players = true
							})
							if near then
								bedwars.AbilityController:useAbility('void_knight_ascend')
							end
						end
					end
					task.wait(0.2)
				until not AutoVoidKnight.Enabled
			end
		end,
		Tooltip = 'Automatically feeds your resources into the void and ascends in fights'
	})
	Keep = AutoVoidKnight:CreateSlider({
		Name = 'Keep',
		Min = 0,
		Max = 64,
		Default = 0,
		Tooltip = 'Resources left untouched in your inventory'
	})
	Range = AutoVoidKnight:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Iron = AutoVoidKnight:CreateToggle({
		Name = 'Iron',
		Default = true
	})
	Emeralds = AutoVoidKnight:CreateToggle({
		Name = 'Emeralds',
		Default = true
	})
	Ascend = AutoVoidKnight:CreateToggle({
		Name = 'Ascend',
		Default = true,
		Tooltip = 'Uses void ascension when an enemy is close'
	})
end)

run(function()
	local AutoWarden
	local Range

	local collected = setmetatable({}, {__mode = 'k'})

	AutoWarden = kits:CreateModule({
		Name = 'AutoWarden',
		Function = function(callback)
			if callback then
				table.clear(collected)

				repeat
					if entitylib.isAlive and store.equippedKit == 'jailor' then
						local origin = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('jailor_soul') do
							if not collected[v] and v.PrimaryPart and (v.PrimaryPart.Position - origin).Magnitude <= Range.Value then
								collected[v] = true
								bedwars.JailorController:collectEntity(lplr, v, v.Name)
							end
						end
					end
					task.wait(0.1)
				until not AutoWarden.Enabled
			end
		end,
		Tooltip = 'Automatically imprisons the souls dropped by enemies you kill'
	})
	Range = AutoWarden:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
end)

run(function()
	local AutoWhim
	local Targets
	local Range
	local FireRate
	local SwitchDelay
	local nextFire = 0

	local function getSpellSource()
		local util = bedwars.MageKitUtil
		local element = bedwars.BalanceFile.MAGE_ELEMENT_CYCLE[(lplr:GetAttribute('MageElementIndex') or 0) + 1]
		if not element or table.find(util.getUnlockedMageElements(lplr), element) == nil then
			element = 'BASE'
		end

		local meta = util.MageElementMeta[element]
		return meta and meta.projectileSource or nil
	end

	local function castSpell()
		local item = getItem('mage_spellbook')
		local source = item and getSpellSource() or nil
		local target = source and getFacingEntity({
			Part = 'RootPart',
			Range = Range.Value,
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Wallcheck = Targets.Walls.Enabled,
			Limit = 10
		}) or nil
		if not target then return end

		local hotbar = store.hand.tool and getHotbar(store.hand.tool) or nil
		if hotbarSwitch(getHotbar(item.tool)) then
			task.wait(store.ping.total or 0)
			if fireProjectile(item, 'mage_spellbook', source.projectileType('mage_spellbook'), target) then
				nextFire = tick() + source.fireDelaySec + FireRate:GetRandomValue()
				task.wait(SwitchDelay.Value)
			end
			hotbarSwitch(hotbar)
		end
	end

	AutoWhim = kits:CreateModule({
		Name = 'AutoWhim',
		Function = function(callback)
			if callback then
				nextFire = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'mage' and store.hand.toolType == 'sword' and (tick() - bedwars.SwordController.lastSwing) < 0.2 and tick() >= nextFire then
						castSpell()
					end
					task.wait(0.1)
				until not AutoWhim.Enabled
			end
		end,
		Tooltip = 'Automatically casts Whim\'s magic book at whoever you\'re meleeing'
	})
	Targets = AutoWhim:CreateTargets({
		Players = true,
		NPCs = false
	})
	Range = AutoWhim:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 22,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	FireRate = AutoWhim:CreateTwoSlider({
		Name = 'Fire Rate',
		Min = 0,
		Max = 1,
		DefaultMin = 0.05,
		DefaultMax = 0.12,
		Decimal = 100
	})
	SwitchDelay = AutoWhim:CreateSlider({
		Name = 'Switch Delay',
		Min = 0,
		Max = 1,
		Decimal = 100,
		Suffix = 'seconds',
		Default = 0.02
	})
end)

run(function()
	local AutoWhisper
	local Heal
	local Threshold
	local Fly

	AutoWhisper = kits:CreateModule({
		Name = 'AutoWhisper',
		Function = function(callback)
			if callback then
				local lowestpoint = math.huge

				repeat
					task.wait()
				until store.matchState ~= 0 or not AutoWhisper.Enabled
				if not AutoWhisper.Enabled then
					return
				end

				for _, v in store.blocks do
					local point = (v.Position.Y - (v.Size.Y / 2)) - 50
					if point < lowestpoint then
						lowestpoint = point
					end
				end

				repeat
					local liftReady = Fly.Enabled and workspace:GetServerTimeNow() - (lplr:GetAttribute('OwlLiftReadyTime') or 0) > 0
					local healReady = Heal.Enabled and workspace:GetServerTimeNow() - (lplr:GetAttribute('OwlHealReadyTime') or 0) > 0

					if liftReady or healReady then
						for _, v in collectionService:GetTagged('Owl') do
							if v:GetAttribute('Owner') == lplr.UserId then
								local plr = playersService:GetPlayerByUserId(v:GetAttribute('Target'))
								local char = plr and plr.Character
								local root = char and char:FindFirstChild('HumanoidRootPart')

								if root then
									if liftReady and root.Velocity.Y < -10 and root.Position.Y < lowestpoint then
										bedwars.AbilityController:useAbility('OWL_LIFT')
									end

									local health = char:GetAttribute('Health')
									local maxHealth = char:GetAttribute('MaxHealth')
									if healReady and (Threshold.Value >= 100 or health and maxHealth and maxHealth > 0 and health / maxHealth <= Threshold.Value / 100) then
										bedwars.AbilityController:useAbility('OWL_HEAL')
									end
								end
								break
							end
						end
					end
					task.wait(0.1)
				until not AutoWhisper.Enabled
			end
		end,
		Tooltip = 'Automatically uses whisper abilities'
	})
	Heal = AutoWhisper:CreateToggle({
		Name = 'Heal',
		Default = true,
		Function = function(call)
			if Threshold then
				Threshold.Object.Visible = call
			end
		end
	})
	Threshold = AutoWhisper:CreateSlider({
		Name = 'Health',
		Min = 1,
		Max = 100,
		Default = 99,
		Darker = true,
		Suffix = '%'
	})
	Fly = AutoWhisper:CreateToggle({
		Name = 'Fly',
		Default = true
	})
end)

run(function()
	local AutoXurot
	local Range
	local Delay
	local FlapSpeed
	local dragonForm = false
	local nextBreath = 0
	local oldFlap, hookedFlap
	local flapped = false

	local Breath = bedwars.Handler:Get('DragonBreath')

	local function isLocal(data)
		if type(data) ~= 'table' then return true end
		return data.player == nil or data.player == lplr
	end

	AutoXurot = kits:CreateModule({
		Name = 'AutoXurot',
		Function = function(callback)
			if callback then
				dragonForm, nextBreath, flapped = false, 0, false

				
				
				local controller = bedwars.VoidDragonController
				if controller and type(controller.flapWings) == 'function' then
					oldFlap = controller.flapWings
					hookedFlap = function(self, ...)
						if not (AutoXurot.Enabled and FlapSpeed.Enabled and store.equippedKit == 'void_dragon') then
							return oldFlap(self, ...)
						end

						local handled = false
						pcall(function()
							if flapped or not bedwars.Handler:Get('DragonFlap'):Fire('CallServer') then return end
							local sprint = bedwars.SprintController
							local status = sprint and sprint.getMovementStatusModifier and sprint:getMovementStatusModifier()
							if not status then return end
							local modifier = status:addModifier({blockSprint = true, constantSpeedMultiplier = 2})
							self.SpeedMaid:GiveTask(modifier)
							self.SpeedMaid:GiveTask(function() flapped = false end)
							flapped, handled = true, true
						end)
						if handled then return end
						return oldFlap(self, ...)
					end
					controller.flapWings = hookedFlap
				end

				local action = bedwars.Handler:Get('VoidDragonAction')
				if action.Remote then
					AutoXurot:Clean(action.Remote:Connect(function(data)
						if isLocal(data) then
							if data.action == 'transform' then
								dragonForm = true
							elseif data.action == 'dragon_deactive' then
								dragonForm = false
							end
						end
					end))
				end

				local deactive = bedwars.Handler:Get('VoidDragonDeactive')
				if deactive.Remote then
					AutoXurot:Clean(deactive.Remote:Connect(function(data)
						if isLocal(data) then
							dragonForm = false
						end
					end))
				end

				AutoXurot:Clean(lplr.CharacterAdded:Connect(function()
					dragonForm = false
				end))

				repeat
					if dragonForm and entitylib.isAlive and store.equippedKit == 'void_dragon' and tick() >= nextBreath then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						})

						if target then
							nextBreath = tick() + Delay.Value
							Breath:Fire('SendToServer', {player = lplr, targetPoint = target.RootPart.Position})
						end
					end
					task.wait(0.05)
				until not AutoXurot.Enabled
			else
				local controller = bedwars.VoidDragonController
				if controller and oldFlap and controller.flapWings == hookedFlap then
					controller.flapWings = oldFlap
				end
				oldFlap, hookedFlap, flapped = nil, nil, false
			end
		end,
		Tooltip = 'Automatically breathes on enemies while you are in dragon form, with optional flap speed'
	})
	Range = AutoXurot:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 200,
		Default = 120,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoXurot:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.5,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
	FlapSpeed = AutoXurot:CreateToggle({
		Name = 'Flap speed',
		Default = true,
		Tooltip = 'Keeps Aether\'s Void Dragon flap speed boost'
	})
end)

run(function()
	local AutoYeti
	local Range
	local Targets

	AutoYeti = kits:CreateModule({
		Name = 'AutoYeti',
		Function = function(callback)
			if callback then
				repeat
					if entitylib.isAlive and store.equippedKit == 'yeti' and bedwars.AbilityController:canUseAbility('yeti_glacial_roar', {disableBlockedAbilityAlert = true}) then
						local origin = entitylib.character.RootPart.Position
						local found = 0
						for _, v in entitylib.List do
							if v.Targetable and (v.RootPart.Position - origin).Magnitude <= Range.Value then
								found += 1
							end
						end

						if found >= Targets.Value then
							bedwars.AbilityController:useAbility('yeti_glacial_roar')
						end
					end
					task.wait(0.1)
				until not AutoYeti.Enabled
			end
		end,
		Tooltip = 'Automatically roars once enough enemies are around you'
	})
	Range = AutoYeti:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 30,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Targets = AutoYeti:CreateSlider({
		Name = 'Targets',
		Min = 1,
		Max = 8,
		Default = 1,
		Tooltip = 'Enemies in range before roaring'
	})
end)

run(function()
	local AutoZeno
	local Targets
	local TargetMode
	local Limit
	local AutoShockWave
	local ShockwaveRange
	local UseStrike
	local UseStorm
	local Range
	local Delay

	local function getAttackData()
		if Limit.Enabled then
			local tool = store.hand.tool
			local itemType = tool and tool.Name
			if itemType and bedwars.WizardUtil:isWizardStaff(itemType) then
				return tool, itemType
			end
			return nil
		end

		for _, item in store.inventory.inventory.items do
			if bedwars.WizardUtil:isWizardStaff(item.itemType) and item.tool then
				switchItem(item.tool, 0)
				return item.tool, item.itemType
			end
		end

		return nil
	end

	local function canUseAbility(ability, itemType)
		if not bedwars.WizardUtil:hasAbility(itemType, ability) then return false end
		local controller = bedwars.WizardStaffController
		if not controller then return false end
		local success, allowed = pcall(controller.canCastAbility, controller, ability)
		if not success or not allowed then return false end
		success, allowed = pcall(bedwars.AbilityController.canUseAbility, bedwars.AbilityController, ability, {disableBlockedAbilityAlert = true})
		return success and allowed
	end

	local function useAbility(ability, target)
		local data = {
			target = ability == 'SHOCKWAVE' and Vector3.zero or target
		}
		return pcall(bedwars.AbilityController.useAbility, bedwars.AbilityController, ability, newproxy(true), data)
	end

	AutoZeno = kits:CreateModule({
		Name = 'AutoZeno',
		Function = function(callback)
			if callback then
				local attempts = {}
				repeat
					if entitylib.isAlive then
						local staff, itemType = getAttackData()

						if staff and itemType then
							local localPosition = entitylib.character.RootPart.Position
							local castRange = math.min(Range.Value, bedwars.WizardUtil:getCastRange(itemType))
							local shockwave = AutoShockWave.Enabled and bedwars.WizardUtil:hasAbility(itemType, 'SHOCKWAVE')
							local ent = entitylib.EntityPosition({
								Origin = localPosition,
								Range = math.max(castRange, shockwave and ShockwaveRange.Value or 0),
								Part = 'RootPart',
								Players = Targets.Players.Enabled,
								NPCs = Targets.NPCs.Enabled,
								Sort = sortmethods[TargetMode.Value]
							})

							if ent then
								local distance = (localPosition - ent.RootPart.Position).Magnitude
								local target = ent.RootPart.Position + ((ent.Humanoid.MoveDirection or Vector3.zero) * (1 + lplr:GetNetworkPing()))
								local abilities = {
									{'LIGHTNING_STORM', UseStorm.Enabled and distance <= castRange},
									{'SHOCKWAVE', shockwave and distance <= ShockwaveRange.Value},
									{'LIGHTNING_STRIKE', UseStrike.Enabled and distance <= castRange}
								}
								for _, ability in abilities do
									if ability[2] and (attempts[ability[1]] or 0) <= tick() and canUseAbility(ability[1], itemType) then
										attempts[ability[1]] = tick() + math.max(Delay.Value, 0.25)
										local success = useAbility(ability[1], target)
										if success then
											task.wait(Delay.Value)
											break
										end
									end
								end
							end
						end
					end
					task.wait(0.1)
				until not AutoZeno.Enabled
			end
		end,
		Tooltip = 'Automatically uses zeno\'s staff.'
	})
	Targets = AutoZeno:CreateTargets({
		Players = true,
		NPCs = false,
	})
	local methods = {'Damage', 'Distance'}
	for _, i in sortlist do
		if not table.find(methods, i) then
			table.insert(methods, i)
		end
	end
	TargetMode = AutoZeno:CreateDropdown({
		Name = 'Target Mode',
		List = methods,
		Default = 'Distance'
	})
	Limit = AutoZeno:CreateToggle({
		Name = 'Limit to item',
		Default = true
	})
	UseStrike = AutoZeno:CreateToggle({
		Name = 'Use Lightning Strike',
		Default = true
	})
	UseStorm = AutoZeno:CreateToggle({Name = 'Use Lightning Storm'})
	AutoShockWave = AutoZeno:CreateToggle({
		Name = 'Auto Shockwave',
		Function = function(call)
			if ShockwaveRange then
				ShockwaveRange.Object.Visible = call
			end
		end,
		Tooltip = 'Automatically uses the shockwave ability when a target is near',
	})
	ShockwaveRange = AutoZeno:CreateSlider({
		Name = 'Shockwave Range',
		Visible = false,
		Darker = true,
		Min = 1,
		Max = 12,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end,
		Decimal = 5,
		Default = 12
	})
	Range = AutoZeno:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 35,
		Suffix = function(val)
			return val > 1 and 'studs' or 'stud'
		end,
		Decimal = 5
	})
	Delay = AutoZeno:CreateSlider({
		Name = 'Delay',
		Min = 0,
		Max = 10,
		Default = 0.5,
		Decimal = 5,
		Suffix = function(val)
			return val > 1 and 'secs' or 'sec'
		end
	})
end)

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


local function createKitExtender(spec)
    local Extender
    local Multiplier
    local controller, original, hooked

    
    
    
    local function install()
        local target = bedwars[spec.Controller]
        while not target and Extender.Enabled do
            task.wait(0.1)
            target = bedwars[spec.Controller]
        end
        if not Extender.Enabled or not target then return end

        local method = target[spec.Method]
        if typeof(method) ~= 'function' then return end
        
        
        
        if hooked and method == hooked then return end

        controller, original = target, method
        hooked = function(...)
            
            
			local direction = spec.Argument and select(spec.Argument, ...) or nil
			if spec.Argument and typeof(direction) ~= 'Vector3' then
				for index = 1, select('#', ...) do
					local candidate = select(index, ...)
					if typeof(candidate) == 'Vector3' then direction = candidate end
				end
			end
            local results = table.pack(method(...))

            if Extender.Enabled and entitylib.isAlive
				and (not spec.Argument or typeof(direction) == 'Vector3') then
				
				
				
				task.defer(function()
					pcall(function()
						if not Extender.Enabled or not entitylib.isAlive then return end
						local root = entitylib.character.RootPart
						local impulse = spec.Impulse(root, direction, Multiplier.Value)
						if impulse then root:ApplyImpulse(impulse) end
					end)
				end)
            end

            return table.unpack(results, 1, results.n)
        end

        controller[spec.Method] = hooked
    end

    Extender = kits:CreateModule({
        Name = spec.Name,
        Category = 'Ability',
        Function = function(callback)
            if callback then
                Extender:Clean(task.spawn(install))
            else
                
                
                if controller and original and controller[spec.Method] == hooked then
                    controller[spec.Method] = original
                end
                controller, original, hooked = nil, nil, nil
            end
        end,
        Tooltip = spec.Tooltip
    })

    Multiplier = Extender:CreateSlider({
        Name = 'Multiplier',
        Min = 1,
        Max = 5,
        Default = 2,
        Decimal = 10,
        Suffix = 'x',
        Tooltip = 'How much further than normal the ability carries you. 1x is the game\'s own distance'
    })

    return Extender
end

run(function()
    createKitExtender({
        Name = 'CatExtender',
        Kit = 'cat',
        Controller = 'CatController',
        Method = 'leap',
        
        Argument = 3,
        Impulse = function(root, direction, multiplier)
            local flat = direction * Vector3.new(1, 0, 1)
            if flat.Magnitude <= 0 then return nil end
            return flat.Unit * root.AssemblyMass * (multiplier - 1) * 70
        end,
        Tooltip = 'Extends how far the Cat/Yamini pounce launches you'
    })
end)

run(function()
	local CryptAura
	local Range
	local Delay
	local nextClaim = 0

	local claimed = setmetatable({}, {__mode = 'k'})

	local Activate = bedwars.Handler:Get('ActivateGravestone')

	CryptAura = kits:CreateModule({
		Name = 'CryptAura',
		Function = function(callback)
			if callback then
				nextClaim = 0
				table.clear(claimed)

				repeat
					if entitylib.isAlive and store.equippedKit == 'necromancer' and tick() >= nextClaim then
						local origin = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('Gravestone') do
							if not claimed[v] and v:GetAttribute('GravestoneSecret') and (v:GetPivot().Position - origin).Magnitude <= Range.Value then
								claimed[v] = true
								nextClaim = tick() + Delay.Value
								Activate:Fire('CallServer', {
									secret = v:GetAttribute('GravestoneSecret'),
									position = v:GetAttribute('GravestonePosition'),
									skeletonData = {
										associatedPlayerUserId = v:GetAttribute('GravestonePlayerUserId'),
										armorType = v:GetAttribute('ArmorType'),
										weaponType = v:GetAttribute('SwordType'),
										bowType = v:GetAttribute('BowType')
									}
								})
								break
							end
						end
					end
					task.wait(0.1)
				until not CryptAura.Enabled
			end
		end,
		Tooltip = 'Automatically claims the gravestones enemies drop into your undead army'
	})
	Range = CryptAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 40,
		Default = 12,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = CryptAura:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.3,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
end)

run(function()
	local DaveyAim
	local Mode
	local Position
	local Range
	local LaunchCannon
	local ShowTarget
	local PlaceCannon
	local LandingColor
	local SafeLand
	local nextCannonPlacement = 0

	local rayCheck = RaycastParams.new()
	rayCheck.RespectCanCollide = true
	local aimRayCheck = RaycastParams.new()
	aimRayCheck.FilterType = Enum.RaycastFilterType.Exclude
	aimRayCheck.RespectCanCollide = true
	local safeLandingRayCheck = RaycastParams.new()
	safeLandingRayCheck.FilterType = Enum.RaycastFilterType.Exclude
	safeLandingRayCheck.RespectCanCollide = true

	local function getLaunchVelocity(delta, velocity, time)
		return (delta + Vector3.new(0, workspace.Gravity * time * time * 0.5, 0)) / time - velocity
	end

	local function softenLanding(root)
		local velocity = root.AssemblyLinearVelocity
		if velocity.Y < 0 then
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, 0, velocity.Z)
		end
	end

	local function getCannon()
		local cannons = {}
		local localPosition = entitylib.character.RootPart.Position
		for _, v in store.blocks do
			if v.Name == 'cannon' and (localPosition - v.Position).Magnitude <= Range.Value then
				table.insert(cannons, v)
			end
		end
		if #cannons > 1 then
			table.sort(cannons, function(a, b)
				return (localPosition - a.Position).Magnitude < (localPosition - b.Position).Magnitude
			end)
		end
		return cannons[1] or nil
	end

	local function placeCannon()
		if tick() < nextCannonPlacement or not entitylib.isAlive then return nil end
		local item = getItem('cannon')
		if not (item and item.tool and item.tool.Parent) then return nil end
		local root = entitylib.character.RootPart
		local foot = entitylib.character.HipHeight + (root.Size.Y / 2) - 3
		local base = roundPos(root.Position - Vector3.new(0, foot, 0))
		local candidates = {base, base + Vector3.new(3, 0, 0), base + Vector3.new(-3, 0, 0), base + Vector3.new(0, 0, 3), base + Vector3.new(0, 0, -3)}
		local target
		for _, position in candidates do
			if not getPlacedBlock(position) and getPlacedBlock(position - Vector3.new(0, 3, 0)) and (position - root.Position).Magnitude <= Range.Value then
				target = position
				break
			end
		end
		if not target then return nil end
		nextCannonPlacement = tick() + 1.5
		local slot, previous = getHotbar(item.tool), store.inventory.hotbarSlot
		if slot ~= nil then pcall(hotbarSwitch, slot) end
		pcall(switchItem, item.tool, 0.1)
		pcall(bedwars.placeBlock, target, 'cannon')
		if previous ~= nil then pcall(hotbarSwitch, previous) end
		local deadline = tick() + 1.5
		repeat
			local block = getPlacedBlock(target)
			if block and block.Parent and block.Name == 'cannon' then return block end
			task.wait(0.05)
		until tick() >= deadline or not entitylib.isAlive
		return nil
	end

	local function isPathBlocked(origin, velocity, time)
		local previous = origin

		for i = 1, 11 do
			local elapsed = time * i / 12
			local point = origin + velocity * elapsed - Vector3.new(0, workspace.Gravity * elapsed * elapsed * 0.5, 0)
			if workspace:Spherecast(previous, 2, point - previous, rayCheck) then
				return true
			end
			previous = point
		end

		return false
	end

	local function getLaunchTime(origin, delta, velocity, ceiling)
		local low, up = 0.0001, 20

		for _ = 1, 50 do
			local first, second = low + (up - low) / 3, up - (up - low) / 3
			if getLaunchVelocity(delta, velocity, first).Magnitude < getLaunchVelocity(delta, velocity, second).Magnitude then
				up = second
			else
				low = first
			end
		end

		local middle = (low + up) / 2
		if getLaunchVelocity(delta, velocity, middle).Magnitude > ceiling then return end
		if not isPathBlocked(origin, getLaunchVelocity(delta, Vector3.zero, middle), middle) then return middle end

		for i = 1, 20 do
			for _, time in {middle * (1 + i * 0.15), middle * (1 - i * 0.045)} do
				if getLaunchVelocity(delta, velocity, time).Magnitude <= ceiling and not isPathBlocked(origin, getLaunchVelocity(delta, Vector3.zero, time), time) then
					return time
				end
			end
		end

		return middle
	end

	local function findSafeLanding(aimPosition, cannon)
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return nil end

		local ignored = {lplr.Character, gameCamera}
		if cannon then
			table.insert(ignored, cannon)
		end
		safeLandingRayCheck.FilterDescendantsInstances = ignored

		local directions = {
			Vector3.zero,
			Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
			Vector3.new(1, 0, 1).Unit, Vector3.new(1, 0, -1).Unit,
			Vector3.new(-1, 0, 1).Unit, Vector3.new(-1, 0, -1).Unit
		}
		local height = math.max(aimPosition.Y, root.Position.Y) + 72

		
		
		
		for distance = 0, 18, 3 do
			for index, direction in ipairs(directions) do
				if distance > 0 or index == 1 then
					local origin = Vector3.new(aimPosition.X, height, aimPosition.Z) + direction * distance
					local hit = workspace:Raycast(origin, Vector3.new(0, -180, 0), safeLandingRayCheck)
					local instance = hit and hit.Instance
					if hit and hit.Position.Y >= aimPosition.Y - 18 and hit.Normal.Y > 0.65 and (not instance:IsA('BasePart') or instance.CanCollide) then
						return hit
					end
				end
			end
		end
	end

	local function getAimRay(origin, direction)
		local ignored = {lplr.Character, gameCamera}
		
		
		for _, block in store.blocks do
			if block.Name == 'cannon' then table.insert(ignored, block) end
		end
		aimRayCheck.FilterDescendantsInstances = ignored
		return workspace:Raycast(origin, direction * 10000, aimRayCheck)
	end

	local function makeVisual(target, blockPosition)
		local part = Instance.new('Part')
		part.Size = Vector3.new(3, 3, 3)
		part.CFrame = CFrame.new(blockPosition)
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		local selection = Instance.new('SelectionBox')
		selection.Adornee = part
		selection.LineThickness = 0.04
		selection.Color3 = Color3.new(1, 1, 1)
		selection.SurfaceColor3 = Color3.new(1, 1, 1)
		selection.SurfaceTransparency = 0.75
		selection.Parent = part
		
		
		
		local tagSize = getfontsize('Landing (000 studs)', 14, uipallet.Font, Vector2.new(1000, 1000))
		local billboard = Instance.new('BillboardGui')
		billboard.Name = 'Tag'
		billboard.Size = UDim2.fromOffset(tagSize.X + 8, tagSize.Y + 7)
		billboard.StudsOffsetWorldSpace = (target - blockPosition) + Vector3.new(0, 2, 0)
		billboard.AlwaysOnTop = true
		billboard.Parent = part
		local tag = Instance.new('TextLabel')
		tag.Size = billboard.Size
		tag.BackgroundColor3 = Color3.new()
		tag.BackgroundTransparency = 0.5
		tag.BorderSizePixel = 0
		tag.RichText = true
		tag.FontFace = uipallet.Font
		tag.TextSize = 14
		tag.TextColor3 = Color3.fromHSV(LandingColor.Hue, LandingColor.Sat, LandingColor.Value)
		tag.Parent = billboard
		bedwars.QueryUtil:setQueryIgnored(part, true)
		part.Parent = gameCamera
		return part
	end

	local function aimCannon(cannon, direction)
		local blockPosition = bedwars.BlockController:getBlockPosition(cannon.Position)
		local aimed
		local timeout = tick() + 1

		repeat
			bedwars.Handler:Get('AimCannon'):Fire('SendToServer', {
				cannonBlockPos = blockPosition,
				lookVector = direction
			})
			task.wait(0.15)
			local look = cannon:GetAttribute('LookVector')
			aimed = look and (look - direction).Magnitude < 0.0001
		until aimed or tick() > timeout or not cannon.Parent

		return aimed
	end

	local daveyLandingGeneration = 0
	local daveyLanded = false

	local function stopDaveyHorizontal(root)
		if not root or not root.Parent then return end
		local velocity = root.AssemblyLinearVelocity
		root.AssemblyLinearVelocity = Vector3.new(0, velocity.Y, 0)
	end

	local function getCannonLaunchSpeed()
		local speed = 200
		local controller = bedwars.CannonHandController
		if canDebug and debug and type(debug.getconstant) == 'function' and controller and type(controller.launchSelf) == 'function' then
			local ok, value = pcall(debug.getconstant, controller.launchSelf, 15)
			if ok and type(value) == 'number' and value > 0 and value < 1000 then speed = value end
		end
		return speed
	end

	local function ensureCannonMovement(cannon, launchDirection)
		local generation = daveyLandingGeneration
		task.spawn(function()
			local character = entitylib.isAlive and entitylib.character
			local root = character and character.RootPart
			if not root then return end
			local startPosition = root.Position
			local direction = launchDirection and launchDirection.Magnitude > 0.001 and launchDirection.Unit or nil
			if not direction and cannon and cannon.Parent then
				local look = cannon:GetAttribute('LookVector')
				direction = typeof(look) == 'Vector3' and look.Magnitude > 0.001 and look.Unit or cannon.CFrame.LookVector
			end
			if not direction then return end

			
			
			for _ = 1, 3 do
				runService.PreSimulation:Wait()
				if generation ~= daveyLandingGeneration or daveyLanded or not root.Parent then return end
				local velocity = root.AssemblyLinearVelocity
				if velocity:Dot(direction) > 20 or (root.Position - startPosition).Magnitude > 1 then return end
			end
			root.AssemblyLinearVelocity = direction * getCannonLaunchSpeed()
		end)
	end

	local function cancelHorizontalOnLanding()
		daveyLandingGeneration += 1
		local generation = daveyLandingGeneration
		daveyLanded = false
		task.spawn(function()
			local character = entitylib.isAlive and entitylib.character
			local humanoid = character and character.Humanoid
			local root = character and character.RootPart
			if not humanoid or not root then return end

			local startPosition = root.Position
			local armed, finished = false, false
			local floorConnection, stateConnection

			local function cleanup()
				if floorConnection then floorConnection:Disconnect(); floorConnection = nil end
				if stateConnection then stateConnection:Disconnect(); stateConnection = nil end
			end

			local function landed()
				if finished or generation ~= daveyLandingGeneration then return end
				finished = true
				daveyLanded = true
				stopDaveyHorizontal(root)
				cleanup()
				
				
				task.spawn(function()
					local settleUntil = tick() + 0.35
					repeat
						runService.PreSimulation:Wait()
						if generation ~= daveyLandingGeneration or not root.Parent then return end
						stopDaveyHorizontal(root)
					until tick() >= settleUntil
				end)
			end

			floorConnection = humanoid:GetPropertyChangedSignal('FloorMaterial'):Connect(function()
				if armed and humanoid.FloorMaterial ~= Enum.Material.Air then landed() end
			end)
			stateConnection = humanoid.StateChanged:Connect(function(_, newState)
				if armed and humanoid.FloorMaterial ~= Enum.Material.Air and (newState == Enum.HumanoidStateType.Landed or newState == Enum.HumanoidStateType.Running or newState == Enum.HumanoidStateType.RunningNoPhysics) then
					landed()
				end
			end)

			local timeout = tick() + 15
			repeat
				runService.PreSimulation:Wait()
				if generation ~= daveyLandingGeneration or not entitylib.isAlive or entitylib.character ~= character or not root.Parent then
					cleanup()
					return
				end
				local velocity = root.AssemblyLinearVelocity
				local horizontal = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
				if not armed and humanoid.FloorMaterial == Enum.Material.Air and ((root.Position - startPosition).Magnitude > 0.75 or math.abs(velocity.Y) > 8 or horizontal > 20) then
					armed = true
				end
				if armed and humanoid.FloorMaterial ~= Enum.Material.Air then landed() end
			until finished or tick() >= timeout
			cleanup()
		end)
	end

	DaveyAim = kits:CreateModule({
		Name = 'DaveyAim',
		Function = function(callback)
			if callback then
				DaveyAim:Toggle()
				if not entitylib.isAlive then return end
				local mouseRay = cloneref(lplr:GetMouse()).UnitRay
				local origin = Position.Value == 'Camera' and gameCamera.CFrame.Position or mouseRay.Origin
				local direction = Position.Value == 'Camera' and gameCamera.CFrame.LookVector or mouseRay.Direction
				local ray = getAimRay(origin, direction)
				if not ray then
					notif('DaveyAim', 'No position found.', 5, 'warning')
					return
				end

				local cannon = getCannon()
				if not cannon then
					cannon = PlaceCannon.Enabled and placeCannon() or nil
					if not cannon then
						notif('DaveyAim', PlaceCannon.Enabled and 'No legal cannon placement found.' or 'No cannon in range.', 5, 'warning')
						return
					end
				end

				rayCheck.FilterDescendantsInstances = {lplr.Character, gameCamera, cannon}
				if SafeLand.Enabled then
					local safeRay = findSafeLanding(ray.Position, cannon)
					if not safeRay then
						notif('DaveyAim', 'No safe landing surface was found near your aim.', 5, 'warning')
						return
					end
					ray = safeRay
				end

				local localPosition = entitylib.character.RootPart.Position
				local target = ray.Position + Vector3.new(0, entitylib.character.HipHeight, 0)
				local velocity = entitylib.character.RootPart.AssemblyLinearVelocity
				if (target - localPosition).Magnitude > 300 then
					notif('DaveyAim', `Too far away ({math.floor((target - localPosition).Magnitude)} studs away, 300 max).`, 5, 'warning')
					return
				end

				local time = getLaunchTime(localPosition, target - localPosition, velocity, math.sqrt(320 * workspace.Gravity))
				if not time then
					notif('DaveyAim', `Out of cannon range ({math.floor((target - localPosition).Magnitude)} studs away, 300 max).`, 5, 'warning')
					return
				end

				local launchDirection = getLaunchVelocity(target - localPosition, velocity, time).Unit
				local blockPosition = bedwars.BlockController:getBlockPosition(cannon.Position)
				local visual = ShowTarget.Enabled and makeVisual(target, roundPos(ray.Position - ray.Normal * 1.5)) or nil
				if visual then
					visual.Tag.TextLabel.Text = `Landing ({math.floor((target - localPosition).Magnitude)} studs)`
				end

				if Mode.Value == 'Legit' then
					cannon.AimPrompt:InputHoldBegin()
					task.wait(cannon.AimPrompt.HoldDuration)

					local timeout = tick() + 0.3
					repeat
						gameCamera.CFrame = gameCamera.CFrame:Lerp(CFrame.lookAt(gameCamera.CFrame.Position, gameCamera.CFrame.Position + launchDirection), 22 * runService.PostSimulation:Wait())
						bedwars.Handler:Get('AimCannon'):Fire('SendToServer', {
							cannonBlockPos = blockPosition,
							lookVector = gameCamera.CFrame.LookVector
						})
					until tick() > timeout
				end

				if not aimCannon(cannon, launchDirection) then
					notif('DaveyAim', 'Cannon refused the aim.', 5, 'warning')
					if visual then
						visual:Destroy()
					end
					return
				end

				if Mode.Value == 'Legit' then
					cannon.StopAimingPrompt:InputHoldBegin()
				end
				task.wait((cannon.StopAimingPrompt.HoldDuration + (0.2 + store.ping.total)) + runService.PostSimulation:Wait())

				if LaunchCannon.Enabled then
					if Mode.Value == 'Legit' then
						cannon.LaunchSelfPrompt:InputHoldBegin()
						task.wait(cannon.LaunchSelfPrompt.HoldDuration + runService.PostSimulation:Wait())
					else
						bedwars.CannonHandController:launchSelf(cannon)
					end
					cancelHorizontalOnLanding()
					ensureCannonMovement(cannon, launchDirection)
				else
					local launched, aimed = false, true
					local connection = cannon.LaunchSelfPrompt.Triggered:Connect(function(plr)
						if plr == lplr then
							launched = true
							cancelHorizontalOnLanding()
							ensureCannonMovement(cannon, launchDirection)
						end
					end)
					local timeout = tick() + 30

					repeat
						runService.PostSimulation:Wait()
						local look = cannon.Parent and cannon:GetAttribute('LookVector')
						aimed = look and (look - launchDirection).Magnitude < 0.0001
					until launched or not aimed or tick() > timeout or not entitylib.isAlive

					connection:Disconnect()
					if not launched then
						if not aimed then
							notif('DaveyAim', 'Cannon was re-aimed before you launched.', 5, 'warning')
						end
						if visual then
							visual:Destroy()
						end
						return
					end
				end

				local landing = tick() + time
				local root
				repeat
					runService.PreSimulation:Wait()
					root = entitylib.isAlive and entitylib.character.RootPart
					if daveyLanded then break end
					if root then
						local remaining = landing - tick()
						if remaining > 0.03 then
							local correction = getLaunchVelocity(target - root.Position, Vector3.zero, remaining)
							root.AssemblyLinearVelocity = correction.Magnitude > 600 and correction.Unit * 600 or correction
						else
							softenLanding(root)
						end
						if visual then
							visual.Tag.TextLabel.Text = `Landing ({math.floor((target - root.Position).Magnitude)} studs)`
						end
					end
				until not root or tick() > landing or daveyLanded

				if entitylib.isAlive then
					softenLanding(entitylib.character.RootPart)
				end

				if visual then
					visual:Destroy()
				end
			end
		end,
		Tooltip = 'Aims a nearby cannon at your cursor and launches you onto it'
	})
	Mode = DaveyAim:CreateDropdown({
		Name = 'Aim Mode',
		List = {'Blatant', 'Legit'},
		Default = 'Blatant'
	})
	Position = DaveyAim:CreateDropdown({
		Name = 'Position Mode',
		List = {'Mouse', 'Camera'},
		Default = 'Mouse'
	})
	Range = DaveyAim:CreateSlider({
		Name = 'Search Range',
		Min = 1,
		Max = 18,
		Default = 10,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	LaunchCannon = DaveyAim:CreateToggle({
		Name = 'Launch Cannon',
		Default = true,
		Tooltip = 'Launches you itself, turn this off to aim only and still land on target when you launch yourself'
	})
	ShowTarget = DaveyAim:CreateToggle({
		Name = 'Show Target',
		Default = true,
		Tooltip = 'Highlights the block you are landing on until you land'
	})
	LandingColor = DaveyAim:CreateColorSlider({
		Name = 'Landing text color',
		DefaultHue = 0,
		DefaultSat = 0.001,
		DefaultValue = 1,
		Darker = true,
		Visible = function() return ShowTarget and ShowTarget.Enabled end
	})
	SafeLand = DaveyAim:CreateToggle({
		Name = 'Safe land',
		Tooltip = 'Moves the target to the nearest supported ground near your aim instead of risking a void landing'
	})
	PlaceCannon = DaveyAim:CreateToggle({
		Name = 'Place cannon',
		Tooltip = 'Places and confirms a cannon from your inventory when none is already nearby'
	})
end)

run(function()
	local EquipKit
	local Kit

	local old = {}

	EquipKit = kits:CreateModule({
		Name = 'EquipKit',
		Function = function(callback)
			if callback then
				EquipKit:Toggle()
				notif('EquipKit', `{bedwars.Handler:Get('BedwarsActivateKit'):Fire('CallServer', {kit = old[Kit.Value]}) and 'Successfully equipped' or 'Failed to equip'} {Kit.Value}.`, 10, 'info')
			end
		end
	})
	local list = {}
	for i, v in bedwars.BedwarsKitMeta do
		table.insert(list, v.name)
		old[v.name] = i
	end
	table.sort(list)
	Kit = EquipKit:CreateDropdown({
		Name = 'Equip kit',
		List = list,
		Default = 'None'
	})
end)

run(function()
	local FalconAura
	local Range
	local Delay
	local Recall
	local nextSend = 0

	FalconAura = kits:CreateModule({
		Name = 'FalconAura',
		Function = function(callback)
			if callback then
				nextSend = 0

				repeat
					if entitylib.isAlive and store.equippedKit == 'falconer' and tick() >= nextSend then
						local target = entitylib.EntityPosition({
							Origin = entitylib.character.RootPart.Position,
							Range = Range.Value,
							Part = 'RootPart',
							Players = true,
							Wallcheck = true
						})

						if target and bedwars.AbilityController:canUseAbility('SEND_FALCON', {disableBlockedAbilityAlert = true}) then
							nextSend = tick() + Delay.Value
							bedwars.AbilityController:useAbility('SEND_FALCON')
						elseif not target and Recall.Enabled and bedwars.AbilityController:canUseAbility('RECALL_FALCON', {disableBlockedAbilityAlert = true}) then
							bedwars.AbilityController:useAbility('RECALL_FALCON')
						end
					end
					task.wait(0.1)
				until not FalconAura.Enabled
			end
		end,
		Tooltip = 'Automatically sends Bekzat falcon at whoever is near you'
	})
	Range = FalconAura:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 150,
		Default = 80,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = FalconAura:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 5,
		Default = 1,
		Decimal = 10,
		Suffix = function(val)
			return val <= 1 and 'sec' or 'secs'
		end
	})
	Recall = FalconAura:CreateToggle({
		Name = 'Recall when clear',
		Default = true,
		Tooltip = 'Calls the falcon back once nobody is in range'
	})
end)

run(function()
	local FishermanSpy
	local Teammates

	FishermanSpy = kits:CreateModule({
		Name = 'FishermanSpy',
		Function = function(call)
			if call then
				FishermanSpy:Clean(bedwars.Handler:Get('FishCaught').Remote:Connect(function(data)
					if data.dropData and data.dropData.drops and data.catchingPlayer and (not Teammates.Enabled or lplr.Team ~= data.catchingPlayer.Team) then
						local text = {}
						for _, v in data.dropData.drops do
							local itemmeta = bedwars.ItemMeta[v.itemType]
							table.insert(text, `{v.amount} {(itemmeta and itemmeta.displayName or v.itemType):lower()}{v.amount >= 2 and 's' or ''}`)
						end

						if #text > 0 then
							notif('FishermanSpy', `{data.catchingPlayer.Name} caught {table.concat(text, ', ')}`, 20, 'info')
						end
					end
				end))
			end
		end,
		Tooltip = 'Notifies you whenever someone reels in a fish, and what it dropped'
	})
	Teammates = FishermanSpy:CreateToggle({
		Name = 'Ignore teammate',
		Default = true
	})
end)

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

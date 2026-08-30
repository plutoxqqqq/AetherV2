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
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
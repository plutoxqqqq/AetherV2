run(function()
	local Active
	local Legit = {Enabled = false}

	-- The kit's behaviour runs while its own toggle is on, so the loops below follow the handle and not a
	-- flag of their own: turning the toggle off stops whatever is running straight away.
	local function IsRunning()
		return Active ~= nil and Active.Enabled
	end

	local function kitCollection(id, func, range, specific)
		local objs = type(id) == 'table' and id or collection(id, Active)
		repeat
			if entitylib.isAlive then
				local localPosition = entitylib.character.RootPart.Position
				for _, v in objs do
					if not IsRunning() then break end
					local part = not v:IsA('Model') and v or (v.PrimaryPart or v:FindFirstChildWhichIsA('BasePart', true))
					if part and (part.Position - localPosition).Magnitude <= (not Legit.Enabled and specific and math.huge or range) then
						func(v)
					end
				end
			end
			task.wait(0.1)
		until not IsRunning()
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
			until not IsRunning()
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

			Active:Clean(function()
				bedwars.BlockKickerKitController.getKickBlockProjectileOriginPosition = old
			end)
		end,
		cat = function()
			local old = bedwars.CatController.leap
			bedwars.CatController.leap = function(...)
				vapeEvents.CatPounce:Fire()
				return old(...)
			end

			Active:Clean(function()
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

			Active:Clean(function()
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

			Active:Clean(function()
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

			Active:Clean(function()
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
			until not IsRunning()
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
			until not IsRunning()
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

			Active:Clean(function()
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
			until not IsRunning()
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
			until not IsRunning()
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
			until not IsRunning()
		end
	}

	-- Every kit ability used to be a toggle on one AutoKit module. Each one now lives on the kit it belongs to,
	-- so a kit holds everything that was built for it and nothing has to be switched on twice.
	local function newBehaviour()
		local cleanups = {}
		local handle = {Enabled = false}

		function handle:Clean(obj)
			table.insert(cleanups, obj)
		end

		function handle:Clear()
			for _, v in cleanups do
				if typeof(v) == 'RBXScriptConnection' then
					pcall(function() v:Disconnect() end)
				elseif typeof(v) == 'Instance' then
					pcall(function() v:Destroy() end)
				elseif typeof(v) == 'function' then
					pcall(v)
				end
			end
			table.clear(cleanups)
		end

		return handle
	end

	-- Only the kits whose collection reaches as far as it can use a legit range: farmer-style harvesting,
	-- soul and petrified-player pickups, and the summoner's claw.
	local LEGIT_RANGE = {
		dragon_slayer = true, grim_reaper = true, hannah = true, miner = true,
		pinata = true, spirit_assassin = true, summoner = true
	}

	local kitIds = {}
	for kitId in AutoKitFunctions do
		table.insert(kitIds, kitId)
	end
	table.sort(kitIds, function(a, b)
		local metaA, metaB = bedwars.BedwarsKitMeta[a], bedwars.BedwarsKitMeta[b]
		return ((metaA and metaA.name) or a):lower() < ((metaB and metaB.name) or b):lower()
	end)

	for _, kitId in kitIds do
		local kit = getKitModule(kitId)
		local meta = bedwars.BedwarsKitMeta[kitId]
		local display = (meta and meta.name) or kitId
		local handle = newBehaviour()

		local legit = LEGIT_RANGE[kitId] and kit:CreateToggle({
			Name = 'Legit Range',
			Tooltip = 'Only reaches things close enough to look legit'
		}) or {Enabled = false}

		local toggle = kit:CreateToggle({
			Name = 'Auto Ability',
			Tooltip = 'Automatically uses the ' .. display .. ' kit abilities',
			Function = function(enabled)
				handle.Enabled = enabled
				if not enabled then
					handle:Clear()
					return
				end

				task.spawn(function()
					repeat
						if handle.Enabled and store.matchState ~= 0 and store.equippedKit == kitId then
							Active, Legit = handle, legit
							local ok, err = pcall(AutoKitFunctions[kitId])
							Active, Legit = nil, {Enabled = false}
							if not ok then
								notif('Kits', tostring(err), 6, 'warning')
								break
							end
						end
						task.wait(0.1)
					until not handle.Enabled
					handle:Clear()
				end)
			end
		})
		handle.Toggle = function() toggle:Toggle() end
	end
end)

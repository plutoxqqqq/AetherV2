run(function()
	-- The ported body reads the module as `Killaura`, so the local is named that way and shadows
	-- nothing: without the `local` the assignment below would write a global and every `Killaura.x`
	-- lookup in the file would depend on it.
	local Killaura
	local Targets
	local Sort
	local SwingRange
	local AttackRange
	local AngleSlider
	local Swing
	local ContinueSwingTime
	local GUI
	local Animation
	local AnimationMode
	local AnimationSpeed
	local AnimationTween
	local Limit
	local LegitAura
	local AttackCheck
	local kitChecks
	local SwingTime
	local SwingTimeSlider
	local AirHit
	local AirHitsChance
	local FastHits
	local LegitSwitch
	local Kits
	local Arrows
	local Gloops
	local Fireball
	local ArrowCharge
	local AttackRemote

	-- State that has to survive between toggles of the module itself.
	local Attacking
	local lastAttackTime = 0
	local lastTargetTime = 0
	local anims, AnimDelay, AnimTween, armC0 = vape.Libraries.auraanims, tick()
	local FROZEN_THRESHOLD = 10
	local FASTHITS_BUILD = 'legacy-good-ka-first-v1'
	local HIT_PERIOD = 0.294
	local SERVER_FLOOR = 0.294
	local KILLAURA_RATE_LEAD = 0.006
	local KA_BACKOFF_STEP = 0
	local KA_BACKOFF_MAX = 0
	-- The attack remote is reported as if the swing happened this far from the target, which is the
	-- distance the pack's own Killaura has always used; the server validates reach from that.
	local SERVER_REACH = 14.399
	local TARGET_LOCK_GRACE = 0.18
	local TARGET_QUERY_PADDING = 2
	local kaPeriod = HIT_PERIOD
	local kaFloor = SERVER_FLOOR
	local kaNextFire = 0
	local kaSync = 0
	local kaSyncSrv = 0
	local kaLastSrv = 0
	local kaLastSend = 0
	local fhLastShotTime = 0
	local fhBusySince = 0
	local fhBusyToken = 0
	local kaFrameEMA = 1 / 60
	local kaBackoff = 0
	local kaPendingChar = nil
	local kaPendingSent = 0
	local kaConfirmSeen = false
	local kaLastConfirm = 0
	local kaConfirmGap = 0.298
	local kaStableConfirms = 0
	local kaDamageZapReady = false
	local glueRemote
	local projectileRemote
	local frostyGunRemote = {FireServer = function() end}
	local gloopTracker = {}
	local kitWeaponList = {'frost_staff', 'ninja_chakram', 'mage_spellbook'}

	local ProjectileDelay = {}
	local autoShootLoop
	local fhUsageIndex = 1
	local preserveSwordIcon = false

	task.spawn(function()
		glueRemote = replicatedStorage:WaitForChild('rbxts_include'):WaitForChild('node_modules'):WaitForChild('@rbxts'):WaitForChild('net'):WaitForChild('out'):WaitForChild('_NetManaged'):WaitForChild('ProjectileFire')
	end)

	task.spawn(function()
		task.wait()
		pcall(function()
			projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
		end)
		pcall(function()
			local net = replicatedStorage.rbxts_include.node_modules['@rbxts'].net.out._NetManaged
			frostyGunRemote = net:WaitForChild('FrostyGunFireActionRequest')
		end)
		pcall(function()
			AttackRemote = bedwars.Client:Get(remotes.AttackEntity).instance
		end)
		pcall(function()
			local netModule = lplr.PlayerScripts
				:WaitForChild('TS')
				:WaitForChild('lib')
				:WaitForChild('network')
			local networkLib = require(netModule)
			local zap = networkLib and networkLib.EntityDamageEventZap
			if zap and zap.On then
				zap.On(function(entityInstance)
					if not Killaura or not Killaura.Enabled then return end
					if FastHits and FastHits.Enabled then return end
					if not kaPendingChar or entityInstance ~= kaPendingChar then return end
					local now = os.clock()
					if kaPendingSent <= 0 or (now - kaPendingSent) > 0.45 then return end

					if kaLastConfirm > 0 then
						local gap = now - kaLastConfirm
						if gap > 0.15 and gap < 0.65 then
							kaConfirmGap = (kaConfirmGap * 0.7) + (gap * 0.3)
						end
					end

					kaLastConfirm = now
					kaConfirmSeen = true
					kaStableConfirms += 1
					kaPendingChar = nil
					kaPendingSent = 0

					if kaStableConfirms >= 3 and kaBackoff > 0 then
						kaBackoff = math.max(0, kaBackoff - 0.0005)
					end
				end)
				kaDamageZapReady = true
			end
		end)
	end)

	local function FireAttackRemote(weapon, entityInstance, selfPos, targetPos)
		if not AttackRemote or type(AttackRemote.FireServer) ~= 'function' then return false end

		local delta = (targetPos - selfPos).Magnitude
		if delta < 0.01 then return false end

		local dir = CFrame.lookAt(selfPos, targetPos).LookVector
		local pos = selfPos + dir * math.max(delta - SERVER_REACH, 0)

		AttackRemote:FireServer({
			weapon = weapon,
			chargedAttack = {chargeRatio = 0},
			entityInstance = entityInstance,
			validate = {
				raycast = {
					cameraPosition = {value = pos},
					cursorDirection = {value = dir}
				},
				targetPosition = {value = targetPos},
				selfPosition = {value = pos}
			}
		})

		return true
	end

	local function getKnitControllers()
		return (bedwars.KnitClient and bedwars.KnitClient.Controllers) or (bedwars.Knit and bedwars.Knit.Controllers)
	end

	local function isOnTinker()
		local ok, mounted = pcall(function()
			local controllers = getKnitControllers()
			return controllers and controllers.TinkerKitController and controllers.TinkerKitController.mounted
		end)
		return ok and mounted == true
	end

	local _lastTinkerSwing = 0
	local function playTinkerSwing()
		local now = workspace:GetServerTimeNow()
		if now - _lastTinkerSwing < 0.35 then return end
		_lastTinkerSwing = now
		pcall(function()
			local controllers = getKnitControllers()
			local controller = controllers and controllers.TinkerKitController
			if not controller then return end
			local model = controller.userMap[lplr]
			if not model then return end
			local mac = controllers.MountAnimationController
			if not mac then return end
			local animId = bedwars.AnimationType and bedwars.AnimationType.TINKER_ATTACK
			mac:playAnimationInMount(model, animId, 1.85)
		end)
	end

	local _adCacheSword = nil
	local _adCacheMeta = nil
	local _adCacheTime = 0

	local function computeAttackData()
		if not entitylib.isAlive then return false end

		local casting = lplr:GetAttribute('IsCasting')
		if casting ~= nil and casting ~= false and casting ~= 0 and casting ~= '' then
			if casting == true then return false end
			if type(casting) == 'number' and casting > workspace:GetServerTimeNow() then return false end
		end

		if bedwars.SwordController and bedwars.SwordController.disableSwingState then return false end

		local stunned = lplr.Character and lplr.Character:GetAttribute('StunnedUntilTime')
		if stunned and stunned > workspace:GetServerTimeNow() then return false end

		if AttackCheck and AttackCheck.Enabled then
			if kitChecks then
				for _, check in pairs(kitChecks) do
					local ok, res = pcall(check)
					if ok and res then return false end
				end
			end

			if tick() - (store.silasAbilityTime or 0) < 2.2 then return false end
			if tick() - (store.terraStompTime or 0) < 0.7 then return false end
			if tick() - (store.terraKickTime or 0) < 0.5 then return false end
		end

		if GUI and GUI.Enabled then
			if bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then return false end
		end

		local sword = (Limit and Limit.Enabled) and store.hand or store.tools.sword
		if not (Limit and Limit.Enabled) and store.hand and store.hand.tool then
			local handMeta = bedwars.ItemMeta[store.hand.tool.Name]
			if handMeta and handMeta.sword then
				sword = store.hand
			end
		end
		if not sword or not sword.tool then return false end

		local meta = bedwars.ItemMeta[sword.tool.Name]
		if not meta then return false end

		if Limit and Limit.Enabled then
			if store.hand.toolType ~= 'sword' or (bedwars.DaoController and bedwars.DaoController.chargingMaid) then return false end
		end

		if LegitAura and LegitAura.Enabled then
			local lastSwing = bedwars.SwordController and bedwars.SwordController.lastSwing
			if not lastSwing or (tick() - lastSwing) > 0.2 then return false end
		end

		return sword, meta
	end

	local function getAttackData()
		local now = os.clock()
		if now - _adCacheTime < 0.02 and _adCacheSword then
			return _adCacheSword, _adCacheMeta
		end
		_adCacheTime = now
		local sword, meta = computeAttackData()
		_adCacheSword = sword
		_adCacheMeta = meta
		return sword, meta
	end

	local function resetSwordCooldown()
		if bedwars.SwordController then
			bedwars.SwordController.lastAttack = 0
			bedwars.SwordController.lastSwing = 0
			if bedwars.SwordController.lastChargedAttackTimeMap then
				for weaponName in pairs(bedwars.SwordController.lastChargedAttackTimeMap) do
					bedwars.SwordController.lastChargedAttackTimeMap[weaponName] = 0
				end
			end
		end
	end

	local function getSwordCooldownRemaining(toolName)
		local controller = bedwars.SwordController
		if not controller or not controller.getRemainingSwingCooldown or not toolName then
			return nil
		end

		local ok, remaining = pcall(
			controller.getRemainingSwingCooldown,
			controller,
			toolName
		)

		if ok and type(remaining) == 'number' then
			return math.max(remaining, 0)
		end

		return nil
	end

	local function getCurrentSwordForTiming()
		local sword = store.hand
		if sword and sword.tool then
			local meta = bedwars.ItemMeta[sword.tool.Name]
			if meta and meta.sword then
				return sword
			end
		end

		return store.tools and store.tools.sword or nil
	end

	local function getAmmo(check)
		if not check.ammoItemTypes then return nil end
		for _, item in store.inventory.inventory.items do
			if not table.find(check.ammoItemTypes, item.itemType) then continue end
			local ok, pt = pcall(check.projectileType, item.itemType)
			if not ok or not pt then continue end
			local pm = bedwars.ProjectileMeta[pt]
			if pm and pm.arrow and pm.launchVelocity and pm.launchVelocity >= 50 then
				return item.itemType
			end
		end
		return nil
	end

	local _projectilesCache = {}
	local _projectilesCacheTime = 0
	local function getProjectiles()
		if not Arrows or not Arrows.Enabled then return {} end
		local now = tick()
		if now - _projectilesCacheTime < 0.2 and #_projectilesCache > 0 then
			return _projectilesCache
		end
		if #_projectilesCache == 0 and now - _projectilesCacheTime < 0.1 then
			return _projectilesCache
		end
		_projectilesCacheTime = now
		table.clear(_projectilesCache)
		for _, item in store.inventory.inventory.items do
			local meta = bedwars.ItemMeta[item.itemType]
			if not meta then continue end
			local proj = meta.projectileSource
			if not proj or not proj.projectileType then continue end
			local ammo = getAmmo(proj)
			if not ammo then continue end
			local projType = proj.projectileType(ammo)
			local pmeta = projType and bedwars.ProjectileMeta[projType]
			if pmeta and pmeta.arrow and pmeta.launchVelocity and pmeta.launchVelocity >= 50 then
				table.insert(_projectilesCache, {item, ammo, projType, proj})
			end
		end
		return _projectilesCache
	end

	local function canShoot(proj)
		local ready = ProjectileDelay[proj[1].itemType] or 0
		return tick() > ready
	end

	local sharedFastHitsRayParams = RaycastParams.new()
	sharedFastHitsRayParams.FilterType = Enum.RaycastFilterType.Exclude
	local _fhFilter = {nil, nil, nil}
	local function setFHFilter(entChar)
		_fhFilter[1] = lplr.Character
		_fhFilter[2] = gameCamera
		_fhFilter[3] = entChar
		sharedFastHitsRayParams.FilterDescendantsInstances = _fhFilter
	end

	local fhBusy = false

	local function setFHBusy()
		fhBusyToken = fhBusyToken + 1
		fhBusy = true
		fhBusySince = workspace:GetServerTimeNow()
		store._fhBusySince = fhBusySince
		return fhBusyToken
	end

	local function clearFHBusy(token)
		if token and token ~= fhBusyToken then return end
		fhBusy = false
		fhBusySince = 0
		store._fhBusySince = nil
	end

	local function fhInAngle(v)
		if not AngleSlider or AngleSlider.Value >= 360 then return true end
		if not v or not v.RootPart then return false end
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return false end
		local look = root.CFrame.LookVector
		local flatLook = look * Vector3.new(1, 0, 1)
		if flatLook.Magnitude < 0.001 then return true end
		local flat = (v.RootPart.Position - root.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude <= 1 then return true end
		return math.acos(math.clamp(flatLook.Unit:Dot(flat.Unit), -1, 1)) <= math.rad(AngleSlider.Value) / 2
	end

	local function fhEquipAwait(tool)
		if not tool or not tool.Parent then return false end
		return switchItem(tool, 0.05) and true or false
	end

	local fhRestoreToken = 0
	local function fhRestoreSword()
		local sw = store.tools.sword
		if not sw or not sw.tool or not sw.tool.Parent then return false end

		local check = lplr.Character and lplr.Character:FindFirstChild('HandInvItem')
		if not check then return false end

		fhRestoreToken = fhRestoreToken + 1
		store._fhRestoreAt = tick()

		if check.Value ~= sw.tool then
			check.Value = sw.tool
		end

		pcall(function()
			bedwars.Client:Get(remotes.EquipItem):CallServerAsync({hand = sw.tool})
		end)

		return true
	end

	local function recoverFastHitState()
		if not fhBusy then return end
		if fhBusySince <= 0 then
			clearFHBusy()
			return
		end

		if workspace:GetServerTimeNow() - fhBusySince > 0.45 then
			fhBusyToken = fhBusyToken + 1
			fhBusy = false
			fhBusySince = 0
			store._fhBusySince = nil
			fhRestoreSword()
		end
	end

	local function fastHitBlocksSword()
		if not fhBusy then return false end

		recoverFastHitState()
		if not fhBusy then return false end

		local sw = store.tools and store.tools.sword
		if not sw or not sw.tool then return true end

		local char = lplr.Character
		local hand = char and char:FindFirstChild('HandInvItem')
		local held = hand and hand.Value or (store.hand and store.hand.tool)

		return held ~= sw.tool
	end

	local _fhVelHistory = {}
	local _fhPing = 0.1
	local _fhPingClock = 0
	local _fhIdChars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'

	local function fhGenId()
		local out = table.create(8)
		for i = 1, 8 do
			local n = math.random(1, #_fhIdChars)
			out[i] = _fhIdChars:sub(n, n)
		end
		return table.concat(out)
	end

	local function getFHPing()
		if tick() - _fhPingClock < 1 then return _fhPing end
		_fhPingClock = tick()
		local ok, val = pcall(function()
			return game:GetService('Stats').Network.ServerStatsItem['Data Ping']:GetValue() / 1000
		end)
		_fhPing = (ok and val) and math.clamp(val, 0.02, 1) or 0.1
		return _fhPing
	end

	local function updateKAAdaptive()
		return
	end

	local function fhWindowOpen(ent, meleeRange, cost)
		if not ent or not ent.RootPart then return false end
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return false end

		local distance = (ent.RootPart.Position - root.Position).Magnitude

		if distance > meleeRange then
			return true
		end

		if LegitAura and LegitAura.Enabled then
			return true
		end

		if kaLastSend <= 0 then
			return false
		end

		local sinceSword = workspace:GetServerTimeNow() - kaLastSend
		local guard = math.clamp(0.09 + (getFHPing() * 0.2), 0.10, 0.14)
		local remaining = kaPeriod - sinceSword

		if sinceSword < 0.02 then
			return false
		end

		return remaining > (guard + (cost or 0))
	end

	local _fhVelClean = 0
	local function smoothedVelocity(ent, targetPart)
		local rawVel = targetPart.AssemblyLinearVelocity or targetPart.Velocity or Vector3.zero
		local key = tostring(ent)
		local now = tick()

		if now - _fhVelClean > 10 then
			_fhVelClean = now

			for k, v in pairs(_fhVelHistory) do
				if type(v) == 'table' and v.t and (now - v.t) > 8 then
					_fhVelHistory[k] = nil
				end
			end

			for k, v in pairs(gloopTracker) do
				if v.lastShot and (now - v.lastShot) > 20 then
					gloopTracker[k] = nil
				end
			end
		end

		local rec = _fhVelHistory[key]

		if not rec or type(rec) ~= 'table' then
			_fhVelHistory[key] = {v = rawVel, t = now}
			return rawVel, rawVel
		end

		rec.v = rec.v:Lerp(rawVel, 0.35)
		rec.t = now
		return rec.v, rawVel
	end

	local function targetGravity(ent)
		local playerGravity = workspace.Gravity
		local balloons = ent.Character and ent.Character:GetAttribute('InflatedBalloons')

		if balloons and balloons > 0 then
			playerGravity = workspace.Gravity * (1 - (balloons >= 4 and 1.2 or balloons >= 3 and 1 or 0.975))
		end

		if ent.Character and ent.Character.PrimaryPart and ent.Character.PrimaryPart:FindFirstChild('rbxassetid://8200754399') then
			playerGravity = 6
		end

		if ent.Player and ent.Player:GetAttribute('IsOwlTarget') then
			local _owls = collectionService:GetTagged('Owl')
			if #_owls > 0 then
				local _uid = ent.Player.UserId
				for _, owl in ipairs(_owls) do
					if owl:GetAttribute('Target') == _uid and owl:GetAttribute('Status') == 2 then
						playerGravity = 0
						break
					end
				end
			end
		end

		return playerGravity
	end

	local function shootProjectile(item, ammo, projectile, itemMeta, selfPos, ent, ignoreSwitch, batch)
		local meta = bedwars.ProjectileMeta[projectile]
		if not meta or not ent or not ent.RootPart then return false end
		if not projectileRemote or type(projectileRemote.InvokeServer) ~= 'function' then return false end

		local busyToken
		local ownsBusy = not batch
		local switched = false

		if not ignoreSwitch then
			if ownsBusy then
				busyToken = setFHBusy()
			end

			if not fhEquipAwait(item.tool) then
				ProjectileDelay[item.itemType] = tick() + 0.3

				if ownsBusy then
					fhRestoreSword()
					clearFHBusy(busyToken)
				end

				return false
			end

			switched = true

			local root = entitylib.character and entitylib.character.RootPart

			if not root then
				if ownsBusy then
					fhRestoreSword()
					clearFHBusy(busyToken)
				end

				return false
			end

			selfPos = root.Position
		end

		local gravity = tonumber(meta.gravitationalAcceleration)
		if gravity == nil then gravity = 196.2 end
		if gravity < 1 then gravity = 0 end

		local targetPart = ent.RootPart
		local playerGravity = targetGravity(ent)
		local isFireball = tostring(ammo):find('fireball') ~= nil

		local maxCharge = tonumber(itemMeta.maxStrengthChargeSec) or 0
		local chargePct = (ArrowCharge and ArrowCharge.Value or 100) / 100
		local drawTime = maxCharge * chargePct

		local multiAt = tonumber(itemMeta.multiShotChargeTime)
		if multiAt and maxCharge > 0 and chargePct >= 1 then
			drawTime = math.max(drawTime, multiAt)
		end

		local minScalar = tonumber(itemMeta.minStrengthScalar) or 1
		local chargeRatio = maxCharge > 0 and math.clamp(drawTime / maxCharge, 0, 1) or 1
		local projSpeed = meta.launchVelocity * (minScalar + (1 - minScalar) * chargeRatio)

		local ping = getFHPing()
		local smoothVel, rawVel = smoothedVelocity(ent, targetPart)

		smoothVel = Vector3.new(smoothVel.X, rawVel.Y, smoothVel.Z)

		local solverVel = isFireball and rawVel or smoothVel

		local hip = ent.HipHeight or 2
		local aimPart = targetPart
		local aimOffset = hip * 0.15

		do
			local itype = tostring(item.itemType)
			local head = ent.Character and ent.Character:FindFirstChild('Head')
			local dist = (targetPart.Position - selfPos).Magnitude

			if itype:find('headhunter') then
				local hspeed = Vector3.new(smoothVel.X, 0, smoothVel.Z).Magnitude

				if head and dist < 90 and hspeed < 28 and math.abs(smoothVel.Y) < 30 then
					aimPart = head
					aimOffset = -0.35
				else
					aimOffset = hip * 0.15
				end
			elseif isFireball then
				aimOffset = 0
			elseif itype:find('bomb') or itype:find('grenade') or itype:find('santa') or itype:find('impulse') then
				aimOffset = -hip * 0.5
			elseif itype:find('rocket') or itype:find('launcher') or itype:find('firework') then
				aimOffset = 0
			elseif meta.arrow then
				aimOffset = hip * 0.15
			elseif itype:find('snowball') or itype:find('chakram') or itype:find('spell') then
				aimOffset = hip * 0.3
			end
		end

		local leadPos = aimPart.Position + Vector3.new(0, aimOffset, 0)

		setFHFilter(ent.Character)

		local originPos

		do
			local handle = item.tool and item.tool:FindFirstChild('Handle')
			local bo = handle and handle:FindFirstChild('BulletOrigin')

			if bo and bo:IsA('Attachment') then
				originPos = bo.WorldPosition
			else
				local char = entitylib.character and entitylib.character.Character
				local hand = char and (char:FindFirstChild('RightHand') or char:FindFirstChild('Right Arm'))

				if hand then
					originPos = hand.Position
				else
					local pp = entitylib.character and entitylib.character.RootPart
					originPos = pp and (pp.Position + Vector3.new(0, 1.5, 0)) or gameCamera.CFrame.Position
				end
			end
		end

		local calc, _impact, flightTime = prediction.SolveTrajectory(
			originPos,
			projSpeed,
			gravity,
			leadPos,
			solverVel,
			playerGravity,
			ent.HipHeight or 2,
			ent.Jumping and 42.6 or nil,
			sharedFastHitsRayParams,
			nil,
			targetPart.Position,
			targetPart,
			nil,
			true
		)

		local lifetime = tonumber(meta.predictionLifetimeSec)
			or tonumber(meta.lifetimeSec)
			or (projSpeed > 0 and math.min(3, 120 / projSpeed) or 3)

		if not calc or (flightTime and flightTime > lifetime) then
			ProjectileDelay[item.itemType] = tick() + 0.3

			if ownsBusy then
				fhRestoreSword()
				clearFHBusy(busyToken)
			end

			return false
		end

		local shootPos = originPos

		if meta.arrow then
			shootPos = (
				CFrame.new(originPos, calc)
				* CFrame.new(Vector3.new(
					-(bedwars.BowConstantsTable.RelX or 0),
					-(bedwars.BowConstantsTable.RelY or 0),
					-(bedwars.BowConstantsTable.RelZ or 0)
				))
			).Position
		end

		do
			local myRoot = entitylib.character and entitylib.character.RootPart

			if myRoot then
				local away = calc - shootPos

				if away.Magnitude > 0.01 then
					shootPos = shootPos + away.Unit * 2
				end

				local flat = (shootPos - myRoot.Position) * Vector3.new(1, 0, 1)

				if flat.Magnitude < 0.5 then
					shootPos = shootPos + Vector3.new(0, 0.5, 0)
				end
			end
		end

		local dir = CFrame.lookAt(shootPos, calc).LookVector
		local id = fhGenId()

		local shotMeta = {
			shotId = fhGenId(),
			drawDurationSec = drawTime,
			drawDurationSeconds = drawTime
		}

		pcall(function()
			targetinfo.Targets[ent] = tick() + 1
		end)

		ProjectileDelay[item.itemType] = tick() + (tonumber(itemMeta.fireDelaySec) or 0.5)

		if not isFireball then
			bedwars.ProjectileController:createLocalProjectile(
				meta,
				ammo,
				projectile,
				shootPos,
				id,
				dir * projSpeed,
				{
					drawDurationSec = drawTime,
					drawDurationSeconds = drawTime
				}
			)
		end

		task.spawn(function()
			local res = projectileRemote:InvokeServer(
				item.tool,
				ammo,
				projectile,
				shootPos,
				selfPos,
				dir * projSpeed,
				id,
				shotMeta,
				workspace:GetServerTimeNow() - (isFireball and ping or 0.045)
			)

			if res then
				pcall(function()
					res.Parent = replicatedStorage
				end)

				local sound = itemMeta.launchSound
				sound = sound and sound[math.random(1, #sound)] or nil

				if sound and bedwars.SoundManager then
					pcall(function()
						bedwars.SoundManager:playSound(sound)
					end)
				end
			else
				local pd = ProjectileDelay[item.itemType] or 0
				local alt = tick() + (tonumber(itemMeta.fireDelaySec) or 0.5) + 0.1

				if alt > pd then
					ProjectileDelay[item.itemType] = alt
				end
			end
		end)

		if switched and ownsBusy then
			fhRestoreSword()
			clearFHBusy(busyToken)
		end

		return true
	end

	local function shootKitWeapon(item, ammo, projectile, selfPos, ent, batch)
		if not ent or not ent.RootPart then return false end
		if not projectileRemote or type(projectileRemote.InvokeServer) ~= 'function' then return false end

		local meta = bedwars.ItemMeta[item.itemType]
		if not meta then return false end

		local pmeta = bedwars.ProjectileMeta[projectile]
		if not pmeta then return false end

		local projSpeed = pmeta.launchVelocity
		local gravity = tonumber(pmeta.gravitationalAcceleration)

		if gravity == nil then gravity = 196.2 end
		if gravity < 1 then gravity = 0 end

		local targetPart = ent.RootPart
		local playerGravity = targetGravity(ent)

		local smoothVel, rawVel = smoothedVelocity(ent, targetPart)
		smoothVel = Vector3.new(smoothVel.X, rawVel.Y, smoothVel.Z)

		local chestPos = targetPart.Position + Vector3.new(0, (ent.HipHeight or 2) * 0.15, 0)

		setFHFilter(ent.Character)

		local calc = prediction.SolveTrajectory(
			selfPos,
			projSpeed,
			gravity,
			chestPos,
			smoothVel,
			playerGravity,
			ent.HipHeight or 2,
			ent.Jumping and 42.6 or nil,
			sharedFastHitsRayParams,
			nil,
			targetPart.Position,
			targetPart,
			nil,
			true
		)

		if not calc or (calc - targetPart.Position).Magnitude > 50 then
			calc = chestPos
		end

		local muzzlePos = selfPos + Vector3.new(0, 1.5, 0)
		local firePos = selfPos - Vector3.new(0, 0.5, 0)
		local dir = CFrame.lookAt(muzzlePos, calc).LookVector
		local id = httpService:GenerateGUID(true)

		local busyToken
		local ownsBusy = not batch

		if ownsBusy then
			busyToken = setFHBusy()
		end

		if not fhEquipAwait(item.tool) then
			if ownsBusy then
				fhRestoreSword()
				clearFHBusy(busyToken)
			end
			return false
		end

		pcall(function()
			frostyGunRemote:FireServer({keyHold = true})
		end)

		pcall(function()
			frostyGunRemote:FireServer({keyHold = false})
		end)

		local fireDelay = (meta.fireDelaySec or 0.7) + 0.05

		targetinfo.Targets[ent] = tick() + 1
		ProjectileDelay[item.itemType] = tick() + fireDelay

		local drawDur = 0.8 + math.random() * 0.8

		task.spawn(function()
			local res = projectileRemote:InvokeServer(
				item.tool,
				nil,
				projectile,
				muzzlePos,
				firePos,
				dir * projSpeed,
				id,
				{
					shotId = httpService:GenerateGUID(false),
					drawDurationSec = drawDur
				},
				workspace:GetServerTimeNow() - 0.045
			)

			if res then
				pcall(function()
					res.Parent = replicatedStorage
				end)
			else
				ProjectileDelay[item.itemType] = tick() + fireDelay
			end
		end)

		if ownsBusy then
			fhRestoreSword()
			clearFHBusy(busyToken)
		end

		return true
	end

	local mageSpellMap = {
		base = 'mage_spell_base',
		nature = 'mage_spell_nature',
		fire = 'mage_spell_fire',
		ice = 'mage_spell_ice'
	}

	local function getMageSpell()
		local ok, spell = pcall(function()
			local idx = lplr:GetAttribute('MageElementIndex') or 0
			local cycle = bedwars.BalanceFile and bedwars.BalanceFile.MAGE_ELEMENT_CYCLE
			local element = cycle and cycle[idx + 1]

			if not element then
				return 'mage_spell_base'
			end

			local elLower = string.lower(tostring(element))
			local unlocked = lplr:GetAttribute(elLower)

			if not unlocked or unlocked == 0 then
				return 'mage_spell_base'
			end

			return mageSpellMap[elLower] or 'mage_spell_base'
		end)

		return ok and spell or 'mage_spell_base'
	end

	local kitAmmoMap = {
		frost_staff = {
			base = 'frosty_snowball',
			leveled = true
		},
		ninja_chakram = {
			base = 'ninja_chakram',
			leveled = true
		},
		mage_spellbook = {
			dynamic = 'mage'
		}
	}

	local function getKitWeapon()
		for _, item in store.inventory.inventory.items do
			local itype = string.lower(item.itemType or '')

			for _, kw in kitWeaponList do
				if string.find(itype, kw) then
					local info = kitAmmoMap[kw]

					if not info then continue end

					local ammo

					if info.dynamic == 'mage' then
						ammo = getMageSpell()
					elseif info.leveled then
						ammo = info.base .. '_' .. (itype:match('_(%d+)$') or '1')
					else
						ammo = info.base
					end

					return {
						item,
						ammo,
						ammo,
						nil
					}
				end
			end
		end

		return nil
	end

	local function getGloopItem()
		for _, item in store.inventory.inventory.items do
			if item.itemType == 'glue_projectile' then
				return item
			end
		end

		return nil
	end

	local function getFireballItem()
		for _, item in store.inventory.inventory.items do
			local itype = item.itemType or ''

			if itype:find('fireball') then
				local meta = bedwars.ItemMeta[itype]

				if meta and meta.projectileSource then
					return {
						item,
						itype,
						meta.projectileSource.projectileType(itype),
						meta.projectileSource
					}
				end
			end
		end

		return nil
	end

	local function isGlooped(ent)
		local char = ent and ent.Character
		if not char then return false end

		local val = char:GetAttribute('GlueSlow')
		return val ~= nil and val ~= 0
	end

	local function shootGloop(item, ent, batch)
		if not ent or not ent.RootPart then return false end

		local key = tostring(ent)
		local now = tick()
		local tracked = gloopTracker[key]

		if tracked and tracked.target == ent then
			if tracked.gloopedUntil and now < tracked.gloopedUntil then
				return false
			end

			if tracked.lastShot and (now - tracked.lastShot) < 3 then
				return false
			end
		end

		if isGlooped(ent) then
			gloopTracker[key] = {
				target = ent,
				lastShot = now,
				gloopedUntil = now + 8
			}
			return false
		end

		local myRoot = entitylib.character and entitylib.character.RootPart
		if not myRoot then return false end

		if (ent.RootPart.Position - myRoot.Position).Magnitude > 45 then
			return false
		end

		-- The trap projectile goes out through the same net-managed ProjectileFire remote the
		-- arrows use; the direct path above is preferred when it resolved, with the shared remote
		-- as the fallback so a slow load cannot silently swallow every gloop.
		local remote = glueRemote or projectileRemote
		if not remote or type(remote.InvokeServer) ~= 'function' then return false end

		local selfPos = myRoot.Position
		local targetPart = ent.RootPart
		local gmeta = bedwars.ProjectileMeta.glue_trap
		local gSpeed = tonumber(gmeta and gmeta.launchVelocity) or 100
		local gGrav = tonumber(gmeta and gmeta.gravitationalAcceleration) or 85

		if gGrav < 1 then
			gGrav = 0
		end

		local gitem = bedwars.ItemMeta[item.itemType]
		local gMax = tonumber(gitem and gitem.maxStrengthChargeSec) or 0
		local gMin = tonumber(gitem and gitem.minStrengthScalar) or 1
		local gPct = (ArrowCharge and ArrowCharge.Value or 100) / 100
		local gRatio = gMax > 0 and math.clamp(gPct, 0, 1) or 1

		gSpeed = gSpeed * (gMin + (1 - gMin) * gRatio)

		local smoothVel, rawVel = smoothedVelocity(ent, targetPart)
		smoothVel = Vector3.new(smoothVel.X, rawVel.Y, smoothVel.Z)

		local playerGravity = targetGravity(ent)
		local aimPos = targetPart.Position - Vector3.new(0, (ent.HipHeight or 2) * 0.25, 0)

		setFHFilter(ent.Character)

		local originPos = selfPos + Vector3.new(0, 1.5, 0)

		local calc, _gImpact, gFlight = prediction.SolveTrajectory(
			originPos,
			gSpeed,
			gGrav,
			aimPos,
			smoothVel,
			playerGravity,
			ent.HipHeight or 2,
			ent.Jumping and 42.6 or nil,
			sharedFastHitsRayParams,
			nil,
			targetPart.Position,
			targetPart,
			nil,
			true
		)

		local gLife = tonumber(gmeta and gmeta.predictionLifetimeSec) or 2

		if not calc or (gFlight and gFlight > gLife) then
			return false
		end

		local dir = CFrame.lookAt(originPos, calc).LookVector
		local busyToken
		local ownsBusy = not batch

		if ownsBusy then
			busyToken = setFHBusy()
		end

		if not fhEquipAwait(item.tool) then
			if ownsBusy then
				fhRestoreSword()
				clearFHBusy(busyToken)
			end
			return false
		end

		local gok, gerr = pcall(function()
			local weaponInst = item.tool
			local inv = replicatedStorage:FindFirstChild('Inventories')
			local mine = inv and inv:FindFirstChild(lplr.Name)
			local w = mine and mine:FindFirstChild(item.itemType)

			if w then
				weaponInst = w
			end

			remote:InvokeServer(
				weaponInst,
				item.itemType,
				'glue_trap',
				originPos,
				selfPos,
				dir * gSpeed,
				httpService:GenerateGUID(true):sub(1, 8):upper(),
				{
					shotId = httpService:GenerateGUID(true):sub(1, 8):upper(),
					drawDurationSec = 0.05
				},
				workspace:GetServerTimeNow() - 0.045
			)
		end)

		if not gok then
			warn('[AetherV2] gloop failed: '..tostring(gerr))

			if ownsBusy then
				fhRestoreSword()
				clearFHBusy(busyToken)
			end

			return false
		end

		gloopTracker[key] = {
			target = ent,
			lastShot = now
		}

		if ownsBusy then
			fhRestoreSword()
			clearFHBusy(busyToken)
		end

		return true
	end

	local fhStage = 1

	local function doFastHitsNEW(ent, meleeRange)
		if not ent or not ent.RootPart or not entitylib.isAlive then
			return false
		end

		local selfPos = entitylib.character.RootPart.Position
		local burstToken
		local fired = false

		local function beginBurst()
			if not burstToken then
				burstToken = setFHBusy()
			end
		end

		local function canSpend(cost)
			return fhWindowOpen(ent, meleeRange, cost)
		end

		if Gloops and Gloops.Enabled and canSpend(0.055) then
			local gloopItem = getGloopItem()

			if gloopItem then
				beginBurst()

				if shootGloop(gloopItem, ent, true) then
					fired = true
				end
			end
		end

		if Arrows and Arrows.Enabled and canSpend(0.055) then
			local src = getProjectiles()
			local ready

			for _i = 1, #src do
				local p = src[_i]

				if p and canShoot(p) then
					ready = {
						p[1],
						p[2],
						p[3],
						p[4]
					}
					break
				end
			end

			if ready then
				beginBurst()

				if shootProjectile(
					ready[1],
					ready[2],
					ready[3],
					ready[4],
					selfPos,
					ent,
					false,
					true
				) then
					fired = true
				end
			end
		end

		if Fireball and Fireball.Enabled and canSpend(0.055) then
			local fb = getFireballItem()

			if fb and canShoot(fb) then
				beginBurst()

				if shootProjectile(
					fb[1],
					fb[2],
					fb[3],
					fb[4],
					selfPos,
					ent,
					false,
					true
				) then
					fired = true
				end
			end
		end

		if Kits and Kits.Enabled and canSpend(0.06) then
			local kw = getKitWeapon()

			if kw and canShoot(kw) then
				beginBurst()

				if shootKitWeapon(
					kw[1],
					kw[2],
					kw[3],
					selfPos,
					ent,
					true
				) then
					fired = true
				end
			end
		end

		if burstToken then
			fhRestoreSword()
			clearFHBusy(burstToken)
		end

		return fired
	end

	local function doFastHitsLegitSwitch(ent)
		if not ent or not ent.RootPart or not entitylib.isAlive then
			return false
		end

		local selfPos = entitylib.character.RootPart.Position
		local projectiles = getProjectiles()

		if not projectiles or #projectiles == 0 then
			return false
		end

		local readyProj

		for _, proj in projectiles do
			if proj and canShoot(proj) then
				readyProj = {
					proj[1],
					proj[2],
					proj[3],
					proj[4]
				}
				break
			end
		end

		if not readyProj then
			return false
		end

		local item, ammo, projectile, itemMeta = unpack(readyProj)
		local bowSlot, swordSlot
		local originalSlot = store.inventory.hotbarSlot
		local hotbar = store.inventory.hotbar

		for i = 1, #hotbar do
			local hv = hotbar[i]

			if hv and hv.item and hv.item.itemType then
				if hv.item.itemType == item.itemType and not bowSlot then
					bowSlot = i - 1
				end

				local hm = bedwars.ItemMeta[hv.item.itemType]

				if hm and hm.sword and not swordSlot then
					swordSlot = i - 1
				end
			end
		end

		if not bowSlot then
			return false
		end

		local token = setFHBusy()

		if hotbarSwitch(bowSlot) then
			task.wait(0.03)
		end

		local fired = shootProjectile(
			item,
			ammo,
			projectile,
			itemMeta,
			selfPos,
			ent,
			true,
			true
		)

		hotbarSwitch(swordSlot or originalSlot)
		clearFHBusy(token)

		return fired and true or false
	end

	local function doFastHits()
		if not FastHits or not FastHits.Enabled then return end
		if not Killaura or not Killaura.Enabled then return end
		if not entitylib.isAlive then return end

		recoverFastHitState()

		if Limit and Limit.Enabled then
			if not store.hand or store.hand.toolType ~= 'sword' then
				return
			end

			if bedwars.DaoController and bedwars.DaoController.chargingMaid then
				return
			end
		end

		local srvNow = workspace:GetServerTimeNow()

		if srvNow - fhLastShotTime < 0.04 then
			return
		end

		local selfRoot = entitylib.character and entitylib.character.RootPart
		if not selfRoot then return end

		local meleeRange = AttackRange.Value + 2
		local fhRange = AttackRange.Value + 5
		local sort = sortmethods[Sort.Value] or sortmethods['Distance']

		local list = entitylib.AllPosition({
			Range = fhRange,
			Wallcheck = Targets.Walls.Enabled or nil,
			Part = 'RootPart',
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Limit = 5,
			Sort = sort
		})

		local ent

		for _, target in list do
			if target and target.RootPart and fhInAngle(target) then
				ent = target
				break
			end
		end

		local meleeTarget = store.KillauraTarget

		if meleeTarget
			and meleeTarget.RootPart
			and meleeTarget.Character
			and meleeTarget.Character.Parent
			and fhInAngle(meleeTarget) then

			local meleeDistance = (meleeTarget.RootPart.Position - selfRoot.Position).Magnitude

			if meleeDistance <= meleeRange then
				ent = meleeTarget
			end
		end

		if not ent then return end

		if (ent.RootPart.Position - selfRoot.Position).Magnitude > fhRange then
			return
		end

		if not fhWindowOpen(ent, meleeRange, 0.05) then
			return
		end

		local fired

		if LegitSwitch and LegitSwitch.Enabled then
			fired = doFastHitsLegitSwitch(ent)
		else
			fired = doFastHitsNEW(ent, meleeRange)
		end

		if fired then
			fhLastShotTime = srvNow
		end
	end

	local function startAutoShootLoop()
		if autoShootLoop then return end

		fhUsageIndex = 1
		fhStage = 1
		table.clear(ProjectileDelay)

		autoShootLoop = task.spawn(function()
			while Killaura and Killaura.Enabled and FastHits and FastHits.Enabled do
				pcall(doFastHits)
				runService.Heartbeat:Wait()
			end

			clearFHBusy()
			autoShootLoop = nil
		end)
	end

	local function stopAutoShootLoop()
		if autoShootLoop then
			pcall(task.cancel, autoShootLoop)
			autoShootLoop = nil
		end

		table.clear(ProjectileDelay)
		table.clear(_fhVelHistory)
		table.clear(gloopTracker)

		fhUsageIndex = 1
		fhStage = 1

		fhBusyToken = fhBusyToken + 1
		fhBusy = false
		fhBusySince = 0

		store._fhBusySince = nil
		store._fhShotAt = nil
		store._fhIdle = nil
	end

	local killauraFireLoop
	local _lockedTarget = nil
	local _lockedUntil = 0
	local _attackSwordName = nil
	local _kaWallParams = RaycastParams.new()
	_kaWallParams.FilterType = Enum.RaycastFilterType.Exclude

	local function withinAngle(v)
		if not AngleSlider or AngleSlider.Value >= 360 then return true end
		if not v or not v.RootPart then return false end
		local root = entitylib.character and entitylib.character.RootPart
		if not root then return true end
		local flatLV = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		local facing = flatLV.Magnitude > 0.001 and flatLV.Unit or root.CFrame.RightVector
		local flat = (v.RootPart.Position - root.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude <= 1 then return true end
		return math.acos(math.clamp(facing:Dot(flat.Unit), -1, 1)) <= math.rad(AngleSlider.Value) / 2
	end

	local function inReach(v)
		local root = entitylib.character and entitylib.character.RootPart
		if not root or not v or not v.RootPart then return false end
		return (v.RootPart.Position - root.Position).Magnitude <= (AttackRange.Value + TARGET_QUERY_PADDING)
	end

	local function aliveTarget(v)
		if not v or not v.RootPart then return false end
		local char = v.Character
		if not char or not char.Parent then return false end
		if v.Health ~= nil and v.Health <= 0 then return false end
		return true
	end

	local function attackWallClear(v)
		if not Targets or not Targets.Walls or not Targets.Walls.Enabled then
			return true
		end

		local root = entitylib.character and entitylib.character.RootPart
		if not root or not v or not v.RootPart then return false end

		_kaWallParams.FilterDescendantsInstances = {lplr.Character, gameCamera}

		local delta = v.RootPart.Position - root.Position
		if delta.Magnitude < 0.01 then return true end

		local hit = workspace:Raycast(root.Position, delta, _kaWallParams)
		if not hit then return true end

		return v.Character and hit.Instance and hit.Instance:IsDescendantOf(v.Character) or false
	end

	local function lockTarget(v)
		_lockedTarget = v
		_lockedUntil = tick() + TARGET_LOCK_GRACE
		return v
	end

	local function resolveTarget()
		local now = tick()

		if aliveTarget(_lockedTarget)
			and inReach(_lockedTarget)
			and withinAngle(_lockedTarget)
			and attackWallClear(_lockedTarget) then

			_lockedUntil = now + TARGET_LOCK_GRACE
			return _lockedTarget
		end

		local preferred = store.KillauraTarget

		if aliveTarget(preferred)
			and inReach(preferred)
			and withinAngle(preferred)
			and attackWallClear(preferred) then

			return lockTarget(preferred)
		end

		local list = entitylib.AllPosition({
			Range = AttackRange.Value + TARGET_QUERY_PADDING,
			Wallcheck = Targets.Walls.Enabled or nil,
			Part = 'RootPart',
			Players = Targets.Players.Enabled,
			NPCs = Targets.NPCs.Enabled,
			Limit = 8,
			Sort = sortmethods[Sort.Value] or sortmethods['Distance']
		})

		for _, ent in list do
			if aliveTarget(ent)
				and inReach(ent)
				and withinAngle(ent)
				and attackWallClear(ent) then

				return lockTarget(ent)
			end
		end

		_lockedTarget = nil
		_lockedUntil = 0
		return nil
	end

	local function attemptFire()
		if fastHitBlocksSword() then
			return false
		end

		local v = resolveTarget()
		if not v then return false end

		local sword, meta = getAttackData()

		if not sword or not meta then
			local hand = store.hand and store.hand.tool
			local hmeta = hand and bedwars.ItemMeta[hand.Name]
			local hspd = hmeta and hmeta.sword and hmeta.sword.attackSpeed

			if type(hspd) == 'number' and hspd >= 0.1 then
				kaPeriod = hspd
			end

			return false
		end

		local swordName = sword.tool.Name

		if _attackSwordName ~= swordName then
			_attackSwordName = swordName
			kaNextFire = 0
			kaLastSrv = 0
			kaLastSend = 0
		end

		local spd = meta.sword and meta.sword.attackSpeed
		if type(spd) == 'number' and spd >= 0.1 then
			kaFloor = math.min(SERVER_FLOOR, spd)
			kaPeriod = math.max(spd - KILLAURA_RATE_LEAD, kaFloor)
		else
			kaFloor = SERVER_FLOOR
			kaPeriod = HIT_PERIOD
		end

		local srvReadyNow = workspace:GetServerTimeNow()

		if kaLastSend > 0 and (srvReadyNow - kaLastSend) < kaFloor then
			return false
		end

		local weaponInst = sword.tool

		pcall(function()
			local inv = replicatedStorage:FindFirstChild('Inventories')
			local mine = inv and inv:FindFirstChild(lplr.Name)
			local w = mine and mine:FindFirstChild(sword.tool.Name)

			if w then
				weaponInst = w
			end
		end)

		local char = lplr.Character
		local selfRoot = entitylib.character and entitylib.character.RootPart
		if not char or not selfRoot then return false end

		local tchar = v.Character
		local targetRoot = v.RootPart
		if not tchar or not tchar.Parent or not targetRoot or not targetRoot.Parent then return false end

		local selfPos = selfRoot.Position
		local targetPos = targetRoot.Position
		local dist = (targetPos - selfPos).Magnitude

		if dist > AttackRange.Value + 2 then
			return false
		end

		if AirHit and AirHit.Enabled and AirHitsChance and AirHitsChance.Value < 100 then
			local hum = tchar:FindFirstChildOfClass('Humanoid')

			if hum then
				local inAir = hum.FloorMaterial == Enum.Material.Air

				if not inAir then
					local st = hum:GetState()
					inAir = st == Enum.HumanoidStateType.Jumping
						or st == Enum.HumanoidStateType.Freefall
				end

				if not inAir then
					local root = tchar.PrimaryPart
					local vy = root and root.AssemblyLinearVelocity.Y or 0
					inAir = math.abs(vy) > 3
				end

				if inAir then
					if math.random(1, 100) > AirHitsChance.Value then
						return false
					end
				end
			end
		end

		-- The summoner claw is not a sword swing: it goes through the game's own attack request and
		-- its local animation, exactly like AutoKaida does it.
		if sword.tool.Name:find('summoner_claw', 1, true) then
			local delta = targetPos - selfPos
			if delta.Magnitude > 0.01 then
				local dir = CFrame.lookAt(selfPos, targetPos).LookVector
				pcall(function()
					bedwars.Handler:Get('SummonerClawAttackRequest'):Fire(nil, {
						position = selfPos + dir * math.max(delta.Magnitude - 16.399, 0),
						direction = dir,
						clientTime = workspace:GetServerTimeNow()
					})
					bedwars.SummonerClawHandController.lastAttackTime = workspace:GetServerTimeNow()
					bedwars.SummonerClawController:clawAttack(lplr, selfPos, dir, sword.tool.Name)
				end)
			end
			return false
		end

		if not FireAttackRemote(weaponInst, tchar, selfPos, targetPos) then
			return false
		end

		lockTarget(v)

		local srvNow = workspace:GetServerTimeNow()

		lastAttackTime = tick()

		-- Let the rest of the pack (the trap disabler, Breaker, the swing animation) see the swing
		-- the same way it sees a real one.
		if bedwars.SwordController then
			bedwars.SwordController.lastAttack = srvNow
		end

		store.attackReach = (dist * 100) // 1 / 100
		store.attackReachUpdate = tick() + 1

		kaLastSend = srvNow
		kaLastSrv = srvNow

		if kaNextFire <= 0 then
			kaNextFire = srvNow + kaPeriod
		else
			local phased = kaNextFire + kaPeriod
			if phased <= srvNow then
				local missed = math.floor((srvNow - phased) / kaPeriod) + 1
				phased += missed * kaPeriod
			end
			kaNextFire = phased
		end

		return true
	end

	local function startKillauraFireLoop()
		if killauraFireLoop then return end

		kaPeriod = HIT_PERIOD
		kaFloor = SERVER_FLOOR
		kaNextFire = 0
		kaLastSrv = 0
		kaLastSend = 0
		kaBackoff = 0
		kaPendingChar = nil
		kaPendingSent = 0
		kaConfirmSeen = false
		kaLastConfirm = 0
		kaConfirmGap = 0.298
		kaStableConfirms = 0
		kaFrameEMA = 1 / 60

		killauraFireLoop = task.spawn(function()
			local lastStep = os.clock()
			local stepSignal = runService.PostSimulation or runService.Heartbeat

			while Killaura and Killaura.Enabled do
				stepSignal:Wait()

				local clockNow = os.clock()
				local dt = clockNow - lastStep
				lastStep = clockNow

				if dt > 0 and dt < 0.20 then
					kaFrameEMA += (dt - kaFrameEMA) * 0.15
				end

				updateKAAdaptive()

				local srvNow = workspace:GetServerTimeNow()
				if kaNextFire <= 0
					or (
						srvNow >= kaNextFire
						and (
							kaLastSend <= 0
							or (srvNow - kaLastSend) >= kaFloor
						)
					) then

					pcall(attemptFire)
				end
			end
		end)
	end

	local function stopKillauraFireLoop()
		if killauraFireLoop then
			pcall(task.cancel, killauraFireLoop)
			killauraFireLoop = nil
		end

		_lockedTarget = nil
		_lockedUntil = 0
		_attackSwordName = nil
		kaNextFire = 0
		kaPendingChar = nil
		kaPendingSent = 0
		kaBackoff = 0
		kaSync = 0
		kaSyncSrv = 0
	end

	Killaura = vape.Categories.Blatant:CreateModule({
		Name = 'KillauraV2',
		Function = function(callback)
			if callback then
				lastAttackTime = 0
				lastTargetTime = 0
				resetSwordCooldown()

				if inputService.TouchEnabled and not preserveSwordIcon then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = Limit and Limit.Enabled
					end)
				end

				if FastHits and FastHits.Enabled then
					startAutoShootLoop()
				end

				startKillauraFireLoop()

				if Animation
					and Animation.Enabled
					and not (
						identifyexecutor
						and table.find(
							{'Argon', 'Delta'},
							({identifyexecutor()})[1]
						)
					) then

					task.spawn(function()
						local started = false

						repeat
							if Attacking and not (LegitAura and LegitAura.Enabled) then
								if not armC0 then
									armC0 = gameCamera.Viewmodel.RightHand.RightWrist.C0
								end

								local first = not started
								started = true

								if AnimationMode.Value == 'Random' then
									anims.Random = {{
										CFrame = CFrame.Angles(
											math.rad(math.random(1, 360)),
											math.rad(math.random(1, 360)),
											math.rad(math.random(1, 360))
										),
										Time = 0.12
									}}
								end

								for _, v in anims[AnimationMode.Value] do
									if AnimTween then
										AnimTween:Destroy()
										AnimTween = nil
									end

									AnimTween = tweenService:Create(
										gameCamera.Viewmodel.RightHand.RightWrist,
										TweenInfo.new(
											first
												and (AnimationTween.Enabled and 0.001 or 0.1)
												or v.Time / AnimationSpeed.Value,
											Enum.EasingStyle.Linear
										),
										{
											C0 = armC0 * v.CFrame
										}
									)

									AnimTween:Play()
									AnimTween.Completed:Wait()

									first = false

									if (not Killaura.Enabled) or (not Attacking) then
										break
									end
								end
							elseif started then
								started = false

								if AnimTween then
									AnimTween:Destroy()
									AnimTween = nil
								end

								AnimTween = tweenService:Create(
									gameCamera.Viewmodel.RightHand.RightWrist,
									TweenInfo.new(
										AnimationTween.Enabled and 0.001 or 0.3,
										Enum.EasingStyle.Exponential
									),
									{
										C0 = armC0
									}
								)

								AnimTween:Play()
							end

							if not started then
								task.wait(1 / 3.5)
							end
						until (not Killaura.Enabled) or (not Animation.Enabled)
					end)
				end

				local _gatherCache = nil
				local _gatherCacheTime = 0
				local _continueSwingUntil = 0
				local _hadSwingTarget = false

				local function gatherTargets()
					if _gatherCache and (tick() - _gatherCacheTime) < 0.02 then
						return _gatherCache[1], _gatherCache[2]
					end

					local attackWalls = Targets.Walls.Enabled or nil
					local players = Targets.Players.Enabled
					local npcs = Targets.NPCs.Enabled
					local sort = sortmethods[Sort.Value]

					local function buildList(range, wallcheck)
						return entitylib.AllPosition({
							Range = range,
							Wallcheck = wallcheck,
							Part = 'RootPart',
							Players = players,
							NPCs = npcs,
							Limit = 5,
							Sort = sort or sortmethods['Distance']
						})
					end

					local attackPlrs = buildList(AttackRange.Value + TARGET_QUERY_PADDING, attackWalls)
					local swingPlrs

					if not attackWalls and AttackRange.Value == SwingRange.Value then
						swingPlrs = attackPlrs
					else
						swingPlrs = buildList(SwingRange.Value, nil)
					end

					_gatherCache = {
						swingPlrs,
						attackPlrs
					}

					_gatherCacheTime = tick()

					return swingPlrs, attackPlrs
				end

				local _cachedSwordType = nil
				local _cachedIsClaw = false

				repeat
					if AttackCheck and AttackCheck.Enabled then
						local triggered = false

						local stunTime = lplr.Character
							and lplr.Character:GetAttribute('StunnedUntilTime')

						if stunTime and stunTime > workspace:GetServerTimeNow() then
							triggered = true
						end

						if not triggered and kitChecks then
							for _, check in pairs(kitChecks) do
								local ok, res = pcall(check)

								if ok and res then
									triggered = true
									break
								end
							end
						end

						if triggered then
							Attacking = false
							getgenv().Attacking = false
							store.KillauraTarget = nil
							_lockedTarget = nil
							_lockedUntil = 0

							task.wait(0.3)
							continue
						end
					end

					local sword, meta = getAttackData()

					if not sword then
						if Attacking then
							Attacking = false
							getgenv().Attacking = false
							store.KillauraTarget = nil
						end

						task.wait(0.05)
						continue
					end

					if targetinfo and targetinfo.Targets then
						targetinfo.Targets.Killaura = nil
					end

					local swordName = sword.tool.Name

					if _cachedSwordType == nil then
						_cachedSwordType = swordName
						_cachedIsClaw = swordName:find('summoner_claw') ~= nil
					elseif swordName ~= _cachedSwordType and not fhBusy then
						_cachedSwordType = swordName
						_cachedIsClaw = swordName:find('summoner_claw') ~= nil
						resetSwordCooldown()

						_adCacheSword = nil
						_adCacheMeta = nil
						_adCacheTime = 0
					end

					local isClaw = _cachedIsClaw

					local selfpos = entitylib.character.RootPart.Position
					local flatLV = entitylib.character.RootPart.CFrame.LookVector * Vector3.new(1, 0, 1)
					local localfacing = flatLV.Magnitude > 0.001
						and flatLV.Unit
						or entitylib.character.RootPart.CFrame.RightVector

					local maxAngle = math.rad(AngleSlider.Value) / 2
					local swingPlrs, attackPlrs = gatherTargets()

					local function passesAngle(v)
						if AngleSlider.Value >= 360 then
							return true
						end

						local flat = (v.RootPart.Position - selfpos) * Vector3.new(1, 0, 1)

						if flat.Magnitude <= 1.0 then
							return true
						end

						return math.acos(
							math.clamp(
								localfacing:Dot(flat.Unit),
								-1,
								1
							)
						) <= maxAngle
					end

					local hasValidSwingTargets = false
					local hasValidAttackTargets = false
					local chosen = nil

					for _, v in swingPlrs do
						if passesAngle(v) then
							hasValidSwingTargets = true
							break
						end
					end

					for _, v in attackPlrs do
						if passesAngle(v) then
							hasValidAttackTargets = true
							chosen = v
							break
						end
					end

					local nowTarget = tick()

					if hasValidSwingTargets then
						lastTargetTime = nowTarget
						_hadSwingTarget = true
						_continueSwingUntil = 0
					elseif _hadSwingTarget then
						_hadSwingTarget = false

						if Swing and Swing.Enabled then
							_continueSwingUntil = nowTarget + ((ContinueSwingTime and ContinueSwingTime.Value) or 2)
						else
							_continueSwingUntil = 0
						end
					end

					if chosen then
						if not Attacking then
							Attacking = true
							getgenv().Attacking = true
						end
					else
						if Attacking then
							Attacking = false
							getgenv().Attacking = false
						end

						store.KillauraTarget = nil
					end

					local shouldSwing = hasValidSwingTargets
						or hasValidAttackTargets
						or ((Swing and Swing.Enabled) and nowTarget < _continueSwingUntil)
					local isLegitAura = LegitAura and LegitAura.Enabled

					if shouldSwing or isLegitAura then
						if not fhBusy
							and store.hand
							and store.hand.tool ~= sword.tool
							and (tick() - (store._kaSwitch or 0)) > 0.25 then

							store._kaSwitch = tick()
							switchItem(sword.tool, 0)
						end

						if chosen then
							store.KillauraTarget = chosen
							targetinfo.Targets[chosen] = tick() + 1

							targetinfo.Targets.Killaura = {
								Humanoid = {
									Health = chosen.Health,
									MaxHealth = chosen.MaxHealth
								},
								Player = chosen.Player
							}
						end

						if not isClaw and AnimDelay <= tick() then
							local allowSwingAnim = shouldSwing
								and not (LegitAura and LegitAura.Enabled)
								and not (Animation and Animation.Enabled)

							if allowSwingAnim then
								local swingSpeed = (SwingTime and SwingTime.Enabled)
									and math.max(SwingTimeSlider.Value, 0.11)
									or kaPeriod

								AnimDelay = tick() + swingSpeed

								if isOnTinker() then
									playTinkerSwing()
								else
									pcall(function()
										bedwars.SwordController:playSwordEffect(meta, false)

										if meta.displayName and meta.displayName:find(' Scythe') then
											bedwars.ScytheController:playLocalAnimation()
										end
									end)
								end

								if vape.ThreadFix and setthreadidentity then
									pcall(setthreadidentity, 8)
								end
							end
						end
					end

					task.wait()
				until not Killaura.Enabled
			else
				stopAutoShootLoop()
				stopKillauraFireLoop()

				store.KillauraTarget = nil

				if inputService.TouchEnabled then
					pcall(function()
						lplr.PlayerGui.MobileUI['2'].Visible = true
					end)
				end

				Attacking = false
				getgenv().Attacking = false

				if targetinfo and targetinfo.Targets then
					targetinfo.Targets.Killaura = nil
				end

				if armC0 then
					if AnimTween then
						AnimTween:Destroy()
						AnimTween = nil
					end

					AnimTween = tweenService:Create(
						gameCamera.Viewmodel.RightHand.RightWrist,
						TweenInfo.new(
							AnimationTween and AnimationTween.Enabled and 0.001 or 0.3,
							Enum.EasingStyle.Exponential
						),
						{
							C0 = armC0
						}
					)

					AnimTween:Play()
				end
			end
		end
	})

	pcall(function()
		local PSI = Killaura:CreateToggle({
			Name = 'Preserve Sword Icon',
			Function = function(callback)
				preserveSwordIcon = callback
			end,
			Default = true
		})

		PSI.Object.Visible = inputService.TouchEnabled
	end)

	Targets = Killaura:CreateTargets({
		Players = true,
		NPCs = true
	})

	SwingRange = Killaura:CreateSlider({
		Name = 'Swing range',
		Min = 1,
		Max = 40,
		Default = 22,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	AttackRange = Killaura:CreateSlider({
		Name = 'Attack range',
		Min = 1,
		Max = 22,
		Default = 22,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end
	})

	AngleSlider = Killaura:CreateSlider({
		Name = 'Max angle',
		Min = 1,
		Max = 360,
		Default = 360
	})

	Sort = Killaura:CreateDropdown({
		Name = 'Target Mode',
		List = {'Mouse', 'Distance', 'Damage', 'Angle', 'Health', 'Kit', 'Threat'},
		Default = 'Mouse'
	})

	GUI = Killaura:CreateToggle({
		Name = 'GUI check'
	})

	Swing = Killaura:CreateToggle({
		Name = 'Continue Swinging',
		Default = true,
		Tooltip = 'Continues the sword swing animation after a target is out of range',
		Function = function(callback)
			if ContinueSwingTime then
				ContinueSwingTime.Object.Visible = callback
			end
		end
	})

	ContinueSwingTime = Killaura:CreateSlider({
		Name = 'Continue Swing Time',
		Min = 0.1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 's',
		Darker = true,
		Visible = true
	})

	SwingTime = Killaura:CreateToggle({
		Name = 'Custom Swing Time',
		Function = function(callback)
			if SwingTimeSlider then
				SwingTimeSlider.Object.Visible = callback
			end
		end,
		Tooltip = 'Changes your swing time'
	})

	SwingTimeSlider = Killaura:CreateSlider({
		Name = 'Custom Swing Speed',
		Min = 0,
		Max = 1,
		Default = 0,
		Decimal = 100,
		Visible = false
	})

	Animation = Killaura:CreateToggle({
		Name = 'Custom Animation',
		Function = function(callback)
			if AnimationMode then
				AnimationMode.Object.Visible = callback
			end

			if AnimationTween then
				AnimationTween.Object.Visible = callback
			end

			if AnimationSpeed then
				AnimationSpeed.Object.Visible = callback
			end

			if Killaura.Enabled then
				Killaura:Toggle()
				Killaura:Toggle()
			end
		end
	})

	local animnames = {}

	for i in anims do
		table.insert(animnames, i)
	end

	AnimationMode = Killaura:CreateDropdown({
		Name = 'Animation Mode',
		List = animnames,
		Darker = true,
		Visible = false
	})

	AnimationSpeed = Killaura:CreateSlider({
		Name = 'Animation Speed',
		Min = 0.1,
		Max = 2,
		Default = 1,
		Decimal = 10,
		Darker = true,
		Visible = false
	})

	AnimationTween = Killaura:CreateToggle({
		Name = 'No Tween',
		Darker = true,
		Visible = false
	})

	Limit = Killaura:CreateToggle({
		Name = 'Limit to items',
		Function = function(callback)
			if inputService.TouchEnabled and Killaura.Enabled then
				pcall(function()
					lplr.PlayerGui.MobileUI['2'].Visible = callback
				end)
			end
		end,
		Tooltip = 'Only attacks when you are holding a sword'
	})

	LegitAura = Killaura:CreateToggle({
		Name = 'Swing only',
		Tooltip = 'Only attacks when you are manually swinging'
	})

	AirHit = Killaura:CreateToggle({
		Name = 'Air Hits',
		Default = true,
		Tooltip = 'Lets you hit enemies in the air',
		Function = function(callback)
			if AirHitsChance then
				AirHitsChance.Object.Visible = callback
			end
		end
	})

	AirHitsChance = Killaura:CreateSlider({
		Name = 'Air Hits Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%',
		Decimal = 5,
		Darker = true,
		Visible = false
	})

	local _watchersActive = true

	Killaura:Clean(function()
		_watchersActive = false
	end)

	task.spawn(function()
		local wasAvailable = false
		local availSince = 0

		while _watchersActive and vape.Loaded do
			task.wait(0.05)

			if bedwars.AbilityController then
				local ok, nowAvailable = pcall(
					bedwars.AbilityController.canUseAbility,
					bedwars.AbilityController,
					'rebellion_shield'
				)

				if ok then
					nowAvailable = nowAvailable == true

					if nowAvailable and not wasAvailable then
						availSince = tick()
					end

					if wasAvailable
						and not nowAvailable
						and availSince > 0
						and (tick() - availSince) > 1 then

						store.silasAbilityTime = tick()
					end

					wasAvailable = nowAvailable
				end
			end
		end
	end)

	task.spawn(function()
		local wasStomp, wasKick = false, false
		local stompSince, kickSince = 0, 0

		while _watchersActive and vape.Loaded do
			task.wait(0.05)

			if bedwars.AbilityController then
				local ok1, nowStomp = pcall(
					bedwars.AbilityController.canUseAbility,
					bedwars.AbilityController,
					'BLOCK_STOMP'
				)

				local ok2, nowKick = pcall(
					bedwars.AbilityController.canUseAbility,
					bedwars.AbilityController,
					'BLOCK_KICK'
				)

				if ok1 then
					nowStomp = nowStomp == true

					if nowStomp and not wasStomp then
						stompSince = tick()
					end

					if wasStomp
						and not nowStomp
						and stompSince > 0
						and (tick() - stompSince) > 1 then

						store.terraStompTime = tick()
					end

					wasStomp = nowStomp
				end

				if ok2 then
					nowKick = nowKick == true

					if nowKick and not wasKick then
						kickSince = tick()
					end

					if wasKick
						and not nowKick
						and kickSince > 0
						and (tick() - kickSince) > 1 then

						store.terraKickTime = tick()
					end

					wasKick = nowKick
				end
			end
		end
	end)

	kitChecks = {
		['Sophia'] = function()
			return isFrozen(nil, FROZEN_THRESHOLD)
		end,
		['Sigrid'] = function()
			return entitylib.isAlive
				and lplr.Character
				and lplr.Character:FindFirstChild('elk') ~= nil
		end
	}

	AttackCheck = Killaura:CreateToggle({
		Name = 'Attack Check',
		Tooltip = 'Cheks whether you are able to attack or not',
		Default = false
	})

	FastHits = Killaura:CreateToggle({
		Name = 'Fast Hits',
		Default = false,
		Tooltip = 'Fires projectiles to do more damage',
		Function = function(call)
			if ArrowCharge then
				ArrowCharge.Object.Visible = call
			end

			if LegitSwitch then
				LegitSwitch.Object.Visible = call
			end

			if Kits then
				Kits.Object.Visible = call
			end

			if Arrows then
				Arrows.Object.Visible = call
			end

			if Gloops then
				Gloops.Object.Visible = call
			end

			if Fireball then
				Fireball.Object.Visible = call
			end

			if call then
				if Killaura and Killaura.Enabled then
					startAutoShootLoop()
				end
			else
				stopAutoShootLoop()
			end
		end
	})

	LegitSwitch = Killaura:CreateToggle({
		Name = 'Legit Switch',
		Default = false,
		Darker = true,
		Visible = false,
		Tooltip = 'Switches to an item and switches back after used'
	})

	Kits = Killaura:CreateToggle({
		Name = 'Kits',
		Default = false,
		Darker = true,
		Visible = false,
		Tooltip = 'Uses kit abilities when in combat'
	})

	Arrows = Killaura:CreateToggle({
		Name = 'Arrows',
		Default = true,
		Darker = true,
		Visible = false,
		Tooltip = 'Shoots arrows when in combat'
	})

	Gloops = Killaura:CreateToggle({
		Name = 'Gloops',
		Default = false,
		Darker = true,
		Visible = false,
		Tooltip = 'Gloops enemies when in combat'
	})

	Fireball = Killaura:CreateToggle({
		Name = 'Fireball',
		Default = false,
		Darker = true,
		Visible = false,
		Tooltip = 'Throws fireballs when in combat'
	})

	ArrowCharge = Killaura:CreateSlider({
		Name = 'Charge Rate',
		Suffix = '%',
		Min = 0,
		Max = 100,
		Default = 100,
		Darker = true,
		Visible = false
	})

	task.defer(function()
		if AirHit
			and AirHit.Enabled
			and AirHitsChance
			and AirHitsChance.Object then

			AirHitsChance.Object.Visible = true
		end

		if FastHits and FastHits.Enabled then
			if ArrowCharge then
				ArrowCharge.Object.Visible = true
			end

			if LegitSwitch then
				LegitSwitch.Object.Visible = true
			end

			if Kits then
				Kits.Object.Visible = true
			end

			if Arrows then
				Arrows.Object.Visible = true
			end

			if Gloops then
				Gloops.Object.Visible = true
			end

			if Fireball then
				Fireball.Object.Visible = true
			end
		end
	end)
end)

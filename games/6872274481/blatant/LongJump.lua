run(function()
    local Value
    local CameraDir
    local LimitItems
    local ChangeDir
    local LongJumpBypass
    local BypassBoost
    local start
    local JumpTick, JumpSpeed, Direction = tick(), 0
    local jumpWasActive = false
	local function horizontalDirection(direction)
		local flat = direction and Vector3.new(direction.X, 0, direction.Z) or Vector3.zero
		if flat.Magnitude > 0.001 then return flat.Unit end
		local look = entitylib.isAlive and entitylib.character.RootPart.CFrame.LookVector or Vector3.zAxis
		flat = Vector3.new(look.X, 0, look.Z)
		return flat.Magnitude > 0.001 and flat.Unit or Vector3.zAxis
	end
    local projectileRemote = {InvokeServer = function() end}
    task.spawn(function()
        projectileRemote = bedwars.Client:Get(remotes.FireProjectile).instance
    end)

    local function launchProjectile(item, pos, proj, speed, dir)
        if not pos then return end

        pos = pos - dir * 0.1
        local shootPosition = (CFrame.lookAlong(pos, Vector3.new(0, -speed, 0)) * CFrame.new(Vector3.new(-bedwars.BowConstantsTable.RelX, -bedwars.BowConstantsTable.RelY, -bedwars.BowConstantsTable.RelZ)))
        switchItem(item.tool, 0)
        task.wait(0.1)
        bedwars.ProjectileController:createLocalProjectile(bedwars.ProjectileMeta[proj], proj, proj, shootPosition.Position, '', shootPosition.LookVector * speed, {drawDurationSeconds = 1})
        if projectileRemote:InvokeServer(item.tool, proj, proj, shootPosition.Position, pos, shootPosition.LookVector * speed, httpService:GenerateGUID(true), {drawDurationSeconds = 1}, workspace:GetServerTimeNow() - 0.045) then
			local itemMeta = bedwars.ItemMeta[item.itemType]
			local source = itemMeta and itemMeta.projectileSource
			local shoot = source and type(source.launchSound) == 'table' and #source.launchSound > 0 and source.launchSound or nil
			shoot = shoot and shoot[math.random(1, #shoot)] or nil
            if shoot then
                bedwars.SoundManager:playSound(shoot)
            end
        end
    end

    local LongJumpMethods = {
        cannon = function(_, pos, dir)
            pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
            local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
            bedwars.placeBlock(rounded, 'cannon', false)

            task.delay(0, function()
                local block, blockpos = getPlacedBlock(rounded)
                if block and block.Name == 'cannon' and (entitylib.character.RootPart.Position - block.Position).Magnitude < 20 then
                    local breaktype = bedwars.ItemMeta[block.Name].block.breakType
                    local tool = getBreakTool(breaktype)
                    if tool then
                        switchItem(tool.tool)
                    end

                    bedwars.Client:Get(remotes.CannonAim):SendToServer({
                        cannonBlockPos = blockpos,
                        lookVector = dir
                    })

                    local broken = 0.1
                    if bedwars.BlockController:calculateBlockDamage(lplr, {blockPosition = blockpos}) < block:GetAttribute('Health') then
                        broken = 0.4
                        bedwars.breakBlock(block, true, true)
                    end

                    task.delay(broken, function()
                        for _ = 1, 3 do
                            local call = bedwars.Client:Get(remotes.CannonLaunch):CallServer({cannonBlockPos = blockpos})
                            if call then
                                bedwars.breakBlock(block, true, true)
                                JumpSpeed = 5.25 * Value.Value
                                JumpTick = tick() + 2.3
								Direction = horizontalDirection(dir)
                                break
                            end
                            task.wait(0.1)
                        end
                    end)
                end
            end)
        end,
        cat = function(_, _, dir)
            LongJump:Clean(vapeEvents.CatPounce.Event:Connect(function()
                JumpSpeed = 4 * Value.Value
                JumpTick = tick() + 2.5
				Direction = horizontalDirection(dir)
                entitylib.character.RootPart.Velocity = Vector3.zero
            end))

            -- The pounce has to be timed off the frame the game actually leaps, and the only
            -- way to know that is the controller itself. This used to be fired by AutoKit's cat
            -- routine, so cat LongJumps silently did nothing unless that module happened to be
            -- on with the cat toggle ticked; the hook lives here now and is put back on cleanup.
            if bedwars.CatController and typeof(bedwars.CatController.leap) == 'function' then
                local controller = bedwars.CatController
                local original = controller.leap
                local hook
                hook = function(...)
                    vapeEvents.CatPounce:Fire()
                    return original(...)
                end
                controller.leap = hook
                LongJump:Clean(function()
                    if controller.leap == hook then
                        controller.leap = original
                    end
                end)
            end

            if not bedwars.AbilityController:canUseAbility('CAT_POUNCE') then
                repeat task.wait() until bedwars.AbilityController:canUseAbility('CAT_POUNCE') or not LongJump.Enabled
            end

            if bedwars.AbilityController:canUseAbility('CAT_POUNCE') and LongJump.Enabled then
                bedwars.AbilityController:useAbility('CAT_POUNCE')
            end
        end,
        fireball = function(item, pos, dir)
            launchProjectile(item, pos, 'fireball', 60, dir)
        end,
        grappling_hook = function(item, pos, dir)
            launchProjectile(item, pos, 'grappling_hook_projectile', 140, dir)
        end,
        jadeHammer = function(item, _, dir)
            local jade = AetherMatchRuntime and AetherMatchRuntime.Jade
            if jade then
                local result = jade:ActivateForTraversal('LongJump', dir, function()
                    return not LongJump.Enabled
                end)
                if not result.confirmed or not LongJump.Enabled then return end
                JumpSpeed = 1.4 * Value.Value
                JumpTick = tick() + 2.5
				Direction = horizontalDirection(dir)
                return
            end

            local ability = getJadeAbility(item)
            if not bedwars.AbilityController:canUseAbility(ability) then
                repeat
                    task.wait()
                    ability = getJadeAbility(item)
                until bedwars.AbilityController:canUseAbility(ability) or not LongJump.Enabled
            end
            if bedwars.AbilityController:canUseAbility(ability) and LongJump.Enabled then
                if not activateJadeTool(item) then bedwars.AbilityController:useAbility(ability) end
                local deadline = tick() + 0.75
                repeat
                    task.wait()
                until not bedwars.AbilityController:canUseAbility(ability) or tick() >= deadline or not LongJump.Enabled
                if not LongJump.Enabled or bedwars.AbilityController:canUseAbility(ability) then return end
                JumpSpeed = 1.4 * Value.Value
                JumpTick = tick() + 2.5
				Direction = horizontalDirection(dir)
            end
        end,
        tnt = function(item, pos, dir)
            pos = pos - Vector3.new(0, (entitylib.character.HipHeight + (entitylib.character.RootPart.Size.Y / 2)) - 3, 0)
            local rounded = Vector3.new(math.round(pos.X / 3) * 3, math.round(pos.Y / 3) * 3, math.round(pos.Z / 3) * 3)
            start = Vector3.new(rounded.X, start.Y, rounded.Z) + (dir * (item.itemType == 'pirate_gunpowder_barrel' and 2.6 or 0.2))
            bedwars.placeBlock(rounded, item.itemType, false)
        end,
        wood_dao = function(item, pos, dir)
            if (lplr.Character:GetAttribute('CanDashNext') or 0) > workspace:GetServerTimeNow() or not bedwars.AbilityController:canUseAbility('dash') then
                repeat task.wait() until (lplr.Character:GetAttribute('CanDashNext') or 0) < workspace:GetServerTimeNow() and bedwars.AbilityController:canUseAbility('dash') or not LongJump.Enabled
            end

            if LongJump.Enabled then
                bedwars.SwordController.lastAttack = workspace:GetServerTimeNow()
                switchItem(item.tool, 0.1)
                replicatedStorage['events-@easy-games/game-core:shared/game-core-networking@getEvents.Events'].useAbility:FireServer('dash', {
                    direction = dir,
                    origin = pos,
                    weapon = item.itemType
                })
                JumpSpeed = 4.5 * Value.Value
                JumpTick = tick() + 2.4
				Direction = horizontalDirection(dir)
            end
        end
    }
    for _, v in {'stone_dao', 'iron_dao', 'diamond_dao', 'emerald_dao'} do
        LongJumpMethods[v] = LongJumpMethods.wood_dao
    end
    for _, hammer in jadeHammerNames do
        LongJumpMethods[hammer] = LongJumpMethods.jadeHammer
    end
    LongJumpMethods.void_axe = LongJumpMethods.jadeHammer
    LongJumpMethods.siege_tnt = LongJumpMethods.tnt
    LongJumpMethods.pirate_gunpowder_barrel = LongJumpMethods.tnt

	local function heldLongJumpMethod()
		local hand = store.hand
		local tool = hand and hand.tool
		if not tool then return nil end
		local raw = hand.itemType or tool.Name
		local normalized = tostring(raw):lower():gsub('[%s%-]+', '_')
		local method = LongJumpMethods[raw] or LongJumpMethods[normalized]
		local jadeName = isJadeHammerName(normalized)
		if jadeName then method = LongJumpMethods.jadeHammer end
		if not method then return nil end
		local item = getItem(raw) or getItem(normalized)
		if jadeName and AetherMatchRuntime and AetherMatchRuntime.Jade then
			item = AetherMatchRuntime.Jade:GetBestHammer() or item
		end
		item = item or {itemType = normalized, tool = tool, amount = hand.amount or 1}
		return method, item, normalized
	end

    LongJump = vape.Categories.Blatant:CreateModule({
        Name = 'LongJump',
        Function = function(callback)
            frictionTable.LongJump = callback or nil
            updateVelocity()
            if callback then
                -- Limit to items: only engage from a long-jump item you're HOLDING. Without one
                -- the driver below would hold you frozen in place waiting for a jump that can never
                -- come (the module's idle state pins your velocity), so turn straight back off.
				if LimitItems and LimitItems.Enabled and not heldLongJumpMethod() then
                    frictionTable.LongJump = nil
                    updateVelocity()
                    notif('LongJump', 'Hold a long-jump item to use it (Limit to items is on).', 4)
                    return task.spawn(function() if LongJump.Enabled then LongJump:Toggle() end end)
                end
                LongJump:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
                    -- Limit to items: the knockback (Heatseeker) boost isn't item-driven, so skip it.
                    if LimitItems and LimitItems.Enabled then return end
                    if damageTable.entityInstance == lplr.Character and damageTable.fromEntity == lplr.Character and (not damageTable.knockbackMultiplier or not damageTable.knockbackMultiplier.disabled) then
                        local knockbackBoost = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
                            vertical = 0,
                            horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 1)
                        }).Magnitude * 1.1

                        if knockbackBoost >= JumpSpeed then
                            local pos = damageTable.fromPosition and Vector3.new(damageTable.fromPosition.X, damageTable.fromPosition.Y, damageTable.fromPosition.Z) or damageTable.fromEntity and damageTable.fromEntity.PrimaryPart.Position
                            if not pos then return end
                            local vec = (entitylib.character.RootPart.Position - pos)
                            JumpSpeed = knockbackBoost
                            JumpTick = tick() + 2.5
                            Direction = Vector3.new(vec.X, 0, vec.Z).Unit
                        end
                    end
                end))
                LongJump:Clean(vapeEvents.GrapplingHookFunctions.Event:Connect(function(dataTable)
                    if dataTable.hookFunction == 'PLAYER_IN_TRANSIT' then
                        local vec = entitylib.character.RootPart.CFrame.LookVector
                        JumpSpeed = 2.5 * Value.Value
                        JumpTick = tick() + 2.5
                        Direction = Vector3.new(vec.X, 0, vec.Z).Unit
                    end
                end))

                start = entitylib.isAlive and entitylib.character.RootPart.Position or nil
                LongJump:Clean(runService.PreSimulation:Connect(function(dt)
                    local root = entitylib.isAlive and entitylib.character.RootPart or nil

                    if root and isnetworkowner(root) then
                        if JumpTick > tick() then
                            if not jumpWasActive then
                                jumpWasActive = true
                                longJumpActivation:Fire(root.AssemblyLinearVelocity)
                            end
                            -- Change direction mid-air: while the boost is running, steer it with
                            -- your movement keys (or where the camera looks) instead of riding the
                            -- fixed line it launched on. MoveDirection is already camera-relative, so
                            -- W/A/S/D bends the boost; with no keys down it holds its current heading.
                            if ChangeDir and ChangeDir.Enabled and Direction then
                                local steer = entitylib.character.Humanoid.MoveDirection
                                steer = Vector3.new(steer.X, 0, steer.Z)
                                if steer.Magnitude < 0.1 and CameraDir and CameraDir.Enabled then
                                    local look = gameCamera.CFrame.LookVector
                                    steer = Vector3.new(look.X, 0, look.Z)
                                end
                                if steer.Magnitude > 0.1 then
                                    Direction = steer.Unit
                                end
                            end
                            root.AssemblyLinearVelocity = Direction * (getSpeed() + ((JumpTick - tick()) > 1.1 and JumpSpeed or 0)) + Vector3.new(0, root.AssemblyLinearVelocity.Y, 0)
                            if entitylib.character.Humanoid.FloorMaterial == Enum.Material.Air and not start then
                                root.AssemblyLinearVelocity += Vector3.new(0, dt * (workspace.Gravity - 23), 0)
                            else
                                root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 15, root.AssemblyLinearVelocity.Z)
                            end
                            start = nil
                        else
                            jumpWasActive = false
                            if start then
                                root.CFrame = CFrame.lookAlong(start, root.CFrame.LookVector)
                            end
                            root.AssemblyLinearVelocity = Vector3.zero
                            JumpSpeed = 0
                        end
                    else
                        start = nil
                    end
                end))

				local heldMethod, heldItem = heldLongJumpMethod()
				if heldMethod then
					task.spawn(heldMethod, heldItem, start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
                    return
                end

                -- Limit to items: a held item was already required above, so never fall through to
                -- the inventory/kit scan (which is what would otherwise fire a kit-based jump).
                if LimitItems and LimitItems.Enabled then return end

                for i, v in LongJumpMethods do
                    local item = getItem(i)
                    if item or store.equippedKit == i then
                        task.spawn(v, item, start, (CameraDir.Enabled and gameCamera or entitylib.character.RootPart).CFrame.LookVector)
                        break
                    end
                end
            else
                JumpTick = tick()
                jumpWasActive = false
                Direction = nil
                JumpSpeed = 0
            end
        end,
        ExtraText = function()
            return 'Heatseeker'
        end,
        Tooltip = 'Lets you jump farther'
    })
    Value = LongJump:CreateSlider({
        Name = 'Speed',
        Min = 1,
        Max = 37,
        Default = 37,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    CameraDir = LongJump:CreateToggle({
        Name = 'Camera Direction'
    })
    LimitItems = LongJump:CreateToggle({
        Name = 'Limit to items',
        Tooltip = 'Only long-jumps from a held item. Without one LongJump turns itself back off instead of freezing you'
    })
    ChangeDir = LongJump:CreateToggle({
        Name = 'Change direction mid-air',
        Tooltip = 'Steer the boost with your movement keys instead of flying in a straight line'
    })

    local api = {
        Module = LongJump,
        Methods = LongJumpMethods,
        GetHeldMethod = heldLongJumpMethod,
        GetJumpTick = function() return JumpTick end
    }
    shared.AetherLongJumpRuntime = api
    vape:Clean(function() if shared.AetherLongJumpRuntime == api then shared.AetherLongJumpRuntime = nil end end)
end)

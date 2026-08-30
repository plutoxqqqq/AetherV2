run(function()
    local Breaker
    local Mode
    local Range
    local Angle
    local AutoTool
    local BreakSpeed
    local UpdateRate
    local Custom
    local Bed
    local Tesla
    local Hive
    local LuckyBlock
    local IronOre
    local Effect
    local CustomHealth = {}
    local Animation
    local SelfBreak
    local InstantBreak
    local LimitItem
    local Closest
    local BreakerType
    local losFilter
    local customlist, parts = {}, {}

    -- Minimal self-contained maid. Recent BedWars updates stopped exposing
    -- `healthbarMaid`/`healthbarProgressRef` on BlockBreaker, so the old code threw on the
    -- very first `self.healthbarMaid:DoCleaning()` and, because the healthbar and the swing
    -- animation share one DamageBlock callback, that single error silently killed BOTH. We
    -- now own the maid/ref instead of depending on the game providing them.
    local function makeMaid()
        local tasks = {}
        return {
            GiveTask = function(_, item)
                table.insert(tasks, item)
                return item
            end,
            DoCleaning = function()
                for _, item in tasks do
                    if typeof(item) == 'function' then
                        pcall(item)
                    elseif typeof(item) == 'RBXScriptConnection' then
                        item:Disconnect()
                    elseif typeof(item) == 'Instance' then
                        item:Destroy()
                    elseif type(item) == 'table' and item.DoCleaning then
                        item:DoCleaning()
                    end
                end
                table.clear(tasks)
            end
        }
    end

    local function customHealthbar(self, blockRef, health, maxHealth, changeHealth, block)
        --if block:GetAttribute('NoHealthbar') then return end
        self.healthbarMaid = self.healthbarMaid or makeMaid()
        self.healthbarProgressRef = self.healthbarProgressRef or bedwars.Roact.createRef()
        if not self.healthbarPart or not self.healthbarBlockRef or self.healthbarBlockRef.blockPosition ~= blockRef.blockPosition then
            self.healthbarMaid:DoCleaning()
            self.healthbarBlockRef = blockRef
            local create = bedwars.Roact.createElement
            local percent = math.clamp(health / maxHealth, 0, 1)
            local cleanCheck = true
            local part = Instance.new('Part')
            part.Size = Vector3.one
            part.CFrame = CFrame.new(bedwars.BlockController:getWorldPosition(blockRef.blockPosition))
            part.Transparency = 1
            part.Anchored = true
            part.CanCollide = false
            part.Parent = workspace
            self.healthbarPart = part
            bedwars.QueryUtil:setQueryIgnored(self.healthbarPart, true)

            local mounted = bedwars.Roact.mount(create('BillboardGui', {
                Size = UDim2.fromOffset(249, 102),
                StudsOffset = Vector3.new(0, 2.5, 0),
                Adornee = part,
                MaxDistance = 40,
                AlwaysOnTop = true
            }, {
                create('Frame', {
                    Size = UDim2.fromOffset(160, 50),
                    Position = UDim2.fromOffset(44, 32),
                    BackgroundColor3 = Color3.new(),
                    BackgroundTransparency = 0.5
                }, {
                    create('UICorner', {CornerRadius = UDim.new(0, 5)}),
                    create('ImageLabel', {
                        Size = UDim2.new(1, 89, 1, 52),
                        Position = UDim2.fromOffset(-48, -31),
                        BackgroundTransparency = 1,
                        Image = getcustomasset('aetherv2/assets/new/blur.png'),
                        ScaleType = Enum.ScaleType.Slice,
                        SliceCenter = Rect.new(52, 31, 261, 502)
                    }),
                    create('TextLabel', {
                        Size = UDim2.fromOffset(145, 14),
                        Position = UDim2.fromOffset(13, 12),
                        BackgroundTransparency = 1,
                        Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Top,
                        TextColor3 = Color3.new(),
                        TextScaled = true,
                        Font = Enum.Font.Arial
                    }),
                    create('TextLabel', {
                        Size = UDim2.fromOffset(145, 14),
                        Position = UDim2.fromOffset(12, 11),
                        BackgroundTransparency = 1,
                        Text = bedwars.ItemMeta[block.Name].displayName or block.Name,
                        TextXAlignment = Enum.TextXAlignment.Left,
                        TextYAlignment = Enum.TextYAlignment.Top,
                        TextColor3 = color.Dark(uipallet.Text, 0.16),
                        TextScaled = true,
                        Font = Enum.Font.Arial
                    }),
                    create('Frame', {
                        Size = UDim2.fromOffset(138, 4),
                        Position = UDim2.fromOffset(12, 32),
                        BackgroundColor3 = uipallet.Main
                    }, {
                        create('UICorner', {CornerRadius = UDim.new(1, 0)}),
                        create('Frame', {
                            [bedwars.Roact.Ref] = self.healthbarProgressRef,
                            Size = UDim2.fromScale(percent, 1),
                            BackgroundColor3 = Color3.fromHSV(math.clamp(percent / 2.5, 0, 1), 0.89, 0.75)
                        }, {create('UICorner', {CornerRadius = UDim.new(1, 0)})})
                    })
                })
            }), part)

            self.healthbarMaid:GiveTask(function()
                cleanCheck = false
                self.healthbarBlockRef = nil
                bedwars.Roact.unmount(mounted)
                if self.healthbarPart then
                    self.healthbarPart:Destroy()
                end
                self.healthbarPart = nil
            end)

            bedwars.RuntimeLib.Promise.delay(5):andThen(function()
                if cleanCheck then
                    self.healthbarMaid:DoCleaning()
                end
            end)
        end

        local newpercent = math.clamp((health - changeHealth) / maxHealth, 0, 1)
        tweenService:Create(self.healthbarProgressRef:getValue(), TweenInfo.new(0.3), {
            Size = UDim2.fromScale(newpercent, 1), BackgroundColor3 = Color3.fromHSV(math.clamp(newpercent / 2.5, 0, 1), 0.89, 0.75)
        }):Play()
    end

    local hit = 0

    local function getMousePosition()
	local suc, mouseinfo = pcall(function()
            return bedwars.BlockBreaker.clientManager:getBlockSelector():getMouseInfo(0)
        end)

        if suc and mouseinfo then
            if mouseinfo.target and mouseinfo.target.blockRef then
                return mouseinfo.target.blockRef.blockPosition * 3
            end
            if mouseinfo.placementPosition then
                return mouseinfo.placementPosition * 3
            end
        end
        return nil
    end

    local cache, cacheExpire = nil, 0
    local function closestMethod(block)
        if tick() > cacheExpire or not cache then
            cache = getMousePosition() or entitylib.character.RootPart.Position
            cacheExpire = tick() + 0.01
        end
        return (cache - block.Position).Magnitude
    end

    -- Line-of-sight support for "Legit" breaker type: only break blocks whose surrounding
    -- air is actually visible from the camera, never blindly through walls.
    losFilter = RaycastParams.new()
    losFilter.FilterType = Enum.RaycastFilterType.Exclude
    losFilter.RespectCanCollide = false
    losFilter.IgnoreWater = true

    local function refreshFilter()
        losFilter.FilterDescendantsInstances = {lplr.Character, gameCamera}
    end

    local VISIBILITY_PROBES = {
        Vector3.zero,
        Vector3.new(1.35, 0, 0), Vector3.new(-1.35, 0, 0),
        Vector3.new(0, 1.35, 0), Vector3.new(0, -1.35, 0),
        Vector3.new(0, 0, 1.35), Vector3.new(0, 0, -1.35)
    }

    local function isVisible(worldPos)
        local eye = gameCamera.CFrame.Position
        for _, offset in VISIBILITY_PROBES do
            local probe = worldPos + offset
            local ray = probe - eye
            local hit = workspace:Raycast(eye, ray, losFilter)
            if not hit or (hit.Position - eye).Magnitude >= ray.Magnitude - 1.5 then
                return true
            end
        end
        return false
    end

    -- Auto tool: put the right tool in your hand as soon as a target is in break range, rather than
    -- as a side effect of the first hit. getBreakTool resolves the best tool the inventory holds for
    -- that break type - the axe for a bed frame, shears for wool - so this is "best compatible tool",
    -- not just "a tool".
    local function autoTool(block, enabled)
        if enabled == nil then enabled = AutoTool.Enabled end
        if not enabled or not block then return end
        local meta = bedwars.ItemMeta[block.Name]
        local breaktype = block.Name == 'gumdrop_bounce_pad' and 'stone' or (meta and meta.block and meta.block.breakType)
        if not breaktype then return end
        local tool = getBreakTool(breaktype) or store.tools.stone
        if not tool or not tool.tool then return end
        if store.hand and store.hand.tool == tool.tool then return end
        -- Same courtesy breakBlock shows: never rip a weapon out of your hand mid-swing or mid-shot.
        local now = workspace:GetServerTimeNow()
        local held = store.hand and store.hand.tool
        if held and store.tools.sword and held == store.tools.sword.tool and (now - bedwars.SwordController.lastAttack) <= 0.4 then return end
        if held and store.hand.toolType == 'bow' and (now - (store.lastProjectileFire or 0)) <= 0.35 then return end
        local hotbar = getHotbar(tool.tool)
        if hotbar then
            hotbarSwitch(hotbar)
        else
            switchItem(tool.tool)
        end
    end

    local function blockHealth(block)
        local health = block:GetAttribute('Health')
        if health then return health end
        local meta = bedwars.ItemMeta[block.Name]
        return meta and meta.block and meta.block.health or 0
    end

    -- Closest break marks ONE block and stays on it until it is gone. Re-picking every tick is what
    -- made it hop between blocks and leave a trail of half-mined ones behind.
    local locked = nil

    local function lockValid(localPosition)
        if not locked or not locked.Parent then return false end
        if (locked.Position - localPosition).Magnitude >= Range.Value then return false end
        if not bedwars.BlockController:isBlockBreakable({blockPosition = locked.Position / 3}, lplr) then return false end
        if (locked:GetAttribute('BedShieldEndTime') or 0) > workspace:GetServerTimeNow() then return false end
        return true
    end

    local function drawPath(target, path, endpos)
        if not path then return end
        local currentnode = target
        for _, part in parts do
            part.Position = currentnode or Vector3.zero
            if currentnode then
                part.BoxHandleAdornment.Color3 = currentnode == endpos and Color3.new(1, 0.2, 0.2) or currentnode == target and Color3.new(0.2, 0.2, 1) or Color3.new(0.2, 1, 0.2)
            end
            currentnode = path[currentnode]
        end
    end

    local function breakOne(v, localPosition)
        hit += 1
        autoTool(v)
        local target, path, endpos = bedwars.breakBlock(
            v,
            Effect.Enabled,
            Animation.Enabled,
            CustomHealth.Enabled and customHealthbar or nil,
            AutoTool.Enabled,
            Closest.Enabled and closestMethod or breakmethods[Mode.Value],
            Angle.Value,
            BreakerType.Value == 'Legit' and isVisible or nil,
            -- Legit: line of sight, then closest to you, still preferring the efficient way in.
            -- Blatant: quickest and nothing else.
            -- Health mode: fewest blocks to break always wins, whatever they cost.
            {
                Legit = BreakerType.Value == 'Legit',
                FewestBlocks = Mode.Value == 'Health'
            }
        )
        return target, path, endpos
    end

    local function attemptBreak(tab, localPosition)
        if not tab then return end

        -- Health mode targets the block with the MOST health first. Ties keep the list's own order,
        -- which is what Legit/Blatant already decided (Legit only offers blocks it can see, Blatant
        -- takes the quickest), so the mode still has the final say between equals.
        local order = tab
        if Mode.Value == 'Health' then
            order = {}
            for _, v in tab do
                table.insert(order, v)
            end
            local health = {}
            for _, v in order do
                health[v] = blockHealth(v)
            end
            table.sort(order, function(a, b)
                return health[a] > health[b]
            end)
        end

        -- Locked onto a block: finish it, do not go looking for another one.
        if Closest.Enabled and locked then
            if lockValid(localPosition) and table.find(tab, locked) then
                local target, path, endpos = breakOne(locked, localPosition)
                if target then
                    drawPath(target, path, endpos)
                    task.wait(InstantBreak.Enabled and (store.damageBlockFail > tick() and 4.5 or 0) or BreakSpeed.Value)
                    return true
                end
            else
                locked = nil
            end
        end

        for _, v in order do
            if (v.Position - localPosition).Magnitude < Range.Value and bedwars.BlockController:isBlockBreakable({blockPosition = v.Position / 3}, lplr) then
                if not SelfBreak.Enabled and v:GetAttribute('PlacedByUserId') == lplr.UserId then continue end
                if (v:GetAttribute('BedShieldEndTime') or 0) > workspace:GetServerTimeNow() then continue end
                if LimitItem.Enabled and not (store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name].breakBlock) then continue end

                local target, path, endpos = breakOne(v, localPosition)
                if not target then continue end
                if Closest.Enabled then
                    locked = v
                end
                drawPath(target, path, endpos)

                task.wait(InstantBreak.Enabled and (store.damageBlockFail > tick() and 4.5 or 0) or BreakSpeed.Value)

                return true
            end
        end

        return false
    end

    Breaker = vape.Categories.Minigames:CreateModule({
        Name = 'Breaker',
        Function = function(callback)
            if callback then
                for _ = 1, 30 do
                    local part = Instance.new('Part')
                    part.Anchored = true
                    part.CanQuery = false
                    part.CanCollide = false
                    part.Transparency = 1
                    part.Parent = gameCamera
                    local highlight = Instance.new('BoxHandleAdornment')
                    highlight.Size = Vector3.one
                    highlight.AlwaysOnTop = true
                    highlight.ZIndex = 1
                    highlight.Transparency = 0.5
                    highlight.Adornee = part
                    highlight.Parent = part
                    table.insert(parts, part)
                end

                local beds = collection('bed', Breaker)
                local luckyblock = collection('LuckyBlock', Breaker)
                local ironores = collection('iron_ore_mesh_block', Breaker)
                local teslas = collection('tesla-trap', Breaker, function(tab, obj)
				task.delay(0.1, function()
					local player = playersService:GetPlayerByUserId(obj:GetAttribute('PlacedByUserId'))
					if player and player:GetAttribute('Team') ~= lplr:GetAttribute('Team') then
						table.insert(tab, obj)
					end
				end)
			end)
			local hives = collection('beehive', Breaker, function(tab, obj)
				task.delay(0.1, function()
					local player = playersService:GetPlayerByUserId(obj:GetAttribute('PlacedByUserId'))
					if player and player:GetAttribute('Team') ~= lplr:GetAttribute('Team') then
						table.insert(tab, obj)
					end
				end)
			end)

                customlist = collection('block', Breaker, function(tab, obj)
                    if table.find(Custom.ListEnabled, obj.Name) then
                        table.insert(tab, obj)
                    end
                end)

                repeat
                    task.wait(1 / UpdateRate.Value)
                    if not Breaker.Enabled then break end
                    if entitylib.isAlive then
                        local localPosition = entitylib.character.RootPart.Position

                        if BreakerType.Value == 'Legit' then
                            refreshFilter()
                        end
                        if attemptBreak(Bed.Enabled and beds, localPosition) then continue end
                        if attemptBreak(Tesla.Enabled and teslas, localPosition) then continue end
                        if attemptBreak(Hive.Enabled and hives, localPosition) then continue end
                        if attemptBreak(customlist, localPosition) then continue end
                        if attemptBreak(LuckyBlock.Enabled and luckyblock, localPosition) then continue end
                        if attemptBreak(IronOre.Enabled and ironores, localPosition) then continue end

                        for _, v in parts do
                            v.Position = Vector3.zero
                        end
                    end
                until not Breaker.Enabled
            else
                locked = nil
                for _, v in parts do
                    v:ClearAllChildren()
                    v:Destroy()
                end
                table.clear(parts)
            end
        end,
        Tooltip = 'Break blocks around you automatically',
        ExtraText = function()
            return BreakerType.Value
        end
    })
    local methods = {}
    for i in breakmethods do
        table.insert(methods, i)
    end
    Mode = Breaker:CreateDropdown({
        Name = 'Break mode',
        List = methods,
        Default = methods[1],
        Tooltip = 'Health - most health first, by the shortest way in\nDistance - nearest block first',
        Function = function()
            locked = nil
        end
    })
    Range = Breaker:CreateSlider({
        Name = 'Break range',
        Min = 1,
        Max = 30,
        Default = 30,
        Suffix = function(val)
            return val == 1 and 'stud' or 'studs'
        end
    })
    BreakSpeed = Breaker:CreateSlider({
        Name = 'Break speed',
        Min = 0,
        Max = 0.3,
        Default = 0.25,
        Decimal = 100,
        Suffix = 'seconds'
    })
    Angle = Breaker:CreateSlider({
        Name = 'Max angle',
        Min = 1,
        Max = 360,
        Default = 120
    })
    UpdateRate = Breaker:CreateSlider({
        Name = 'Update rate',
        Min = 1,
        Max = 120,
        Default = 60,
        Suffix = 'hz'
    })
    Custom = Breaker:CreateTextList({
        Name = 'Custom',
        Function = function()
            if not customlist then return end
            table.clear(customlist)
            for _, obj in store.blocks do
                if table.find(Custom.ListEnabled, obj.Name) then
                    table.insert(customlist, obj)
                end
            end
        end
    })
    Bed = Breaker:CreateToggle({
        Name = 'Break Bed',
        Default = true
    })
    Tesla = Breaker:CreateToggle({
	Name = 'Break Tesla',
	Default = true,
    })
    Hive = Breaker:CreateToggle({
	Name = 'Break Hive',
	Default = true,
    })
    LuckyBlock = Breaker:CreateToggle({
        Name = 'Break Lucky Block',
        Default = true
    })
    IronOre = Breaker:CreateToggle({
        Name = 'Break Iron Ore',
        Default = true
    })
    Effect = Breaker:CreateToggle({
        Name = 'Show Healthbar & Effects',
        Function = function(callback)
            if CustomHealth.Object then
                CustomHealth.Object.Visible = callback
            end
        end,
        Default = true
    })
    CustomHealth = Breaker:CreateToggle({
        Name = 'Custom Healthbar',
        Default = true,
        Darker = true
    })
    Animation = Breaker:CreateToggle({Name = 'Animation'})
    SelfBreak = Breaker:CreateToggle({Name = 'Self Break'})
    InstantBreak = Breaker:CreateToggle({Name = 'Instant Break'})
    AutoTool = Breaker:CreateToggle({
        Name = 'Auto Tool',
        Tooltip = 'Switches to the best tool for the block as soon as it is in break range - the axe for a bed, shears for wool'
    })
    BreakerType = Breaker:CreateDropdown({
        Name = 'Breaker Type',
        List = {'Blatant', 'Legit'},
        Default = 'Blatant',
        Tooltip = 'Blatant - the quickest way in, visible or not\nLegit - only what you can actually see'
    })
    Closest = Breaker:CreateToggle({
        Name = 'Closest break',
        Tooltip = 'Stays on one block until it breaks instead of leaving several half mined',
        Function = function(callback)
            Mode.Object.Visible = not callback
            locked = nil
        end
    })
    LimitItem = Breaker:CreateToggle({
        Name = 'Limit to items',
        Tooltip = 'Only breaks when tools are held'
    })

end)
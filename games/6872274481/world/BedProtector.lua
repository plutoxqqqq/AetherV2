run(function()
    local BedProtector
    local PlaceRange
    local Layers
    local Blacklist
    local Mode
    local Smart
    local Switch
    local WoolOnly
    local LimitItem
    local Template
    local EmergencyKey
    local previewParts = {}
    local templateSpecs = {
        ['Quick Wool'] = {Layers = 1, Wool = true},
        Layered = {Layers = 2, Wool = false},
        Defensive = {Layers = 3, Wool = false},
        ['Anti-Explosive'] = {Layers = 2, Wool = false}
    }

    local function clearPreview()
        for _, part in previewParts do part:Destroy() end
        table.clear(previewParts)
    end

    local function getBedNear()
        local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
        for _, v in collectionService:GetTagged('bed') do
            if (localPosition - v.Position).Magnitude < 14
                and v:GetAttribute('Team' .. (lplr:GetAttribute('Team') or -1) .. 'NoBreak') then
                return v
            end
        end
        return nil
    end

    local function getBlocks()
        local blocks = {}
        for _, item in store.inventory.inventory.items do
            local block = bedwars.ItemMeta[item.itemType].block
            if block and (not Template or Template.Value ~= 'Quick Wool' or item.itemType:find('wool'))
                and not table.find(Blacklist.ListEnabled, item.itemType:find('wool') and 'wool' or item.itemType) then
                table.insert(blocks, { item.itemType, block.health, item.tool })
            end
        end
        table.sort(blocks, function(a, b)
            return a[2] > b[2]
        end)
        return blocks
    end

    -- A BedWars bed is two grid cells long, and its pivot sits on the grid line
    -- between them. roundPos() therefore snapped the whole defence onto a single
    -- (rounded) cell, so the shell was built around half the bed and came out as an
    -- off-centre rectangle that left the other half exposed. Resolve BOTH occupied
    -- cells from the bed's orientation so the onion layers wrap the real footprint.
    local function bedCells(bed)
        local cf, size
        if bed:IsA('BasePart') then
            cf, size = bed.CFrame, bed.Size
        else
            cf = bed:GetPivot()
            local ok, ext = pcall(function() return bed:GetExtentsSize() end)
            size = ok and ext or Vector3.new(3, 3, 6)
        end
        local center = cf.Position
        -- The long horizontal axis is local X (RightVector) or local Z (LookVector),
        -- whichever the bed is 2 blocks along.
        local axis = (size.X >= size.Z) and cf.RightVector or cf.LookVector
        axis = Vector3.new(axis.X, 0, axis.Z)
        axis = axis.Magnitude > 0 and axis.Unit or Vector3.new(1, 0, 0)
        local a = roundPos(center + axis * 1.5)
        local b = roundPos(center - axis * 1.5)
        if a == b then b = roundPos(center - axis * 3) end
        return a, b
    end

    --[[
        Onion‑layer bed protection.

        protected = a set of positions (Vector3) that are already part of the defense.
        Initially contains only the bed position.
        For each layer:
            - Examine every position in the current protected set.
            - For each position, look at all adjacent horizontal positions (N, S, E, W)
              and the position directly above.
            - If an adjacent position is NOT already protected and does NOT contain
              a block placed by another player (or is air), it becomes part of the new layer.
            - After collecting all new positions for this layer, place them all.
            - Then merge them into the protected set.
        This guarantees that each layer is a complete shell surrounding the previous one,
        expands outward by 1 block in every horizontal direction, and increases height
        by exactly 1 block per layer.
    ]]

    --[[
        Bed patcher (replaced with the reference build's routine)

        The onion algorithm above builds a shell. Patching is a different job: the shell is
        already there and has holes in it, and running the builder to fill them re-walks the
        whole structure from the bed outwards every pass.

        Instead, walk the defence the way it was built - one horizontal ring per level, out
        from the bed - and place into any cell of that ring that is empty. Rings are generated
        in the bed's own orientation so the patch lines up with a defence that is not axis
        aligned, and a level whose centre column is missing is skipped entirely: there is no
        ring at a height the defence never reached.
    ]]
    local PATCH_LEVELS = 6

    -- A diamond ring of grid offsets at `radius` cells out and `radius - i` cells up. Taken
    -- from the reference build unchanged, because the order it yields cells in is what makes
    -- the patch fill inwards-out rather than jumping about.
    local function ringOffsets(radius, spacing)
        local offsets = {}
        for i = radius, 0, -1 do
            for j = i, 0, -1 do
                table.insert(offsets, Vector3.new(j, radius - i, i + 1 - j) * spacing)
                table.insert(offsets, Vector3.new(-j, radius - i, i + 1 - j) * spacing)
                table.insert(offsets, Vector3.new(j, radius - i, -(i - j)) * spacing)
                table.insert(offsets, Vector3.new(-j, radius - i, -(i - j)) * spacing)
            end
        end
        return offsets
    end

    -- The single block to patch with: the toughest one that passes the options. 'Limit to
    -- item' means exactly what is in your hand, and nothing at all if that is not a block.
    local function getPatchBlock()
        if LimitItem.Enabled then
            local hand = store.hand
            if not hand or hand.toolType ~= 'block' or not hand.tool then return nil end
            local itemType = hand.tool.Name
            if WoolOnly.Enabled and not itemType:find('wool') then return nil end
            if table.find(Blacklist.ListEnabled, itemType:find('wool') and 'wool' or itemType) then return nil end
            return {itemType, 0, hand.tool}
        end

        local best
        for _, item in store.inventory.inventory.items do
            local meta = bedwars.ItemMeta[item.itemType]
            local block = meta and meta.block
            if not block then continue end
            if WoolOnly.Enabled and not item.itemType:find('wool') then continue end
            if table.find(Blacklist.ListEnabled, item.itemType:find('wool') and 'wool' or item.itemType) then continue end
            if not best or (block.health or 0) > best[2] then
                best = {item.itemType, block.health or 0, item.tool}
            end
        end
        return best
    end

    local function patchBed(bed)
        local bedCFrame = bed:IsA('BasePart') and bed.CFrame or bed:GetPivot()
        -- The two cells the bed itself sits in. A ring passes over them, and asking the server
        -- to build into your own bed is never going to succeed.
        local cellA, cellB = bedCells(bed)

        -- Ring 1 is the shell touching the bed, which is part of any defence, so it is always
        -- worth scanning. Past that, a ring is only walked when the one inside it exists -
        -- otherwise the patcher would march outwards building a defence you never had, which
        -- is the shell builder's job, not this one's.
        --
        -- The reference build gated each ring on there being a block in the column directly
        -- above the bed. That is the first block an opponent breaks, so the moment somebody
        -- actually broke into the defence the patcher stopped repairing it.
        local previousFilled = true
        for level = 1, PATCH_LEVELS do
            if not BedProtector.Enabled or not previousFilled then return end

            local filled = false
            for _, offset in ringOffsets(level, 3) do
                if not BedProtector.Enabled then return end

                local position = (bedCFrame * CFrame.new(offset)).Position
                local cell = roundPos(position)
                if cell == cellA or cell == cellB then continue end
                if getPlacedBlock(position) then
                    filled = true
                    continue
                end

                if not entitylib.isAlive then return end
                if (entitylib.character.RootPart.Position - position).Magnitude > PlaceRange.Value then continue end

                local block = getPatchBlock()
                if not block then return end

                if Switch.Enabled then
                    local slot = getHotbar(block[3])
                    if slot and hotbarSwitch(slot) then task.wait() end
                end
                task.spawn(bedwars.placeBlock, position, block[1], false)
                filled = true
                task.wait(0.1)
            end
            previousFilled = filled
        end
    end

    BedProtector = vape.Categories.World:CreateModule({
        Name = 'BedProtector',
        Function = function(callback)
            if callback then
                local spec = templateSpecs[Template.Value]
                local estimated = spec and ((spec.Layers * spec.Layers * 16) + 6) or 0
                notif('BedProtector', Template.Value..' needs about '..estimated..' blocks', 5, 'info')
                BedProtector:Clean(inputService.InputBegan:Connect(function(input, processed)
                    if not processed and input.KeyCode.Name == EmergencyKey.Value and BedProtector.Enabled then
                        clearPreview()
                        BedProtector:Toggle()
                        notif('BedProtector', 'Emergency stop', 3, 'warning')
                    end
                end))
                repeat
                    local bed = getBedNear()
                    if bed and Mode.Value == 'Bed patcher' then
                        patchBed(bed)
                    elseif bed then
                        -- Seed the protected set with BOTH grid cells the bed occupies so
                        -- the shell wraps the whole two-block bed instead of half of it.
                        local cellA, cellB = bedCells(bed)
                        local protected = { [cellA] = true, [cellB] = true }

                        for i, block in getBlocks() do
                            local switch, old = Switch.Enabled, store.hand and store.hand.tool and getHotbar(store.hand.tool) or nil
                            local hotbar = switch and getHotbar(block[3]) or nil

                            for layer = 1, Layers.Value do
                                local newPositions = {}

                                -- For every block already in the protected structure...
                                for pos in pairs(protected) do
                                    -- Check all four horizontal directions.
                                    for dx = -3, 3, 3 do
                                        for dz = -3, 3, 3 do
                                            if dx ~= 0 or dz ~= 0 then
                                                local newPos = pos + Vector3.new(dx, 0, dz)
                                                if not protected[newPos] then
                                                    newPositions[newPos] = true
                                                end
                                            end
                                        end
                                    end
                                    -- Also check directly above.
                                    local upPos = pos + Vector3.new(0, 3, 0)
                                    if not protected[upPos] then
                                        newPositions[upPos] = true
                                    end
                                end

                                -- Order this layer's candidates nearest-first. Placing the
                                -- closest reachable blocks immediately removes the long stall
                                -- before the first block went down when the dictionary happened
                                -- to yield far/out-of-range positions first.
                                local ordered = {}
                                for newPos in pairs(newPositions) do
                                    table.insert(ordered, newPos)
                                end
                                local rootPos = entitylib.character.RootPart.Position
                                table.sort(ordered, function(a, b)
                                    return (rootPos - a).Magnitude < (rootPos - b).Magnitude
                                end)

                                -- Place all blocks in this new layer.
                                local placedAny = false
                                for _, newPos in ordered do
                                    if not BedProtector.Enabled then break end
                                    if getPlacedBlock(newPos) then
                                        protected[newPos] = true   -- mark as already protected (block exists)
                                        continue
                                    end
                                    if (entitylib.character.RootPart.Position - newPos).Magnitude > PlaceRange.Value then
                                        continue
                                    end
                                    if hotbar and hotbarSwitch(hotbar) then task.wait() end
                                    task.spawn(bedwars.placeBlock, newPos, block[1], false)
                                    placedAny = true
                                    protected[newPos] = true
                                    task.wait(0.05)
                                end

                                -- Nothing placed this layer means the bed is out of reach, so
                                -- there is no point walking the outer ones.
                                if not placedAny then break end
                                if not BedProtector.Enabled then break end
                            end

                            if switch and old and hotbarSwitch(old) then task.wait() end
                        end
                    else
                        if Mode.Value == 'On Key' then
                            notif('BedProtector', 'Unable to locate bed', 5)
                            BedProtector:Toggle()
                        end
                    end
                    -- Bed patcher re-scans faster so broken blocks are repaired promptly.
                    task.wait(Mode.Value == 'Bed patcher' and 0.2 or 0.5)
                    if Mode.Value == 'On Key' then
                        BedProtector:Toggle()
                        break
                    end
                until not BedProtector.Enabled
            end
            if not callback then clearPreview() end
        end,
        Tooltip = 'Automatically places strong blocks around the bed'
    })

    -- Options. Smart belongs to the shell builder and Wool only / Limit to item belong to the
    -- patcher, so each set follows the Mode dropdown.
    local function syncModeOptions()
        -- The dropdown fires its callback while it is still being created, before Mode itself
        -- has been assigned.
        if not Mode then return end
        if Smart and Smart.Object then Smart.Object.Visible = Mode.Value == 'Toggle' end
        local patching = Mode.Value == 'Bed patcher'
        if WoolOnly and WoolOnly.Object then WoolOnly.Object.Visible = patching end
        if LimitItem and LimitItem.Object then LimitItem.Object.Visible = patching end
    end

    Mode = BedProtector:CreateDropdown({
        Name = 'Mode',
        List = {'Toggle', 'On Key', 'Bed patcher'},
        Default = 'Toggle',
        Tooltip = 'Toggle builds and maintains the shell, On Key builds once, Bed patcher fills in what is missing',
        Function = function()
            syncModeOptions()
        end,
    })
    Template = BedProtector:CreateDropdown({
        Name = 'Template',
        List = {'Quick Wool', 'Layered', 'Defensive', 'Anti-Explosive'},
        Function = function(value)
            local spec = templateSpecs[value]
            if not spec or not Layers then return end
            Layers:SetValue(spec.Layers)
            if WoolOnly then WoolOnly:SetValue(spec.Wool) end
            clearPreview()
            local bed = getBedNear()
            if bed then
                local a, b = bedCells(bed)
                for _, centre in {a, b} do
                    for x = -spec.Layers, spec.Layers do
                        for z = -spec.Layers, spec.Layers do
                            if math.max(math.abs(x), math.abs(z)) ~= spec.Layers then continue end
                            local pos = centre + Vector3.new(x * 3, 0, z * 3)
                            if getPlacedBlock(pos) then continue end
                            local ghost = Instance.new('Part')
                            ghost.Name, ghost.Size, ghost.Position = 'BedProtectorPreview', Vector3.new(3, 3, 3), pos
                            ghost.Anchored, ghost.CanCollide, ghost.CanQuery = true, false, false
                            ghost.Material, ghost.Color, ghost.Transparency = Enum.Material.ForceField, Color3.fromRGB(90, 210, 140), 0.65
                            ghost.Parent = workspace
                            table.insert(previewParts, ghost)
                        end
                    end
                end
                task.delay(5, clearPreview)
            end
        end
    })
    EmergencyKey = BedProtector:CreateDropdown({Name = 'Emergency Stop', List = {'X', 'V', 'B', 'N', 'Delete'}, Default = 'X'})
    Blacklist = BedProtector:CreateTextList({
        Name = 'Blacklist',
        Default = {'siege_tnt', 'tnt'},
    })
    PlaceRange = BedProtector:CreateSlider({
        Name = 'Place Range',
        Min = 1, Max = 30, Default = 15,
    })
    Layers = BedProtector:CreateSlider({
        Name = 'Layers',
        Min = 1, Max = 5, Default = 1,
        Suffix = function(val) return val <= 1 and 'layer' or 'layers' end,
    })
    Switch = BedProtector:CreateToggle({Name = 'Auto Switch'})
    Smart = BedProtector:CreateToggle({Name = 'Smart', Default = true})
    WoolOnly = BedProtector:CreateToggle({
        Name = 'Wool only',
        Tooltip = 'Bed patcher only. Patches holes with wool instead of the toughest block you have'
    })
    LimitItem = BedProtector:CreateToggle({
        Name = 'Limit to item',
        Tooltip = 'Bed patcher only. Patches with the block in your hand and nothing else'
    })
    -- Mode's own callback runs while these two are still nil (it fires as the dropdown is
    -- created), so the first sync happens here instead.
    syncModeOptions()
end)
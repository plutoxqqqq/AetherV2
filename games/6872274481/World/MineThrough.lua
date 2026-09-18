run(function()
    local MineThrough
    local Place
    local Players
    local NPCs
    local Self

    -- The block selector always casts from the camera and nothing further away than the longest
    -- possible reach can sit between that ray and a block, so the scan is kept to what can matter.
    local SCAN_DISTANCE = 64
    local QUERY_IGNORE = 'gamecore_GameQueryIgnore'

    local depth = 0
    local originalGetMouseInfo
    local selectorHook
    local originalHitBlock
    local breakHook

    local function watched(entity)
        if entity.Player then
            return Players.Enabled
        end
        return NPCs.Enabled
    end

    local function collect()
        local list, saved = {}, {}
        local origin = gameCamera.CFrame.Position
        local function scan(character, root)
            if not character or not root then return end
            if (root.Position - origin).Magnitude > SCAN_DISTANCE then return end
            for _, part in character:GetDescendants() do
                if not part:IsA('BasePart') then continue end
                -- Parts that are already transparent are left alone so what gets put back is exact.
                local ignored = part:GetAttribute(QUERY_IGNORE)
                if part.CanQuery and ignored ~= true then
                    table.insert(list, part)
                    saved[part] = ignored
                end
            end
        end

        for _, entity in entitylib.List do
            if watched(entity) then
                scan(entity.Character, entity.RootPart)
            end
        end
        if Self.Enabled and entitylib.isAlive then
            scan(entitylib.character.Character, entitylib.character.RootPart)
        end
        return list, saved
    end

    -- Entities stop counting as hitboxes for as long as the callback runs: raycasts skip them, and
    -- the game's own queries skip them too, which is what lets a block behind a player be selected,
    -- mined and built against.
    local function ignoreHitboxes(callback, ...)
        if depth > 0 then return callback(...) end
        depth = 1

        local list, saved = collect()
        for _, part in list do
            part.CanQuery = false
            part:SetAttribute(QUERY_IGNORE, true)
        end

        local args = table.pack(...)
        local results = table.pack(xpcall(function()
            return callback(table.unpack(args, 1, args.n))
        end, function(err) return err end))

        for _, part in list do
            if part.Parent then
                part.CanQuery = true
                part:SetAttribute(QUERY_IGNORE, saved[part])
            end
        end
        depth = 0

        if not results[1] then error(results[2], 0) end
        return table.unpack(results, 2, results.n)
    end

    local function hookSelector()
        if selectorHook then return end
        local selector = bedwars.BlockSelector
        if type(selector) ~= 'table' or type(selector.getMouseInfo) ~= 'function' then return end

        originalGetMouseInfo = selector.getMouseInfo
        selectorHook = function(self, mode, ...)
            -- Mode 1 is the block under the crosshair, which the game mines. Mode 0 is where a block
            -- would be placed, and that only passes through entities while Place is on.
            if depth > 0 or not MineThrough.Enabled or (mode == 0 and not Place.Enabled) then
                return originalGetMouseInfo(self, mode, ...)
            end
            return ignoreHitboxes(originalGetMouseInfo, self, mode, ...)
        end
        selector.getMouseInfo = selectorHook
    end

    local function unhookSelector()
        if not selectorHook then return end
        -- Reach wraps the same function and saves whatever was there when it loaded, so only our own
        -- wrapper is taken back out instead of clobbering a hook installed after us.
        if bedwars.BlockSelector.getMouseInfo == selectorHook then
            bedwars.BlockSelector.getMouseInfo = originalGetMouseInfo
        end
        selectorHook, originalGetMouseInfo = nil, nil
    end

    local function hookBreak()
        if breakHook then return end
        local breaker = bedwars.BlockBreaker
        if type(breaker) ~= 'table' or type(breaker.hitBlock) ~= 'function' then return end

        originalHitBlock = breaker.hitBlock
        breakHook = function(self, ...)
            -- The mining action picks and damages the block under the crosshair on its own, so it
            -- gets the same see-through entities as the selector.
            if depth > 0 or not MineThrough.Enabled then
                return originalHitBlock(self, ...)
            end
            return ignoreHitboxes(originalHitBlock, self, ...)
        end
        breaker.hitBlock = breakHook
    end

    local function unhookBreak()
        if not breakHook then return end
        if bedwars.BlockBreaker.hitBlock == breakHook then
            bedwars.BlockBreaker.hitBlock = originalHitBlock
        end
        breakHook, originalHitBlock = nil, nil
    end

    MineThrough = vape.Categories.World:CreateModule({
        Name = 'MineThrough',
        Tooltip = 'Mines the block behind an entity under your crosshair instead of stopping at it',
        Function = function(enabled)
            if enabled then
                hookSelector()
                hookBreak()
                bedwars.MineThrough = Place.Enabled and ignoreHitboxes or nil
            else
                bedwars.MineThrough = nil
                unhookSelector()
                unhookBreak()
            end
        end,
        ExtraText = function()
            return Place.Enabled and 'Mine + place' or 'Mine'
        end
    })
    Place = MineThrough:CreateToggle({
        Name = 'Place',
        Default = true,
        Tooltip = 'Places through entities as well - turn it off and an entity in the way still blocks placement',
        Function = function(value)
            if MineThrough.Enabled then
                bedwars.MineThrough = value and ignoreHitboxes or nil
            end
        end
    })
    Players = MineThrough:CreateToggle({
        Name = 'Players',
        Default = true,
        Tooltip = 'Mine and place through other players'
    })
    NPCs = MineThrough:CreateToggle({
        Name = 'NPCs',
        Default = true,
        Tooltip = 'Mine and place through mobs and NPCs too'
    })
    Self = MineThrough:CreateToggle({
        Name = 'Self',
        Default = true,
        Tooltip = 'Ignore your own hitbox as well, which helps once the camera is off your head'
    })
end)

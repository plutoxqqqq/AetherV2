run(function()
    local outlines = {}
    local borrowed = {}
    local connections = {}

    local OutlineTargets
    local Colour

    -- The colour is read from the slider on every use rather than cached from its callback: the
    -- slider only runs its callback when it is moved (or loaded from a config), so a cached value
    -- stayed at the initial white and an outline turned on before touching the slider was white
    -- instead of the colour the slider was showing.
    local function currentColor(ent)
        return entitylib.getEntityColor(ent) or (Colour and Color3.fromHSV(Colour.Hue, Colour.Sat, Colour.Value)) or Color3.new(1, 1, 1)
    end

    local function shouldOutline(ent)
        if not OutlineTargets then return true end
        if ent.Player and not OutlineTargets.Players.Enabled then return false end
        if ent.NPC and not OutlineTargets.NPCs.Enabled then return false end
        return true
    end

    local function removeOutline(ent)
        local h = outlines[ent]
        if not h then return end
        outlines[ent] = nil
        if borrowed[ent] then
            -- A highlight that was already on the body (Chams' one) is handed back hidden rather
            -- than destroyed, so the module that owns it keeps working.
            borrowed[ent] = nil
            if h.Parent then h.OutlineTransparency = 1 end
            return
        end
        h:Destroy()
    end

    local function addOutline(ent)
        if not shouldOutline(ent) then removeOutline(ent) return end
        local char = ent.Character
        if not char then return end

        local existing = outlines[ent]
        -- Only one Highlight renders for a character, so a second one is not an outline - it is a
        -- silent no-op. The highlight already on the body (Chams' one) is taken over instead.
        local onBody = char:FindFirstChildOfClass('Highlight')
        if onBody and onBody ~= existing then
            if existing and not borrowed[ent] then existing:Destroy() end
            existing = onBody
            borrowed[ent] = onBody
        elseif not existing then
            existing = Instance.new('Highlight')
            existing.FillTransparency = 1
            existing.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
            existing.Adornee = char
            existing.Parent = coreGui
        end

        existing.OutlineColor = currentColor(ent)
        existing.OutlineTransparency = 0
        outlines[ent] = existing
    end

    local function refreshAll()
        for ent in outlines do
            if not shouldOutline(ent) then removeOutline(ent) end
        end
        for _, ent in entitylib.List do
            addOutline(ent)
        end
    end

    local PlayerOutline
    PlayerOutline = vape.Categories.Render:CreateModule({
        Name = 'PlayerOutline',
        Tooltip = 'adds outline to all players',
        Function = function(enabled)
            if enabled then
                for _, ent in entitylib.List do
                    addOutline(ent)
                end

                connections[1] = entitylib.Events.EntityAdded:Connect(function(ent)
                    task.wait(0.5)
                    if not PlayerOutline.Enabled then return end
                    addOutline(ent)
                end)

                connections[2] = entitylib.Events.EntityRemoved:Connect(removeOutline)

                -- Chams can be switched on after this module: when it adds its own highlight, the
                -- outline moves onto it so the two are never fighting over the one highlight a
                -- character may render.
                connections[3] = runService.Heartbeat:Connect(function()
                    for ent in outlines do
                        if not outlines[ent].Parent then removeOutline(ent) else addOutline(ent) end
                    end
                end)
            else
				for _, c in connections do pcall(c.Disconnect, c) end
				table.clear(connections)
				for _, h in outlines do pcall(h.Destroy, h) end
                table.clear(outlines)
            end
        end
    })

    OutlineTargets = PlayerOutline:CreateTargets({
        Players = true,
        NPCs = true,
        Function = function()
            if PlayerOutline.Enabled then refreshAll() end
        end
    })

    Colour = PlayerOutline:CreateColorSlider({
        Name = 'Outline Colour',
        Function = function()
            for ent, outline in outlines do
                outline.OutlineColor = currentColor(ent)
            end
        end
    })
end)

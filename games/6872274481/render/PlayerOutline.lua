run(function()
    local outlineColor = Color3.new(1, 1, 1)
    local outlines = {}
    local connections = {}

    local OutlineTargets

    local function shouldOutline(ent)
        if not OutlineTargets then return true end
        if ent.Player and not OutlineTargets.Players.Enabled then return false end
        if ent.NPC and not OutlineTargets.NPCs.Enabled then return false end
        return true
    end

    local function removeOutline(ent)
        if outlines[ent] then
            outlines[ent]:Destroy()
            outlines[ent] = nil
        end
    end

    local function addOutline(ent)
        if not shouldOutline(ent) then return end
        if outlines[ent] then return end
        local char = ent.Character
        if not char then return end
        local h = Instance.new('Highlight')
        h.OutlineColor = outlineColor
        h.FillTransparency = 1
        h.OutlineTransparency = 0
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Adornee = char
        h.Parent = coreGui
        outlines[ent] = h
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

    PlayerOutline:CreateColorSlider({
        Name = 'Outline Color',
        Function = function(h, s, v)
            outlineColor = Color3.fromHSV(h, s, v)
            for _, outline in outlines do
                outline.OutlineColor = outlineColor
            end
        end
    })
end)
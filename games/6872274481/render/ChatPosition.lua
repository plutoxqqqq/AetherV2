run(function()
    local ChatPosition
    local Vertical
    local Horizontal
    local moved

    -- The chat is one of two completely different systems and the old module only ever spoke to
    -- the wrong one. SetCore('ChatWindowPosition') drives the legacy Lua chat; BedWars runs on
    -- TextChatService, which ignores SetCore entirely - so the module did
    -- nothing. We drive both now: SetCore for the legacy chat, and for TextChatService we find the
    -- window it actually rendered and move that frame ourselves, re-asserting it because the chat
    -- rebuilds its GUI on respawn and channel changes.
    local function targetOffset()
        return Vector2.new(Horizontal and Horizontal.Value or 0, Vertical and Vertical.Value or 200)
    end

    -- Legacy chat is the supported path. Retry because the CoreScript registers the SetCore
    -- callback a moment after join and a single early call is silently dropped.
    local function applyLegacy()
        local off = targetOffset()
        pcall(function()
            starterGui:SetCore('ChatWindowPosition', UDim2.fromOffset(off.X, off.Y))
        end)
    end

    -- TextChatService's window has no public position property, so move the rendered frame. Its
    -- name is randomised, so match it by shape: a GuiObject holding the message list (a
    -- ScrollingFrame) under a chat-named ScreenGui in CoreGui or PlayerGui.
    local function findChatFrame()
        local roots = {coreGui}
        local pg = lplr:FindFirstChild('PlayerGui')
        if pg then table.insert(roots, pg) end
        for _, root in roots do
            for _, gui in root:GetChildren() do
                if gui:IsA('ScreenGui') and gui.Name:lower():find('chat') then
                    for _, child in gui:GetChildren() do
                        if child:IsA('GuiObject') and child:FindFirstChildWhichIsA('ScrollingFrame', true) then
                            return child
                        end
                    end
                end
            end
        end
    end

    local function apply()
        applyLegacy()
        local frame = findChatFrame()
        if frame then
            moved = frame
            pcall(function()
                frame.Position = UDim2.fromOffset(targetOffset().X, targetOffset().Y)
            end)
        end
    end

    local function restore()
        pcall(function()
            starterGui:SetCore('ChatWindowPosition', UDim2.new())
        end)
        if moved and moved.Parent then
            pcall(function() moved.Position = UDim2.new() end)
        end
        moved = nil
    end

    ChatPosition = vape.Categories.Render:CreateModule({
        Name = 'ChatPosition',
        Function = function(callback)
            if callback then
                ChatPosition:Clean(task.spawn(function()
                    while ChatPosition.Enabled do
                        apply()
                        task.wait(1)
                    end
                end))
            else
                restore()
            end
        end,
        Tooltip = 'Repositions the chat window. Works with both the legacy chat and TextChatService'
    })
    Vertical = ChatPosition:CreateSlider({
        Name = 'Vertical',
        Min = 0,
        Max = 700,
        Default = 200,
        Suffix = ' px',
        Tooltip = 'How far down from the top-left the chat window sits',
        Function = function()
            if ChatPosition.Enabled then apply() end
        end
    })
    Horizontal = ChatPosition:CreateSlider({
        Name = 'Horizontal',
        Min = 0,
        Max = 700,
        Default = 0,
        Suffix = ' px',
        Tooltip = 'How far right from the left edge the chat window sits',
        Function = function()
            if ChatPosition.Enabled then apply() end
        end
    })
end)
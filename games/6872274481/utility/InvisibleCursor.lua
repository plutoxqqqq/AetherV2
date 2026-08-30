run(function()
    local InvisibleCursor = {}
    local isActive = false
    local renderConnection
    local ViewMode = {Value = 'First Person'}
    local LimitToItems = {Enabled = false}
    local ShowOnGUI = {Enabled = false}
    local lastCursorState = nil

    local function hasBowEquipped()
        if not store.hand or not store.hand.tool then
            return false
        end

        local toolName = store.hand.tool.Name:lower()
        return toolName:find('bow') ~= nil or toolName:find('crossbow') ~= nil
    end

    local function shouldHideCursor()
        if not isActive then return false end

        if ShowOnGUI.Enabled and isGUIOpen() then
            return false
        end

        if LimitToItems.Enabled and not hasBowEquipped() then
            return false
        end

        local inFirstPerson = isFirstPerson()

        if ViewMode.Value == 'First Person' then
            return inFirstPerson
        elseif ViewMode.Value == 'Third Person' then
            return not inFirstPerson
        elseif ViewMode.Value == 'Both' then
            return true
        end

        return false
    end

    local function updateCursor()
        local shouldHide = shouldHideCursor()

        if lastCursorState == shouldHide then
            return
        end

        lastCursorState = shouldHide
        inputService.MouseIconEnabled = not shouldHide
    end

    InvisibleCursor = vape.Categories.Utility:CreateModule({
        Name = 'InvisibleCursor',
        Function = function(callback)
            if callback then
                isActive = true
                lastCursorState = nil

                if renderConnection then
                    renderConnection:Disconnect()
                end

                renderConnection = runService.RenderStepped:Connect(updateCursor)

                InvisibleCursor:Clean(vapeEvents.InventoryChanged.Event:Connect(updateCursor))
            else
                isActive = false

                if renderConnection then
                    renderConnection:Disconnect()
                    renderConnection = nil
                end

                inputService.MouseIconEnabled = true
                lastCursorState = nil
            end
        end,
    })

    ViewMode = InvisibleCursor:CreateDropdown({
        Name = 'View Mode',
        List = {'First Person', 'Third Person', 'Both'},
        Default = 'First Person',
        Function = function(val)
            ViewMode.Value = val
            updateCursor()
        end
    })

    LimitToItems = InvisibleCursor:CreateToggle({
        Name = 'Limit to Bow',
        Default = false,
        Function = function(val)
            LimitToItems.Enabled = val
            updateCursor()
        end
    })

    ShowOnGUI = InvisibleCursor:CreateToggle({
        Name = 'Show on GUI',
        Default = false,
        Function = function(val)
            ShowOnGUI.Enabled = val
            updateCursor()
        end
    })
end)
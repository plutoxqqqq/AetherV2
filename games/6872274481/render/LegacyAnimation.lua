run(function()
    local LegacyAnimation
    local enabled = false
    local renderConnection = nil
    local lastSetValue = nil
    local CameraMode = { Value = 'Both' }

    local function ensureAttribute()
        local workspace = game:GetService("Workspace")
        if workspace:GetAttribute("RbxLegacyAnimationBlending") == nil then
            workspace:SetAttribute("RbxLegacyAnimationBlending", false)
        end
    end

    local function setLegacyAnimation(value)
        local workspace = game:GetService("Workspace")
        ensureAttribute()
        if lastSetValue ~= value then
            workspace:SetAttribute("RbxLegacyAnimationBlending", value)
            lastSetValue = value
        end
    end

    local function updateLegacyAnimation()
        if not enabled then
            setLegacyAnimation(false)
            return
        end

        local mode = 'Both'
        if CameraMode and CameraMode.Value then
            mode = CameraMode.Value
        end

        local inFirstPerson = isFirstPerson()

        local shouldEnable = false
        if mode == "Both" then
            shouldEnable = true
        elseif mode == "First Person" then
            shouldEnable = inFirstPerson
        elseif mode == "Third Person" then
            shouldEnable = not inFirstPerson
        end

        setLegacyAnimation(shouldEnable)
    end

    LegacyAnimation = vape.Categories.Render:CreateModule({
        Name = 'LegacyAnimation',
        Function = function(callback)
            enabled = callback

            if enabled then
                if not renderConnection then
                    renderConnection = game:GetService("RunService").RenderStepped:Connect(updateLegacyAnimation)
                end
                updateLegacyAnimation()
            else
                if renderConnection then
                    renderConnection:Disconnect()
                    renderConnection = nil
                end
                setLegacyAnimation(false)
            end
        end,
        Tooltip = 'turns on Roblox legacy animation blending'
    })

    CameraMode = LegacyAnimation:CreateDropdown({
        Name = 'Camera Mode',
        List = {'Both', 'First Person', 'Third Person'},
        Default = 'Both',
        Function = function(val)
            CameraMode.Value = val
            updateLegacyAnimation()
        end
    })
end)
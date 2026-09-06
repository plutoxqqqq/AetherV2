run(function()
    local SetPlayerLevel
    local originalLevel = nil
    local customLevel = 1

    SetPlayerLevel = vape.Categories.Render:CreateModule({
        Name = "SetPlayerLevel",
        Function = function(state)
            if state then
                originalLevel = lplr:GetAttribute("PlayerLevel")
                lplr:SetAttribute("PlayerLevel", customLevel)
            else
                lplr:SetAttribute("PlayerLevel", originalLevel)
                originalLevel = nil
            end
        end,
        Tooltip = "Spoof your player level (client-sided)"
    })

    SetPlayerLevel:CreateSlider({
        Name = "Level",
        Min = 1,
        Max = 1000,
        Default = 1,
        Decimal = 1,
        Function = function(val)
            customLevel = math.floor(val)
            if SetPlayerLevel.Enabled then
                lplr:SetAttribute("PlayerLevel", customLevel)
            end
        end
    })
end)

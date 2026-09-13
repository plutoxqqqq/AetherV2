run(function()
    local SetPlayerLevel
    local originalLevel = nil
    local customLevel = 1

    SetPlayerLevel = vape.Categories.Render:CreateModule({
        Name = 'SetPlayerLevel',
        Function = function(state)
            if state then
                originalLevel = lplr:GetAttribute('PlayerLevel')
                lplr:SetAttribute('PlayerLevel', customLevel)
            else
                if originalLevel ~= nil then
                    lplr:SetAttribute('PlayerLevel', originalLevel)
                end
                originalLevel = nil
            end
        end,
        Tooltip = 'Client-sided player level spoof.'
    })

    SetPlayerLevel:CreateSlider({
        Name = 'Level',
        Min = 1,
        Max = 1000,
        Default = 1,
        Decimal = 1,
        Function = function(val)
            customLevel = math.floor(val)
            if SetPlayerLevel.Enabled then
                lplr:SetAttribute('PlayerLevel', customLevel)
            end
        end
    })
end)

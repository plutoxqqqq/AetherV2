run(function()
    local ChatNameColor
    local Color
    local original
    local applying = false

    local function selectedColor()
        return Color3.fromHSV(Color.Hue, Color.Sat, Color.Value)
    end

    local function apply()
        if not ChatNameColor.Enabled then return end
        applying = true
        lplr:SetAttribute('ChatNameColor', selectedColor())
        applying = false
    end

    ChatNameColor = vape.Categories.Render:CreateModule({
        Name = 'ChatNameColor',
        Tooltip = 'Changes your chat name colour while enabled',
        Function = function(enabled)
            if enabled then
                original = lplr:GetAttribute('ChatNameColor')
                apply()
                ChatNameColor:Clean(lplr:GetAttributeChangedSignal('ChatNameColor'):Connect(function()
                    if not applying then apply() end
                end))
            else
                applying = true
                lplr:SetAttribute('ChatNameColor', original)
                applying = false
                original = nil
            end
        end
    })
    Color = ChatNameColor:CreateColorSlider({Name = 'Colour', Function = apply})
end)
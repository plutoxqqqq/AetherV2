run(function()
    local ChillLighting
    local oldAmbient, oldOutdoor
    ChillLighting = vape.Categories.Render:CreateModule({
        Name = 'ChillLighting',
        Function = function(callback)
            if callback then
                oldAmbient = lightingService.Ambient
                oldOutdoor = lightingService.OutdoorAmbient
                lightingService.Ambient = Color3.fromRGB(32, 212, 212)
                lightingService.OutdoorAmbient = Color3.fromRGB(32, 212, 212)
            else
                if oldAmbient then lightingService.Ambient = oldAmbient end
                if oldOutdoor then lightingService.OutdoorAmbient = oldOutdoor end
            end
        end,
        Tooltip = 'Changes the ambient lighting to a chill teal'
    })
end)

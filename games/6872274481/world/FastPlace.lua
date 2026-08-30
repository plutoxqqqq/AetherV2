run(function()
    local FastPlace
    local CPS
    local originalCPS

    local function restore()
        if originalCPS ~= nil then
            bedwars.SharedConstants.BLOCK_PLACE_CPS = originalCPS
            originalCPS = nil
        end
    end

    FastPlace = vape.Categories.World:CreateModule({
        Name = 'FastPlace',
        Function = function(enabled)
            if enabled then
                -- Capture on every enable: other modules and game updates may legitimately change it.
                originalCPS = bedwars.SharedConstants.BLOCK_PLACE_CPS or 12
                bedwars.SharedConstants.BLOCK_PLACE_CPS = math.clamp(CPS.Value, 1, 20)
            else
                restore()
            end
        end,
        Tooltip = 'Reduces only the placement cooldown; does not hook placement or alter range.'
    })
    CPS = FastPlace:CreateSlider({
        Name = 'CPS', Min = 1, Max = 20, Default = 13,
        Function = function(value)
            if FastPlace.Enabled then bedwars.SharedConstants.BLOCK_PLACE_CPS = math.clamp(value, 1, 20) end
        end
    })
    FastPlace:CreateButton({Name = 'Use current BedWars CPS', Function = function()
        local current = originalCPS or bedwars.SharedConstants.BLOCK_PLACE_CPS or 12
        CPS:SetValue(math.clamp(current, 1, 20))
    end})
end)
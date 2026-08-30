run(function()
    local NoBob
    local oldPlayAnimation

    local function refreshViewmodel()
        pcall(function()
            bedwars.InventoryViewmodelController:handleStore(
                bedwars.Store:getState()
            )
        end)
    end

    NoBob = vape.Categories.Render:CreateModule({
        Name = 'NoBob',
        Function = function(callback)
            if callback then
                oldPlayAnimation = bedwars.ViewmodelController.playAnimation

                bedwars.ViewmodelController.playAnimation = function(self, animationType, ...)
                    if animationType == bedwars.AnimationType.FP_WALK then
                        return
                    end

                    return oldPlayAnimation(self, animationType, ...)
                end

                -- Rebuild the held-item viewmodel so an already-playing
                -- walking animation is cleared immediately.
                refreshViewmodel()
            else
                if oldPlayAnimation then
                    bedwars.ViewmodelController.playAnimation = oldPlayAnimation
                    oldPlayAnimation = nil
                end

                -- Restore the normal BedWars viewmodel state.
                refreshViewmodel()
            end
        end,
        Tooltip = 'Removes the sword bob animation while moving'
    })
end)
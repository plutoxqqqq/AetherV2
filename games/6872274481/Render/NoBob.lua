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

                
                
                refreshViewmodel()
            else
                if oldPlayAnimation then
                    bedwars.ViewmodelController.playAnimation = oldPlayAnimation
                    oldPlayAnimation = nil
                end

                
                refreshViewmodel()
            end
        end,
        Tooltip = 'Removes the sword bob animation while moving'
    })
end)

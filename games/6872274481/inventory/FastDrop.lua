run(function()
    local FastDrop

    FastDrop = vape.Categories.Inventory:CreateModule({
        Name = 'FastDrop',
        Function = function(callback)
            if callback then
                repeat
                    if entitylib.isAlive and (not store.inventory.opened) and (inputService:IsKeyDown(Enum.KeyCode.Q) or inputService:IsKeyDown(Enum.KeyCode.H) or inputService:IsKeyDown(Enum.KeyCode.Backspace)) and inputService:GetFocusedTextBox() == nil then
                        -- dropItemInHand is a Knit controller method, so it needs its
                        -- controller as self. It was being called bare (self = nil), which is
                        -- why holding the drop key did nothing.
                        task.spawn(bedwars.ItemDropController.dropItemInHand, bedwars.ItemDropController)
                        task.wait()
                    else
                        task.wait(0.1)
                    end
                until not FastDrop.Enabled
            end
        end,
        Tooltip = 'Rapidly drops the item in your hand while you hold Q, H or Backspace'
    })
end)
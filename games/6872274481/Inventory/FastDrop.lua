run(function()
    local FastDrop
    local EveryItem

    -- Every drop goes through the game's own remote, so a stack leaves the inventory exactly the way a
    -- normal drop would instead of being written straight to the world.
    local function dropItem(item)
        local tool = item and item.tool
        if not tool or not item.itemType then return false end
        local ok, drop = pcall(function()
            return bedwars.Handler:Get('DropItem'):Fire('CallServer', {item = tool, amount = item.amount})
        end)
        return ok and drop ~= nil
    end

    FastDrop = vape.Categories.Inventory:CreateModule({
        Name = 'FastDrop',
        Function = function(callback)
            if callback then
                repeat
                    local held = inputService:GetFocusedTextBox() == nil
                        and (inputService:IsKeyDown(Enum.KeyCode.Q) or inputService:IsKeyDown(Enum.KeyCode.H) or inputService:IsKeyDown(Enum.KeyCode.Backspace))
                    if entitylib.isAlive and (not store.inventory.opened) and held then
                        if EveryItem.Enabled then
                            local inventory = store.inventory and store.inventory.inventory
                            for _, item in type(inventory) == 'table' and inventory.items or {} do
                                if not FastDrop.Enabled or not entitylib.isAlive then break end
                                dropItem(item)
                                task.wait(0.03)
                            end
                            task.wait(0.05)
                        else
                            task.spawn(bedwars.ItemDropController.dropItemInHand, bedwars.ItemDropController)
                            task.wait()
                        end
                    else
                        task.wait(0.1)
                    end
                until not FastDrop.Enabled
            end
        end,
        Tooltip = 'Rapidly drops the item in your hand while you hold Q, H or Backspace'
    })
    EveryItem = FastDrop:CreateToggle({
        Name = 'Every item',
        Tooltip = 'Drops every droppable stack you are carrying instead of just the item in your hand'
    })
end)

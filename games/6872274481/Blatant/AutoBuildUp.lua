run(function()
    local AutoBuildUp
    local LimitItems
    local pending = {}
    local nextPlacement = 0
    local directions = {
        Vector3.new(3, 0, 0), Vector3.new(-3, 0, 0), Vector3.new(0, 3, 0),
        Vector3.new(0, -3, 0), Vector3.new(0, 0, 3), Vector3.new(0, 0, -3)
    }

    local function getBuildBlock()
        local hand = store.hand
        if hand and hand.toolType == 'block' and hand.tool then return hand.tool.Name end
        if LimitItems.Enabled then return nil end
        local wool = getWool()
        if wool then return wool end
        for _, item in store.inventory.inventory.items do
            local meta = bedwars.ItemMeta[item.itemType]
            if meta and meta.block and (item.amount or 0) > 0 then return item.itemType end
        end
    end

    local function adjacent(pos)
        for _, offset in directions do
            if getPlacedBlock(pos + offset) then return true end
        end
        return false
    end

    local function queuePlacement(pos, block)
        local key = tostring(pos)
        local request = pending[key]
        if request and tick() < request.retryAt then return end
        if not adjacent(pos) then return end
        pending[key] = {retryAt = tick() + math.clamp(0.22 + lplr:GetNetworkPing(), 0.25, 0.55), attempts = request and request.attempts + 1 or 1}
        nextPlacement = tick() + math.max(0.125, lplr:GetNetworkPing() * 0.6)
        task.spawn(function()
            bedwars.placeBlock(pos, block)
            task.delay(math.clamp(0.18 + lplr:GetNetworkPing(), 0.22, 0.5), function()
                if not AutoBuildUp.Enabled then return end
                if getPlacedBlock(pos) then
                    pending[key] = nil
                elseif pending[key] and pending[key].attempts >= 3 then
                    pending[key] = nil
                end
            end)
        end)
    end

    AutoBuildUp = vape.Categories.Blatant:CreateModule({
        Name = 'AutoBuildUp',
        Function = function(callback)
            table.clear(pending)
            nextPlacement = 0
            if not callback then return end
            AutoBuildUp:Clean(runService.Heartbeat:Connect(function()
                if not entitylib.isAlive or inputService:GetFocusedTextBox() then return end
                local character = entitylib.character
                local root, humanoid = character.RootPart, character.Humanoid
                if not root or not humanoid then return end
                local holding = humanoid.Jump or inputService:IsKeyDown(Enum.KeyCode.Space) or inputService:IsKeyDown(Enum.KeyCode.ButtonA)
                if not holding then return end
                local infinite = vape.Modules.InfiniteJump and vape.Modules.InfiniteJump.Enabled
                if infinite and root.AssemblyLinearVelocity.Y < 22 then
                    root.AssemblyLinearVelocity = Vector3.new(root.AssemblyLinearVelocity.X, 28, root.AssemblyLinearVelocity.Z)
                end
                if tick() < nextPlacement then return end
                local block = getBuildBlock()
                if not block then return end
                local feet = root.Position.Y - (character.HipHeight or 3)
                local target = bedwars.BlockController:getBlockPosition(Vector3.new(root.Position.X, feet - 1.5, root.Position.Z)) * 3
                if feet < target.Y + 1.5 or getPlacedBlock(target) then return end
                queuePlacement(target, block)
            end))
        end,
        Tooltip = 'Towers upward while jump is held'
    })
    LimitItems = AutoBuildUp:CreateToggle({Name = 'Limit to items', Tooltip = 'Only towers with the held block'})
end)

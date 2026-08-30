run(function()
    local AutoVoidDrop
    local OwlCheck
    local PearlCheck

    local pearlRay = RaycastParams.new()
    pearlRay.RespectCanCollide = true
    pearlRay.FilterType = Enum.RaycastFilterType.Exclude

    -- Where a telepearl we threw is going to put us. The arc is walked forward in short steps
    -- with a cast between each pair, so the first thing it would hit is the landing. Estimated,
    -- not exact - it only has to answer "is there ground at the end of this", which is the
    -- difference between saving the loot and throwing it into the void for nothing.
    local function pearlLandsOnGround(pearl, lowestpoint)
        local position = pearl.Position
        local velocity = pearl.AssemblyLinearVelocity
        -- A pearl carried by a controller rather than by physics reports no velocity, and there
        -- is nothing to project from. Unknown counts as "keep the loot".
        if velocity.Magnitude < 1 then return true end

        local meta = bedwars.ProjectileMeta.telepearl
        local gravity = (meta and meta.gravitationalAcceleration) or workspace.Gravity
        pearlRay.FilterDescendantsInstances = {lplr.Character, gameCamera, pearl}

        local step = 0.05
        for _ = 1, 120 do
            local nextPosition = position + (velocity * step)
            local result = workspace:Raycast(position, nextPosition - position, pearlRay)
            if result then
                return result.Position.Y > lowestpoint
            end
            if nextPosition.Y < lowestpoint then return false end
            position = nextPosition
            velocity -= Vector3.new(0, gravity * step, 0)
        end
        -- Still airborne after six seconds: no landing found, so it is not saving us.
        return false
    end

    local function pearlWillSave(lowestpoint)
        for _, projectile in store.selfProjectiles do
            if projectile.Parent and projectile.Name == 'telepearl' and pearlLandsOnGround(projectile, lowestpoint) then
                return true
            end
        end
        return false
    end

    AutoVoidDrop = vape.Categories.Utility:CreateModule({
        Name = 'AutoVoidDrop',
        Function = function(callback)
            if callback then
                repeat task.wait() until store.matchState ~= 0 or (not AutoVoidDrop.Enabled)
                if not AutoVoidDrop.Enabled then return end

                local lowestpoint = math.huge
                for _, v in store.blocks do
                    local point = (v.Position.Y - (v.Size.Y / 2)) - 50
                    if point < lowestpoint then
                        lowestpoint = point
                    end
                end

                repeat
                    if entitylib.isAlive then
                        local root = entitylib.character.RootPart
                        if root.Position.Y < lowestpoint and (lplr.Character:GetAttribute('InflatedBalloons') or 0) <= 0 and not getItem('balloon') then
                            local saved = OwlCheck.Enabled and root:FindFirstChild('OwlLiftForce')
                                or (PearlCheck.Enabled and pearlWillSave(lowestpoint))
                            if not saved then
                                for _, item in {'iron', 'diamond', 'emerald', 'gold'} do
                                    item = getItem(item)
                                    if item then
                                        item = bedwars.Client:Get(remotes.DropItem):CallServer({
                                            item = item.tool,
                                            amount = item.amount
                                        })

                                        if item then
                                            item:SetAttribute('ClientDropTime', tick() + 100)
                                        end
                                    end
                                end
                            end
                        end
                    end

                    task.wait(0.1)
                until not AutoVoidDrop.Enabled
            end
        end,
        Tooltip = 'Drops resources when you fall into the void'
    })
    OwlCheck = AutoVoidDrop:CreateToggle({
        Name = 'Owl check',
        Default = true,
        Tooltip = 'Refuses to drop items if being picked up by an owl'
    })
    PearlCheck = AutoVoidDrop:CreateToggle({
        Name = 'Pearl check',
        Default = true,
        Tooltip = 'Keeps your loot if a telepearl you threw is still in the air and looks like it lands on ground'
    })
end)
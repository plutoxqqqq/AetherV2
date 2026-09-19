run(function()
    local AutoBalloon
    local PopAboveLand

    local plainCheck = RaycastParams.new()
    plainCheck.FilterType = Enum.RaycastFilterType.Exclude
    plainCheck.RespectCanCollide = true

    -- Ground under the feet, using the pack's map-only ray when it is available so the character and
    -- every entity are never mistaken for land.
    local function groundBelow(root)
        if entitylib.isAlive then
            plainCheck.FilterDescendantsInstances = {lplr.Character, gameCamera}
        end
        local params = store.airRay or plainCheck
        return workspace:Raycast(root.Position, Vector3.new(0, -3000, 0), params)
    end

    local function balloonCount()
        return (lplr.Character and lplr.Character:GetAttribute('InflatedBalloons')) or 0
    end

    AutoBalloon = vape.Categories.Utility:CreateModule({
        Name = 'AutoBalloon',
        Function = function(callback)
            if callback then
                repeat task.wait() until store.matchState ~= 0 or (not AutoBalloon.Enabled)
                if not AutoBalloon.Enabled then return end

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
                        if PopAboveLand.Enabled and balloonCount() > 0 and groundBelow(root) then
                            -- The controller owns the balloons, so it is asked to let them go: this
                            -- is the same call the game makes when a balloon is popped in play.
                            for _ = 1, 3 do
                                if balloonCount() <= 0 then break end
                                pcall(function()
                                    bedwars.BalloonController:deflateBalloon()
                                end)
                                task.wait(0.05)
                            end
                        elseif root.Position.Y < lowestpoint and balloonCount() < 3 then
                            local balloon = getItem('balloon')
                            if balloon then
                                for _ = 1, 3 do
                                    bedwars.BalloonController:inflateBalloon()
                                end
                            end
                            task.wait(0.1)
                        end
                    end
                    task.wait(0.1)
                until not AutoBalloon.Enabled
            end
        end,
        Tooltip = 'Inflates when you fall into the void'
    })

    PopAboveLand = AutoBalloon:CreateToggle({
        Name = 'Pop when above land',
        Tooltip = 'Pops the balloons as soon as there is ground underneath you again'
    })
end)

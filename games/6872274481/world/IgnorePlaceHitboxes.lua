run(function()
    local IgnorePlaceHitboxes
    local function withIgnoredHitboxes(callback)
        local originals = {}
        for _, plr in playersService:GetPlayers() do
            local character = plr.Character
            if character then
                for _, part in character:GetDescendants() do
                    if part:IsA('BasePart') then
                        originals[part] = part.CanQuery
                        part.CanQuery = false
                    end
                end
            end
        end
        local results = table.pack(xpcall(callback, function(err) return err end))
        for part, value in originals do
            if part.Parent then part.CanQuery = value end
        end
        if not results[1] then error(results[2], 0) end
        return table.unpack(results, 2, results.n)
    end

    IgnorePlaceHitboxes = vape.Categories.World:CreateModule({
        Name = 'IgnorePlaceHitboxes',
        Tooltip = 'Allows block placement through players and your own character',
        Function = function(enabled)
            if enabled then
                bedwars.IgnorePlaceHitboxes = withIgnoredHitboxes
            else
                bedwars.IgnorePlaceHitboxes = nil
            end
        end
    })
end)
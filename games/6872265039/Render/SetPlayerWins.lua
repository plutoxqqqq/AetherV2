run(function()
    local SetPlayerWins
    local originalWins = nil
    local customWins = 0
    local winsValue = nil 

    local function findWinsValue()
        local leaderstats = lplr:FindFirstChild("leaderstats")
        if leaderstats then
            return leaderstats:FindFirstChild("Wins") or leaderstats:FindFirstChild("OverallWins")
        end
        return nil
    end

    local function applyWinsOverride()
        winsValue = findWinsValue()
        if winsValue and winsValue:IsA("IntValue") then
            if originalWins == nil then
                originalWins = winsValue.Value
            end
            winsValue.Value = customWins
        else
            notif("SetPlayerWins", "Could not find Wins value", 3)
        end
    end

    local function restoreWins()
        if winsValue and winsValue:IsA("IntValue") and originalWins ~= nil then
            winsValue.Value = originalWins
        end
        winsValue = nil
        originalWins = nil
    end

    SetPlayerWins = vape.Categories.Render:CreateModule({
        Name = "SetPlayerWins",
        Function = function(state)
            if state then
                applyWinsOverride()
                SetPlayerWins:Clean(lplr.ChildAdded:Connect(function(child)
                    if child.Name == "leaderstats" and SetPlayerWins.Enabled then
                        applyWinsOverride()
                    end
                end))
            else
                restoreWins()
            end
        end,
        Tooltip = "Modify your wins in leaderstats (client‑sided)"
    })

    SetPlayerWins:CreateSlider({
        Name = "Wins",
        Min = 0,
        Max = 10000,
        Default = 0,
        Decimal = 1,
        Function = function(val)
            customWins = math.floor(val)
            if SetPlayerWins.Enabled and winsValue then
                winsValue.Value = customWins
            end
        end
    })
end)

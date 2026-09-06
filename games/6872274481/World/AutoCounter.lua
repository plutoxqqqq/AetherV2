run(function()
    local AutoCounter
    local tntCount
    local LimitItem
    local AutoPlaceToggle
    local HighlightToggle

    local alltntBlocks = {}
    local counteredtnt = {}
    local tntHighlights = {}
    local autoCounterPlacing = false
	local function fixPosition(pos)
		return bedwars.BlockController:getBlockPosition(pos) * 3
	end

    local function addHighlight(tntBlock)
        if tntHighlights[tntBlock] or not tntBlock.Parent then return end
        local h = Instance.new('SelectionBox')
        h.Adornee = tntBlock
        h.Color3 = Color3.fromRGB(255, 50, 50)
        h.LineThickness = 0.05
        h.SurfaceTransparency = 0.6
        h.SurfaceColor3 = Color3.fromRGB(255, 50, 50)
        h.Parent = coreGui
        tntHighlights[tntBlock] = h
    end

    local function removeHighlight(tntBlock)
        if tntHighlights[tntBlock] then
            tntHighlights[tntBlock]:Destroy()
            tntHighlights[tntBlock] = nil
        end
    end

    local function clearAllHighlights()
        for _, h in pairs(tntHighlights) do
            h:Destroy()
        end
        table.clear(tntHighlights)
    end

    local function isEnemytnt(tntBlock)
        if not tntBlock or not tntBlock.Parent then return false end
        if tntBlock:GetAttribute("AutoCountertnt") then return false end

        local placerId = tntBlock:GetAttribute("PlacedByUserId")
        if not placerId then
            return true
        end

        if placerId == lplr.UserId then
            return false
        end
        local myTeam = lplr:GetAttribute('Team')
        if myTeam then
            for _, player in playersService:GetPlayers() do
                if player.UserId == placerId and player:GetAttribute('Team') == myTeam then
                    return false
                end
            end
        end

        return true
    end

    local function isHoldingtnt()
        return isHoldingItem({'tnt'})
    end

    AutoCounter = vape.Categories.World:CreateModule({
        Name = 'AutoCounter',
        Function = function(callback)
            if callback then
                table.clear(counteredtnt)

                local tntAddedConnection = workspace.DescendantAdded:Connect(function(obj)
                    if obj.Name == "tnt" and obj:IsA("Part") then
                        if autoCounterPlacing then
                            obj:SetAttribute("AutoCountertnt", true)
                        end
                        alltntBlocks[obj] = true

                        task.defer(function()
                            if HighlightToggle and HighlightToggle.Enabled and isEnemytnt(obj) then
                                addHighlight(obj)
                            end
                        end)

                        local ancestryConnection
                        ancestryConnection = obj.AncestryChanged:Connect(function()
                            if not obj.Parent then
                                alltntBlocks[obj] = nil
                                counteredtnt[obj] = nil
                                removeHighlight(obj)
                                local fixedPos = fixPosition(obj.Position)
                                local posKey = string.format("%.0f,%.0f,%.0f", fixedPos.X, fixedPos.Y, fixedPos.Z)
                                autoCounterPositions[posKey] = nil
                                if ancestryConnection then
                                    ancestryConnection:Disconnect()
                                end
                            end
                        end)
                    end
                end)
                AutoCounter:Clean(tntAddedConnection)

                for _, obj in workspace:GetDescendants() do
                    if obj.Name == "tnt" and obj:IsA("Part") and not alltntBlocks[obj] then
                        alltntBlocks[obj] = true
                    end
                end

                local horizontalSides = {}
                for _, side in ipairs(Enum.NormalId:GetEnumItems()) do
                    local sideVec = Vector3.fromNormalId(side)
                    if sideVec.Y == 0 then
                        table.insert(horizontalSides, sideVec)
                    end
                end

                repeat
                    if not entitylib.isAlive then
                        task.wait(0.1)
                        continue
                    end

                    if HighlightToggle and HighlightToggle.Enabled then
                        for tntBlock in pairs(alltntBlocks) do
                            if tntBlock.Parent and isEnemytnt(tntBlock) then
                                addHighlight(tntBlock)
                            end
                        end
                    else
                        clearAllHighlights()
                    end

                    if AutoPlaceToggle and AutoPlaceToggle.Enabled then
                        if LimitItem.Enabled and not isHoldingtnt() then
                            task.wait(0.1)
                            continue
                        end

                        if not getItem("tnt") then
                            task.wait(0.1)
                            continue
                        end

                        local myPosition = entitylib.character.RootPart.Position
                        local maxDistanceSq = 30 * 30

                        for tntBlock in pairs(alltntBlocks) do
                            if tntBlock.Parent and not counteredtnt[tntBlock] and isEnemytnt(tntBlock) then
                                local offset = tntBlock.Position - myPosition
                                local distanceSq = offset.X * offset.X + offset.Y * offset.Y + offset.Z * offset.Z

                                if distanceSq <= maxDistanceSq then
                                    local placedCount = 0
                                    local maxCount = tntCount.Value

                                    for _, sideVec in ipairs(horizontalSides) do
                                        if LimitItem.Enabled and not isHoldingtnt() then break end
                                        if placedCount >= maxCount then break end

                                        local placePos = fixPosition(tntBlock.Position + sideVec * 3.5)
                                        if not getPlacedBlock(placePos) and getItem("tnt") then
                                            if LimitItem.Enabled and not isHoldingtnt() then break end
                                            autoCounterPlacing = true
                                            bedwars.placeBlock(placePos, "tnt")
                                            autoCounterPlacing = false
                                            placedCount = placedCount + 1
                                            task.wait(0.05)
                                        end
                                    end

                                    counteredtnt[tntBlock] = true
                                    task.defer(function()
                                        if tntBlock.Parent then
                                            tntBlock.AncestryChanged:Wait()
                                        end
                                        counteredtnt[tntBlock] = nil
                                    end)
                                end
                            end
                        end
                    end

                    task.wait(0.1)
                until not AutoCounter.Enabled
            else
                table.clear(counteredtnt)
                clearAllHighlights()
            end
        end,
        Tooltip = 'Highlights and counters enemy TNT'
    })

    tntCount = AutoCounter:CreateSlider({
        Name = 'TNT Count',
        Min = 1,
        Max = 5,
        Default = 3
    })

    LimitItem = AutoCounter:CreateToggle({
        Name = 'Limit to TNT',
        Default = true,
    })

    AutoPlaceToggle = AutoCounter:CreateToggle({
        Name = 'Auto Place',
        Default = true,
    })

    HighlightToggle = AutoCounter:CreateToggle({
        Name = 'Highlight',
        Default = true,
    })
end)

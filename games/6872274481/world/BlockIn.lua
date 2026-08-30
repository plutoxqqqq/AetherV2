run(function()
    local BlockIn

    local rayCheck = RaycastParams.new()
    rayCheck.RespectCanCollide = true
    rayCheck.FilterType = Enum.RaycastFilterType.Exclude

    local BreakSpeed
    local PlaceMode
    local PlaceDelay
    local Bedfinder
    local LimitItem
    local UseBlacklist
    local Blacklist
    local Priority
    local ReturnSlot
    local WoolOnly
    local BedBreak

    local function isBlacklisted(itemType)
	return UseBlacklist and UseBlacklist.Enabled and Blacklist and table.find(Blacklist.ListEnabled, itemType)
    end

    local function getBlocks()
	local blocks = {}

	if LimitItem and LimitItem.Enabled then
		local itemType = store.hand.toolType == 'block' and store.hand.tool and store.hand.tool.Name
		local meta = itemType and bedwars.ItemMeta[itemType]
		local block = meta and meta.block
		if block and not isBlacklisted(itemType) and (store.hand.amount or 0) > 0
			and (not WoolOnly.Enabled or itemType:find('wool')) then
			table.insert(blocks, { itemType, block.health or 0, store.hand.tool, store.hand.amount })
		end
		return blocks
	end

	for _, item in store.inventory.inventory.items do
		local itemType = item.itemType
		local meta = itemType and bedwars.ItemMeta[itemType]
		local block = meta and meta.block
		if block and not isBlacklisted(itemType) and (item.amount or 0) > 0
			and (not WoolOnly.Enabled or itemType:find('wool')) then
			table.insert(blocks, { itemType, block.health or 0, item.tool, item.amount })
		end
	end
	table.sort(blocks, function(a, b)
		return Priority.Value == 'Lowest cost' and a[2] < b[2] or Priority.Value ~= 'Lowest cost' and a[2] > b[2]
	end)
	return blocks
    end

    local function getBed()
	local localPosition = entitylib.isAlive and entitylib.character.RootPart.Position or Vector3.zero
	for _, v in collectionService:GetTagged('bed') do
		if
			not v:GetAttribute('Team' .. (lplr:GetAttribute('Team') or -1) .. 'NoBreak')
			and (localPosition - v.Position).Magnitude <= 30
		then
			return v
		end
	end
	return
    end

    local function getPyramid(protectedDirection)
	local pattern = {
		Vector3.new(3, 0, 0),
		Vector3.new(0, 0, 3),
		Vector3.new(-3, 0, 0),
		Vector3.new(0, 0, -3),
		Vector3.new(3, 3, 0),
		Vector3.new(0, 3, 3),
		Vector3.new(-3, 3, 0),
		Vector3.new(0, 3, -3),
	}

	local rng = Random.new()

	if rng:NextNumber() < 0.95 then
		local extraCount = rng:NextInteger(1, 3)
		for _ = 1, extraCount do
			local dirX = (rng:NextInteger(0, 1) == 1 and 1 or -1)
			local dirZ = (rng:NextInteger(0, 1) == 1 and 1 or -1)
			local y = ({ 0, 3 })[rng:NextInteger(1, 2)]

			local offset = Vector3.new(3 * dirX, y, 3 * dirZ)

			if table.find(pattern, offset) then
				continue
			end
			table.insert(pattern, offset)
		end
	end

	local axis = rng:NextInteger(0, 1) == 1 and 'X' or 'Z'
	local dir = rng:NextInteger(0, 1) == 1 and 1 or -1
	local extraPos = axis == 'X' and Vector3.new(3 * dir, 6, 0) or Vector3.new(0, 6, 3 * dir)
	table.insert(pattern, extraPos)
	table.insert(pattern, Vector3.new(0, 6, 0))

	if protectedDirection then
		for index = #pattern, 1, -1 do
			local flat = pattern[index] * Vector3.new(1, 0, 1)
			if flat.Magnitude > 0 and flat.Unit:Dot(protectedDirection) > 0.65 then table.remove(pattern, index) end
		end
	end
	return pattern
    end

    BlockIn = vape.Categories.World:CreateModule({
	Name = 'BlockIn',
	Function = function(callback)
		if callback then
			local selfpos = entitylib.isAlive and entitylib.character.RootPart.Position or nil
			local previousSlot = store.inventory.hotbarSlot

			if selfpos then
				rayCheck.FilterDescendantsInstances = { lplr.Character, gameCamera }

				if Bedfinder.Enabled and not getBed() then
					notif('BlockIn', 'No bed found', 2, 'warning')
				elseif LimitItem and LimitItem.Enabled and store.hand.toolType ~= 'block' then
					notif('BlockIn', 'Hold a block first', 2, 'warning')
				else
					local oldPlaceCPS = bedwars.SharedConstants.BLOCK_PLACE_CPS
                    local restored = false
                    local function restoreState()
                        if restored then return end
                        restored = true
                        bedwars.SharedConstants.BLOCK_PLACE_CPS = oldPlaceCPS or 12
                        if ReturnSlot.Enabled and previousSlot ~= nil then hotbarSwitch(previousSlot) end
                    end
                    BlockIn:Clean(restoreState)
					bedwars.SharedConstants.BLOCK_PLACE_CPS = math.clamp(20, 1, 20)
					if PlaceMode.Value == 'Smart' then
						local ray
						for _, offset in { Vector3.new(0, -2, 0), Vector3.new(0, 1, 0) } do
							local placement = workspace:Raycast(
								selfpos + offset,
								entitylib.character.RootPart.CFrame.LookVector * 4,
								rayCheck
							)

							if placement and placement.Instance and placement.Instance:IsA('BasePart') then
								local pos = placement.Instance.Position
								local rounded = roundPos(pos)
								local oldSlot = store.hand and store.hand.tool and getHotbar(store.hand.tool)
								ray = placement.Instance:GetPivot().Position

								if bedwars.BlockController:isBlockBreakable({ blockPosition = pos / 3 }, lplr) then
									repeat
										if not entitylib.isAlive then
											break
										end
										task.spawn(bedwars.breakBlock, placement.Instance, false, nil, true, true)
										task.wait(BreakSpeed.Value)
									until not getPlacedBlock(rounded) or not BlockIn.Enabled or not entitylib.isAlive
								end

								if oldSlot then
									hotbarSwitch(oldSlot)
								end

								if BlockIn.Enabled and entitylib.isAlive then
									selfpos = entitylib.character.RootPart.Position
								end
							end
						end
						if ray then
							lplr.Character.Humanoid:MoveTo(Vector3.new(ray.X, selfpos.Y, ray.Z))
							lplr.Character.Humanoid.MoveToFinished:Wait()
							if entitylib.isAlive then
								selfpos = entitylib.character.RootPart.Position
							end
						end
					end

					local blocks = getBlocks()
                    local function currentBreakingDirection()
                        if not BedBreak.Enabled or not entitylib.isAlive or not inputService:IsMouseButtonPressed(0) then return nil end
                        local bed = getBed()
                        local selector = bedwars.BlockBreaker.clientManager:getBlockSelector()
                        local mouseinfo = selector and selector:getMouseInfo(0)
                        local target = mouseinfo and mouseinfo.target and mouseinfo.target.blockRef
                        if not bed or not target or (bed.Position - entitylib.character.RootPart.Position).Magnitude > 14 then return nil end
                        local delta = (target.blockPosition * 3 - entitylib.character.RootPart.Position) * Vector3.new(1, 0, 1)
                        return delta.Magnitude > 0.1 and delta.Unit or nil
                    end
					for i, block in blocks do
						if not BlockIn.Enabled or not entitylib.isAlive then
							break
						end
						if (block[4] or 0) <= 0 then
							continue
						end
						for index, v in store.inventory.hotbar do
							if v.item and v.item.tool == block[3] and index ~= (store.inventory.hotbarSlot + 1) then
								hotbarSwitch(index - 1)
								break
							end
						end
						local pattern = getPyramid(currentBreakingDirection())

						for i2, pos in pattern do
							if not BlockIn.Enabled or not entitylib.isAlive then
								break
							end
							if getPlacedBlock(selfpos + pos) and i2 ~= 10 then
								continue
							end
                            -- Re-read the active break ray before every placement. If the player
                            -- changes block or face mid-run, never close that new attack corridor.
                            local direction = currentBreakingDirection()
                            local flat = pos * Vector3.new(1, 0, 1)
                            if direction and flat.Magnitude > 0 and flat.Unit:Dot(direction) > 0.65 then continue end
                            local worldPosition = selfpos + pos
                            local placed = getPlacedBlock(worldPosition)
                            for _ = 1, 3 do
                                if placed or not BlockIn.Enabled or not entitylib.isAlive then break end
                                bedwars.placeBlock(worldPosition, block[1], true)
                                local deadline = tick() + 0.35
                                repeat
                                    task.wait()
                                    placed = getPlacedBlock(worldPosition)
                                until placed or tick() >= deadline or not BlockIn.Enabled or not entitylib.isAlive
                            end
                            if not placed and BlockIn.Enabled then
                                notif('BlockIn', 'Placement was not confirmed; leaving the opening clear', 3, 'warning')
                            end
							local delay = PlaceDelay:GetRandomValue()
							if delay > 0 then
								task.wait(delay)
							end
						end
					end

					if #blocks < 1 then
						notif('BlockIn', 'Missing blocks', 4, 'warning')
					end
                    restoreState()
				end
			end
			if BlockIn.Enabled then
				BlockIn:Toggle()
			end
		end
	end,
	Tooltip = 'Automatically places strong blocks around yourself'
    })

    BreakSpeed = BlockIn:CreateSlider({
	Name = 'Break speed',
	Min = 0,
	Max = 0.3,
	Default = 0.25,
	Decimal = 100,
	Tooltip = 'How long it takes to break the surrounding block (smart mode)',
	Suffix = 'seconds',
    })
    PlaceMode = BlockIn:CreateDropdown({
	Name = 'Placement Mode',
	List = { 'Normal', 'Smart' },
	Default = 'Normal',
    })
    PlaceDelay = BlockIn:CreateTwoSlider({
	Name = 'Place Delay',
	Min = 0,
	Max = 5,
	DefaultMin = 0.07,
	DefaultMax = 0.1,
	Decimal = 5,
    })
    Bedfinder = BlockIn:CreateToggle({ Name = 'Bed finder' })
    BedBreak = BlockIn:CreateToggle({Name = 'Bed break', Tooltip = 'Keeps the active bed-breaking side open while patching outside gaps'})
    Priority = BlockIn:CreateDropdown({Name = 'Block priority', List = {'Hardest', 'Lowest cost'}, Default = 'Hardest'})
    ReturnSlot = BlockIn:CreateToggle({Name = 'Return to last slot', Default = true})
    WoolOnly = BlockIn:CreateToggle({Name = 'Wool only'})
    LimitItem = BlockIn:CreateToggle({
	Name = 'Limit to items',
	Tooltip = 'Only block-in with the block you are holding',
    })
    UseBlacklist = BlockIn:CreateToggle({
	Name = 'Use blacklist',
	Default = true,
	Function = function(call)
		if Blacklist then
			Blacklist.Object.Visible = call
		end
	end,
    })
    Blacklist = BlockIn:CreateTextList({
	Name = 'Blacklists',
	Placeholder = 'block',
	Default = {
		'cannon',
		'tnt',
		'siege_tnt',
	},
    })
end)
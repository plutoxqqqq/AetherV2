run(function()
	local Scaffold
	local Count
	local Expand
	local Tower
	local Downwards
	local Diagonal
	local LimitItem
	local Mouse
	local BridgeWidth
	local KeepY
	local LevelBridge
	local JumpBridge
	local BlockPreference
	local RestoreSlot
	local FillColor
	local OutlineColor
	local adjacent, lastpos, label, visualBlock = {}, Vector3.zero
	local visualTween, visualPos
	local visualSpeed = 0.1
	local lockedY, restoreSlot, nextJump = nil, nil, 0

	for x = -3, 3, 3 do
		for y = -3, 3, 3 do
			for z = -3, 3, 3 do
				local vec = Vector3.new(x, y, z)
				if vec ~= Vector3.zero then
					table.insert(adjacent, vec)
				end
			end
		end
	end

	local function nearCorner(poscheck, pos)
		local startpos = poscheck - Vector3.new(3, 3, 3)
		local endpos = poscheck + Vector3.new(3, 3, 3)
		local check = poscheck + (pos - poscheck).Unit * 100
		return Vector3.new(math.clamp(check.X, startpos.X, endpos.X), math.clamp(check.Y, startpos.Y, endpos.Y), math.clamp(check.Z, startpos.Z, endpos.Z))
	end

	local function blockProximity(pos)
		local mag, returned = 60
		local tab = getBlocksInPoints(bedwars.BlockController:getBlockPosition(pos - Vector3.new(21, 21, 21)), bedwars.BlockController:getBlockPosition(pos + Vector3.new(21, 21, 21)))
		for _, v in tab do
			local blockpos = nearCorner(v, pos)
			local newmag = (pos - blockpos).Magnitude
			if newmag < mag then
				mag, returned = newmag, blockpos
			end
		end
		table.clear(tab)
		return returned
	end

	local function checkAdjacent(pos)
		for _, v in adjacent do
			if getPlacedBlock(pos + v) then
				return true
			end
		end
		return false
	end

	local function getScaffoldBlock()
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name, store.hand.amount
		elseif (not LimitItem.Enabled) then
			local items = (store.inventory.inventory or {}).items or {}
			if BlockPreference.Value == 'Wool first' then
				local wool, amount = getWool()
				if wool then return wool, amount end
			end
			local chosen
			for _, item in items do
				local meta = bedwars.ItemMeta[item.itemType]
				if meta and meta.block and (not chosen or (BlockPreference.Value == 'Highest count' and (item.amount or 0) > (chosen.amount or 0))) then
					chosen = item
					if BlockPreference.Value == 'Nearest slot' then break end
				end
			end
			if chosen then return chosen.itemType, chosen.amount end
		end

		return nil, 0
	end

	local function clearVisuals()
		if visualTween then
			visualTween:Cancel()
			visualTween = nil
		end
		if visualBlock then
			visualBlock.Parent = nil
		end
		visualPos = nil
	end

	local function updateVisual(pos)
		if not visualBlock or not pos then return end

		local blockpos = bedwars.BlockController:getBlockPosition(pos) * 3
		if visualPos == blockpos then return end

		if visualTween then
			visualTween:Cancel()
			visualTween = nil
		end

		if visualBlock.Parent == gameCamera then
			visualTween = tweenService:Create(visualBlock, TweenInfo.new(visualSpeed, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = CFrame.new(blockpos)})
			visualTween:Play()
		else
			visualBlock.CFrame = CFrame.new(blockpos)
			visualBlock.Parent = gameCamera
		end
		visualPos = blockpos
	end

	Scaffold = vape.Categories.Utility:CreateModule({
		Name = 'Scaffold',
		Function = function(callback)
			if label then
				label.Visible = callback
			end

			if callback then
				lockedY, restoreSlot, nextJump = nil, nil, 0
				repeat
					if entitylib.isAlive then
						local wool, amount = getScaffoldBlock()

						if Mouse.Enabled then
							if not inputService:IsMouseButtonPressed(0) then
								wool = nil
							end
						end

						if label then
							amount = amount or 0
							label.Text = amount..' <font color="rgb(170, 170, 170)">(Scaffold)</font>'
							label.TextColor3 = Color3.fromHSV((amount / 128) / 2.8, 0.86, 1)
						end

						if wool then
							local root = entitylib.character.RootPart
							
							
							if store.hand.toolType ~= 'block' then
								for slot, entry in store.inventory.hotbar or {} do
									if entry.item and entry.item.itemType == wool then
										restoreSlot = restoreSlot or store.inventory.hotbarSlot
										hotbarSwitch(slot - 1)
										break
									end
								end
							end
							if Tower.Enabled and inputService:IsKeyDown(Enum.KeyCode.Space) and (not inputService:GetFocusedTextBox()) then
								root.Velocity = Vector3.new(root.Velocity.X, 38, root.Velocity.Z)
							end
							if JumpBridge.Enabled and not Tower.Enabled and entitylib.character.Humanoid.FloorMaterial ~= Enum.Material.Air and entitylib.character.Humanoid.MoveDirection.Magnitude > 0.05 and tick() >= nextJump then
								entitylib.character.Humanoid.Jump = true
								nextJump = tick() + 0.24
							end

							for i = Expand.Value, 1, -1 do
								local currentpos = roundPos(root.Position - Vector3.new(0, entitylib.character.HipHeight + (Downwards.Enabled and inputService:IsKeyDown(Enum.KeyCode.LeftShift) and 4.5 or 1.5), 0) + entitylib.character.Humanoid.MoveDirection * (i * 3))
								local downwards = Downwards.Enabled and inputService:IsKeyDown(Enum.KeyCode.LeftShift)
								if (KeepY.Enabled or LevelBridge.Enabled) and not downwards then
									lockedY = lockedY or currentpos.Y
									currentpos = Vector3.new(currentpos.X, lockedY, currentpos.Z)
								else
									lockedY = currentpos.Y
								end
								if Diagonal.Enabled then
									if math.abs(math.round(math.deg(math.atan2(-entitylib.character.Humanoid.MoveDirection.X, -entitylib.character.Humanoid.MoveDirection.Z)) / 45) * 45) % 90 == 45 then
										local dt = (lastpos - currentpos)
										if ((dt.X == 0 and dt.Z ~= 0) or (dt.X ~= 0 and dt.Z == 0)) and ((lastpos - root.Position) * Vector3.new(1, 0, 1)).Magnitude < 2.5 then
											currentpos = lastpos
										end
									end
								end

								updateVisual(currentpos)
								local positions = {currentpos}
								if BridgeWidth.Value > 1 then
									local direction = entitylib.character.Humanoid.MoveDirection
									if direction.Magnitude < 0.05 then direction = root.CFrame.LookVector end
									local side = Vector3.new(-direction.Z, 0, direction.X)
									if side.Magnitude > 0 then
										side = side.Unit * 3
										for offset = 1, BridgeWidth.Value - 1 do
											table.insert(positions, currentpos + side * ((offset % 2 == 0 and -1 or 1) * math.ceil(offset / 2)))
										end
									end
								end
								for _, placepos in positions do
									local block, blockpos = getPlacedBlock(placepos)
									if not block then
										blockpos = checkAdjacent(blockpos * 3) and blockpos * 3 or blockProximity(placepos)
										if blockpos then Scaffold:Delay(0, function() bedwars.placeBlock(blockpos, wool, false) end) end
									end
								end
								lastpos = currentpos
							end
						end
					end
					task.wait(0.03)
				until not Scaffold.Enabled
				clearVisuals()
				if RestoreSlot.Enabled and restoreSlot ~= nil then hotbarSwitch(restoreSlot) end
				restoreSlot, lockedY = nil, nil
			end
		end,
		Tooltip = 'Helps you make bridges/scaffold walk.'
	})
	Expand = Scaffold:CreateSlider({
		Name = 'Expand',
		Min = 1,
		Max = 6
	})
	BridgeWidth = Scaffold:CreateSlider({
		Name = 'Bridge width', Min = 1, Max = 3, Default = 1,
		Tooltip = 'Places up to three blocks across while bridging'
	})
	KeepY = Scaffold:CreateToggle({Name = 'Keep Y', Default = true, Tooltip = 'Keeps a level bridge unless downwards mode is held'})
	LevelBridge = Scaffold:CreateToggle({Name = 'Level bridge', Default = false, Tooltip = 'Locks Scaffold to the starting bridge level'})
	JumpBridge = Scaffold:CreateToggle({Name = 'Jump bridge', Tooltip = 'Repeats natural jumps while moving on a bridge'})
	Tower = Scaffold:CreateToggle({
		Name = 'Tower',
		Default = true
	})
	Downwards = Scaffold:CreateToggle({
		Name = 'Downwards',
		Default = true
	})
	Diagonal = Scaffold:CreateToggle({
		Name = 'Diagonal',
		Default = true
	})
	LimitItem = Scaffold:CreateToggle({Name = 'Limit to items'})
	BlockPreference = Scaffold:CreateDropdown({
		Name = 'Block preference', List = {'Wool first', 'Nearest slot', 'Highest count'}, Default = 'Wool first',
		Tooltip = 'Chooses which inventory block Scaffold should use'
	})
	RestoreSlot = Scaffold:CreateToggle({Name = 'Restore slot', Default = true, Tooltip = 'Returns to the slot held before automatic block selection'})
	Mouse = Scaffold:CreateToggle({Name = 'Require mouse down'})
	Scaffold:CreateToggle({
		Name = 'Visual',
		Tooltip = 'Renders an overlay on the block about to be placed',
		Function = function(callback)
			FillColor.Object.Visible = callback
			OutlineColor.Object.Visible = callback
			if callback then
				visualBlock = Instance.new('Part')
				visualBlock.Size = Vector3.new(3, 3, 3)
				visualBlock.Anchored = true
				visualBlock.CanCollide = false
				visualBlock.CanQuery = false
				visualBlock.CanTouch = false
				visualBlock.CastShadow = false
				visualBlock.Transparency = 1
				local selection = Instance.new('SelectionBox')
				selection.Adornee = visualBlock
				selection.LineThickness = 0.04
				selection.Color3 = Color3.fromHSV(OutlineColor.Hue, OutlineColor.Sat, OutlineColor.Value)
				selection.Transparency = 1 - OutlineColor.Opacity
				selection.SurfaceColor3 = Color3.fromHSV(FillColor.Hue, FillColor.Sat, FillColor.Value)
				selection.SurfaceTransparency = 1 - FillColor.Opacity
				selection.Parent = visualBlock
				bedwars.QueryUtil:setQueryIgnored(visualBlock, true)
			else
				clearVisuals()
				if visualBlock then visualBlock:Destroy() end
				visualBlock = nil
			end
		end
	})
	FillColor = Scaffold:CreateColorSlider({
		Name = 'Fill Color',
		DefaultSat = 0,
		DefaultOpacity = 0.4,
		Darker = true,
		Visible = false,
		Function = function(hue, sat, val, opacity)
			if visualBlock then
				visualBlock.SelectionBox.SurfaceColor3 = Color3.fromHSV(hue, sat, val)
				visualBlock.SelectionBox.SurfaceTransparency = 1 - opacity
			end
		end
	})
	OutlineColor = Scaffold:CreateColorSlider({
		Name = 'Outline Color',
		DefaultValue = 0,
		Darker = true,
		Visible = false,
		Function = function(hue, sat, val, opacity)
			if visualBlock then
				visualBlock.SelectionBox.Color3 = Color3.fromHSV(hue, sat, val)
				visualBlock.SelectionBox.Transparency = 1 - opacity
			end
		end
	})
	Count = Scaffold:CreateToggle({
		Name = 'Block Count',
		Function = function(callback)
			if callback then
				label = Instance.new('TextLabel')
				label.Size = UDim2.fromOffset(100, 20)
				label.Position = UDim2.new(0.5, 6, 0.5, 60)
				label.BackgroundTransparency = 1
				label.AnchorPoint = Vector2.new(0.5, 0)
				label.Text = '0'
				label.TextColor3 = Color3.new(0, 1, 0)
				label.TextSize = 18
				label.RichText = true
				label.Font = Enum.Font.Arial
				label.Visible = Scaffold.Enabled
				label.Parent = vape.gui
			else
				label:Destroy()
				label = nil
			end
		end
	})
end)

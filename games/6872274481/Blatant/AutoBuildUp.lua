run(function()
	local AutoBuildUp
	local LimitItems

	local function getBuildBlock()
		if store.hand.toolType == 'block' then
			return store.hand.tool.Name
		end

		if LimitItems.Enabled then
			return nil
		end

		local wool = getWool()
		if wool then
			return wool
		end

		for _, item in (store.inventory.inventory or {}).items or {} do
			local meta = bedwars.ItemMeta[item.itemType]
			if meta and meta.block and (item.amount or 0) > 0 then
				return item.itemType
			end
		end

		return nil
	end

	AutoBuildUp = vape.Categories.Blatant:CreateModule({
		Name = 'AutoBuildUp',
		Function = function(callback)
			if not callback then return end

			AutoBuildUp:Clean(runService.Heartbeat:Connect(function()
				if not entitylib.isAlive or inputService:GetFocusedTextBox() then
					return
				end

				if not inputService:IsKeyDown(Enum.KeyCode.Space)
					and not inputService:IsKeyDown(Enum.KeyCode.ButtonA) then
					return
				end

				local character = entitylib.character
				local root = character.RootPart
				local humanoid = character.Humanoid

				if not root or not humanoid then return end

				local block = getBuildBlock()
				if not block then return end

				-- Keep the player moving upward while jump is held.
				root.Velocity = Vector3.new(
					root.Velocity.X,
					38,
					root.Velocity.Z
				)

				-- Find the block directly underneath the player.
				local position = roundPos(
					root.Position
						- Vector3.new(0, character.HipHeight + 1.5, 0)
				)

				if getPlacedBlock(position) then
					return
				end

				local _, blockPosition = getPlacedBlock(position)

				if blockPosition then
					bedwars.placeBlock(blockPosition * 3, block, false)
				else
					bedwars.placeBlock(position, block, false)
				end
			end))
		end,
		Tooltip = 'Places blocks beneath you while jumping'
	})

	LimitItems = AutoBuildUp:CreateToggle({
		Name = 'Limit to items',
		Tooltip = 'Only uses the currently held block'
	})
end)
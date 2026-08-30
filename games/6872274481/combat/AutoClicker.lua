run(function()
	local AutoClicker
	local CPS
	local BlockCPS = {}
	local Attacks
	local Blocks
	local Wool
	local Thread
	local heldInputs = {}
	local bridgeInputs = {}

	local function stopInput(source)
		heldInputs[source] = nil
		bridgeInputs[source] = nil
		if not next(heldInputs) and Thread then
			task.cancel(Thread)
			Thread = nil
		end
	end

	local function AutoClick(source, autoBridge)
		heldInputs[source] = true
		bridgeInputs[source] = autoBridge or nil
		if Thread then
			return
		end

		Thread = task.delay(1 / (store.hand.toolType == 'block' and BlockCPS or CPS).GetRandomValue(), function()
			repeat
				if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
					local blockPlacer = bedwars.BlockPlacementController.blockPlacer
					if store.hand.toolType == 'block' and Blocks.Enabled and (not Wool.Enabled or store.hand.tool.Name:find('wool_')) and blockPlacer then
						if (workspace:GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= ((1 / 12) * 0.5) then
							if next(bridgeInputs) and blockPlacer.autoBridge then
								blockPlacer:autoBridge(workspace:GetServerTimeNow() - bedwars.KnockbackController:getLastKnockbackTime() >= 0.2)
							else
								local mouseinfo = blockPlacer.clientManager:getBlockSelector():getMouseInfo(0)
								if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
									task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition)
								end
							end
						end
					elseif store.hand.toolType == 'sword' and Attacks.Enabled then
						bedwars.SwordController:swingSwordAtMouse()
					end
				end

				task.wait(1 / (store.hand.toolType == 'block' and BlockCPS or CPS).GetRandomValue())
			until not AutoClicker.Enabled or not next(heldInputs)
			Thread = nil
		end)
	end

	AutoClicker = vape.Categories.Combat:CreateModule({
		Name = 'AutoClicker',
		Function = function(callback)
			if callback then
				AutoClicker:Clean(inputService.InputBegan:Connect(function(input, processed)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						AutoClick(input, false)
					elseif input.UserInputType == Enum.UserInputType.Touch then
						-- World touches use the selector's suggested placement exactly like desktop.
						-- Gui buttons are handled below so camera/menu touches cannot start clicking.
						local overButton = false
						for _, object in guiService:GetGuiObjectsAtPosition(input.Position.X, input.Position.Y) do
							if object:IsA('GuiButton') then overButton = true; break end
						end
						if not processed and not overButton then AutoClick(input, false) end
					end
				end))

				AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
						stopInput(input)
					end
				end))

				if inputService.TouchEnabled then
					local hooked = {}
					local function hookButton(button)
						if hooked[button] or not button:IsA('GuiButton') then return end
						local name = button.Name:lower()
						local label = button:IsA('TextButton') and button.Text:lower() or ''
						local relevant = tonumber(button.Name) ~= nil or name:find('attack', 1, true) or name:find('place', 1, true)
							or name:find('build', 1, true) or name:find('block', 1, true) or label:find('build', 1, true)
						if not relevant then return end
						hooked[button] = true
						local autoBridge = tonumber(button.Name) ~= nil or name:find('build', 1, true) ~= nil
							or name:find('bridge', 1, true) ~= nil or label:find('build', 1, true) ~= nil
						AutoClicker:Clean(button.MouseButton1Down:Connect(function() AutoClick(button, autoBridge) end))
						AutoClicker:Clean(button.MouseButton1Up:Connect(function()
							stopInput(button)
						end))
						AutoClicker:Clean(button.InputEnded:Connect(function(input)
							if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then stopInput(button) end
						end))
						AutoClicker:Clean(button.AncestryChanged:Connect(function(_, parent)
							if not parent then stopInput(button) end
						end))
					end
					task.spawn(function()
						local mobileUI = lplr.PlayerGui:WaitForChild('MobileUI', 20)
						if not mobileUI or not AutoClicker.Enabled then return end
						for _, button in mobileUI:GetDescendants() do hookButton(button) end
						AutoClicker:Clean(mobileUI.DescendantAdded:Connect(hookButton))
					end)
				end
			else
				table.clear(heldInputs)
				table.clear(bridgeInputs)
				if Thread then
					task.cancel(Thread)
					Thread = nil
				end
			end
		end,
		Tooltip = 'Hold attack button to automatically click'
	})
	Attacks = AutoClicker:CreateToggle({
		Name = 'Attack',
		Default = true,
		Function = function(callback)
			if CPS and CPS.Object then
				CPS.Object.Visible = callback
			end
		end,
		Tooltip = 'Automatically attacks while the mouse button is held'
	})
	CPS = AutoClicker:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
	})
	Blocks = AutoClicker:CreateToggle({
		Name = 'Place Blocks',
		Default = true,
		Function = function(callback)
			if BlockCPS.Object then
				BlockCPS.Object.Visible = callback
			end
			if Wool and Wool.Object then Wool.Object.Visible = callback end
		end
	})
	Wool = AutoClicker:CreateToggle({Name = 'Wool only', Tooltip = 'Only places while wool is held.', Darker = true})
	BlockCPS = AutoClicker:CreateTwoSlider({
		Name = 'Block CPS',
		Min = 1,
		Max = 12,
		DefaultMin = 12,
		DefaultMax = 12,
		Darker = true
	})
end)
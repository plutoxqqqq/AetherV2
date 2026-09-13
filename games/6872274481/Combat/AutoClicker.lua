run(function()
	local AutoClicker
	local CPS
	local Place
	local Wool
	local BlockCPS = {}
	local Thread
	
	local function isAttack(input)
		local keybinds = bedwars.KeybindLoadController:getKeybinds()
		local keyboard = keybinds and keybinds.keyboard and keybinds.keyboard.controlActions.Attack or Enum.UserInputType.MouseButton1
		local gamepad = keybinds and keybinds.gamepad and keybinds.gamepad.controlActions.Attack or Enum.KeyCode.ButtonR2
	
		return input.UserInputType == keyboard or input.KeyCode == keyboard or input.KeyCode == gamepad
	end
	
	local function getBlockInterval()
		return 1 / (bedwars.SharedConstants.BLOCK_PLACE_CPS or 12)
	end
	
	local function getClickDelay()
		if store.hand.toolType == 'block' then
			return math.max(1 / BlockCPS.GetRandomValue(), getBlockInterval())
		end
	
		return 1 / CPS.GetRandomValue()
	end
	
	local function AutoClick()
		if Thread then
			task.cancel(Thread)
		end
	
		Thread = task.delay(getClickDelay(), function()
			repeat
				if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
					local blockPlacer = bedwars.BlockPlacementController.blockPlacer
					if store.hand.toolType == 'block' and Place.Enabled and (Wool.Enabled and store.hand.tool.Name:find('wool_') or not Wool.Enabled) and blockPlacer and canPlace() then
						if (workspace:GetServerTimeNow() - bedwars.BlockCpsController.lastPlaceTimestamp) >= (getBlockInterval() * 0.5) then
							if inputService.TouchEnabled then
								task.spawn(blockPlacer.autoBridge, blockPlacer, workspace:GetServerTimeNow() - bedwars.KnockbackController:getLastKnockbackTime() >= 0.2)
							else
								local selector = blockPlacer.clientManager:getBlockSelector()
								local mouseinfo = selector and selector:getMouseInfo(0)
								if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
									task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition, mouseinfo)
								end
							end
						end
					elseif store.hand.toolType == 'sword' then
						if inputService.TouchEnabled then
							bedwars.SwordController:mobileSwingPressed()
						elseif canSwing() and not bedwars.SwordController.disableSwingState then
							bedwars.SwordController:swingSwordAtMouse(0.39)
						end
					end
				end
	
				task.wait(getClickDelay())
			until not AutoClicker.Enabled
		end)
	end
	
	AutoClicker = vape.Categories.Combat:CreateModule({
		Name = 'AutoClicker',
		Function = function(callback)
			if callback then
				AutoClicker:Clean(inputService.InputBegan:Connect(function(input)
					if isAttack(input) then
						AutoClick()
					end
				end))
	
				AutoClicker:Clean(inputService.InputEnded:Connect(function(input)
					if isAttack(input) and Thread then
						task.cancel(Thread)
						Thread = nil
					end
				end))
	
				if inputService.TouchEnabled then
					local hooked = {}
					local function hookButton(button)
						if hooked[button] or not button:IsA('GuiButton') or not tonumber(button.Name) then return end
						hooked[button] = true
						AutoClicker:Clean(button.MouseButton1Down:Connect(AutoClick))
						AutoClicker:Clean(button.MouseButton1Up:Connect(function()
							if Thread then
								task.cancel(Thread)
								Thread = nil
							end
						end))
					end
	
					task.spawn(function()
						local mobileUI = lplr.PlayerGui:WaitForChild('MobileUI', 20)
						if not mobileUI or not AutoClicker.Enabled then return end
	
						for _, v in mobileUI:GetChildren() do
							hookButton(v)
						end
						AutoClicker:Clean(mobileUI.ChildAdded:Connect(hookButton))
					end)
				end
			else
				if Thread then
					task.cancel(Thread)
					Thread = nil
				end
			end
		end,
		Tooltip = 'Hold attack button to automatically click'
	})
	CPS = AutoClicker:CreateTwoSlider({
		Name = 'CPS',
		Min = 1,
		Max = 9,
		DefaultMin = 7,
		DefaultMax = 7
	})
	Place = AutoClicker:CreateToggle({
		Name = 'Place Blocks',
		Default = true,
		Function = function(callback)
			if BlockCPS.Object then
				BlockCPS.Object.Visible = callback
			end
	
			if Wool and Wool.Object then
				Wool.Object.Visible = callback
			end
		end
	})
	Wool = AutoClicker:CreateToggle({Name = 'Wool only', Tooltip = 'Only clicks when you are holding wool.', Darker = true})
	BlockCPS = AutoClicker:CreateTwoSlider({
		Name = 'Block CPS',
		Min = 1,
		Max = 12,
		DefaultMin = 12,
		DefaultMax = 12,
		Darker = true
	})
end)

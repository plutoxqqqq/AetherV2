run(function()
	local AutoClicker
	local CPS
	local Place
	local Wool
	local BlockCPS = {}
	local Thread

	local function isCasting()
		local casting = lplr:GetAttribute('IsCasting')
		return casting and casting ~= 0 and casting ~= ''
	end

	local function canSwing()
		if type(bedwars.SwordController.getSwordSwingDisabled) ~= 'function' or bedwars.SwordController:getSwordSwingDisabled() or isCasting() then
			return false
		end

		local itemmeta = store.hand and store.hand.tool and bedwars.ItemMeta[store.hand.tool.Name]
		return itemmeta ~= nil and itemmeta.sword ~= nil and itemmeta.sword.chargedAttack == nil
	end

	local function canPlace()
		local controller = bedwars.BlockPlacementController
		return controller ~= nil and not controller.disabled and not isCasting()
	end

	local function getWoolBaseCps()
		if Wool.Enabled and store.hand and store.hand.tool then
			return store.hand.tool.Name:find('wool_') ~= nil
		end
		return not Wool.Enabled
	end

	local function placeInterval()
		local cps = BlockCPS:GetRandomValue()
		return math.max(1 / math.max(cps, 0.001), 1 / (bedwars.SharedConstants.BLOCK_PLACE_CPS or 12))
	end

	local function clickInterval()
		return 1 / math.max(CPS:GetRandomValue(), 0.001)
	end

	local function canClickBlock()
		if store.hand.toolType ~= 'block' or not Place.Enabled then return false end
		if not getWoolBaseCps() then return false end
		local blockPlacer = bedwars.BlockPlacementController.blockPlacer
		if not blockPlacer or not canPlace() then return false end
		return (workspace:GetServerTimeNow() - (bedwars.BlockCpsController.lastPlaceTimestamp or 0)) >= ((1 / (bedwars.SharedConstants.BLOCK_PLACE_CPS or 12)) * 0.5)
	end

	local function AutoClick()
		if Thread then
			task.cancel(Thread)
		end

		local delay = store.hand.toolType == 'block' and placeInterval() or clickInterval()
		Thread = task.delay(delay, function()
			repeat
				if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
					if store.hand.toolType == 'block' then
						if canClickBlock() then
							local blockPlacer = bedwars.BlockPlacementController.blockPlacer
							if inputService.TouchEnabled and blockPlacer.autoBridge then
								task.spawn(blockPlacer.autoBridge, blockPlacer, workspace:GetServerTimeNow() - bedwars.KnockbackController:getLastKnockbackTime() >= 0.2)
							else
								local selector = blockPlacer.clientManager and blockPlacer.clientManager:getBlockSelector()
								local mouseinfo = selector and selector:getMouseInfo(0)
								if mouseinfo and mouseinfo.placementPosition == mouseinfo.placementPosition then
									task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition, mouseinfo)
								end
							end
						end
					elseif store.hand.toolType == 'sword' then
						if inputService.TouchEnabled then
							local controller = bedwars.SwordController
							if controller.mobileSwingPressed then
								controller:mobileSwingPressed()
							end
						elseif canSwing() and not bedwars.SwordController.disableSwingState then
							bedwars.SwordController:swingSwordAtMouse(0.39)
						end
					end
				end

				task.wait(store.hand.toolType == 'block' and placeInterval() or clickInterval())
			until not AutoClicker.Enabled
		end)
	end

	local function isAttack(input)
		local keybinds = bedwars.KeybindLoadController and bedwars.KeybindLoadController:getKeybinds()
		local keyboard = keybinds and keybinds.keyboard and keybinds.keyboard.controlActions.Attack or Enum.UserInputType.MouseButton1
		local gamepad = keybinds and keybinds.gamepad and keybinds.gamepad.controlActions.Attack or Enum.KeyCode.ButtonR2
		return input.UserInputType == keyboard or input.KeyCode == keyboard or input.KeyCode == gamepad
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
		Function = function(callback)
			if BlockCPS.Object then
				BlockCPS.Object.Visible = callback
			end

			if Wool then
				Wool.Object.Visible = callback
			end
		end,
		Default = true
	})
	Wool = AutoClicker:CreateToggle({Name = 'Wool only', Tooltip = 'Only clicks when you are holding wool', Darker = true})
	BlockCPS = AutoClicker:CreateTwoSlider({
		Name = 'Block CPS',
		Min = 1,
		Max = 20,
		DefaultMin = 20,
		DefaultMax = 20,
		Darker = true
	})
end)

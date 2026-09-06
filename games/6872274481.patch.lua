local license = ... or {}
local vape = shared.vape
if not vape then return end

local cloneref = cloneref or function(obj) return obj end
local playersService = cloneref(game:GetService('Players'))
local inputService = cloneref(game:GetService('UserInputService'))
local lplr = playersService.LocalPlayer
local entitylib = vape.Libraries and vape.Libraries.entity
local store = shared.store or (getgenv and getgenv().store)
local bedwars = (getgenv and getgenv().bedwars) or shared.bedwars
if not (entitylib and store and bedwars and vape.Categories and vape.Categories.Combat) then
	return
end

if type(vape.Remove) == 'function' then
	pcall(function()
		vape:Remove('AutoClicker')
	end)
end

local AutoClicker
local CPS
local Place
local Wool
local BlockCPS = {}
local Thread

local function isAttack(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		return true
	end
	local keybinds
	pcall(function()
		keybinds = bedwars.KeybindLoadController and bedwars.KeybindLoadController:getKeybinds()
	end)
	local keyboard = keybinds and keybinds.keyboard and keybinds.keyboard.controlActions.Attack
	local gamepad = keybinds and keybinds.gamepad and keybinds.gamepad.controlActions.Attack or Enum.KeyCode.ButtonR2
	return input.UserInputType == keyboard or input.KeyCode == keyboard or input.KeyCode == gamepad
end

local function holdingAttack()
	return inputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
end

local function handIsBlock()
	local hand = store.hand
	if not hand then return false end
	if hand.toolType == 'block' then return true end
	local name = hand.tool and hand.tool.Name or hand.itemType
	local meta = name and bedwars.ItemMeta and bedwars.ItemMeta[name]
	return meta and meta.block ~= nil
end

local function handIsSword()
	local hand = store.hand
	if not hand then return false end
	if hand.toolType == 'sword' then return true end
	local name = hand.tool and hand.tool.Name or hand.itemType
	local meta = name and bedwars.ItemMeta and bedwars.ItemMeta[name]
	return meta and meta.sword ~= nil
end

local function canPlace()
	local hand = store.hand
	if not entitylib.isAlive or not hand then return false end
	if Wool and Wool.Enabled then
		local name = hand.tool and hand.tool.Name or hand.itemType or ''
		if not tostring(name):find('wool') then return false end
	end
	return handIsBlock()
end

local function canSwing()
	if not entitylib.isAlive or not handIsSword() then return false end
	if bedwars.DaoController and bedwars.DaoController.chargingMaid then return false end
	if bedwars.SwordController and bedwars.SwordController.disableSwingState then return false end
	return true
end

local function getBlockInterval()
	return 1 / ((bedwars.SharedConstants and bedwars.SharedConstants.BLOCK_PLACE_CPS) or 12)
end

local function getClickDelay()
	if handIsBlock() then
		local cps = BlockCPS.GetRandomValue and BlockCPS.GetRandomValue() or 12
		return math.max(1 / math.max(cps, 1), getBlockInterval())
	end
	local cps = CPS.GetRandomValue and CPS.GetRandomValue() or 7
	return 1 / math.max(cps, 1)
end

local function AutoClick()
	if Thread then
		pcall(task.cancel, Thread)
	end

	Thread = task.spawn(function()
		repeat
			local guiOpen = false
			pcall(function()
				guiOpen = bedwars.AppController and bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN)
			end)
			if (holdingAttack() or inputService.TouchEnabled) and not guiOpen then
				local blockPlacer = bedwars.BlockPlacementController and bedwars.BlockPlacementController.blockPlacer
				if Place.Enabled and canPlace() then
					local lastPlace = 0
					pcall(function()
						lastPlace = bedwars.BlockCpsController.lastPlaceTimestamp
					end)
					if (workspace:GetServerTimeNow() - lastPlace) >= (getBlockInterval() * 0.5) then
						if inputService.TouchEnabled and blockPlacer and blockPlacer.autoBridge then
							local lastKb = 0
							pcall(function()
								lastKb = bedwars.KnockbackController:getLastKnockbackTime()
							end)
							task.spawn(blockPlacer.autoBridge, blockPlacer, workspace:GetServerTimeNow() - lastKb >= 0.2)
						elseif blockPlacer then
							local selector = blockPlacer.clientManager and blockPlacer.clientManager:getBlockSelector()
							local mouseinfo = selector and selector:getMouseInfo(0)
							if mouseinfo and mouseinfo.placementPosition then
								task.spawn(blockPlacer.placeBlock, blockPlacer, mouseinfo.placementPosition, mouseinfo)
							elseif bedwars.placeBlock then
								local mouse = lplr:GetMouse()
								if mouse and mouse.Hit then
									pcall(bedwars.placeBlock, mouse.Hit.Position, store.hand.itemType)
								end
							end
						elseif bedwars.placeBlock then
							local mouse = lplr:GetMouse()
							if mouse and mouse.Hit then
								pcall(bedwars.placeBlock, mouse.Hit.Position, store.hand.itemType)
							end
						end
					end
				elseif canSwing() then
					if inputService.TouchEnabled then
						pcall(function()
							bedwars.SwordController:mobileSwingPressed()
						end)
					else
						pcall(function()
							bedwars.SwordController:swingSwordAtMouse(0.39)
						end)
					end
				end
			end
			task.wait(getClickDelay())
		until not AutoClicker.Enabled or (not inputService.TouchEnabled and not holdingAttack())
		Thread = nil
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
					pcall(task.cancel, Thread)
					Thread = nil
				end
			end))
		elseif Thread then
			pcall(task.cancel, Thread)
			Thread = nil
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

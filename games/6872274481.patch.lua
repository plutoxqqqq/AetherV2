local license = ... or {}
local vape = shared.vape
if not vape then return end

local env = getgenv and getgenv() or _G
local entitylib = vape.Libraries and vape.Libraries.entity
local store = (env and env.store) or shared.store
local bedwars = (env and env.bedwars) or shared.bedwars

if env then
	env.canPlace = env.canPlace or function()
		if not (bedwars and store and store.hand and store.hand.toolType == 'block') then
			return false
		end
		local placer = bedwars.BlockPlacementController and bedwars.BlockPlacementController.blockPlacer
		if not placer then return false end
		local ok, info = pcall(function()
			local selector = placer.clientManager and placer.clientManager:getBlockSelector()
			return selector and selector:getMouseInfo(0)
		end)
		return ok and type(info) == 'table' and info.placementPosition ~= nil
	end
	env.canSwing = env.canSwing or function()
		if not (entitylib and entitylib.isAlive and store and store.hand and store.hand.toolType == 'sword') then
			return false
		end
		if bedwars and bedwars.SwordController and bedwars.SwordController.disableSwingState then
			return false
		end
		if bedwars and bedwars.DaoController and bedwars.DaoController.chargingMaid then
			return false
		end
		return true
	end
end

local Runtime = shared.AetherBedWarsRuntime
if type(Runtime) == 'table' and type(Runtime.Context) == 'table' and type(Runtime.InstallLongJumpJadeHook) == 'function' then
	pcall(Runtime.InstallLongJumpJadeHook, Runtime, vape.Modules and vape.Modules.LongJump)
end

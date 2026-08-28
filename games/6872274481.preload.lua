-- BedWars readiness gate for games/6872274481.lua.
--
-- This file is intentionally side-effect free: it only waits until the client framework that the
-- main BedWars module reads during bootstrap has actually replicated and initialized. The main game
-- file installs hooks/connections while it boots, so retrying that file itself after a partial
-- failure can leave duplicate state behind. Waiting here lets the real game file execute once, after
-- its critical dependencies exist.

local playersService = game:GetService('Players')
local replicatedStorage = game:GetService('ReplicatedStorage')
local lplr = playersService.LocalPlayer
local deadline = os.clock() + 60
local lastError = 'BedWars runtime has not replicated yet'

repeat
	local ok, result = xpcall(function()
		assert(lplr and lplr:FindFirstChild('PlayerScripts'), 'LocalPlayer scripts are unavailable')
		local playerTS = lplr.PlayerScripts:FindFirstChild('TS')
		assert(playerTS, 'PlayerScripts.TS is unavailable')

		local rbxts = replicatedStorage:FindFirstChild('rbxts_include')
		local replicatedTS = replicatedStorage:FindFirstChild('TS')
		assert(rbxts and replicatedTS, 'ReplicatedStorage BedWars runtime is unavailable')

		local nodeModules = rbxts:FindFirstChild('node_modules')
		assert(nodeModules, 'rbxts node_modules are unavailable')

		local easyGames = nodeModules:FindFirstChild('@easy-games')
		local knitFolder = easyGames and easyGames:FindFirstChild('knit')
		local knitSource = knitFolder and knitFolder:FindFirstChild('src')
		assert(knitSource, 'Knit is unavailable')
		local Knit = require(knitSource).KnitClient
		assert(Knit and Knit.Controllers, 'Knit controllers are unavailable')
		for _, controller in {'BlockBreakController', 'ProjectileController', 'SwordController'} do
			assert(Knit.Controllers[controller], controller..' is unavailable')
		end

		local flameworkFolder = nodeModules:FindFirstChild('@flamework')
		local flameworkCore = flameworkFolder and flameworkFolder:FindFirstChild('core')
		local flameworkOut = flameworkCore and flameworkCore:FindFirstChild('out')
		assert(flameworkOut and require(flameworkOut).Flamework, 'Flamework runtime is unavailable')

		local inventoryFolder = replicatedTS:FindFirstChild('inventory')
		local inventoryUtil = inventoryFolder and inventoryFolder:FindFirstChild('inventory-util')
		assert(inventoryUtil and require(inventoryUtil).InventoryUtil, 'InventoryUtil is unavailable')

		local remotes = replicatedTS:FindFirstChild('remotes')
		local remoteModule = remotes and require(remotes)
		assert(remoteModule and remoteModule.default and remoteModule.default.Client, 'BedWars remote client is unavailable')

		local ui = playerTS:FindFirstChild('ui')
		local store = ui and ui:FindFirstChild('store')
		assert(store and require(store).ClientStore, 'BedWars ClientStore is unavailable')

		return true
	end, debug and debug.traceback or tostring)

	if ok and result then
		-- Knit/PlayerScripts can become visible on the same scheduler slice as their final startup
		-- work. One short settle period keeps the main module from racing that last initialization.
		task.wait(0.5)
		return true
	end

	lastError = result
	task.wait(0.2)
until os.clock() >= deadline

error('BedWars runtime did not become ready: '..tostring(lastError), 0)

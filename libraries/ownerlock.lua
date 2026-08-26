-- AetherV2 private-owner policy.
--
-- This file and the matching "PRIVATE OWNER LOCK" blocks in init.lua/main.lua are deliberately
-- isolated so the restriction can be removed cleanly if the project becomes public again.
local playersService = game:GetService('Players')

local ownerAccounts = {
	[10892298546] = 'plutoxqqqqq',
	[11192223658] = 'plutoxqqqqqq',
	[11507362139] = 'plutoxqqqqqqq',
	[11515370034] = 'aetherv2owner'
}
pcall(table.freeze, ownerAccounts)

local function verify(player)
	if typeof(player) ~= 'Instance' or not player:IsA('Player') then
		return false, 'local player is unavailable'
	end

	local expectedName = ownerAccounts[player.UserId]
	if not expectedName then
		return false, 'account is not an approved owner account'
	end
	if string.lower(player.Name) ~= expectedName then
		return false, 'username and UserId do not match the owner policy'
	end
	if player ~= playersService.LocalPlayer or player.Parent ~= playersService then
		return false, 'local player identity changed'
	end
	return true
end

local ownerLock = {}

function ownerLock.Verify(player)
	return verify(player)
end

function ownerLock.Start(vape, onViolation)
	assert(type(vape) == 'table', 'owner lock requires the active Aether instance')
	assert(type(onViolation) == 'function', 'owner lock requires a violation handler')

	local player = playersService.LocalPlayer
	local valid, reason = verify(player)
	if not valid then
		onViolation(reason)
		return
	end

	local active = true
	local token = {}
	shared.AetherOwnerGuard = token

	local function stop()
		active = false
		if shared.AetherOwnerGuard == token then
			shared.AetherOwnerGuard = nil
		end
	end

	local function inspect()
		if not active then return end
		if shared.AetherOwnerGuard ~= token then
			active = false
			onViolation('owner guard integrity changed')
			return
		end
		local allowed, problem = verify(player)
		if not allowed then
			active = false
			onViolation(problem)
		end
	end

	-- Property events catch identity removal immediately; the independent loop also catches a
	-- disconnected/altered event and mutation of the shared guard marker.
	local ancestryConnection = player.AncestryChanged:Connect(inspect)
	local nameConnection = player:GetPropertyChangedSignal('Name'):Connect(inspect)
	vape:Clean(function()
		stop()
		ancestryConnection:Disconnect()
		nameConnection:Disconnect()
	end)

	task.spawn(function()
		while active do
			task.wait(0.75)
			inspect()
		end
	end)

	return token
end

pcall(table.freeze, ownerLock)
return ownerLock

-- Shared combat state.
--
-- "In combat" means the local player has taken damage within the last COMBAT_WINDOW
-- seconds. The state is built from the damage and death events the BedWars pack already
-- fires (vapeEvents.EntityDamageEvent / EntityDeathEvent, the same source DamageBoost,
-- AutoNyx and friends listen to), so a module never has to wire its own damage hook.
--
-- Dying clears the timer instead of leaving the killing blow in place: a player who just
-- died reads as out of combat, so a module gating on this state resumes as soon as it
-- respawns rather than 3 seconds after being killed.
--
-- Consumers reach it through getgenv().AetherCombat, shared.AetherCombat or
-- vape.Libraries.combat (set by the BedWars base).

local cloneref = cloneref or function(obj)
	return obj
end

local playersService = cloneref(game:GetService('Players'))
local lplr = playersService.LocalPlayer

local COMBAT_WINDOW = 3

local combat = {
	Window = COMBAT_WINDOW,
	Started = false,
	LastDamageAt = nil,
	ClearedAt = nil,
	Connections = {},
}

local function clearedNow()
	return combat.ClearedAt ~= nil and (tick() - combat.ClearedAt) < combat.Window
end

-- True while the local player has taken damage inside the combat window.
function combat:IsInCombat()
	if clearedNow() then
		return false
	end
	return self.LastDamageAt ~= nil and (tick() - self.LastDamageAt) < self.Window
end

-- Seconds since the last accepted damage, or nil when there is none.
function combat:TimeSinceDamage()
	if self.LastDamageAt == nil then
		return nil
	end
	return tick() - self.LastDamageAt
end

-- Seconds left before the state falls back to out of combat, 0 when it already has.
function combat:TimeLeft()
	if not self:IsInCombat() then
		return 0
	end
	return math.max(self.Window - (tick() - self.LastDamageAt), 0)
end

-- Drop the state (death, respawn, or anything that should not count as a fight).
function combat:Reset()
	self.LastDamageAt = nil
	self.ClearedAt = tick()
end

local function onDamage(damageTable)
	if type(damageTable) ~= 'table' or damageTable.entityInstance ~= lplr.Character then
		return
	end
	-- A blow that lands after the death event (the kill shot) must not restart the timer.
	if clearedNow() then
		return
	end
	combat.LastDamageAt = tick()
end

local function onDeath(deathTable)
	if type(deathTable) == 'table' and deathTable.entityInstance ~= lplr.Character then
		return
	end
	combat:Reset()
end

function combat:Start()
	if self.Started then
		return self
	end
	self.Started = true

	local vape = shared.vape
	local vapeEvents = getgenv().vapeEvents
	local function track(connection)
		if not connection then
			return
		end
		table.insert(self.Connections, connection)
		if vape and type(vape.Clean) == 'function' then
			vape:Clean(connection)
		end
	end

	if vapeEvents then
		track(vapeEvents.EntityDamageEvent.Event:Connect(onDamage))
		track(vapeEvents.EntityDeathEvent.Event:Connect(onDeath))
	end
	track(lplr.CharacterAdded:Connect(function()
		self:Reset()
	end))
	track(lplr.CharacterRemoving:Connect(function()
		self:Reset()
	end))

	return self
end

function combat:Stop()
	self.Started = false
	for _, connection in self.Connections do
		pcall(function()
			connection:Disconnect()
		end)
	end
	table.clear(self.Connections)
	self.LastDamageAt = nil
	self.ClearedAt = nil
end

combat:Start()

return combat

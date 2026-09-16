run(function()
	local util = vape.Libraries.bedwarsutil
	local CatExtender
	local Multiplier
	local WallKick
	local WallMultiplier

	local function root()
		return util.Utils.Root()
	end

	local function launch(impulse)
		if not impulse then return end
		local part = root()
		if part then part:ApplyImpulse(impulse) end
	end

	CatExtender = kits:CreateModule({
		Name = 'CatExtender',
		Category = 'Ability',
		Function = function(callback)
			if not callback then return end
			-- The hook is kept installed while the toggle is on, so it still lands if the game
			-- only builds CatController once the match starts or after a respawn.
			util.Hook.Controller(CatExtender, 'CatController', 'leap', function(original, ...)
				local results = table.pack(original(...))
				if CatExtender.Enabled and util.IsKit('cat') then
					local direction = util.FindVector(...)
					local part = root()
					local value = Multiplier and Multiplier.Value or 1
					if direction and part and value > 1 then
						local flat = direction * Vector3.new(1, 0, 1)
						if flat.Magnitude > 1e-4 then
							launch(flat.Unit * part.AssemblyMass * (value - 1) * 70)
						end
					end
				end
				return table.unpack(results, 1, results.n)
			end)
		end,
		Tooltip = 'Extends how far the Cat/Yamini pounce launches you'
	})

	Multiplier = CatExtender:CreateSlider({
		Name = 'Multiplier',
		Min = 1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 'x',
		Tooltip = 'How much further than normal the pounce carries you. 1x is the game\'s own distance'
	})

	WallKick = kits:CreateModule({
		Name = 'YaminiWallKick',
		Category = 'Ability',
		Function = function(callback)
			if not callback then return end
			util.Hook.Controller(WallKick, 'CatController', 'dismountWall', function(original, ...)
				local results = table.pack(original(...))
				if WallKick.Enabled and util.IsKit('cat') then
					local part = root()
					local value = WallMultiplier and WallMultiplier.Value or 1
					if part and value > 1 then
						launch(Vector3.new(0, part.AssemblyMass * (value - 1) * 25, 0))
					end
				end
				return table.unpack(results, 1, results.n)
			end)
		end,
		Tooltip = 'Extends how high dropping off a climbed wall throws you'
	})

	WallMultiplier = WallKick:CreateSlider({
		Name = 'Multiplier',
		Min = 1,
		Max = 5,
		Default = 2,
		Decimal = 10,
		Suffix = 'x'
	})
end)

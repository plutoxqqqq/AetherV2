run(function()
    local HitBoxes
    local Targets
    local TargetPart
    local Expand
    local modified = {}

    HitBoxes = vape.Categories.Blatant:CreateModule({
	Name = 'HitBoxes',
	Function = function(callback)
		if callback then
			repeat
				for _, v in entitylib.List do
					if v.Targetable then
						if not Targets.Players.Enabled and v.Player then
							continue
						end
						if not Targets.NPCs.Enabled and v.NPC then
							continue
						end
						local part = v[TargetPart.Value]
						if not modified[part] then
							modified[part] = {part.Size, part.Massless}
						end
						part.Size = modified[part][1] + Vector3.new(Expand.Value, Expand.Value, Expand.Value)
						part.Massless = true
					end
				end
				task.wait()
			until not HitBoxes.Enabled
		else
			for i, v in modified do
				i.Size = v[1]
				i.Massless = v[2]
			end
			table.clear(modified)
		end
	end,
	Tooltip = 'Expands entities hitboxes',
    })
    Targets = HitBoxes:CreateTargets({ Players = true })
    TargetPart = HitBoxes:CreateDropdown({
	Name = 'Part',
	List = { 'RootPart', 'Head' },
    })
    Expand = HitBoxes:CreateSlider({
	Name = 'Expand amount',
	Min = 0,
	Max = 2,
	Decimal = 10,
	Suffix = function(val)
		return val == 1 and 'stud' or 'studs'
	end,
    })
end)

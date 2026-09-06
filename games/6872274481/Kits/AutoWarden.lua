run(function()
	local AutoWarden
	local Range

	local collected = setmetatable({}, {__mode = 'k'})

	AutoWarden = kits:CreateModule({
		Name = 'AutoWarden',
		Function = function(callback)
			if callback then
				table.clear(collected)

				repeat
					if entitylib.isAlive and store.equippedKit == 'jailor' then
						local origin = entitylib.character.RootPart.Position
						for _, v in collectionService:GetTagged('jailor_soul') do
							if not collected[v] and v.PrimaryPart and (v.PrimaryPart.Position - origin).Magnitude <= Range.Value then
								collected[v] = true
								bedwars.JailorController:collectEntity(lplr, v, v.Name)
							end
						end
					end
					task.wait(0.1)
				until not AutoWarden.Enabled
			end
		end,
		Tooltip = 'Automatically imprisons the souls dropped by enemies you kill'
	})
	Range = AutoWarden:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 60,
		Default = 25,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
end)

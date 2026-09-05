run(function()
	local AntiLasso
	local Chance
	local Check
	local watching = setmetatable({}, {__mode = 'k'})
	
	local function Added(ent)
		if watching[ent] then return end
	
		watching[ent] = ent.ChildAdded:Connect(function(v)
			if v:IsA('Accessory') and v:FindFirstChild('Rope') and Random.new(os.clock()):NextNumber(1, 100) < Chance.Value and (not Check.Enabled or entitylib.EntityPosition({
				Range = 50,
				Part = 'RootPart',
				Players = true
			})) then
				ent.PrimaryPart.Anchored = true
				v.Destroying:Once(function()
					task.wait(0.5)
					ent.PrimaryPart.Anchored = false
				end)
			end
		end)
	end
	
	AntiLasso = vape.Categories.Utility:CreateModule({
		Name = 'AntiLasso',
		Function = function(callback)
			if callback then
				AntiLasso:Clean(entitylib.Events.LocalAdded:Connect(function(ent)
					task.delay(1, function()
						Added(ent.Character)
					end)
				end))
				if entitylib.isAlive then
					Added(lplr.Character)
				end
			end
		end,
		Tooltip = 'Prevents you from getting pulled by lasso projectile.'
	})
	Chance = AntiLasso:CreateSlider({
		Name = 'Chance',
		Min = 0,
		Max = 100,
		Default = 100,
		Suffix = '%'
	})
	Check = AntiLasso:CreateToggle({Name = 'Only when targeting'})
end)

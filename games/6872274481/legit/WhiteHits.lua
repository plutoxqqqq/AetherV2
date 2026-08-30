run(function()
	local WhiteHits
	WhiteHits = vape.Categories.Legit:CreateModule({
		Name = "WhiteHits",
		Function = function(callback)
			if callback then
				repeat
					for i, v in entitylib.List do
						local highlight = v.Character and v.Character:FindFirstChild('_DamageHighlight_')
						if highlight then
							highlight:Destroy()
						end
					end
					task.wait(0.1)
				until not WhiteHits.Enabled
			end
		end
	})
end)
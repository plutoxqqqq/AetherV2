run(function()
	local AntiEffect
	local Dizzy
	local Fear
	local Vignettes
	local oldvignettes
	
	AntiEffect = vape.Categories.Utility:CreateModule({
		Name = 'AntiEffect',
		Function = function(callback)
			if callback then
				if Dizzy.Enabled then
					runService:UnbindFromRenderStep('dizzy-status')
				end
	
				if Fear.Enabled then
					runService:UnbindFromRenderStep('werewolf-fear-status')
				end
	
				if Vignettes.Enabled then
					oldvignettes = bedwars.VignetteController.enableOnScreenEffects
					bedwars.VignetteController.enableOnScreenEffects = false
					bedwars.VignetteController:destroyAllVignettes()
				end
	
				local added = bedwars.SyncEvents.StatusEffectAdded:setPriority(1000):connect(function(event)
					if event.entityInstance ~= lplr.Character then return end
	
					if Dizzy.Enabled and event.statusEffect == bedwars.StatusEffectMeta.DIZZY then
						runService:UnbindFromRenderStep('dizzy-status')
					end
	
					if Fear.Enabled and event.statusEffect == bedwars.StatusEffectMeta.WEREWOLF_FEAR then
						runService:UnbindFromRenderStep('werewolf-fear-status')
					end
				end)
				AntiEffect:Clean(function()
					added:Destroy()
				end)
			else
				if oldvignettes ~= nil then
					bedwars.VignetteController.enableOnScreenEffects = oldvignettes
					oldvignettes = nil
				end
			end
		end,
		Tooltip = 'Throws away the parts of a debuff the game plays on your own client'
	})
	Dizzy = AntiEffect:CreateToggle({
		Name = 'Dizzy',
		Default = true,
		Tooltip = 'Stops the dizzy toad swinging your walk direction around, the slow itself is on the server'
	})
	Fear = AntiEffect:CreateToggle({
		Name = 'Werewolf fear',
		Default = true,
		Tooltip = 'Stops the werewolf tail walking you away from it'
	})
	Vignettes = AntiEffect:CreateToggle({
		Name = 'Vignettes',
		Function = function(callback)
			if AntiEffect.Enabled and callback then
				oldvignettes = bedwars.VignetteController.enableOnScreenEffects
				bedwars.VignetteController.enableOnScreenEffects = false
				bedwars.VignetteController:destroyAllVignettes()
			elseif AntiEffect.Enabled and oldvignettes ~= nil then
				bedwars.VignetteController.enableOnScreenEffects = oldvignettes
				oldvignettes = nil
			end
		end,
		Default = true,
		Tooltip = 'Clears the coloured screen border frozen, decay, soaked and the rest put over your view'
	})
end)
run(function()
    local TexturePacks
    local Pack

    TexturePacks = vape.Categories.Legit:CreateModule({
	Name = 'TexturePack',
	Function = function(callback)
		if callback then
			loadstring(game:HttpGet('https://raw.githubusercontent.com/MaxlaserTech/TexturePacks/main/' .. Pack.Value .. '.lua'), Pack.Value)()
		else
			if getgenv().texturepack then
				getgenv().texturepack:Disconnect()
				getgenv().texturepack = nil
			end
		end
	end
    })

    Pack = TexturePacks:CreateDropdown({
	Name = 'Pack',
	List = {'Acidic', 'Devourer', 'Enlightened', 'FatCat', 'Fury', 'Makima', 'Marin-Kitsawaba', 'Moon4Real', 'Nebula', 'Onyx', 'Prime', 'Simply', 'Vile', 'VioletsDreams', 'Wichtiger'},
    })
end)
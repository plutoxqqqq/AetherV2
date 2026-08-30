run(function()
    local FastBreak
    local BedCheck
    local Blacklist
    local Blacklisted
    local Time

    local newlist, old = {}, nil
    local function find(tab, ind)
	for i, v in tab do
		if v == ind or v:find(ind) then
			return i
		end
	end
	return nil
    end

    FastBreak = vape.Categories.Blatant:CreateModule({
	Name = 'FastBreak',
	Function = function(callback)
		if callback then
			old = bedwars.BlockBreaker.hitBlock
			bedwars.BlockBreaker.hitBlock = function(self, ...)
				local _, params = unpack({ ... })
				pcall(function()
					local block, info = nil, self.clientManager:getBlockSelector():getMouseInfo(1, {ray = params})
					block = info and info.target and info.target.blockInstance or nil
					if block and (not Blacklist.Enabled or not find(newlist, block.Name)) and (not BedCheck.Enabled or block.Name ~= 'bed') then
						bedwars.BlockBreakController.blockBreaker:setCooldown(Time.Value)
					end
				end)

				return old(self, ...)
			end

			repeat
				if (tick() - store.lastHit) > 0.3 then
					bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
				end
				task.wait(0.1)
			until not FastBreak.Enabled
		else
			bedwars.BlockBreaker.hitBlock = old
			bedwars.BlockBreakController.blockBreaker:setCooldown(0.3)
		end
	end,
	Tooltip = 'Decreases block hit cooldown'
    })
    Time = FastBreak:CreateSlider({
	Name = 'Break speed',
	Min = 0,
	Max = 0.3,
	Default = 0.25,
	Decimal = 100,
	Suffix = 'seconds',
    })
    BedCheck = FastBreak:CreateToggle({
	Name = 'Bed Check',
	Tooltip = "Doesn't increase speed if you are breaking a bed",
    })
    Blacklist = FastBreak:CreateToggle({
	Name = 'Use blacklist',
	Function = function(callback)
		if Blacklisted and Blacklisted.Object then
			Blacklisted.Object.Visible = callback
		end
	end,
    })
    Blacklisted = FastBreak:CreateTextList({
	Name = 'Blocks',
	Darker = true,
	Visible = false,
	Function = function(list)
		newlist = {}
		for _, v in list do
			if v:find('iron') then
				table.insert(newlist, 'iron_ore_mesh_block')
			else
				table.insert(newlist, v)
			end
		end
	end,
    })
end)
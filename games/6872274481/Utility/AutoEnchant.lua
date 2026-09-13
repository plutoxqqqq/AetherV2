run(function()
	local AutoEnchant
	local Wanted
	local Repair
	local Range
	local Delay

	local Research = bedwars.Handler:Get('ResearchEnchant')
	local Fix = bedwars.Handler:Get('RepairEnchantTable')
	local learned

	AutoEnchant = vape.Categories.Utility:CreateModule({
		Name = 'AutoEnchant',
		Function = function(callback)
			if callback then
				learned = nil

				repeat
					if entitylib.isAlive and entitylib.character and entitylib.character.RootPart and not table.find(Wanted.ListEnabled, learned) then
						local localPosition = entitylib.character.RootPart.Position
						local emeralds = getItem('emerald')
						local diamonds = getItem('diamond')

						for _, v in store.enchant do
							local part = v:IsA('Model') and v.PrimaryPart or v
							if not part or not part.Position then continue end
							if (localPosition - part.Position).Magnitude > Range.Value then continue end

							if v:HasTag('broken-enchant-table') then
								if Repair.Enabled and diamonds and diamonds.amount >= 8 then
									Fix:Fire('CallServer', v)
									break
								end
							elseif emeralds and emeralds.amount >= 2 then
								local enchant = Research:Fire('CallServer', {enchantTable = v})
								learned = typeof(enchant) == 'table' and enchant.enchantType or learned
								if learned then
									local meta = bedwars.EnchantMeta and bedwars.EnchantMeta[learned]
									notif('AutoEnchant', 'Researched '..tostring(meta and (meta.name or meta.displayName) or learned), 3)
								end
								break
							end
						end
					end
					task.wait(Delay.Value)
				until not AutoEnchant.Enabled
			end
		end,
		Tooltip = 'Rerolls the enchant table until you get an enchant you asked for'
	})

	Range = AutoEnchant:CreateSlider({
		Name = 'Range',
		Min = 1,
		Max = 30,
		Default = 12,
		Suffix = function(val)
			return val <= 1 and 'stud' or 'studs'
		end
	})
	Delay = AutoEnchant:CreateSlider({
		Name = 'Delay',
		Min = 0.1,
		Max = 3,
		Default = 0.5,
		Decimal = 10,
		Suffix = 'seconds',
		Tooltip = 'Spacing between rerolls, each one costs 2 emeralds'
	})
	Repair = AutoEnchant:CreateToggle({
		Name = 'Repair tables',
		Default = true,
		Tooltip = 'Fixes a broken enchant table for 8 diamonds before rerolling'
	})
	Wanted = AutoEnchant:CreateTextList({
		Name = 'Enchants',
		Default = {'critical_strike', 'execute', 'soul_reaver'},
		Darker = true,
		Tooltip = 'Stops rerolling once one of these is researched'
	})
end)

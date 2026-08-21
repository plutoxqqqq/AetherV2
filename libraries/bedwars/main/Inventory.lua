local cloneref = cloneref or function(obj)
	return obj
end

local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local Players = cloneref(game:GetService('Players'))
local lplr = Players.LocalPlayer

local invmanage, Cache = {}, {}

invmanage.getInventory = function(plr: Player)
    plr = plr or lplr
	if typeof(plr) ~= 'Instance' then
		return {}
	end

	if not plr:IsA('Player') then
		return {}
	end

	if not ReplicatedStorage.Inventories:FindFirstChild(plr.Name) then
        return {}
    end

	if not Cache[plr.UserId] then
		Cache[plr.UserId] = {}
	end
	table.clear(Cache[plr.UserId])
	
	Cache[plr.UserId].items = {}
    Cache[plr.UserId].armor = {}
    Cache[plr.UserId].hand = nil

	for _, v in ReplicatedStorage.Inventories[plr.Name]:GetChildren() do
		table.insert(Cache[plr.UserId].items, {
			tool = v,
			itemType = v.Name,
			amount = v:GetAttribute('Amount'),
            addedToBackpackTime = v:GetAttribute('AddedToBackpackTime'),
			itemSkin = v:GetAttribute('ItemSkin')
		})
	end

	for i = 0, 2 do
		local armorItem = lplr.Character:FindFirstChild('ArmorInvItem_'..i)

		if armorItem and armorItem.Value then
			table.insert(Cache[plr.UserId].armor, {
				tool = armorItem.Value,
				itemType = armorItem.Value.Name,
				amount = armorItem.Value:GetAttribute('Amount'),
				addedToBackpackTime = armorItem.Value:GetAttribute('AddedToBackpackTime'),
				itemSkin = armorItem.Value:GetAttribute('ItemSkin')
			})
		end
	end

	local Hand = lplr.Character:FindFirstChild('HandInvItem')
	if Hand and Hand.Value then
		Cache[plr.UserId].hand = {
			tool = Hand.Value,
			itemType = Hand.Value.Name,
			amount = Hand:GetAttribute('Amount'),
            addedToBackpackTime = Hand:GetAttribute('AddedToBackpackTime'),
			itemSkin = Hand:GetAttribute('ItemSkin')
		}
	end

	return Cache[plr.UserId]
end

return {
	InventoryUtil = invmanage
}
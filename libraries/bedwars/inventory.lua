local Inventory = {}
function Inventory.new(runtime)
    local api = {}
    function api:get(player)
        player = player or runtime.LocalPlayer
        local util = runtime.InventoryUtil
        if not util or not util.getInventory then return {items = {}, armor = {}} end
        local ok, inventory = pcall(util.getInventory, player)
        return ok and inventory or {items = {}, armor = {}}
    end
    function api:find(itemType, player)
        for _, item in self:get(player).items or {} do
            if item.itemType == itemType then return item end
        end
    end
    return api
end
return Inventory

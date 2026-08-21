local Loader = loadstring(game:HttpGet('https://gitlab.com/stxvv/bedwarsdeps/-/raw/main/main.lua?ref_type=heads'))()
local ItemMeta
do
    ItemMeta = Loader:GetJson('definitions/ItemMeta')
end

function ItemMeta.getItemMeta(item)
    local suc, res = pcall(function()
        return ItemMeta[item]
    end)

    if not suc then
        warn('[ItemMeta]: First method not avaliable, trying legacy method')
        local suc2, res2 = pcall(function()
            return ItemMeta.items[item]
        end)

        if suc2 then
            return res2
        end
    else
        return res
    end
end

return ItemMeta
local Client
do
    Client = loadstring(game:HttpGet('https://gitlab.com/stxvv/bedwarsdeps/-/raw/main/main.lua?ref_type=heads'))():GetMain('Client')
end

local Upgrades = {}

Client:Get('BulkUpdateTeamUpgrades'):Connect(function(upgrade)
    Upgrades = upgrade
end)

Client:Get('TeamUpgradePurchased'):Connect(function(teamId, upgrade)
    Upgrades = upgrade
end)

return {
    currentUpgrades = Upgrades,
    requestPurchaseTeamUpgrade = function(self, data)
        return Client:Get('RequestPurchaseTeamUpgrade'):CallServer(data)
    end
}
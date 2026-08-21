local Loader = loadstring(game:HttpGet('https://gitlab.com/stxvv/bedwarsdeps/-/raw/main/main.lua?ref_type=heads'))()
local Client

do
    Client = Loader:GetMain('Client')
end

return {
    canUseAbility = function(self)
        return true
    end,
    useAbility = function(self, name, ...)
        return Client:Get('useAbility'):SendToServer(name, ...)
    end
}
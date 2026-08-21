local cloneref = cloneref or function(obj)
    return obj
end

local lplr = cloneref(game:GetService('Players')).LocalPlayer

return {
    isAppOpen = function(name: string)
        return lplr.PlayerGui:FindFirstChild(name) and lplr.PlayerGui:FindFirstChild(name).Enabled
    end
}
local FOV = {
    fov = workspace.CurrentCamera.FieldOfView
}

local Loader = loadstring(game:HttpGet('https://gitlab.com/stxvv/bedwarsdeps/-/raw/main/main.lua?ref_type=heads'))()
local Store
do
    Store = Loader:GetMain('Store')
end

function FOV:getFOV()
    return self.fov
end

function FOV:setFOV(fov)
    self.fov = fov
    workspace.CurrentCamera.FieldOfView = fov

    Store:getState().Settings.fov = math.min(130, workspace.CurrentCamera.FieldOfView + 10)
end

return FOV
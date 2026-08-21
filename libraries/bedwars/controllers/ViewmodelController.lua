local ViewmodelController = {
    tracks = {}
}

do
    AnimationUtil = loadstring(game:HttpGet('https://gitlab.com/stxvv/bedwarsdeps/-/raw/main/main.lua?ref_type=heads'))():GetController('AnimationUtil')
end

local cloneref = cloneref or function(obj)
    return obj
end
local Players = cloneref(game:GetService('Players'))
local lplr = Players.LocalPlayer

function ViewmodelController:getViewModel()
    return workspace.CurrentCamera.Viewmodel
end

function ViewmodelController:getAnimator()
    local viewmodel = self:getViewModel()

    if not viewmodel then
        return nil
    end

    local humanoid = viewmodel:FindFirstChildOfClass('Humanoid')

    if not humanoid then
        return nil
    end

    return humanoid:FindFirstChildOfClass('Animator')
end

function ViewmodelController:playAnimation(animationType, config)
    if not self:getAnimator() then return nil end
    config = config or {}

    local animation = Instance.new('Animation')
    animation.AnimationId = AnimationUtil:getAssetId(animationType)

    local track = self:getAnimator():LoadAnimation(animation)
    track.Looped = config.looped or false
    track.Priority = config.priority or Enum.AnimationPriority.Action

    track:Play(config.fadeTime or 0)
    table.insert(self.tracks, track)

    return track
end

function ViewmodelController:stopAnimation(track, fadeTime)
    if track then
        track:Stop(fadeTime or 0)
        track:Destroy()
    end
end

function ViewmodelController:isVisible()
    return lplr.CameraMode == Enum.CameraMode.LockFirstPerson or (workspace.CurrentCamera.CFrame.Position - lplr.Character.Head.Position).Magnitude < 1.5
end

return ViewmodelController
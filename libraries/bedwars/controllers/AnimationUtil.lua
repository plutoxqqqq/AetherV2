local prodAnimations
do
    prodAnimations = loadstring(game:HttpGet('https://gitlab.com/stxvv/bedwarsdeps/-/raw/main/main.lua?ref_type=heads'))():GetMeta('ProdAnimations').ProdAnimations
end

local animUtil = {}
animUtil.__index = animUtil

function animUtil:playAnimation(object, animId, options)
    options = options or {}

    local animator
    if object:IsA('Player') and object.Character then
        local humanoid = object.Character:FindFirstChild('Humanoid')
        if humanoid ~= nil then
            humanoid = humanoid:FindFirstChild('Animator')
        end

        animator = humanoid
    end

    if object:IsA('Animator') then animator = object end

    if object:IsA('Model') then
        local humanoid = object:FindFirstChild('Humanoid')
        if humanoid ~= nil then
            humanoid = humanoid:FindFirstChild('Animator')
        end

        animator = humanoid
        if not animator then
            local animcontroller = object:FindFirstChild('AnimationController')
            if animcontroller ~= nil then
                animcontroller = object:FindFirstChild('Animator')
            end

            animator = animcontroller
        end
    end

    if not animator or not animator:IsDescendantOf(game) then
        return nil
    end

    if type(animId) == 'number' then
        animId = animUtil:getAssetId(animId)
    end

    local animation = Instance.new('Animation')
    animation.AnimationId = animId

    local track = animator:LoadAnimation(animation)
    local priority = track.Priority

    if options.looped ~= nil then
        track.Looped = options.looped
    end

    if options.fadeSamePriorityTracks ~= false then
        for _, v in animator:GetPlayingAnimationTracks() do
            if v ~= track and v.Priority == priority and v:GetAttribute('OriginalWeight') == nil then
                v:SetAttribute('OriginalWeight', v.WeightTarget)
                v:AdjustWeight(0, 0.1)
            end
        end
    end

    track:Play(options.fadeInTime, nil, options.speed)

    local conn
    conn = track.Stopped:Connect(function()
        if conn then
            conn:Disconnect()
        end

        track:Destroy()

        if not animator.Parent then
            return
        end

        if track:GetAttribute('OriginalWeight') ~= nil then
            return
        end

        local tracks = {}
        for _, v in animator:GetPlayingAnimationTracks() do
            if v ~= track and v.Priority == priority then
                table.insert(tracks, v)
            end
        end

        if #tracks == 0 then
            return
        end

        local anim = tracks[#tracks]
        local weight = anim:GetAttribute('OriginalWeight')

        if weight then
            anim:SetAttribute('OriginalWeight', nil)
            anim:AdjustWeight(weight, 0.1)
        end
    end)
end

function animUtil:getAssetId(id)
    return prodAnimations[id]
end

return animUtil
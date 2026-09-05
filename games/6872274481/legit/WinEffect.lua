run(function()
    local WinEffect
    local List
    local NameToId = {}

    local function selectedId()
        return List and NameToId[List.Value] or nil
    end

    local function applyAttribute()
        local id = selectedId()
        if id ~= nil then
            lplr:SetAttribute('WinEffectType', id)
        end
    end

    local function playEffect()
        local id = selectedId()
        if id == nil then return end
        applyAttribute()

        local remote
        pcall(function()
            remote = bedwars.Client:Get('WinEffectTriggered')
        end)
        local instance = remote and remote.instance
        if instance and instance.OnClientEvent then
            local payload = {
                winEffectType = id,
                winningPlayer = lplr
            }
            local fired = false
            pcall(function()
                for _, conn in getconnections(instance.OnClientEvent) do
                    local fn = conn.Function or conn.FunctionValue
                    if type(fn) == 'function' then
                        fired = true
                        pcall(fn, payload)
                    end
                end
            end)
            if not fired then
                pcall(function()
                    firesignal(instance.OnClientEvent, payload)
                end)
            end
        end
    end

    WinEffect = vape.Categories.Legit:CreateModule({
        Name = 'WinEffect',
        Function = function(callback)
            if callback then
                applyAttribute()
                WinEffect:Clean(lplr:GetAttributeChangedSignal('WinEffectType'):Connect(applyAttribute))
                WinEffect:Clean(vapeEvents.MatchEndEvent.Event:Connect(playEffect))
            end
        end,
        Tooltip = 'Allows you to select any clientside win effect'
    })
    local WinEffectName = {}
    for i, v in bedwars.WinEffectMeta do
        table.insert(WinEffectName, v.name)
        NameToId[v.name] = i
    end
    table.sort(WinEffectName)
    List = WinEffect:CreateDropdown({
        Name = 'Effects',
        List = WinEffectName,
        Function = function()
            if WinEffect.Enabled then
                applyAttribute()
            end
        end
    })
end)

local cloneref = cloneref or function(ref: any)
    return ref
end

local removed, problem = true, nil
if type(isfolder) ~= 'function' then
    removed, problem = false, 'This executor cannot inspect folders'
elseif isfolder('aetherv2') then
    if type(delfolder) == 'function' then
        removed, problem = pcall(delfolder, 'aetherv2')
    else
        removed, problem = false, 'This executor cannot remove folders'
    end
end

pcall(function()
    cloneref(game:GetService('StarterGui')):SetCore('SendNotification', {
        Title = 'AetherV2',
        Text = removed and 'Cache cleared. Please rejoin for a clean install.' or 'Could not clear the cache: '..tostring(problem),
        Duration = 20
    })
end)

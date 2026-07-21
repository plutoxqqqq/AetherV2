local cloneref = cloneref or function(ref: any)
    return ref
end

if isfolder('aetherv2') then
    delfolder('aetherv2')
end

cloneref(game:GetService('StarterGui')):SetCore('SendNotification', {
    Title = 'AetherV2',
    Text = 'Successfully reinstalled AetherV2, Please rejoin the game to take effect',
    Duration = 20
})
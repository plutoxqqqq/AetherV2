run(function()
    local FPSUnlocker, Cap
    FPSUnlocker = vape.Categories.Utility:CreateModule({
        Name = 'FPSUnlocker',
        Function = function(enabled)
            if typeof(setfpscap) ~= 'function' then
                if enabled then
                    notif('FPSUnlocker', 'Your executor does not support setfpscap.', 5, 'warning')
                    task.defer(function() if FPSUnlocker.Enabled then FPSUnlocker:Toggle() end end)
                end
                return
            end
            local ok = pcall(setfpscap, enabled and Cap.Value or 60)
            if not ok and enabled then
                notif('FPSUnlocker', 'The executor rejected setfpscap.', 5, 'warning')
                task.defer(function() if FPSUnlocker.Enabled then FPSUnlocker:Toggle() end end)
            end
        end,
        Tooltip = 'Changes the frame-rate cap when the executor supports setfpscap.'
    })
    Cap = FPSUnlocker:CreateSlider({
        Name = 'FPS cap',
        Min = 60,
        Max = 1000,
        Default = 240,
        Function = function(value)
            if FPSUnlocker.Enabled and typeof(setfpscap) == 'function' then pcall(setfpscap, value) end
        end
    })
end)


--[[AETHER_UNIVERSAL_UNORDERED_MODULES]]
-- blatant/DeathSpawn.lua

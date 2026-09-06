run(function()
    local BackTrack
    local Mode
    local Latency
    local Tick

    BackTrack = vape.Categories.Utility:CreateModule({
        Name = 'BackTrack',
        Function = function(callback)
            if callback then
                repeat
                    local ent = entitylib.EntityPosition({
                        Part = 'RootPart',
                        Range = 22,
                        Players = true,
                        Wallcheck = true,
                    })

                    if ent then
                        if Mode.Value == 'Manual' then
                            setfflag('TargetTimeDelayFacctorTenths', '50000')
                            task.wait(0.05 * Tick.Value)
                            setfflag('TargetTimeDelayFacctorTenths', '20')
                            task.wait(0.05 * Tick.Value)
                        else
                            setfflag('TargetTimeDelayFacctorTenths', tostring(math.floor(20 + (Latency:GetRandomValue() / 20))))
                            task.wait(1)
                        end
                    else
                        setfflag('TargetTimeDelayFacctorTenths', '20')
                    end
                    task.wait()
                until not BackTrack.Enabled
            end
        end,
        Tooltip = 'Lags targets at certain times to increase attack distance'
    })
    getgenv().Backtrack = BackTrack
    Latency = BackTrack:CreateTwoSlider({
        Name = 'Latency',
        Min = 1,
        Max = 500,
        DefaultMin = 50,
        DefaultMax = 120,
        Darker = true,
    })
    Tick = BackTrack:CreateSlider({
        Name = 'Ticks',
        Min = 1,
        Max = 20,
        Default = 5,
        Darker = true,
        Visible = false,
    })
    Mode = BackTrack:CreateDropdown({
        Name = 'Mode',
        List = { 'Manual', 'Lag Based' },
        Default = 'Manual',
        Function = function(val)
            if Latency and Tick then
                Latency.Object.Visible = val == 'Manual'
                Tick.Object.Visible = val == 'Lag Based'
            end
        end,
    })
end)

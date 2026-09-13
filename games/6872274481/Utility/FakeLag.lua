run(function()
    local FakeLag
    local TransmissionOffset
    local Mode
    local Delay

    local rng
    local num = 0

    FakeLag = vape.Categories.Utility:CreateModule({
        Name = 'FakeLag',
        Function = function(callback)
            if callback then
                rng = Random.new()

                local clock, restore, after = os.clock(), os.clock(), 0
                repeat
                    local ms = Delay.Value / 1000

                    if Mode.Value == 'Dynamic' then
                        if (os.clock() - clock) >= ms or restore > os.clock() then
                            if clock ~= 9e9 then
                                restore = os.clock() + (TransmissionOffset.Value / 1000)
                                clock = 9e9
                            end
                            setfflag('PhysicsSenderMaxBandwidthBps', '38760')
                        else
                            if clock == 9e9 then
                                clock = os.clock()
                                restore = 0
                            end
                            setfflag('PhysicsSenderMaxBandwidthBps', '0')
                        end
                    elseif Mode.Value == 'Repel' then
                        if store.update > tick() then
                            setfflag('PhysicsSenderMaxBandwidthBps', '0')
                            setfflag('S2PhysicsSenderRate', '0')
                            setfflag('DataSenderRate', '-1')
                            task.wait(rng:NextNumber(70, 150) / 1000)
                            setfflag('PhysicsSenderMaxBandwidthBps', '38760')
                            setfflag('DataSenderRate', '60')
                            setfflag('S2PhysicsSenderRate', '15')
                            after = os.clock() + rng:NextNumber(0.001, (Delay.Value / 1000))
                            store.update = 0
                            num = rng:NextNumber()
                        end
                        if os.clock() > after then
                            num = rng:NextNumber()
                            after = os.clock() + rng:NextNumber(0.001, (Delay.Value / 1000))
                        end
                    elseif Mode.Value == 'Latency' then
                        setfflag('PhysicsSenderMaxBandwidthBps', '0')
                        task.wait(Delay.Value / 1500)
                        setfflag('PhysicsSenderMaxBandwidthBps', '38760')
                        task.wait(ms)
                    end
                    runService.PreRender:Wait()
                until not FakeLag.Enabled
            else
                setfflag('DataSenderRate', '60')
                setfflag('PhysicsSenderMaxBandwidthBps', '38760')
            end
        end,
        Tooltip = 'Delays packets, simulating lag',
        ExtraText = function()
            return Mode and Mode.Value or 'Dynamic'
        end
    })
    getgenv().FakeLag = FakeLag

    TransmissionOffset = FakeLag:CreateSlider({
        Name = 'Transmission Offset',
        Min = 1,
        Max = 10,
        Default = 3,
        Decimal = 5,
        Darker = true,
    })
    Mode = FakeLag:CreateDropdown({
        Name = 'Mode',
        List = { 'Dynamic', 'Repel', 'Latency' },
        Default = 'Dynamic',
        Function = function(val)
            TransmissionOffset.Object.Visible = val == 'Dynamic'
            setfflag('PhysicsSenderMaxBandwidthBps', '38760')
        end,
    })
    Delay = FakeLag:CreateSlider({
        Name = 'Delay',
        Suffix = function()
            return 'ms'
        end,
        Min = 1,
        Max = 500,
        Default = 100,
    })
end)

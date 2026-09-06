run(function()
    local connection

    vape.Categories.World:CreateModule({
        Name = 'Anti-AFK',
        Function = function(callback)
            if callback then
                connection = lplr.Idled:Connect(function()
                    local VirtualUser = game:GetService('VirtualUser')

                    VirtualUser:CaptureController()
                    VirtualUser:ClickButton2(Vector2.new())
                end)
            elseif connection then
                connection:Disconnect()
                connection = nil
            end
        end,
        Tooltip = 'Lets you stay ingame without getting kicked'
    })
end)

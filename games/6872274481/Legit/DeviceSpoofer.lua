run(function()
    local DeviceSpoofer
    local Device
    local realInputType, realGetUserInputType

    local function report(value)
        pcall(function()
            bedwars.Handler:Get('SendUserInputType'):Fire('SendToServer', {userInputType = value})
        end)
    end

    DeviceSpoofer = vape.Categories.Legit:CreateModule({
        Name = 'DeviceSpoofer',
        Function = function(callback)
            local controller = bedwars.UserInputController
            if callback then
                if not controller or typeof(controller.getUserInputType) ~= 'function' then
                    notif('DeviceSpoofer', 'The input controller is unavailable.', 5, 'warning')
                    DeviceSpoofer:Toggle()
                    return
                end
                
                
                realInputType = controller:getUserInputType()
                realGetUserInputType = controller.getUserInputType
                controller.getUserInputType = function()
                    return Device.Value:upper()
                end
                report(Device.Value:upper())
            else
                if controller and realGetUserInputType then
                    controller.getUserInputType = realGetUserInputType
                end
                if realInputType then
                    report(realInputType)
                end
                realGetUserInputType, realInputType = nil, nil
            end
        end,
        Tooltip = 'Spoofs the device you show up as to the server'
    })

    Device = DeviceSpoofer:CreateDropdown({
        Name = 'Device',
        List = {'Mobile', 'PC', 'Gamepad'},
        Function = function(val)
            if DeviceSpoofer.Enabled then
                report(val:upper())
            end
        end
    })
end)

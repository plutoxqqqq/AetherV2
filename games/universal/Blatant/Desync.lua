run(function()
    local Desync
    local hook

    local function resync()
        if entitylib.isAlive then
            entitylib.character.RootPart.CFrame += Vector3.new(math.nan, math.nan, math.nan)
            notif('Desync', 'Resynced', 2, 'info')
        end
    end

    Desync = vape.Categories.Blatant:CreateModule({
        Name = 'Desync',
        Function = function(callback)
            if callback then
                if not rakNetCheck('Desync') then
                    Desync:Toggle()
                    return
                end

                hook = function(packet)
                    -- Runs on every outgoing packet on the network thread: a single error
                    -- here (short buffer, missing array) crashes/disconnects the client, so
                    -- everything is guarded with pcall and an explicit length check.
                    pcall(function()
                        if packet.AsArray and packet.AsArray[1] == 0x1b then
                            local data = packet.AsBuffer
                            if data and buffer.len(data) >= 5 then
                                buffer.writeu32(data, 1, 0xFFFFFFFF)
                                packet:SetData(data)
                            end
                        end
                    end)
                end

                resync()
                raknet.add_send_hook(hook)
            elseif hook then
                raknet.remove_send_hook(hook)
                hook = nil
            end
        end,
        Tooltip = 'Prevent the server from replicating your current position to other players'
    })

    Desync:CreateButton({
        Name = 'Resync',
        Function = resync
    })
end)

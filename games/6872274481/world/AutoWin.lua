run(function()
    local Runtime = assert(AetherMatchRuntime, 'Aether runtime missing')
    local MatchDirector = assert(Runtime.MatchDirector, 'AutoWin director missing')
-- AutoWin HUD V2
--------------------------------------------------------------------------------
local function makeHUD(module,debugOption)
    local frame=module.Children
    if not frame then return nil end
    frame.Size=UDim2.fromOffset(286,154);if frame.Position==UDim2.new() then frame.Position=UDim2.fromOffset(16,220) end
    for _,child in ipairs(frame:GetChildren()) do if child.Name=='AetherAutoWinV7' then child:Destroy() end end
    local bg=Instance.new('Frame');bg.Name='AetherAutoWinV7';bg.Size=UDim2.fromScale(1,1);bg.BackgroundColor3=Color3.new();bg.BackgroundTransparency=0.3;bg.BorderSizePixel=0;bg.Parent=frame
    local corner=Instance.new('UICorner');corner.CornerRadius=UDim.new(0,6);corner.Parent=bg
    local labels={};local names={'Objective','Action','Target','Route','Blocks','Health','Risk','Movement','Recovery'}
    for index,name in ipairs(names) do
        local label=Instance.new('TextLabel');label.Name=name;label.Size=UDim2.new(1,-12,0,14);label.Position=UDim2.fromOffset(7,5+(index-1)*15);label.BackgroundTransparency=1;label.Font=index<=2 and Enum.Font.GothamBold or Enum.Font.Gotham;label.TextSize=11;label.TextXAlignment=Enum.TextXAlignment.Left;label.TextColor3=Color3.new(1,1,1);label.Text=name..': -';label.Parent=bg;labels[name]=label
    end
    local debugLabel=Instance.new('TextLabel');debugLabel.Size=UDim2.new(1,-12,0,28);debugLabel.Position=UDim2.fromOffset(7,138);debugLabel.BackgroundTransparency=1;debugLabel.Font=Enum.Font.Code;debugLabel.TextSize=9;debugLabel.TextXAlignment=Enum.TextXAlignment.Left;debugLabel.TextYAlignment=Enum.TextYAlignment.Top;debugLabel.TextColor3=Color3.fromRGB(180,180,180);debugLabel.Visible=false;debugLabel.Parent=bg
    local hud={Frame=frame,Labels=labels,Debug=debugLabel,Data={}}
    function hud:Set(data)
        self.Data=data
        for _,name in ipairs(names) do if labels[name] then labels[name].Text=name..': '..tostring(data[name] or '-') end end
        local dbg=debugOption and debugOption.Enabled
        debugLabel.Visible=dbg and true or false
        if dbg then debugLabel.Text=string.format('world %s | replans %s | leases %s\nlast: %s',data.World or '-',data.Replans or 0,data.Leases or 0,data.Failure or '-') end
        frame.Size=UDim2.fromOffset(286,dbg and 174 or 144)
    end
    return hud
end

--------------------------------------------------------------------------------
-- AutoWin module V7
--------------------------------------------------------------------------------
local AutoWin
local AutoOptions={}
AutoWin=vape.Categories.World:CreateModule({Name='AutoWin',Tooltip='Reactive match director: plans objectives, loadout, routes, combat and session lifecycle',Size=UDim2.fromOffset(286,144),Function=function(callback)
    if callback then
        local hud=makeHUD(AutoWin,AutoOptions.Debug);Runtime.AutoWinDirector=MatchDirector.new(AutoWin,AutoOptions,hud);Runtime.AutoWinDirector:Start();AutoWin:Clean(function() if Runtime.AutoWinDirector then Runtime.AutoWinDirector:Cancel('module-disabled');Runtime.AutoWinDirector=nil end end)
    elseif Runtime.AutoWinDirector then Runtime.AutoWinDirector:Cancel('module-disabled');Runtime.AutoWinDirector=nil end
end})
Runtime.AutoWin=AutoWin
AutoOptions.Aggression=AutoWin:CreateDropdown({Name='Aggression',List={'Safe','Balanced','Blatant'},Tooltip='Risk tolerance used by objective scoring and recovery'});pcall(function()AutoOptions.Aggression:SetValue('Balanced')end)
AutoOptions.TakeOver=AutoWin:CreateToggle({Name='Take over modules',Default=true,Tooltip='Temporarily leases existing Aether helpers and safely restores untouched settings'})
AutoOptions.KillPlayers=AutoWin:CreateToggle({Name='Kill players',Default=true})
AutoOptions.RespawnAfterBed=AutoWin:CreateToggle({Name='Respawn after bed',Default=true,Tooltip='Compatibility setting; semantic recovery decides when a safe reset is appropriate'})
AutoOptions.BankLoot=AutoWin:CreateToggle({Name='Bank loot',Default=true})
AutoOptions.YuziDash=AutoWin:CreateToggle({Name='Yuzi dash',Default=true,Tooltip='Allows traversal adapters to consider Yuzi movement when available'})
AutoOptions.AutoEquipKit=AutoWin:CreateToggle({Name='Auto equip Yuzi',Default=true,Darker=true})
AutoOptions.DaoPriority=AutoWin:CreateToggle({Name='Dao priority',Default=true,Darker=true})
AutoOptions.IronAmount=AutoWin:CreateSlider({Name='Iron amount',Min=8,Max=64,Default=16,Suffix=' iron'})
AutoOptions.WoolAmount=AutoWin:CreateSlider({Name='Block amount',Min=16,Max=128,Default=32,Suffix=' blocks'})
AutoOptions.BedReach=AutoWin:CreateSlider({Name='Bed reach',Min=3,Max=14,Default=8,Decimal=10,Suffix=' studs'})
AutoOptions.PlayerReach=AutoWin:CreateSlider({Name='Player reach',Min=3,Max=14,Default=8,Decimal=10,Suffix=' studs'})
AutoOptions.StartDelay=AutoWin:CreateSlider({Name='Start delay',Min=0,Max=10,Default=2,Decimal=10,Suffix=' seconds'})
AutoOptions.StuckLimit=AutoWin:CreateSlider({Name='Watchdog',Min=0,Max=10,Default=4,Decimal=10,Suffix=' minutes'})
AutoOptions.Requeue=AutoWin:CreateToggle({Name='Auto queue',Default=true})
local queueList={'Current','Random'};for id,meta in pairs(bedwars.QueueMeta or {}) do if not meta.disabled and not meta.voiceChatOnly then table.insert(queueList,id) end end;table.sort(queueList,function(a,b)if a=='Current'then return true elseif b=='Current'then return false elseif a=='Random'then return true elseif b=='Random'then return false else return tostring(a)<tostring(b) end end)
AutoOptions.Gamemode=AutoWin:CreateDropdown({Name='Gamemode',List=queueList,Darker=true})
AutoOptions.ResumeInLobby=AutoWin:CreateToggle({Name='Resume in lobby',Default=true,Darker=true})
AutoOptions.AutoRejoin=AutoWin:CreateToggle({Name='Auto rejoin',Default=true})
AutoOptions.KeepAwake=AutoWin:CreateToggle({Name='Keep awake',Default=true})
AutoOptions.ShowHUD=AutoWin:CreateToggle({Name='Show HUD',Default=true,Function=function(value)if AutoWin.Children then AutoWin.Children.Visible=value and AutoWin.Enabled end end})
AutoOptions.Notify=AutoWin:CreateToggle({Name='Notifications'})
AutoOptions.Debug=AutoWin:CreateToggle({Name='Debug',Tooltip='Shows objective/action diagnostics without notification spam'})

--------------------------------------------------------------------------------

end)

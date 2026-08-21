
local cloneref = cloneref or function(obj)
    return obj
end

local Players = cloneref(game:GetService('Players'))
local lplr = Players.LocalPlayer

local Client
do
    Client = loadstring(game:HttpGet('https://gitlab.com/stxvv/bedwarsdeps/-/raw/main/main.lua?ref_type=heads'))():GetMain('Client')
end

if not lplr:WaitForChild('PlayerGui'):WaitForChild('TopBarAppGui'):WaitForChild('TopBarApp'):FindFirstChild('2'):FindFirstChild('5') then
    return {
        matchState = 0,
        getMatchState = function(self)
            return self.matchState
        end
    }
end

local matchController, timer = {
    Name = 'MatchController',
    matchState = 0
}, lplr:WaitForChild('PlayerGui'):WaitForChild('TopBarAppGui'):WaitForChild('TopBarApp'):FindFirstChild('2'):FindFirstChild('5')

local timersecs, lasttimersecs = 0, 0

task.spawn(function()
	repeat task.wait()
		timersecs = tonumber(timer.Text:split(':')[2])
	until matchController.matchState == 2
end)

task.spawn(function()
	repeat
        lasttimersecs = timersecs
        task.wait()
    until timersecs > lasttimersecs

	matchController.matchState = 1;
end)

do
    Client:Get('MatchEndEvent'):Connect(function(table)
        matchController.matchState = 2
    end)
end

function matchController:getMatchState()
    return self.matchState
end

return matchController
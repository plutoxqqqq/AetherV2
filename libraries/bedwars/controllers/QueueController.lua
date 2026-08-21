local Client
do
    Client = loadstring(game:HttpGet('https://gitlab.com/stxvv/bedwarsdeps/-/raw/main/main.lua?ref_type=heads'))():GetMain('Client')
end

return {
    joinQueue = function(self, queue)
        Client:Get('joinQueue'):SendToServer({
            ['queueType'] = queue
        })
    end
}
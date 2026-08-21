repeat task.wait() until game:IsLoaded()

local cloneref = cloneref or function(obj)
    return obj
end

local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local Players = cloneref(game:GetService('Players'))
local lplr = Players.LocalPlayer

local Loader = loadstring(game:HttpGet('https://gitlab.com/stxvv/bedwarsdeps/-/raw/main/main.lua?ref_type=heads'))()
local Ratelimits

do
    Ratelimits = Loader:GetMeta('Ratelimits').remotes
end

local Client, Cache = {}, {
    Ratelimits = {},
    Remotes = {}
}

local function canFire(name)
    if tick() < Cache.Ratelimits[name] then
        return false
    end

    Cache.Ratelimits[name] = tick() + Ratelimits[name].rate
    return true
end

task.spawn(function()
    for _, v in ReplicatedStorage:GetDescendants() do
        if not Ratelimits[v.Name] then
            Ratelimits[v.Name] = {
                rate = 0.2
            }
        end
            
        Cache.Ratelimits[v.Name] = 0
        if v:IsA('RemoteEvent') then
            table.insert(Cache.Remotes, {
                inst = v,
                instance = v,
                SendToServer = function(self, ...)
                    if canFire(v.Name) then
                        v:FireServer(...)
                    end
                end,
                Connect = function(self, func)
                    return v.OnClientEvent:Connect(func)
                end
            })
        elseif v:IsA('RemoteFunction') then
            table.insert(Cache.Remotes, {
                inst = v,
                instance = v,
                CallServerAsync = function(self, ...)
                    if not canFire(v.Name) then
                        return {
                            andThen = function(self, func)
                                func(nil)
                                return self
                            end,
                            awaitStatus = function(self)
                                return nil
                            end,
                            returned = nil
                        }
                    end

                    local val = v:InvokeServer(...)
                    return {
                        andThen = function(self, func)
                            func(val)
                        end,
                        awaitStatus = function(self)
                            return val
                        end,
                        returned = val
                    }
                end,
                CallServer = function(self, ...)
                    if canFire(v.Name) then
                        return v:InvokeServer(...)
                    end
                end,
                Connect = function(self, func)
                    v.OnClientInvoke = func
                end
            })
        else
            Ratelimits[v.Name] = nil
            Cache.Ratelimits[v.Name] = nil
        end
    end
end)

function Client:Get(name)
    for _, v in Cache.Remotes do
        if v.inst.Name == name then
            return v
        end
    end

    return nil
end
Client.WaitFor = Client.Get

function Client:GetNamespace(name)
    return {
        Get = function(self, nme)
            for _, v in Cache.Remotes do
                if v.inst.Name == name..'/'..nme then
                    return v
                end
            end

            return nil
        end,
        WaitFor = function(self, name) return self:Get(name) end,
        OnEvent = function(self, name, func)
            local val = self:Get(name).inst.OnClientEvent:Connect(func)

            return {
                andThen = function(self, func)
                    func(val)
                end,
                Disconnect = function(self)
                    val:Disconnect()
                end
            }
        end
    }
end

function Client:OnEvent(name, func)
    local val = Client:Get(name).inst.OnClientEvent:Connect(func)

    return {
        andThen = function(self, func)
            func(val)
        end,
        Disconnect = function(self)
            val:Disconnect()
        end
    }
end

return Client
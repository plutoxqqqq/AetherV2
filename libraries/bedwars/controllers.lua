local Controllers = {}
function Controllers.new(runtime)
    local api = {}
    function api:get(name)
        local Knit = runtime.Knit
        return Knit and Knit.Controllers and Knit.Controllers[name] or nil
    end
    function api:has(name) return self:get(name) ~= nil end
    function api:all()
        local Knit = runtime.Knit
        return Knit and Knit.Controllers or {}
    end
    return api
end
return Controllers

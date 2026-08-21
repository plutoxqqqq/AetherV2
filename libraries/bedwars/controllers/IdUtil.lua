-- https://lua.expert/
local t = {
	generateId = function(p1, p2) --[[ Line: 5 ]]
		local v1 = ""
		local v2 = if p2 == nil then "ABCDEFGHIJKLMNPQRSTUVWXYZ123456789" else p2
		local v3, count, v4, v5 = false, 0, #v2, v2

		while true do
			if v3 then
				count = count + 1
			else
				v3 = true
			end

			if not (count < p1) then
				break
			end

			local v7 = math.floor(math.random() * v4)

			v1 = v1 .. string.sub(v5, v7 + 1, v7 + 1)
		end

		return v1
	end
}
local v1 = setmetatable({}, {
	__tostring = function() --[[ __tostring | Line: 35 ]]
		return "IncrementingId"
	end
})

v1.__index = v1
function v1.new(...) --[[ new | Line: 40 | Upvalues: v1 (ref) ]]
	local v2 = setmetatable({}, v1)

	return v2:constructor(...) or v2
end
function v1.constructor(p1, p2, p3, p4) --[[ constructor | Line: 44 ]]
	p1.startingNumber = p2
	p1.maxNumber = p3
	p1.rollOver = p4
	p1.id = p2
end
function v1.getCurrId(p1) --[[ getCurrId | Line: 50 ]]
	return p1.id
end
function v1.getNextId(p1) --[[ getNextId | Line: 53 ]]
	if not (p1.id + 1 > p1.maxNumber) then
		p1.id = p1.id + 1

		return p1.id
	end

	if p1.rollOver then
		return p1.startingNumber
	end

	return p1.id
end
t.IncrementingId = v1

return {
	IdUtil = t
}
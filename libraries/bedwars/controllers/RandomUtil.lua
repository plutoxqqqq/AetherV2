-- https://lua.expert/
local t = {
	fromList = function(...) --[[ fromList | Line: 12 ]]
		local t = { ... }

		return t[math.floor(math.random() * #t) + 1]
	end
}

local function randomArraySelectN(p1, p2, p3) --[[ randomArraySelectN | Line: 22 ]]
	if p2 < 1 then
		return {}
	end

	local v1 = table.create(#p1)
	local t = {}

	for v2, v3 in p1 do
		v1[v2] = v3
	end

	local v4 = false
	local count = 0

	while true do
		local v5, v6

		if v4 then
			count = count + 1
		else
			v4 = true
		end

		if not (count < math.min(p2, #p1)) then
			break
		end

		local v7 = math
		local v8 = math

		v5 = if p3 == nil then p3 else p3:NextNumber()
		v6 = if v5 == nil then math.random() else v5

		local v13 = table.remove(v1, v7.clamp(v8.floor(v6 * #v1), 0, #v1 - 1) + 1)

		if v13 ~= nil then
			table.insert(t, v13)
		end
	end

	return t
end

t.randomArraySelectN = randomArraySelectN
function t.shuffleArray(p1, p2) --[[ shuffleArray | Line: 77 | Upvalues: randomArraySelectN (copy) ]]
	return randomArraySelectN(p1, #p1, p2)
end

return {
	RandomUtil = t
}
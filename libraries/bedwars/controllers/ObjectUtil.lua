-- https://lua.expert/
local HttpService = game:GetService("HttpService")
local t = {
	keys = function(p1) --[[ keys | Line: 5 ]]
		local v1 = table.create(#p1)

		for k in pairs(p1) do
			v1[#v1 + 1] = k
		end

		return v1
	end,
	values = function(p1) --[[ values | Line: 13 ]]
		local v1 = table.create(#p1)

		for k, v in pairs(p1) do
			v1[#v1 + 1] = v
		end

		return v1
	end,
	entries = function(p1) --[[ entries | Line: 21 ]]
		local v1 = table.create(#p1)

		for k, v in pairs(p1) do
			v1[#v1 + 1] = { k, v }
		end

		return v1
	end,
	assign = function(p1, ...) --[[ assign | Line: 29 ]]
		for i = 1, select("#", ...) do
			local v1 = select(i, ...)

			if type(v1) == "table" then
				for k, v in pairs(v1) do
					p1[k] = v
				end
			end
		end

		return p1
	end,
	copy = function(p1) --[[ copy | Line: 41 ]]
		local v1 = table.create(#p1)

		for k, v in pairs(p1) do
			v1[k] = v
		end

		return v1
	end
}

local function v1(p1, p2) --[[ deepCopyHelper | Line: 49 | Upvalues: v1 (copy) ]]
	local v12 = table.create(#p1)

	p2[p1] = v12

	for k, v in pairs(p1) do
		if type(k) == "table" then
			k = p2[k] or v1(k, p2)
		end

		if type(v) == "table" then
			v = p2[v] or v1(v, p2)
		end

		v12[k] = v
	end

	if type(p1) == "table" then
		local v4 = getmetatable(p1)

		if v4 then
			setmetatable(v12, v4)
		end
	end

	return v12
end

function t.deepCopy(p1) --[[ deepCopy | Line: 75 | Upvalues: v1 (copy) ]]
	return v1(p1, {})
end
function t.deepEquals(p1, p2) --[[ deepEquals | Line: 79 | Upvalues: t (copy) ]]
	for k in pairs(p1) do
		local v1 = p1[k]
		local v2 = p2[k]

		if type(v1) == "table" and type(v2) == "table" then
			if not t.deepEquals(v1, v2) then
				return false
			end

			continue
		end

		if v1 ~= v2 then
			return false
		end
	end

	for k in pairs(p2) do
		if p1[k] == nil then
			return false
		end
	end

	return true
end
function t.toString(p1) --[[ toString | Line: 104 | Upvalues: HttpService (copy) ]]
	return HttpService:JSONEncode(p1)
end
function t.isEmpty(p1) --[[ isEmpty | Line: 108 ]]
	return next(p1) == nil
end
function t.fromEntries(p1) --[[ fromEntries | Line: 112 ]]
	local v1 = #p1
	local v2 = table.create(v1)

	if p1 then
		for i = 1, v1 do
			local v3 = p1[i]

			v2[v3[1]] = v3[2]
		end
	end

	return v2
end

return t
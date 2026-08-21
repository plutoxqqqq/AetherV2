-- https://lua.expert/
local v1 = setmetatable({}, {
	__tostring = function() --[[ __tostring | Line: 6 ]]
		return "GameQueryUtil"
	end
})

v1.__index = v1
function v1.new(...) --[[ new | Line: 11 | Upvalues: v1 (ref) ]]
	local v2 = setmetatable({}, v1)

	return v2:constructor(...) or v2
end
function v1.constructor(p1) --[[ constructor | Line: 15 ]] end
function v1.isQueryIgnored(p1, p2) --[[ isQueryIgnored | Line: 17 ]]
	if not p2:IsA("BasePart") then
		return false
	end

	return p2:GetAttribute("gamecore_GameQueryIgnore") == true
end
function v1.setQueryIgnored(p1, p2, p3) --[[ setQueryIgnored | Line: 23 ]]
	if p3 == nil then
		p3 = true
	end

	if not p2:IsA("BasePart") then
		return nil
	end

	p2:SetAttribute("gamecore_GameQueryIgnore", if p3 then true else nil)

	if not p1.ADJUST_CAN_QUERY then
		return
	end

	p2.CanQuery = not p3
end
function v1.raycast(p1, p2, p3, p4, p5) --[[ raycast | Line: 35 ]]
	debug.profilebegin("gq-cast")

	if not p4 then
		p4 = RaycastParams.new()
	end

	local v2 = nil
	local v3

	repeat
		if v2 then
			local t = {}

			table.move(v2, 1, #v2, #t + 1, t)
			p4.FilterDescendantsInstances = t
		end

		local v4 = if p5 == nil then p5 else p5.world

		v3 = (if v4 == nil then game.Workspace else v4):Raycast(p2, p3, p4)

		if v3 then
			if not p1:isQueryIgnored(v3.Instance) then
				local v6 = if p5 == nil then p5 else p5.ignorePart

				if not v6 or not p5.ignorePart(v3.Instance) then
					break
				end
			end

			local t = { Enum.RaycastFilterType.Blacklist, Enum.RaycastFilterType.Exclude }

			if table.find(t, p4.FilterType) == nil then
				local v8 = -1

				for v10, v11 in p4.FilterDescendantsInstances do
					local v9
					local v12 = v3

					if v12 ~= nil then
						v12 = v12.Instance:IsDescendantOf(v11)
					end

					if v12 then
						v9 = v12
					else
						local v14 = v3

						if v14 ~= nil then
							v14 = v14.Instance
						end

						v9 = if v14 == v11 then true else false
					end

					if v9 == true then
						v8 = v10 - 1

						break
					end
				end

				if not v2 then
					local t2 = {}
					local FilterDescendantsInstances = p4.FilterDescendantsInstances

					table.move(FilterDescendantsInstances, 1, #FilterDescendantsInstances, #t2 + 1, t2)
					v2 = t2
				end

				table.remove(v2, v8 + 1)
			else
				p4:AddToFilter(v3.Instance)
			end
		end
	until v3 == nil

	debug.profileend()

	return v3
end
v1.ADJUST_CAN_QUERY = false

return {
	GameQueryUtil = v1
}
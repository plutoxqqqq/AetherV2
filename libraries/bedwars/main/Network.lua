-- https://lua.expert/
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local v1 = nil
local v2 = nil
local v3 = nil
local v4 = nil
local v5 = nil
local v6 = nil
local v7 = nil
local v8 = nil
local v9 = nil
local _ = {
	CFrame.Angles(0, 0, 0),
	CFrame.Angles(1.5707963267948966, 0, 0),
	CFrame.Angles(0, math.pi, math.pi),
	CFrame.Angles(-1.5707963267948966, 0, 0),
	CFrame.Angles(0, math.pi, 1.5707963267948966),
	CFrame.Angles(0, 1.5707963267948966, 1.5707963267948966),
	CFrame.Angles(0, 0, 1.5707963267948966),
	CFrame.Angles(0, -1.5707963267948966, 1.5707963267948966),
	CFrame.Angles(-1.5707963267948966, -1.5707963267948966, 0),
	CFrame.Angles(0, -1.5707963267948966, 0),
	CFrame.Angles(1.5707963267948966, -1.5707963267948966, 0),
	CFrame.Angles(0, 1.5707963267948966, math.pi),
	CFrame.Angles(0, -1.5707963267948966, math.pi),
	CFrame.Angles(0, math.pi, 0),
	CFrame.Angles(-1.5707963267948966, -3.141592653589793, 0),
	CFrame.Angles(0, 0, math.pi),
	CFrame.Angles(1.5707963267948966, math.pi, 0),
	CFrame.Angles(0, 0, -1.5707963267948966),
	CFrame.Angles(0, -1.5707963267948966, -1.5707963267948966),
	CFrame.Angles(0, -3.141592653589793, -1.5707963267948966),
	CFrame.Angles(0, 1.5707963267948966, -1.5707963267948966),
	CFrame.Angles(1.5707963267948966, 1.5707963267948966, 0),
	CFrame.Angles(0, 1.5707963267948966, 0),
	CFrame.Angles(-1.5707963267948966, 1.5707963267948966, 0)
}

local function alloc(p1) --[[ alloc | Line: 49 | Upvalues: v2 (ref), v3 (ref), v1 (ref), v5 (ref) ]]
	if v3 < v2 + p1 then
		while v3 < v2 + p1 do
			v3 = v3 * 2
		end

		local v12 = buffer.create(v3)

		buffer.copy(v12, 0, v1, 0, v2)
		v1 = v12
	end

	v5 = v2
	v2 = v2 + p1

	return v5
end

local function read(p1) --[[ read | Line: 67 | Upvalues: v7 (ref) ]]
	local v1 = v7

	v7 = v7 + p1

	return v1
end

local function save() --[[ save | Line: 74 | Upvalues: v1 (ref), v2 (ref), v3 (ref), v4 (ref) ]]
	return {
		buff = v1,
		used = v2,
		size = v3,
		inst = v4
	}
end

local function load(p1) --[[ load | Line: 83 | Upvalues: v1 (ref), v2 (ref), v3 (ref), v4 (ref) ]]
	v1 = p1.buff
	v2 = p1.used
	v3 = p1.size
	v4 = p1.inst
end

local function load_empty() --[[ load_empty | Line: 95 | Upvalues: v1 (ref), v2 (ref), v3 (ref), v4 (ref) ]]
	v1 = buffer.create(64)
	v2 = 0
	v3 = 64
	v4 = {}
end

v1 = buffer.create(64)
v2 = 0
v3 = 64
v4 = {}

local t = {}

if not RunService:IsRunning() then
	local function f10() --[[ Line: 108 ]] end

	return table.freeze({
		SendEvents = f10,
		EntityDamageEventZap = table.freeze({
			On = f10
		}),
		PickupItemEventZap = table.freeze({
			On = f10
		}),
		ProjectileLaunchZap = table.freeze({
			On = f10
		}),
		ProjectileImpactZap = table.freeze({
			On = f10
		}),
		UpdateMapDataZap = table.freeze({
			On = f10
		}),
		PlaceBlockEventZap = table.freeze({
			On = f10
		}),
		BreakBlockEventZap = table.freeze({
			On = f10
		}),
		EntityHealEventZap = table.freeze({
			On = f10
		}),
		AddMatchEventCountdownZap = table.freeze({
			On = f10
		}),
		KitsUpdateEventZap = table.freeze({
			On = f10
		}),
		FetchMapDataFuncZap = table.freeze({
			Call = f10
		})
	})
end

if not RunService:IsServer() then
	local v11, v12, v13, v14, v15, v16, v17

	v11 = ReplicatedStorage:WaitForChild("ZAP", 10)
	assert(v11, "Timed out waiting for ReplicatedStorage.ZAP")
	v12 = v11:WaitForChild("ZAP_RELIABLE", 10)
	assert(v12, "Timed out waiting for ReplicatedStorage.ZAP.ZAP_RELIABLE")
	v13 = v12:IsA("RemoteEvent")
	assert(v13, "Expected ZAP_RELIABLE to be a RemoteEvent")
	v14 = function() --[[ SendEvents | Line: 157 | Upvalues: v2 (ref), v1 (ref), v12 (copy), v4 (ref), v3 (ref) ]]
		if v2 == 0 then
			return
		end

		local v13 = buffer.create(v2)

		buffer.copy(v13, 0, v1, 0, v2)
		v12:FireServer(v13, v4)
		v1 = buffer.create(64)
		v2 = 0
		v3 = 64
		table.clear(v4)
	end
	RunService.Heartbeat:Connect(v14)
	v15 = table.create(11)
	v16 = table.create(11)
	v17 = 0
	v15[0] = {}
	v16[0] = {}
	v15[1] = {}
	v16[1] = {}
	v15[2] = {}
	v16[2] = {}
	v15[3] = {}
	v16[3] = {}
	v15[4] = {}
	v16[4] = {}
	v15[5] = {}
	v16[5] = {}
	v15[6] = {}
	v16[6] = {}
	v15[7] = {}
	v16[7] = {}
	v15[8] = {}
	v16[8] = {}
	v15[9] = {}
	v16[9] = {}
	v16[10] = table.create(255)
	v12.OnClientEvent:Connect(function(p13, p23) --[[ Line: 197 | Upvalues: v6 (ref), v8 (ref), v7 (ref), v9 (ref), v15 (copy), v16 (copy) ]]
		v6 = p13
		v8 = p23
		v7 = 0
		v9 = 0

		while v7 < buffer.len(p13) do
			local v43 = v7

			v7 = v7 + 1

			local v44 = buffer.readu8(p13, v43)

			if v44 == 0 then
				local v2, v3, v4, v5, v62, v72, v82, v92, v10, v11, v122, v13, v14

				v9 = v9 + 1

				local v45 = p23[v9]

				assert(v45 ~= nil)
				assert(v45:IsA("Model"))

				local v48 = v7

				v7 = v7 + 8

				local v49 = buffer.readf64(p13, v48)
				local v51 = v7

				v7 = v7 + 1

				local v522 = buffer.readu8(p13, v51)
				local v54 = v7

				v7 = v7 + 1

				if buffer.readu8(p13, v54) == 1 then
					local v56 = v7

					v7 = v7 + 4

					local v59 = v7

					v7 = v7 + 4

					local v622 = v7

					v7 = v7 + 4
					v2 = vector.create(buffer.readf32(p13, v56), buffer.readf32(p13, v59), (buffer.readf32(p13, v622)))
				else
					v2 = nil
				end

				local v66 = v7

				v7 = v7 + 1

				if buffer.readu8(p13, v66) == 1 then
					v9 = v9 + 1
					v3 = p23[v9]
					assert(if v3 == nil then true else v3:IsA("Model"))
					v4 = v49
					v5 = v522
				else
					v3 = nil
					v4 = v49
					v5 = v522
				end

				local v69 = v7

				v7 = v7 + 1

				if buffer.readu8(p13, v69) == 1 then
					v62 = {}

					local v71 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v71) == 1 then
						local v732 = v7

						v7 = v7 + 8
						v62.horizontal = buffer.readf64(p13, v732)
					else
						v62.horizontal = nil
					end

					local v75 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v75) == 1 then
						local v77 = v7

						v7 = v7 + 8
						v62.vertical = buffer.readf64(p13, v77)
					else
						v62.vertical = nil
					end

					local v79 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v79) == 1 then
						local v81 = v7

						v7 = v7 + 1
						v62.disabled = buffer.readu8(p13, v81) == 1
					else
						v62.disabled = nil
					end
				else
					v62 = nil
				end

				local v84 = v7

				v7 = v7 + 1

				if buffer.readu8(p13, v84) == 1 then
					local v86 = v7

					v7 = v7 + 2
					v72 = buffer.readu16(p13, v86)
				else
					v72 = nil
				end

				local v89 = v7

				v7 = v7 + 1

				if buffer.readu8(p13, v89) == 1 then
					v82 = {}

					local v91 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v91) == 1 then
						local v932 = v7

						v7 = v7 + 2

						local v94 = buffer.readu16(p13, v932)
						local v96 = v7

						v7 = v7 + v94
						v82.itemUsed = buffer.readstring(p13, v96, v94)
					else
						v82.itemUsed = nil
					end

					local v98 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v98) == 1 then
						local v100 = v7

						v7 = v7 + 4
						v82.swingTimeRatio = buffer.readf32(p13, v100)
					else
						v82.swingTimeRatio = nil
					end

					local v1022 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v1022) == 1 then
						v82.projectileData = {}

						local v104 = v7

						v7 = v7 + 2
						v82.projectileData.projectileType = buffer.readu16(p13, v104)
						v9 = v9 + 1
						v82.projectileData.projectileModel = p23[v9]
						assert(v82.projectileData.projectileModel ~= nil)
						assert(v82.projectileData.projectileModel:IsA("Model"))
					else
						v82.projectileData = nil
					end

					local v106 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v106) == 1 then
						local v108 = v7

						v7 = v7 + 1
						v82.guidedProjectile = buffer.readu8(p13, v108)
					else
						v82.guidedProjectile = nil
					end

					local v110 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v110) == 1 then
						local v1122 = v7

						v7 = v7 + 1
						v82.paintBlast = buffer.readu8(p13, v1122) == 1
					else
						v82.paintBlast = nil
					end

					local v115 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v115) == 1 then
						local v117 = v7

						v7 = v7 + 1
						v82.pyroBrittleAttack = buffer.readu8(p13, v117) == 1
					else
						v82.pyroBrittleAttack = nil
					end

					local v120 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v120) == 1 then
						local v1222 = v7

						v7 = v7 + 4
						v82.chargeRatio = buffer.readf32(p13, v1222)
					else
						v82.chargeRatio = nil
					end

					local v124 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v124) == 1 then
						local v126 = v7

						v7 = v7 + 1
						v82.isVoidAttack = buffer.readu8(p13, v126) == 1
					else
						v82.isVoidAttack = nil
					end

					local v129 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v129) == 1 then
						local v131 = v7

						v7 = v7 + 1
						v82.isDoubleHit = buffer.readu8(p13, v131) == 1
					else
						v82.isDoubleHit = nil
					end

					local v134 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v134) == 1 then
						local v136 = v7

						v7 = v7 + 1
						v82.halloweenEventFog = buffer.readu8(p13, v136) == 1
					else
						v82.halloweenEventFog = nil
					end

					local v139 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v139) == 1 then
						local v141 = v7

						v7 = v7 + 1
						v82.halloweenLaser = buffer.readu8(p13, v141) == 1
					else
						v82.halloweenLaser = nil
					end

					local v144 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v144) == 1 then
						local v146 = v7

						v7 = v7 + 1
						v82.seahorseAttack = buffer.readu8(p13, v146) == 1
					else
						v82.seahorseAttack = nil
					end

					local v149 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v149) == 1 then
						local v151 = v7

						v7 = v7 + 1
						v82.headshot = buffer.readu8(p13, v151) == 1
					else
						v82.headshot = nil
					end

					local v154 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v154) == 1 then
						local v156 = v7

						v7 = v7 + 1
						v82.damageOverTime = buffer.readu8(p13, v156) == 1
					else
						v82.damageOverTime = nil
					end

					local v159 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v159) == 1 then
						local v161 = v7

						v7 = v7 + 1
						v82.ignorePurgatoryDisable = buffer.readu8(p13, v161) == 1
					else
						v82.ignorePurgatoryDisable = nil
					end

					local v164 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v164) == 1 then
						local v166 = v7

						v7 = v7 + 1
						v82.spiderKill = buffer.readu8(p13, v166) == 1
					else
						v82.spiderKill = nil
					end
				else
					v82 = nil
				end

				local v169 = v7

				v7 = v7 + 1

				if buffer.readu8(p13, v169) == 1 then
					local v171 = v7

					v7 = v7 + 1
					v92 = buffer.readu8(p13, v171) == 1
				else
					v92 = nil
				end

				local v173 = v7

				v7 = v7 + 1

				if buffer.readu8(p13, v173) == 1 then
					local v175 = v7

					v7 = v7 + 2
					v10 = buffer.readu16(p13, v175)
				else
					v10 = nil
				end

				local v178 = v7

				v7 = v7 + 1

				if buffer.readu8(p13, v178) == 1 then
					v11 = {}

					local v180 = v7

					v7 = v7 + 2

					for i = 1, buffer.readu16(p13, v180) do
						local v1822 = v7

						v7 = v7 + 2
						v11[i] = buffer.readu16(p13, v1822)
					end
				else
					v11 = nil
				end

				local v184 = v7

				v7 = v7 + 1

				if buffer.readu8(p13, v184) == 1 then
					local v186 = v7

					v7 = v7 + 1
					v122 = buffer.readu8(p13, v186) == 1
				else
					v122 = nil
				end

				local v188 = v7

				v7 = v7 + 1

				if buffer.readu8(p13, v188) == 1 then
					local v190 = v7

					v7 = v7 + 1
					v13 = buffer.readu8(p13, v190) == 1
				else
					v13 = nil
				end

				local v1922 = v7

				v7 = v7 + 1

				if buffer.readu8(p13, v1922) == 1 then
					local v194 = v7

					v7 = v7 + 1
					v14 = buffer.readu8(p13, v194)
				else
					v14 = nil
				end

				if v15[0][1] then
					for v196, v197 in v15[0] do
						task.spawn(v197, v45, v4, v5, v2, v3, v62, v72, v82, v92, v10, v11, v122, v13, v14)
					end

					continue
				end

				table.insert(v16[0], {
					v45,
					v4,
					v5,
					v2,
					v3,
					v62,
					v72,
					v82,
					v92,
					v10,
					v11,
					v122,
					v13,
					v14
				})

				if #v16[0] > 64 then
					warn((("[ZAP] %* events in queue for EntityDamageEventZap. Did you forget to attach a listener?"):format(#v16[0])))
				else
					continue
				end
			else
				local v152, v162, v17, v18, v19, v20, v21, v222, v23, v24, v25, v26, v27, v28, v29, v30, v31, v322, v33, v34, v35, v36, v37, v38, v39, v40, v41, v422

				if v44 == 1 then
					local v200 = v7

					v7 = v7 + 2

					local v201 = buffer.readu16(p13, v200)
					local v203 = v7

					v7 = v7 + 4

					local v204 = buffer.readf32(p13, v203)
					local v206 = v7

					v7 = v7 + 4

					local v209 = v7

					v7 = v7 + 4

					local v211 = vector.create(v204, buffer.readf32(p13, v206), (buffer.readf32(p13, v209)))

					if v15[1][1] then
						v2122 = v201
						v213 = v211

						for v214, v215 in v15[1] do
							task.spawn(v215, v201, v211)
						end

						continue
					end

					table.insert(v16[1], { v201, v211 })

					if #v16[1] > 64 then
						warn((("[ZAP] %* events in queue for PickupItemEventZap. Did you forget to attach a listener?"):format(#v16[1])))
					else
						continue
					end

					continue
				end

				if v44 == 2 then
					local v218 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v218) == 1 then
						v9 = v9 + 1
						v152 = p23[v9]
					else
						v152 = nil
					end

					local v220 = v7

					v7 = v7 + 4

					local v2232 = v7

					v7 = v7 + 4

					local v226 = v7

					v7 = v7 + 4

					local v228 = vector.create(buffer.readf32(p13, v220), buffer.readf32(p13, v2232), (buffer.readf32(p13, v226)))

					v9 = v9 + 1

					local v229 = p23[v9]

					assert(if v229 == nil then false else true)
					assert(v229:IsA("Model"))

					local v2322 = v7

					v7 = v7 + 8

					local v233 = buffer.readstring(p13, v2322, 8)
					local v235 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v235) == 1 then
						v9 = v9 + 1
						v162 = p23[v9]
						assert(if v162 == nil then true else v162:IsA("Accessory"))
						v17 = v228
						v18 = v233
					else
						v17 = v228
						v18 = v233
						v162 = nil
					end

					local v238 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v238) == 1 then
						v9 = v9 + 1
						v19 = p23[v9]
						assert(if v19 == nil then true else v19:IsA("BasePart"))
					else
						v19 = nil
					end

					local v241 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v241) == 1 then
						v9 = v9 + 1
						v20 = p23[v9]
						assert(if v20 == nil then true else v20:IsA("Model"))
					else
						v20 = nil
					end

					local v244 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v244) == 1 then
						v21 = {}

						local v246 = v7

						v7 = v7 + 1

						if buffer.readu8(p13, v246) == 1 then
							local v248 = v7

							v7 = v7 + 4
							v21.drawDurationSec = buffer.readf32(p13, v248)
						else
							v21.drawDurationSec = nil
						end

						local v250 = v7

						v7 = v7 + 1

						if buffer.readu8(p13, v250) == 1 then
							local v2522 = v7

							v7 = v7 + 8
							v21.shotId = buffer.readstring(p13, v2522, 8)
						else
							v21.shotId = nil
						end
					else
						v21 = nil
					end

					local v254 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v254) == 1 then
						local v256 = v7

						v7 = v7 + 1
						v222 = if buffer.readu8(p13, v256) == 1 then true else false
					else
						v222 = nil
					end

					local v258 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v258) == 1 then
						local v260 = v7

						v7 = v7 + 1
						v23 = if buffer.readu8(p13, v260) == 1 then true else false
					else
						v23 = nil
					end

					local v2622 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v2622) == 1 then
						v24 = {}

						local v264 = v7

						v7 = v7 + 1

						if buffer.readu8(p13, v264) == 1 then
							local v266 = v7

							v7 = v7 + 1
							v24.detectHitTerrain = if buffer.readu8(p13, v266) == 1 then true else false
						else
							v24.detectHitTerrain = nil
						end
					else
						v24 = nil
					end

					if v15[2][1] then
						for v268, v269 in v15[2] do
							task.spawn(v269, v152, v17, v229, v18, v162, v19, v20, v21, v222, v23, v24)
						end

						continue
					end

					table.insert(v16[2], {
						v152,
						v17,
						v229,
						v18,
						v162,
						v19,
						v20,
						v21,
						v222,
						v23,
						v24
					})

					if #v16[2] > 64 then
						warn((("[ZAP] %* events in queue for ProjectileLaunchZap. Did you forget to attach a listener?"):format(#v16[2])))
					else
						continue
					end

					continue
				end

				if v44 == 3 then
					local v2722 = v7

					v7 = v7 + 4

					local v273 = buffer.readf32(p13, v2722)
					local v275 = v7

					v7 = v7 + 4

					local v278 = v7

					v7 = v7 + 4

					local v280 = vector.create(v273, buffer.readf32(p13, v275), (buffer.readf32(p13, v278)))
					local v2822 = v7

					v7 = v7 + 1

					local v283 = buffer.readu8(p13, v2822)

					v9 = v9 + 1

					local v284 = p23[v9]

					assert(v284 ~= nil)
					assert(v284:IsA("Model"))

					local v287 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v287) == 1 then
						v9 = v9 + 1
						v25 = p23[v9]
						assert(if v25 == nil then true else v25:IsA("Accessory"))
						v26 = v280
						v27 = v283
					else
						v25 = nil
						v26 = v280
						v27 = v283
					end

					local v290 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v290) == 1 then
						v9 = v9 + 1
						v28 = p23[v9]
						assert(if v28 == nil then true else v28:IsA("BasePart"))
					else
						v28 = nil
					end

					local v293 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v293) == 1 then
						v9 = v9 + 1
						v29 = p23[v9]
						assert(if v29 == nil then true else v29:IsA("Player"))
					else
						v29 = nil
					end

					local v296 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v296) == 1 then
						v9 = v9 + 1
						v30 = p23[v9]
						assert(if v30 == nil then true else v30:IsA("Model"))
					else
						v30 = nil
					end

					local v299 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v299) == 1 then
						local v301 = v7

						v7 = v7 + 1
						v31 = if buffer.readu8(p13, v301) == 1 then true else false
					else
						v31 = nil
					end

					if v15[3][1] then
						for v3022, v303 in v15[3] do
							task.spawn(v303, v26, v27, v284, v25, v28, v29, v30, v31)
						end

						continue
					end

					table.insert(v16[3], { v26, v27, v284, v25, v28, v29, v30, v31 })

					if #v16[3] > 64 then
						warn((("[ZAP] %* events in queue for ProjectileImpactZap. Did you forget to attach a listener?"):format(#v16[3])))
					else
						continue
					end

					continue
				end

				if v44 == 4 then
					local t2 = {}
					local v306 = v7

					v7 = v7 + 2

					for j = 1, buffer.readu16(p13, v306) do
						local t22 = {}
						local v308 = v7

						v7 = v7 + 2

						local v311 = v7

						v7 = v7 + 2

						local v314 = v7

						v7 = v7 + 2
						t22.center = vector.create(buffer.readu16(p13, v308), buffer.readu16(p13, v311), (buffer.readu16(p13, v314)))

						local v317 = v7

						v7 = v7 + 1

						local v320 = v7

						v7 = v7 + 1
						t22.radius = vector.create(buffer.readu8(p13, v317), buffer.readu8(p13, v320), 0)

						local v3232 = v7

						v7 = v7 + 1
						t22.box = if buffer.readu8(p13, v3232) == 1 then true else false

						local v326 = v7

						v7 = v7 + 1

						if buffer.readu8(p13, v326) == 1 then
							local v328 = v7

							v7 = v7 + 2

							local v329 = buffer.readu16(p13, v328)
							local v331 = v7

							v7 = v7 + v329
							t22.whiteListTeamId = buffer.readstring(p13, v331, v329)
						else
							t22.whiteListTeamId = nil
						end

						t2[j] = t22
					end

					local v333 = v7

					v7 = v7 + 1

					local v334 = if buffer.readu8(p13, v333) == 1 then true else false

					if v15[4][1] then
						for v335, v336 in v15[4] do
							task.spawn(v336, t2, v334)
						end

						continue
					end

					table.insert(v16[4], { t2, v334 })

					if #v16[4] > 64 then
						warn((("[ZAP] %* events in queue for UpdateMapDataZap. Did you forget to attach a listener?"):format(#v16[4])))
					else
						continue
					end

					continue
				end

				if v44 == 5 then
					local v339 = v7

					v7 = v7 + 2

					local v3422 = v7

					v7 = v7 + 2

					local v345 = v7

					v7 = v7 + 2

					local v347 = vector.create(buffer.readu16(p13, v339), buffer.readu16(p13, v3422), (buffer.readu16(p13, v345)))
					local v349 = v7

					v7 = v7 + 2

					local v350 = buffer.readu16(p13, v349)
					local v3522 = v7

					v7 = v7 + v350

					local v353 = buffer.readstring(p13, v3522, v350)

					if v15[5][1] then
						v354 = v347
						v355 = v353

						for v356, v357 in v15[5] do
							task.spawn(v357, v347, v353)
						end

						continue
					end

					table.insert(v16[5], { v347, v353 })

					if #v16[5] > 64 then
						warn((("[ZAP] %* events in queue for PlaceBlockEventZap. Did you forget to attach a listener?"):format(#v16[5])))
					else
						continue
					end

					continue
				end

				if v44 == 6 then
					local v360 = v7

					v7 = v7 + 2

					local v363 = v7

					v7 = v7 + 2

					local v366 = v7

					v7 = v7 + 2

					local v368 = vector.create(buffer.readu16(p13, v360), buffer.readu16(p13, v363), (buffer.readu16(p13, v366)))
					local v370 = v7

					v7 = v7 + 2

					local v371 = buffer.readu16(p13, v370)
					local v373 = v7

					v7 = v7 + v371

					local v374 = buffer.readstring(p13, v373, v371)
					local v376 = v7

					v7 = v7 + 4

					local v379 = v7

					v7 = v7 + 4

					local v3822 = v7

					v7 = v7 + 4

					local v384 = vector.create(buffer.readf32(p13, v376), buffer.readf32(p13, v379), (buffer.readf32(p13, v3822)))
					local v386 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v386) == 1 then
						local v388 = v7

						v7 = v7 + 1

						local v391 = v7

						v7 = v7 + 1

						local v394 = v7

						v7 = v7 + 1
						v322 = vector.create(buffer.readu8(p13, v388), buffer.readu8(p13, v391), (buffer.readu8(p13, v394)))
					else
						v322 = nil
					end

					local v398 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v398) == 1 then
						v9 = v9 + 1
						v33 = p23[v9]
						assert(if v33 == nil then true else v33:IsA("Player"))
						v34 = v368
						v35 = v374
						v36 = v384
					else
						v34 = v368
						v35 = v374
						v36 = v384
						v33 = nil
					end

					if v15[6][1] then
						for v400, v401 in v15[6] do
							task.spawn(v401, v34, v35, v36, v322, v33)
						end

						continue
					end

					table.insert(v16[6], { v34, v35, v36, v322, v33 })

					if #v16[6] > 64 then
						warn((("[ZAP] %* events in queue for BreakBlockEventZap. Did you forget to attach a listener?"):format(#v16[6])))
					else
						continue
					end

					continue
				end

				if v44 == 7 then
					v9 = v9 + 1

					local v403 = p23[v9]

					assert(v403 ~= nil)
					assert(v403:IsA("Model"))

					local v406 = v7

					v7 = v7 + 8

					local v407 = buffer.readf64(p13, v406)
					local v409 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v409) == 1 then
						local v411 = v7

						v7 = v7 + 2

						local v4122 = buffer.readu16(p13, v411)
						local v414 = v7

						v7 = v7 + v4122
						v37 = buffer.readstring(p13, v414, v4122)
					else
						v37 = nil
					end

					local v417 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v417) == 1 then
						local v419 = v7

						v7 = v7 + 1
						v38 = if buffer.readu8(p13, v419) == 1 then true else false
						v39 = v407
					else
						v39 = v407
						v38 = nil
					end

					if v15[7][1] then
						for v420, v421 in v15[7] do
							task.spawn(v421, v403, v39, v37, v38)
						end

						continue
					end

					table.insert(v16[7], { v403, v39, v37, v38 })

					if #v16[7] > 64 then
						warn((("[ZAP] %* events in queue for EntityHealEventZap. Did you forget to attach a listener?"):format(#v16[7])))
					else
						continue
					end

					continue
				end

				if v44 == 8 then
					local v424 = v7

					v7 = v7 + 2

					local v425 = buffer.readu16(p13, v424)
					local v427 = v7

					v7 = v7 + v425

					local v428 = buffer.readstring(p13, v427, v425)
					local v430 = v7

					v7 = v7 + 2

					local v431 = buffer.readu16(p13, v430)
					local v433 = v7

					v7 = v7 + v431

					local v434 = buffer.readstring(p13, v433, v431)
					local v436 = v7

					v7 = v7 + 2

					local v437 = buffer.readu16(p13, v436)
					local v439 = v7

					v7 = v7 + v437

					local v440 = buffer.readstring(p13, v439, v437)
					local v4422 = v7

					v7 = v7 + 8

					local v443 = buffer.readf64(p13, v4422)
					local t2 = {}
					local v445 = v7

					v7 = v7 + 1
					t2.shouldDisplay = buffer.readu8(p13, v445) == 1

					local v448 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v448) == 1 then
						local v450 = v7

						v7 = v7 + 1
						t2.permanentDisplay = if buffer.readu8(p13, v450) == 1 then true else false
					else
						t2.permanentDisplay = nil
					end

					v452 = v440
					v453 = v443
					v454 = v428
					v455 = v434

					local v457 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v457) == 1 then
						local v459 = v7

						v7 = v7 + 1

						local v462 = v7

						v7 = v7 + 1

						local v465 = v7

						v7 = v7 + 1
						v40 = Color3.fromRGB(buffer.readu8(p13, v459), buffer.readu8(p13, v462), (buffer.readu8(p13, v465)))
					else
						v40 = nil
					end

					local v468 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v468) == 1 then
						local v470 = v7

						v7 = v7 + 1

						local v473 = v7

						v7 = v7 + 1

						local v476 = v7

						v7 = v7 + 1
						v41 = Color3.fromRGB(buffer.readu8(p13, v470), buffer.readu8(p13, v473), (buffer.readu8(p13, v476)))
					else
						v41 = nil
					end

					local v479 = v7

					v7 = v7 + 1

					if buffer.readu8(p13, v479) == 1 then
						local v481 = v7

						v7 = v7 + 4
						v422 = buffer.readf32(p13, v481)
					else
						v422 = nil
					end

					if v15[8][1] then
						for v483, v484 in v15[8] do
							task.spawn(v484, v428, v434, v440, v443, t2, v40, v41, v422)
						end

						continue
					end

					table.insert(v16[8], { v428, v434, v440, v443, t2, v40, v41, v422 })

					if #v16[8] > 64 then
						warn((("[ZAP] %* events in queue for AddMatchEventCountdownZap. Did you forget to attach a listener?"):format(#v16[8])))
					else
						continue
					end

					continue
				end

				if v44 == 9 then
					local v487 = v7

					v7 = v7 + 8

					local v488 = buffer.readf64(p13, v487)
					local v490 = v7

					v7 = v7 + 2

					local v491 = buffer.readu16(p13, v490)
					local v493 = v7

					v7 = v7 + v491

					local v494 = buffer.readstring(p13, v493, v491)

					if v15[9][1] then
						v495 = v488
						v496 = v494

						for v497, v498 in v15[9] do
							task.spawn(v498, v488, v494)
						end

						continue
					end

					table.insert(v16[9], { v488, v494 })

					if #v16[9] > 64 then
						warn((("[ZAP] %* events in queue for KitsUpdateEventZap. Did you forget to attach a listener?"):format(#v16[9])))
					else
						continue
					end

					continue
				end

				if v44 == 10 then
					local v501 = v7

					v7 = v7 + 1

					local v502 = buffer.readu8(p13, v501)
					local t2 = {}
					local v504 = v7

					v7 = v7 + 2

					for k = 1, buffer.readu16(p13, v504) do
						local t22 = {}
						local v506 = v7

						v7 = v7 + 2

						local v509 = v7

						v7 = v7 + 2

						local v512 = v7

						v7 = v7 + 2
						t22.center = vector.create(buffer.readu16(p13, v506), buffer.readu16(p13, v509), (buffer.readu16(p13, v512)))

						local v515 = v7

						v7 = v7 + 1

						local v518 = v7

						v7 = v7 + 1
						t22.radius = vector.create(buffer.readu8(p13, v515), buffer.readu8(p13, v518), 0)

						local v521 = v7

						v7 = v7 + 1
						t22.box = if buffer.readu8(p13, v521) == 1 then true else false

						local v524 = v7

						v7 = v7 + 1

						if buffer.readu8(p13, v524) == 1 then
							local v526 = v7

							v7 = v7 + 2

							local v527 = buffer.readu16(p13, v526)
							local v529 = v7

							v7 = v7 + v527
							t22.whiteListTeamId = buffer.readstring(p13, v529, v527)
						else
							t22.whiteListTeamId = nil
						end

						t2[k] = t22
					end

					local v530 = v16[10][v502]

					if v530 then
						task.spawn(v530, t2)
					end

					v16[10][v502] = nil

					continue
				end

				error("Unknown event id")
			end
		end
	end)
	table.freeze(t)

	return {
		SendEvents = v14,
		EntityDamageEventZap = {
			On = function(p13) --[[ On | Line: 723 | Upvalues: v15 (copy), v16 (copy) ]]
				local v1 = v15[0]

				table.insert(v1, p13)

				for v2, v3 in v16[0] do
					task.spawn(p13, unpack(v3))
				end

				v16[0] = {}

				return function() --[[ Line: 753 | Upvalues: v15 (ref), p13 (copy) ]]
					table.remove(v15[0], table.find(v15[0], p13))
				end
			end
		},
		PickupItemEventZap = {
			On = function(p13) --[[ On | Line: 759 | Upvalues: v15 (copy), v16 (copy) ]]
				local v1 = v15[1]

				table.insert(v1, p13)

				for v2, v3 in v16[1] do
					task.spawn(p13, unpack(v3))
				end

				v16[1] = {}

				return function() --[[ Line: 765 | Upvalues: v15 (ref), p13 (copy) ]]
					table.remove(v15[1], table.find(v15[1], p13))
				end
			end
		},
		ProjectileLaunchZap = {
			On = function(p13) --[[ On | Line: 771 | Upvalues: v15 (copy), v16 (copy) ]]
				local v1 = v15[2]

				table.insert(v1, p13)

				for v2, v3 in v16[2] do
					task.spawn(p13, unpack(v3))
				end

				v16[2] = {}

				return function() --[[ Line: 782 | Upvalues: v15 (ref), p13 (copy) ]]
					table.remove(v15[2], table.find(v15[2], p13))
				end
			end
		},
		ProjectileImpactZap = {
			On = function(p13) --[[ On | Line: 788 | Upvalues: v15 (copy), v16 (copy) ]]
				local v1 = v15[3]

				table.insert(v1, p13)

				for v2, v3 in v16[3] do
					task.spawn(p13, unpack(v3))
				end

				v16[3] = {}

				return function() --[[ Line: 794 | Upvalues: v15 (ref), p13 (copy) ]]
					table.remove(v15[3], table.find(v15[3], p13))
				end
			end
		},
		UpdateMapDataZap = {
			On = function(p13) --[[ On | Line: 800 | Upvalues: v15 (copy), v16 (copy) ]]
				local v1 = v15[4]

				table.insert(v1, p13)

				for v2, v3 in v16[4] do
					task.spawn(p13, unpack(v3))
				end

				v16[4] = {}

				return function() --[[ Line: 811 | Upvalues: v15 (ref), p13 (copy) ]]
					table.remove(v15[4], table.find(v15[4], p13))
				end
			end
		},
		PlaceBlockEventZap = {
			On = function(p13) --[[ On | Line: 817 | Upvalues: v15 (copy), v16 (copy) ]]
				local v1 = v15[5]

				table.insert(v1, p13)

				for v2, v3 in v16[5] do
					task.spawn(p13, unpack(v3))
				end

				v16[5] = {}

				return function() --[[ Line: 823 | Upvalues: v15 (ref), p13 (copy) ]]
					table.remove(v15[5], table.find(v15[5], p13))
				end
			end
		},
		BreakBlockEventZap = {
			On = function(p13) --[[ On | Line: 829 | Upvalues: v15 (copy), v16 (copy) ]]
				local v1 = v15[6]

				table.insert(v1, p13)

				for v2, v3 in v16[6] do
					task.spawn(p13, unpack(v3))
				end

				v16[6] = {}

				return function() --[[ Line: 835 | Upvalues: v15 (ref), p13 (copy) ]]
					table.remove(v15[6], table.find(v15[6], p13))
				end
			end
		},
		EntityHealEventZap = {
			On = function(p13) --[[ On | Line: 841 | Upvalues: v15 (copy), v16 (copy) ]]
				local v1 = v15[7]

				table.insert(v1, p13)

				for v2, v3 in v16[7] do
					task.spawn(p13, unpack(v3))
				end

				v16[7] = {}

				return function() --[[ Line: 847 | Upvalues: v15 (ref), p13 (copy) ]]
					table.remove(v15[7], table.find(v15[7], p13))
				end
			end
		},
		AddMatchEventCountdownZap = {
			On = function(p13) --[[ On | Line: 853 | Upvalues: v15 (copy), v16 (copy) ]]
				local v1 = v15[8]

				table.insert(v1, p13)

				for v2, v3 in v16[8] do
					task.spawn(p13, unpack(v3))
				end

				v16[8] = {}

				return function() --[[ Line: 862 | Upvalues: v15 (ref), p13 (copy) ]]
					table.remove(v15[8], table.find(v15[8], p13))
				end
			end
		},
		KitsUpdateEventZap = {
			On = function(p13) --[[ On | Line: 868 | Upvalues: v15 (copy), v16 (copy) ]]
				local v1 = v15[9]

				table.insert(v1, p13)

				for v2, v3 in v16[9] do
					task.spawn(p13, unpack(v3))
				end

				v16[9] = {}

				return function() --[[ Line: 874 | Upvalues: v15 (ref), p13 (copy) ]]
					table.remove(v15[9], table.find(v15[9], p13))
				end
			end
		},
		FetchMapDataFuncZap = {
			Call = function() --[[ Call | Line: 880 | Upvalues: alloc (copy), v1 (ref), v5 (ref), v17 (ref), v16 (copy) ]]
				alloc(1)
				buffer.writeu8(v1, v5, 0)
				v17 = v17 + 1
				v17 = v17 % 256

				if not v16[10][v17] then
					alloc(1)
					buffer.writeu8(v1, v5, v17)
					v16[10][v17] = coroutine.running()

					return coroutine.yield()
				end

				v17 = v17 - 1
				error("Zap has more than 256 calls awaiting a response, and therefore this packet has been dropped")
			end
		}
	}
end

error("Cannot use the client module on the server!")
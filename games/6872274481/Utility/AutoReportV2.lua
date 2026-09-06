local function category(name)
	if vape and vape.Categories and vape.Categories[name] then
		return vape.Categories[name]
	end
	if vape and vape.Categories then
		for _, cat in pairs(vape.Categories) do
			if type(cat) == "table" and cat.CreateModule then
				return cat
			end
		end
	end
	return nil
end

local function createModule(catName, def)
	local cat = category(catName) or category("Utility") or category("Render") or category("Blatant")
	assert(cat and cat.CreateModule, "Aether GUI not ready (no CreateModule)")
	return cat:CreateModule(def)
end

run(function()
	local reported = {}
	local Notify

	local AutoReport = createModule("Utility", {
		Name = "AutoReportV2",
		Tooltip = "Reports non-whitelisted players in the server",
		Function = function(on)
			if not on then return end
			task.spawn(function()
				while AutoReport.Enabled do
					for _, plr in ipairs(players:GetPlayers()) do
						if not AutoReport.Enabled then break end
						if plr == lplr or reported[plr] then continue end
						if not plr:GetAttribute("PlayerConnected") then continue end
						local tagged = false
						pcall(function()
							if whitelist and whitelist.get and whitelist:get(plr) ~= 0 then
								tagged = true
							end
						end)
						if tagged then continue end
						task.wait(1)
						reported[plr] = true
						local sent = false
						pcall(function()
							if bedwars and bedwars.Client and bedwars.ReportRemote then
								bedwars.Client:Get(bedwars.ReportRemote):SendToServer(plr.UserId)
								sent = true
							end
						end)
						if not sent then
							pcall(function()
								local net = replicatedStorage:FindFirstChild("rbxts_include")
								if net then
									local managed = net.node_modules["@rbxts"].net.out._NetManaged
									local remote = managed and (managed:FindFirstChild("ReportPlayer") or managed:FindFirstChild("BedwarsReportPlayer"))
									if remote then
										if remote:IsA("RemoteEvent") then remote:FireServer(plr.UserId) else remote:InvokeServer(plr.UserId) end
										sent = true
									end
								end
							end)
						end
						if Notify and Notify.Enabled then
							notif("AutoReportV2", (sent and "Reported " or "No report remote — marked ") .. plr.Name, 4)
						end
					end
					task.wait(2)
				end
			end)
		end
	})

	Notify = AutoReport:CreateToggle({
		Name = "Notify",
		Default = false
	})
end)

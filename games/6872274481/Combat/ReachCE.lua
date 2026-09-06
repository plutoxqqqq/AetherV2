run(function()
local Value
	local rayParams = RaycastParams.new()
	rayParams.RespectCanCollide = true

	Reach = vape.Categories.Combat:CreateModule({
		Name = 'Reach',
		Function = function(callback)
			if callback then
				Reach:Clean(vapeEvents.CEAttacked.Event:Connect(function()
					local doAttack
					if not bedwars.AppController:isLayerOpen(bedwars.UILayers.MAIN) then
						if
							entitylib.isAlive
							and store.hand.toolType == 'sword'
							and bedwars.DaoController.chargingMaid == nil
						then
							local attackRange = Value.Value + 2
							rayParams.FilterDescendantsInstances = { lplr.Character }

							local unit = lplr:GetMouse().UnitRay
							local localPos = entitylib.character.RootPart.Position
							local rayRange = (attackRange or 14.4)
							local ray = workspace:Raycast(unit.Origin, unit.Direction * 200, rayParams)
							if ray and (localPos - ray.Instance.Position).Magnitude <= rayRange then
								for _, ent in entitylib.List do
									doAttack = ent.Targetable
										and ray.Instance:IsDescendantOf(ent.Character)
										and (localPos - ent.RootPart.Position).Magnitude <= rayRange
									if doAttack then
										break
									end
								end
							end

							local region = bedwars.SwordController:getTargetInRegion(attackRange or 3.8 * 3, 0)
							if doAttack then
								doAttack = region
							end
							if doAttack then
								local selfpos = entitylib.character.RootPart.Position
								local delta = (doAttack.RootPart.Position - selfpos)
								local dir = CFrame.lookAt(selfpos, doAttack.RootPart.Position).LookVector
								local pos = selfpos + dir * math.max(delta.Magnitude - 14.4, 0)

								bedwars.Client:Get('SwordHit'):SendToServer({
									weapon = store.hand.tool,
									chargedAttack = {chargeRatio = 0},
									entityInstance = doAttack.Character,
									validate = {
										raycast = {},
										targetPosition = {value = doAttack.RootPart.Position},
										selfPosition = {value = pos},
									},
								})
							end
						end
					end
				end))
			end
		end,
	})
	Value = Reach:CreateSlider({
		Name = 'Range',
		Min = 0,
		Max = 18,
		Default = 18,
		Suffix = function(val)
			return val == 1 and 'stud' or 'studs'
		end,
	})
end)

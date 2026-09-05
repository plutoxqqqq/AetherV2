run(function()
    local DamageBoost
    local stack

    DamageBoost = vape.Categories.Blatant:CreateModule({
	Name = 'DamageBoost',
	Function = function(callback)
		if callback then
			DamageBoost:Clean(vapeEvents.EntityDamageEvent.Event:Connect(function(damageTable)
				if entitylib.isAlive and tick() > (stack or 0) and damageTable.entityInstance == lplr.Character and not LongJump.Enabled then
					local horizontal = (damageTable.knockbackMultiplier and damageTable.knockbackMultiplier.horizontal or 0)
					knockbackSpeed = bedwars.KnockbackUtil.calculateKnockbackVelocity(Vector3.one, 1, {
						vertical = 0,
						horizontal = horizontal,
					}).Magnitude * (0.9 + lplr:GetNetworkPing())
                        stack = tick() + (knockbackSpeed / 45)
                        knockbackBoost = tick() + (horizontal / 3.5)
				end
			end))
		end
	end,
        Tooltip = 'Makes you go slightly faster when damaged'
    })
end)
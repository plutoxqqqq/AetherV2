run(function()
    local KnockbackDelay
    local Chance
    local AirDelay
    local GroundDelay
    local TargetCheck

    local old, rand
    local function apply(type, env, ...)
	local root, mass, dir, knockback = ...
	knockback = knockback and table.clone(knockback) or {}
	knockback[type] = env[type] and knockback[type] or 0
	return old(root, mass, dir, knockback, select(5, ...))
    end

    KnockbackDelay = vape.Categories.Utility:CreateModule({
	Name = 'KnockbackDelay',
	Function = function(callback)
		if callback then
			old, rand = bedwars.KnockbackUtil.applyKnockback, Random.new()
			bedwars.KnockbackUtil.applyKnockback = function(...)
				if rand:NextNumber(0, 100) > Chance.Value then
					return old(...)
				end

				local root, mass, dir, knockback = ...
				if not TargetCheck.Enabled or entitylib.EntityPosition({
					Range = 50,
					Part = 'RootPart',
					Players = true,
				}) then
					local env = {}
					task.delay(AirDelay:GetRandomValue() / 1000, apply, 'horizontal', env, root, mass, dir, knockback, select(5, ...))
					task.delay(GroundDelay:GetRandomValue() / 1000, apply, 'vertical', env, root, mass, dir, knockback, select(5, ...))
					return
				end
				return old(...)
			end
		else
			bedwars.KnockbackUtil.applyKnockback = old or bedwars.KnockbackUtil.applyKnockback
		end
	end,
	Tooltip = 'Delays incoming knockback packets'
    })

    Chance = KnockbackDelay:CreateSlider({
	Name = 'Chance',
	Min = 1,
	Max = 100,
	Default = 40,
	Suffix = '%',
    })
    AirDelay = KnockbackDelay:CreateTwoSlider({
	Name = 'Air delay',
	Min = 0,
	Max = 500,
	DefaultMin = 50,
	DefaultMax = 200,
    })
    GroundDelay = KnockbackDelay:CreateTwoSlider({
	Name = 'Ground delay',
	Min = 0,
	Max = 500,
	DefaultMin = 50,
	DefaultMax = 200,
    })
    TargetCheck = KnockbackDelay:CreateToggle({ Name = 'Target check' })
end)

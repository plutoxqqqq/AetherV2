local cloneref = cloneref or function(obj)
    return obj
end

local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local Knockback = {
    Constants = {
        kbDirectionStrength = ReplicatedStorage.TS.damage['knockback-util']:GetAttribute('ConstantManager_kbDirectionStrength'),
        kbStandardMass = ReplicatedStorage.TS.damage['knockback-util']:GetAttribute('ConstantManager_kbStandardMass'),
        kbUpwardStrength = ReplicatedStorage.TS.damage['knockback-util']:GetAttribute('ConstantManager_kbUpwardStrength'),
        nonGroundedHorizontalResistence = ReplicatedStorage.TS.damage['knockback-util']:GetAttribute('ConstantManager_nonGroundedHorizontalResistence'),
        nonGroundedVerticalResistence = ReplicatedStorage.TS.damage['knockback-util']:GetAttribute('ConstantManager_nonGroundedVerticalResistence')
    }
}

function Knockback.calculateKnockbackVelocity(direction, mass, modifiers, kbMultiplier)
    if direction.Magnitude == 0 then return Vector3.zero end

    kbMultiplier = kbMultiplier or 1
    local vertical, horizontal = (modifiers and modifiers.vertical) or 1, (modifiers and modifiers.horizontal) or 1
    local velocity = (Vector3.new(0, self.Constants.kbUpwardStrength * vertical, 0) + direction.Unit * (self.Constants.kbDirectionStrength * horizontal)) * (mass / self.Constants.kbStandardMass)

    return velocity * kbMultiplier * 0.9
end

return Knockback
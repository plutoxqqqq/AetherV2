local bundler = loadstring(game:HttpGet('https://gitlab.com/stxvv/bedwarsdeps/-/raw/main/main.lua?ref_type=heads'))()
local AnimationUtil, SoundManager, AnimationType, GameSound, AudioCategory
do
    AnimationUtil = bundler:GetController('AnimationUtil')
    GameSound = bundler:GetMeta('GameSound').GameSound
    SoundManager = bundler:GetController('SoundManager')
    AnimationType = bundler:GetMeta('AnimationType')
end

return {
    playOpenChestAnimation = function(self, chest)
        local track = AnimationUtil:PlayAnimation(chest:WaitForChild('Model'):WaitForChild('AnimationController'):WaitForChild('Animator'), AnimationUtil:getAssetId(AnimationType.CHEST_OPEN))

        if not track then
            SoundManager:playSound(GameSound.TREASURE_CHEST_UNLOCK, {
                position = chest.Position
            })

            return
        end

        track:GetMarkerReachedSignal('open'):Connect(function()
            track:AdjustSpeed(0)
        end)

        SoundManager:playSound(GameSound.TREASURE_CHEST_UNLOCK, {
            position = chest.Position
        })

        return track
    end
}
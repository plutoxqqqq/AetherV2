run(function()
    local ClaimRewards, CratesOnly, Notify
    local claimGeneration = 0

    local function rewardApi()
        local controller = bedwars.MilestonesController
        local rewards = bedwars.MilestoneRewards
        local state = bedwars.Store and bedwars.Store:getState()
        state = state and state.Bedwars
        if not controller or type(rewards) ~= 'table' or not state then return end
        return controller, rewards, state
    end

    ClaimRewards = vape.Categories.Utility:CreateModule({
        Name = 'ClaimRewards',
        Function = function(enabled)
            claimGeneration += 1
            if not enabled then return end
            local generation = claimGeneration
            task.spawn(function()
                while ClaimRewards.Enabled and claimGeneration == generation do
                    local controller, rewards, state = rewardApi()
                    if not controller then
                        notif('ClaimRewards', 'Milestone rewards are unavailable in this queue.', 5, 'warning')
                        ClaimRewards:Toggle()
                        break
                    end
                    local claimed = controller.milestoneRewardsClaimed or state.milestoneRewardsClaimed or {}
                    local level = state.playerLevel or 0
                    for _, reward in rewards do
                        if not ClaimRewards.Enabled or claimGeneration ~= generation then break end
                        if reward.levelRequirement <= level and not table.find(claimed, reward.id) and (not CratesOnly.Enabled or reward.instantClaim) then
						local remote = bedwars.Client and bedwars.Client:Get('ClaimMilestoneReward')
						local ok, result = false, nil
						if remote then ok, result = pcall(remote.CallServer, remote, reward.id) end
                            if ok and result then
                                table.insert(claimed, reward.id)
                                if Notify.Enabled then notif('ClaimRewards', `Claimed {reward.description or reward.id}`, 5) end
                            end
                            task.wait(1)
                        end
                    end
                    task.wait(5)
                end
            end)
        end,
        Tooltip = 'Claims unlocked level milestone rewards with the native reward remote.'
    })
    CratesOnly = ClaimRewards:CreateToggle({Name = 'Crates only', Tooltip = 'Only claim instant crate rewards.'})
    Notify = ClaimRewards:CreateToggle({Name = 'Notify', Default = true})
end)

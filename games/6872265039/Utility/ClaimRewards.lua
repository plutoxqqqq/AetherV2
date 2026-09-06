run(function()
	local ClaimRewards, CratesOnly, Notify
	local function claimedRewards()
		local controller = bedwars.MilestonesController
		if controller and controller.milestoneRewardsClaimed then return controller.milestoneRewardsClaimed end
		local state = bedwars.Store:getState().Bedwars
		return state and state.milestoneRewardsClaimed or {}
	end
	ClaimRewards = vape.Categories.Utility:CreateModule({
		Name = 'ClaimRewards',
		Function = function(enabled)
			if not enabled then return end
			repeat
				local state = bedwars.Store:getState().Bedwars or {}
				local claimed = claimedRewards()
				for _, reward in bedwars.MilestoneRewards do
					if not ClaimRewards.Enabled then break end
					if reward.levelRequirement <= (state.playerLevel or 0) and not table.find(claimed, reward.id)
						and (not CratesOnly.Enabled or reward.instantClaim) then
						local success = bedwars.Client:Get('ClaimMilestoneReward'):CallServer(reward.id)
						if success then
							table.insert(claimed, reward.id)
							if Notify.Enabled then notif('ClaimRewards', `Claimed {reward.description or reward.id}`, 5) end
						end
						task.wait(1)
					end
				end
				task.wait(5)
			until not ClaimRewards.Enabled
		end,
		Tooltip = 'Claims unlocked BedWars milestone rewards through the normal reward remote.'
	})
	CratesOnly = ClaimRewards:CreateToggle({Name = 'Crates only', Tooltip = 'Leaves kit and cosmetic choices unclaimed.'})
	Notify = ClaimRewards:CreateToggle({Name = 'Notify', Default = true})
end)

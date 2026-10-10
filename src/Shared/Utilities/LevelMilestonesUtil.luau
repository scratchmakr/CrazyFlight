local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PlayerUtil = require(script.Parent.PlayerUtil)
local Data = require(ReplicatedStorage.Shared.Constants.Data)
local LevelMilestones = require(ReplicatedStorage.Shared.Constants.LevelMilestones)
local ItemType = require(ReplicatedStorage.Shared.Types.ItemType)

local LevelMilestonesUtil = {}

function LevelMilestonesUtil.isUnlocked(state: Data.PlayerData, levelIndex: number)
    local milestonesState = state.milestones
    local milestoneInfo = milestonesState and milestonesState[levelIndex]
    local purchased = milestoneInfo and milestoneInfo.purchased
    if purchased then
        return true
    end

    local inventoryState = state.inventory
    local xp = inventoryState[ItemType.XP] or 0
    local level = PlayerUtil.calculateLevel(xp)
    local metadata = LevelMilestones.METADATA[levelIndex]
    local requiredLevel = metadata.requiredLevel
    if level < requiredLevel then
        return false
    end
    
    return true
end

function LevelMilestonesUtil.isClaimed(state: Data.PlayerData, levelIndex: number)
    local milestonesState = state.milestones
    local milestoneInfo = milestonesState and milestonesState[levelIndex]
    local claimed = milestoneInfo and milestoneInfo.claimed
    return claimed
end

function LevelMilestonesUtil.canClaim(state: Data.PlayerData, levelIndex: number)
    local isClaimed = LevelMilestonesUtil.isClaimed(state, levelIndex)
    if isClaimed then
        return false, `You have already claimed this milestone!`
    end
    
    local metadata = LevelMilestones.METADATA[levelIndex]
    local requiredLevel = metadata and metadata.requiredLevel
    local isUnlocked = LevelMilestonesUtil.isUnlocked(state, levelIndex)
    if not isUnlocked then
        return false, `You need to be level {requiredLevel} to unlock this milestone!`
    end

    return true
end

function LevelMilestonesUtil.getRewards(state: Data.PlayerData, indices: { number })
    local totalRewards = {}
    for _, index in indices do
        local metadata = LevelMilestones.METADATA[index]
        local rewards = metadata.rewards
        for itemType, amount in rewards do
            totalRewards[itemType] = (totalRewards[itemType] or 0) + amount
        end
    end
    return totalRewards
end

function LevelMilestonesUtil.getAllClaimableMilestones(state: Data.PlayerData)
    local claimableMilestones = {}
    for _, milestoneInfo in LevelMilestones.METADATA do
        local levelIndex = milestoneInfo.requiredLevel
        local canClaim = LevelMilestonesUtil.canClaim(state, levelIndex)
        if canClaim then
            table.insert(claimableMilestones, levelIndex)
        end    
    end
    return claimableMilestones
end

function LevelMilestonesUtil.getSkipGamepass(state: Data.PlayerData)
    local levelMilestonesState = state and state.milestones
    local nextLevelIndex = levelMilestonesState and #levelMilestonesState + 1
    if not nextLevelIndex then
        return nil
    end

    local tierInterval = math.clamp(math.ceil(nextLevelIndex / LevelMilestones.TIER_INTERVALS), 1, #LevelMilestones.SKIP_GAMEPASSES)
    return LevelMilestones.SKIP_GAMEPASSES[tierInterval]
end

return LevelMilestonesUtil
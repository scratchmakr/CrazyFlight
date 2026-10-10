local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LuckyBlockConfig = require(ReplicatedStorage.Shared.Constants.Configs.LuckyBlockConfig)
local WeightUtil = require(script.Parent.WeightUtil)
local Equipment = require(ReplicatedStorage.Shared.Constants.Equipment)
local LuckyBlocks = require(ReplicatedStorage.Shared.Constants.LuckyBlocks)
local Reroll = require(ReplicatedStorage.Shared.Constants.Reroll)
local LuckyBlockFormat = require(ReplicatedStorage.Shared.Formats.LuckyBlockFormat)
local EquipmentTypes = require(ReplicatedStorage.Shared.Types.EquipmentTypes)

local LuckyBlockUtil = {}
local MAX_CHAIN_LENGTH = 4
local LUCK_REROLL_SALT = 0x2468ACE0
local REWARD_SALT = 0x5A17BEEF

function LuckyBlockUtil.getMetadata(luckyBlockType: string): LuckyBlocks.LuckyBlockInfo
    return LuckyBlocks.METADATA[luckyBlockType]
end

function LuckyBlockUtil.getAllEquipmentWeights(skew: number)
    local weights = {}
    for tabType, tabMetadata in Equipment.METADATA do
        for equipmentType, equipmentInfo in tabMetadata do
            local rngInfo = equipmentInfo.rngInfo
            if not rngInfo then
                continue
            end
            local chance = rngInfo.chance
            if chance <= 0 then
                continue
            end
            weights[equipmentType] = chance
        end
    end
    return weights
end

function LuckyBlockUtil.getEquipmentWeights(luckyBlockType: string)
    local weights = {}
    local metadata = LuckyBlockUtil.getMetadata(luckyBlockType)
    if not metadata then
        return weights
    end

    local skew = metadata.skew or 1
    local tabMetadata = Equipment.METADATA[metadata.tabType] :: Equipment.GeneralStructure
    if not tabMetadata then
        if metadata.tabType == EquipmentTypes.TabType.ALL then
            weights = LuckyBlockUtil.getAllEquipmentWeights(skew)
        end
        return weights
    end

    -- TODO: Add equipped weights
    for equipmentType, equipmentInfo in tabMetadata do
        local rngInfo = equipmentInfo.rngInfo
        if not rngInfo then
            continue
        end
        local chance = rngInfo.chance
        if chance <= 0 then
            continue
        end
        weights[equipmentType] = chance
    end
    WeightUtil.applyLuck(weights, skew)

    return weights
end

function LuckyBlockUtil.injectRerolls(weights: {[string]: number})
    weights = table.clone(weights)
    local totalWeight = WeightUtil.getTotalWeight(weights)
    for rerollType, rerollInfo in Reroll.METADATA do
        local percentage = rerollInfo.percentage / 100
        local weight = WeightUtil.getInjectedWeight(totalWeight, percentage)
        weights[rerollType] = weight
    end

    return weights
end

function LuckyBlockUtil.rollLuckyBlock(context: LuckyBlockFormat.RollContext): {string}
    local rewardSequence = {}
    local blockType = context.blockType
    local seed = context.seed
    local random = Random.new(seed)
    local baseWeights = LuckyBlockUtil.getEquipmentWeights(blockType)
    local injectedWeights = LuckyBlockUtil.injectRerolls(baseWeights)
    local luck = 1
    local rollIndex = 1

    while true do
        local rollSeed = WeightUtil.getRollSeed(seed, rollIndex)
        random = Random.new(rollSeed)

        local weightTable = rollIndex >= MAX_CHAIN_LENGTH and baseWeights or injectedWeights
        local rolledItem = WeightUtil.getRandomKeyFromDictionary(weightTable, random)

        local luckMetadata = Reroll.METADATA[rolledItem]
        local luckMultiplier = luckMetadata and luckMetadata.luckMultiplier or 1
        luck *= luckMultiplier
        local adjustedWeights = WeightUtil.applyLuck(baseWeights, luck)
        local rewardSeed = WeightUtil.mixSeed(
            rollSeed,
            REWARD_SALT
        )

        local rewardRandom = Random.new(rewardSeed)
        local reward = WeightUtil.getRandomKeyFromDictionary(adjustedWeights, rewardRandom)
        table.insert(rewardSequence, luckMetadata and rolledItem or reward)
        if not luckMetadata or rollIndex >= MAX_CHAIN_LENGTH then
            return rewardSequence
        end

        rollIndex += 1
    end

    return rewardSequence
end

function LuckyBlockUtil.getTotalRollTime(rollSequence: {string})
    local totalRolls = #rollSequence
    local rollTime = LuckyBlockConfig.ROLL_TIME * totalRolls
    local selectTime = LuckyBlockConfig.SELECT_TIME * (totalRolls - 1)
    return rollTime + selectTime
end

return LuckyBlockUtil
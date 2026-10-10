local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RerollType = require(ReplicatedStorage.Shared.Types.RerollType)
local Weight = {}
local LUCK_STRENGTH = 1.5
local ROLL_SALT = 0x13579BDF

function Weight.mixSeed(seed: number, salt: number): number
    local x = bit32.bxor(seed, salt)

    -- xorshift32
    x = bit32.bxor(x, bit32.lshift(x, 13))
    x = bit32.bxor(x, bit32.rshift(x, 17))
    x = bit32.bxor(x, bit32.lshift(x, 5))

    return x
end

function Weight.getRollSeed(baseSeed: number, rollIndex: number): number
    return Weight.mixSeed(
        Weight.mixSeed(baseSeed, ROLL_SALT),
        rollIndex
    )
end

function Weight.getRandomKeyFromDictionary(dict: {[unknown]: number}, random: Random?)
	local totalWeight = 0
	for _, weight in dict do
		if typeof(weight) == "number" then
			totalWeight += weight
		end
	end
	local counter =	(random or Random.new()):NextNumber(0, totalWeight)
	for key, weight in dict do
		counter -= weight
		if counter <= 0 then
			return key
		end
	end
end

function Weight.getInjectedWeight(currentTotal: number, desiredChance: number): number
    return (desiredChance * currentTotal) / (1 - desiredChance)
end

function Weight.applyLuck(weights: {[string]: number}, luck: number)
    local adjustedWeights = {}

    local maxWeight = 0
    for _, weight in weights do
        maxWeight = math.max(maxWeight, weight)
    end

    for key, weight in weights do
        if table.find(RerollType, key) then
            continue
        end
        local normalizedWeight = weight / maxWeight

        local rarityAlpha = (1 - normalizedWeight) ^ LUCK_STRENGTH
        local multiplier = luck ^ rarityAlpha

        adjustedWeights[key] = weight * multiplier
    end

    return adjustedWeights
end

function Weight.getTotalWeight(dict: {[unknown]: number})
	local totalWeight = 0
	for _, weight in dict do
		if typeof(weight) == "number" then
			totalWeight += weight
		end
	end
	return totalWeight
end

return Weight

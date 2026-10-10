local PlayerUtil = {}

function PlayerUtil.calculateLevel(totalXP: number)
    local level = 1
    local currentXp = totalXP

    while currentXp >= PlayerUtil.calculateXP(level) do
        currentXp -= PlayerUtil.calculateXP(level)
        level += 1
    end

    return level, currentXp -- leftover xp
end

function PlayerUtil.calculateXP(level: number)
    return math.floor(100 * (1.25 ^ (level - 1)))
end

return PlayerUtil
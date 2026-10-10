local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Configs = {
    DatastoreMutator = "v6",
    LeaderboardMutator = "v6",
    GroupId = 34125659,
    ConchAdmins = {
        "58427452", -- kedo
        "139050819", -- aaron
        "139045890", -- alex
        "4431631146", -- nathan
        "2969685850", -- kyle (scratchmakr)
        "320880981", -- kyle (Crypt0Crash)
    },

    SNAPSHOT_INTERVAL = 0.1,
    MAX_SNAPSHOT_HISTORY = 100,
    DEFAULT_BULLET_SIZE = Vector3.one * 0.75,
}

if RunService:IsStudio() then
    Configs.DatastoreMutator = "studio"
    Configs.LeaderboardMutator = "studio"
end

return Configs
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Data = require(ReplicatedStorage.Shared.Constants.Data)
export type RollContext = {
    blockType: string,
    seed: number,
    playerState: Data.PlayerState?,
}

export type DisplayRollContext = {
    userId: number,
} & RollContext

return {}
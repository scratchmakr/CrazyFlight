local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RblxUtils = require(ReplicatedStorage.Packages.RblxUtils)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Data = require(ReplicatedStorage.Shared.Constants.Data)
local Network = require(ReplicatedStorage.Shared.Network)
local Symbols = require(ReplicatedStorage.Shared.Types.Symbols)
local TableUtil = require(ReplicatedStorage.Shared.Utilities.TableUtil)

export type Context = {
    player: Player,
    state: Data.PlayerState?,
}

local PlayerClass = {}
PlayerClass.__index = PlayerClass

function PlayerClass.new(context: Context)
    local player = context.player
    local userId = tostring(player.UserId)
    local self = setmetatable({
        userId = userId,
        attributes = context.state or RblxUtils.Table.deepCopy(Data.STATE_TEMPLATE),
        masterTrove = Trove.new(),
    }, PlayerClass)
    return self
end

export type Self = typeof(PlayerClass.new(...))
export type Attributes = typeof(({} :: Self).attributes)

function PlayerClass.updateAttributes(self: Self, attributes: Attributes)
    local userId = self.userId
    local updatedAttributes = RblxUtils.Table.deepCopy({
        [userId] = attributes and RblxUtils.Table.merge(self.attributes, attributes) or Symbols.NIL_SYMBOL
    })
    Network.Player.Update_Player_Attributes:Server():FireAll(updatedAttributes)

    if attributes then
        self.attributes = TableUtil.deepMerge(self.attributes, attributes)
    end
end

function PlayerClass.destroy(self: Self)
    local masterTrove = self.masterTrove
    if masterTrove then
        masterTrove:Destroy()
    end
    self:updateAttributes(nil)
    setmetatable(self, nil)
end

return PlayerClass
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Charm = require(ReplicatedStorage.Packages.Charm)
local RblxUtils = require(ReplicatedStorage.Packages.RblxUtils)
local Data = require(ReplicatedStorage.Shared.Constants.Data)

type Accounts = { [string]: Data.PlayerData }

local getAccounts, setAccounts = Charm.signal({} :: Accounts)

local DataStore = {
    getAccounts = getAccounts,
    setAccounts = setAccounts,
}

function DataStore.setAccount(userId: number, account: Data.PlayerData)
    local current = RblxUtils.Table.deepCopy(getAccounts())
    current[tostring(userId)] = account
    setAccounts(current)
end

function DataStore.removeAccount(player: Player)
    local current = RblxUtils.Table.deepCopy(getAccounts())
    current[tostring(player.UserId)] = nil
    setAccounts(current)
end

function DataStore.getAccount(player: Player): Data.PlayerData
    return getAccounts()[tostring(player.UserId)]
end

return DataStore
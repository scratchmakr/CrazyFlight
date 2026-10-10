local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Charm = require(ReplicatedStorage.Packages.Charm)
local Data = require(ReplicatedStorage.Shared.Constants.Data)

local DataStore = require(ServerScriptService.Server.Stores.DataStore)
local Lyra = require(ReplicatedStorage.Packages.Lyra)
local RblxUtils = require(ReplicatedStorage.Packages.RblxUtils)
local Configs = require(ReplicatedStorage.Shared.Constants.Configs)
local ItemType = require(ReplicatedStorage.Shared.Types.ItemType)
local StringUtil = require(ReplicatedStorage.Shared.Utilities.StringUtil)
local PlayerClass = require(ReplicatedStorage.Shared.Classes.Player)

local config: Lyra.PlayerStoreConfig<Data.PlayerData> = {
    name = `PlayerData_{Configs.DatastoreMutator}`,
    template = Data.TEMPLATE,
    schema = function(data)
        local success, err = Data.DataCheck:matches(data)
        return success, tostring(err) 
    end,
    migrationSteps = {
        -- Lyra.MigrationStep.addFields("marketplace_v1", {
        --     marketplace = Marketplace.TEMPLATE,
        -- }),
        -- Lyra.MigrationStep.addFields("equipment_index_v1", {
        --     equipmentIndex = EquipmentIndex.TEMPLATE,
        -- }),
    },
    changedCallbacks = {
        function(key, newData)
            -- print("DataService.changedCallbacks", key, newData)
            DataStore.setAccount(tonumber(key) :: number, newData)
        end,
    }
}

local DataService = {
    store = Lyra.createPlayerStore(config),
    onLoaded = {} :: { (player: Player) -> () },
    onBeforeUnload = {} :: { (player: Player) -> () },
    clientsReady = {} :: { [number]: boolean },
    playerClasses = {} :: { [number]: PlayerClass.Self },
}

function DataService._onLoaded(fn: (player: Player) -> ())
    table.insert(DataService.onLoaded, fn)
end

function DataService._onBeforeUnload(fn: (player: Player) -> ())
    table.insert(DataService.onBeforeUnload, fn)
end

function DataService._ClientReady(player: Player)
    local userId = player.UserId
    DataService.clientsReady[userId] = true
end

function DataService._PlayerAdded(player: Player)
    local userId = player.UserId
    DataService.store:load(player):andThen(function()
        while not DataService.clientsReady[userId] do
            -- print("waiting for client ready", userId)
            task.wait()
        end

        task.defer(function()
            for _, fn in DataService.onLoaded do
                task.spawn(fn, player)
            end
        end)
    end)
    DataStore.setAccount(userId, DataService.store:peek(userId))

    DataService.createPlayerClass(userId)
    local leaderstats = Instance.new("Folder", player)
    leaderstats.Name = "leaderstats"

    local money = Instance.new("StringValue", leaderstats)
    money.Name = "Money"

    local disconnect = Charm.effect(function()
        local account = DataStore.getAccount(player)
        local inventory = account and account.inventory
        money.Value = StringUtil.abbreviateNumber(inventory and inventory[ItemType.MONEY] or 0)
    end)

    DataService._onBeforeUnload(function(playerRemoved: Player)
        if playerRemoved ~= player then
            return
        end
        
        disconnect()
    end)
end

function DataService._PlayerRemoving(player: Player)
    local userId = player.UserId
    DataService.clientsReady[userId] = nil
    for _, fn in DataService.onBeforeUnload do
        local ok, err = pcall(fn, player)
        if not ok then
            warn("DataService onBeforeUnload error", err)
        end
    end
    local plrClass = DataService.playerClasses[userId]
    if plrClass then
        plrClass:destroy()
        DataService.playerClasses[userId] = nil
    end
    
    DataService.store:updateImmutable(player, function(state)
        return RblxUtils.Table.merge(state, {
            lastLeave = math.round(workspace:GetServerTimeNow()),
        })
    end)
    DataService.store:unload(player)
end

function DataService.getPlayerState(userId: number): Data.PlayerState
    local player = Players:GetPlayerByUserId(userId)
    local account = player and DataStore.getAccount(player)
    if not account then
        return RblxUtils.Table.deepCopy(Data.STATE_TEMPLATE)
    end
    
    return RblxUtils.Table.deepCopy({
        trackedStats = account.trackedStats,
        titles = account.titles,
        inventory = account.inventory,
    })
end

function DataService.getPlayerClass(userId: number): PlayerClass.Self?
    local playerClass = DataService.playerClasses[userId]
    if not playerClass then
        return
    end
    return playerClass
end

function DataService.createPlayerClass(userId: number): PlayerClass.Self
    local playerClass = PlayerClass.new({
        player = Players:GetPlayerByUserId(userId),
        data = DataService.getPlayerState(userId),
    })
    DataService.playerClasses[userId] = playerClass
    return playerClass
end

function DataService.broadcastPlayerState(
    player: Player,
    attributes: PlayerClass.Attributes -- ensure [key] = attributes[key]
)
    local userId = player.UserId
    local playerClass = DataService.getPlayerClass(userId) or DataService.createPlayerClass(userId)

    if playerClass then
        playerClass:updateAttributes(attributes)
    end

    DataService.playerClasses[userId] = playerClass
end

function DataService.updatePlayerState(player: Player, dataKey: string, keysToUpdate: { string }?, data: { [string]: any }?)
    local account = DataStore.getAccount(player)
    if not account then
        return
    end

    data = data or account[dataKey]
    if not data then
        return
    end

    local broadcastAttributes = {}
    for _, key in keysToUpdate or RblxUtils.Table.keys(data) do
        broadcastAttributes[key] = data[key]
    end

    DataService.broadcastPlayerState(player, {
        [dataKey] = broadcastAttributes,
    })

    return true
end

function DataService.getOfflineAccount(userId: number)
    local ok, data = pcall(function()
        return DataService.store:peekAsync(tonumber(userId))
    end)

    if not ok then
        warn("Error getting offline account", data)
        return nil
    end

    return data or Data.TEMPLATE
end

function DataService.updateImmutableForUserId(
    userId: number,
    transform: (Data.PlayerData) -> Data.PlayerData | false
): boolean
    local player = Players:GetPlayerByUserId(userId)
    if player then
        local ok, result = pcall(function()
            return DataService.store:updateImmutableAsync(player, transform)
        end)
        return ok and result == true
    end

    local store = (DataService.store :: any)._store
    local key = tostring(userId)
    local loadOk, loadErr = pcall(function()
        store:loadAsync(key, { userId })
    end)
    if not loadOk then
        warn("DataService.updateImmutableForUserId load failed", userId, loadErr)
        return false
    end

    local ok, err = pcall(function()
        local updated = store:updateImmutableAsync(key, transform)
        assert(updated, "updateImmutableAsync returned false")
        store:saveAsync(key)
    end)
    if not ok then
        warn("DataService.updateImmutableForUserId update failed", userId, err)
    end

    pcall(function()
        store:unloadAsync(key)
    end)

    return ok
end

function DataService.updateAndSaveForUserId(
    userId: number,
    transform: (Data.PlayerData) -> Data.PlayerData | false
): boolean
    local player = Players:GetPlayerByUserId(userId)
    if player then
        local ok, result = pcall(function()
            return DataService.store:updateImmutableAsync(player, transform)
        end)
        if not (ok and result == true) then
            return false
        end

        local saveOk = pcall(function()
            DataService.store:saveAsync(player)
        end)
        return saveOk
    end

    return DataService.updateImmutableForUserId(userId, transform)
end

game:BindToClose(function() -- ensures doesn't force quit
    task.wait()
    DataService.store:closeAsync()
end)

return DataService
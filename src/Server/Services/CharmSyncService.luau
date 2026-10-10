local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local Signal = require(ReplicatedStorage.Packages.Signal)

local ServerScriptService = game:GetService("ServerScriptService")
local DataService = require(script.Parent.DataService)
local Charm = require(ReplicatedStorage.Packages.Charm)
local CharmSync = require(ReplicatedStorage.Packages.CharmSync)
local Network = require(ReplicatedStorage.Shared.Network)

local DataStore = require(ServerScriptService.Server.Stores.DataStore)
local ServerEvents = require(ServerScriptService.Server.ServerEvents)

local CharmSyncService = {}

function CharmSyncService._PlayerRemoving(player: Player)
    local returnSignal = Signal.new()
	local trove = Trove.new()
    local user = tostring(player.UserId)
	
    local signalsSent = 0
    local returnedSignals = 0
    trove:Add(returnSignal:Connect(function()
        returnedSignals += 1
    end))
    for _, signal in ServerEvents.PlayerLeftSignals do
        --print("iterating: ", user)
        signal:Fire({user = user, returnSignal = returnSignal, plr = player})
        signalsSent += 1
    end
    local timeout = 3
    local time = tick()
    repeat
        task.wait()
        --print("signals sent vs returned", signalsSent, returnedSignals)
    until returnedSignals >= signalsSent or tick() - time >= timeout
    trove:Destroy()
    DataStore.setAccount(player.UserId, {lastLeave = math.round(workspace:GetServerTimeNow())})
    CharmSync.server.removeClient(player)
end

function CharmSyncService._Init()
    CharmSync.server.connect(function(player, data)
        Network.Charm.patch:Server():Fire(player, data)
    end)
    Network.Charm.ready:Server():On(function(player: Player)
        CharmSync.server.addSignalsToClient(player, {
            [`data-{player.UserId}`] = Charm.computed(function()
                return DataStore.getAccount(player)
            end),
        })
        ServerEvents.ClientReady:Fire(player)
    end)

    -- DataService._onLoaded(function(player: Player)
    --     print("CharmSyncService.DataService._onLoaded", player)
    --     CharmSync.server.addSignalsToClient(player, {
    --         data = Charm.computed(function()
    --             local data = DataStore.getAccount(player)
    --             print("CharmSyncService.data", player, data)
    --             return data
    --         end),
    --     })
    -- end)
end

return CharmSyncService

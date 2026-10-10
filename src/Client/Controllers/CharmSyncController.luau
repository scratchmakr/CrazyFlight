local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Store = require(StarterPlayer.StarterPlayerScripts.Client.Store)
local UIEvents = require(StarterPlayer.StarterPlayerScripts.Client.UIEvents)
local CharmSync = require(ReplicatedStorage.Packages.CharmSync)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Network = require(ReplicatedStorage.Shared.Network)

local CharmSyncController = {
    _dataLoaded = Fusion.Value(false),
}

function CharmSyncController._Init()
    CharmSync.client.addSignals({
        [`data-{LocalPlayer.UserId}`] = Store.setData, 
    })

    Network.Charm.patch:Client():On(function(data)
        CharmSync.client.patch(data)
        UIEvents.DataLoaded:Fire()
    end)
end

function CharmSyncController._Start()
    Network.Charm.ready:Client():Fire()
end

function CharmSyncController.getDataLoaded()
    return CharmSyncController._dataLoaded
end

return CharmSyncController
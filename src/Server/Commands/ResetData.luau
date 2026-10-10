local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Conch = require(ReplicatedStorage.Packages.Conch)
local DataService = require(ServerScriptService.Server.Services.DataService)
local Data = require(ReplicatedStorage.Shared.Constants.Data)

Conch.register("reset-data", {
    description = "Reset the data for a player",
    permissions = { "data-destructive" },
    arguments = function()
        return Conch.args.player("Player", "The player to reset the data for")
    end,
    callback = function(player: Player)
        DataService.store:updateImmutable(player, function(data: Data.PlayerData)
            return Data.TEMPLATE
        end)

        if RunService:IsStudio() then
            return
        end
        player:Kick("Reset data! Please rejoin.")
    end
})

return {}


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Red = require(ReplicatedStorage.Packages.Red)
local Data = require(ReplicatedStorage.Shared.Constants.Data)

return {
    ready = Red.Event("ready", function()
        return 
    end),

    patch = Red.Event("patch", function(data)
        return data :: Data.PlayerData
    end),
}
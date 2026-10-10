local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Obtain = require(StarterPlayer.StarterPlayerScripts.Client.Classes.Obtain)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local ImpactFXType = require(ReplicatedStorage.Shared.Types.Cosmetics.ImpactFXType)
local CrateType = require(ReplicatedStorage.Shared.Types.CrateType)
return {
    fusion = Fusion,
    story = function()
        task.spawn(function()
            local obtainClass = Obtain.new({
                items = {
                    {
                        itemType = CrateType.CRATE,
                        amount = 1,
                    }
                },
            })
            obtainClass:next()
        end)
        return 
    end,
}
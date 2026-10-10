local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local DataService = require(ServerScriptService.Server.Services.DataService)
local Conch = require(ReplicatedStorage.Packages.Conch)
local RblxUtils = require(ReplicatedStorage.Packages.RblxUtils)
local Items = require(ReplicatedStorage.Shared.Constants.Items)
local ItemEnum = require(ReplicatedStorage.Shared.Types.Enums.ItemEnum)

Conch.register("grant-item", {
    description = "Grant items to a player",
    permissions = { "data-destructive" },
    arguments = function()
        return Conch.args.player("Player", "The player to grant the brainrot to"),
        ItemEnum("Item", "The item to grant to the player"),
        Conch.args.number("Amount", "The amount of items to grant to the player")
    end,
    callback = function(player: Player, item: string, amount: number)
        if typeof(item) ~= "string" then
            Conch.log("error", "Item must be a string")
            return
        end

        if typeof(amount) ~= "number" then
            Conch.log("error", "Amount must be a number")
            return
        end

        local metadata = Items.METADATA[item]
        if not metadata then
            Conch.log("error", "Item not found")
            return
        end

        DataService.store:updateImmutable(player, function(state)
            local inventory = RblxUtils.Table.deepCopy(state.inventory)
            inventory[item] = (inventory[item] or 0) + amount
            return RblxUtils.Table.merge(state, {
                inventory = inventory,
            })
        end)
        
        Conch.log("success", `{amount} {metadata.name} granted to {player.Name}`)
    end
})

return {}


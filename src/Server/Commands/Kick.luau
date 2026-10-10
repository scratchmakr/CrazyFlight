local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Conch = require(ReplicatedStorage.Packages.Conch)

Conch.register("kick", {
    description = "Kick a player",
    permissions = { "moderator" },
    arguments = function()
        return Conch.args.player("Player", "The player to kick"),
        Conch.args.string("Reason", "The reason for the kick")
    end,
    callback = function(player: Player, reason: string)
        reason = reason or "No reason provided."
        player:Kick(reason)
        Conch.log("success", `Player {player.Name} kicked for {reason}`)
    end
})

return {}


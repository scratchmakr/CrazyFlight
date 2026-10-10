local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local HitmarkerController = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.Equipment.HitmarkerController)
local Hitmarker = require(script.Parent)
local Vide = require(ReplicatedStorage.Packages.Vide)
return {
    vide = Vide,
    story = function()
        local hitmarkerClass = HitmarkerController.applyHitmarkerToRig(workspace.DamageRig, {
            markerId = nil,
            damage = Random.new():NextInteger(1, 100),
            isCritical = true,
        })
        task.delay(3, function()
            hitmarkerClass:destroy()
        end)

        return hitmarkerClass.attributes.hitmarkerUI
    end,
}
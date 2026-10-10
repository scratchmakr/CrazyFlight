local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local UIContainer = require(StarterPlayer.StarterPlayerScripts.Client.Constants.UIContainer)
local RollIndicator = require(script.Parent)
local Vide = require(ReplicatedStorage.Packages.Vide)
local LuckyBlocksType = require(ReplicatedStorage.Shared.Types.LuckyBlocksType)

local FRAME = UIContainer.Screens.RollContainer
return {
    vide = Vide,
    story = function()
        local frame = FRAME:Clone()
        local rollClass = RollIndicator.new({})
        rollClass.frame.Parent = frame
        task.spawn(function()
            task.wait(1)
            rollClass:roll(LuckyBlocksType.DEFAULT_PRIMARY, 1790)
            rollClass.masterTrove:Add(RunService.PreRender:Connect(function(dt: number)
                rollClass:update(dt)
            end))
            task.wait(2)
            -- rollClass:_cleanup()
            -- rollClass:roll(LuckyBlocksType.DEFAULT_PRIMARY, 1234567890)
            task.wait(5)
            rollClass:destroy()
        end)
        return frame 
    end,
}
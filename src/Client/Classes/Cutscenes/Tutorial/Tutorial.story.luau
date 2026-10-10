local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Tutorial = require(script.Parent)
local Fusion = require(ReplicatedStorage.Packages.Fusion)


return {
    fusion = Fusion,
    story = function()
        local screenGui = Fusion.New("Frame") {
            Size = UDim2.fromScale(1, 1),
            BackgroundTransparency = 1,
        }
        local newTutorial = Tutorial.new({
            screenGui = screenGui,
        })
        task.spawn(function()
            newTutorial:start()
            print("newTutorial started", newTutorial)
            task.wait(5)
            newTutorial:destroy()
        end)

        return screenGui
    end
}
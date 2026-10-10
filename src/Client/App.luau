local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
local StarterPlayer = game:GetService("StarterPlayer")
local Vide = require(ReplicatedStorage.Packages.Vide)
local ScreenGui = require(StarterPlayer.StarterPlayerScripts.Client.Utility.ScreenGui)
local PagesFolder = StarterPlayer.StarterPlayerScripts.Client.Pages

local initialized = false
local App = {
    _hudUI = nil :: ScreenGui?,
}

local pages = {}

do
    for _, pageModule in PagesFolder:GetChildren() do
        pages[pageModule.Name] = require(pageModule)
    end
end

function App.Initialize()
    if initialized then
        return
    end
    initialized = true
    local screenUIs = {
        [Enum.ScreenInsets.CoreUISafeInsets.Name] = ScreenGui({
            Name = "CoreUISafeHUD",
            DisplayOrder = 3,
            ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
            Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
        }),
        [Enum.ScreenInsets.DeviceSafeInsets.Name] = ScreenGui({
            Name = "DeviceSafeHUD",
            DisplayOrder = 2,
            ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets,
            Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
        }),
        [Enum.ScreenInsets.None.Name] = ScreenGui({
            Name = "HUD",
            DisplayOrder = 1,
            ScreenInsets = Enum.ScreenInsets.None,
            Parent = Players.LocalPlayer:WaitForChild("PlayerGui"),
        }),
    }
    screenUIs[Enum.ScreenInsets.CoreUISafeInsets.Name].ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
    App._hudUI = screenUIs
    Vide.root(function()
        for _, page in pages do
            if typeof(page) ~= "function" then
                continue
            end
    
            local pageInfo = page()
            if typeof(pageInfo) ~= "table" then
                error(`Page {page} returned invalid page info`)
            end
    
            local screenInsets = pageInfo.screenInsets
            local frame = pageInfo.frame
            if typeof(frame) == "Instance" then
                frame.Parent = App._hudUI[screenInsets.Name]
            else
                warn(`Page returned invalid frame`, page)
            end
        end
    end)
end

return App
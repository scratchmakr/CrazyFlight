local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Loader = require(ReplicatedStorage.Packages.Loader)
local Trove = require(ReplicatedStorage.Packages.Trove)
local StarterPlayer = game:GetService("StarterPlayer")
local App = require(script.App)
local UIEvents = require(StarterPlayer.StarterPlayerScripts.Client.UIEvents)
local ControllersFolder = StarterPlayer.StarterPlayerScripts.Client.Controllers

local modules = Loader.LoadDescendants(ControllersFolder)
local totalModules = #modules
local function doFunction(funcName: string, ...)
    for _, module in modules do
        local func = module[funcName]
        if func then
            task.spawn(function(...)
                local success, err = pcall(func, ...)
                if not success then
                    warn(err)
                end
            end, ...)
        end
    end
end

local debounce
local connectionTrove = Trove.new()
connectionTrove:Add(UIEvents.DataLoaded:Connect(function()
    if debounce then
        return
    end
    debounce = true
    doFunction("_DataLoaded")
    App.Initialize()
    connectionTrove:Destroy()
end))

local currentCharacter

local function onCharacterAdded(character: Model)
    if not character then
        return
    end
    if currentCharacter == character then
        return
    end
    
    currentCharacter = character
    doFunction("_CharacterAdded", character)
end

Players.PlayerAdded:Connect(function(player: Player)
    if player == LocalPlayer then
        return
    end
    doFunction("_PlayerAdded", player)
end)

Players.PlayerRemoving:Connect(function(player: Player)
    if player == LocalPlayer then
        return
    end
    doFunction("_PlayerRemoving", player)
end)

LocalPlayer.CharacterAdded:Connect(onCharacterAdded)
onCharacterAdded(LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait())

local timeOfInitialization = os.clock()
local initializedModules = 0
for _, module in modules do
    local init = module._Init
    if init then
        task.spawn(function()
            local success, err = pcall(init)
            if not success then
                warn("Error initializing module", module, err)
            end
        end)
        initializedModules += 1
    end
end

while initializedModules < totalModules do
    task.wait()
end
local bootstrapTime = math.round((os.clock() - timeOfInitialization) * 1000)
print(`[Client] bootstrap completed in {bootstrapTime}ms`)
doFunction("_Start")

RunService.PreRender:Connect(function(dt)
    doFunction("_PreRenderUpdate", dt)
end)
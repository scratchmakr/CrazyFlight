local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Loader = require(ReplicatedStorage.Packages.Loader)

local ServerScriptService = game:GetService("ServerScriptService")
local DataService = require(script.Services.DataService)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ServerEvents = require(ServerScriptService.Server.ServerEvents)
local Services = ServerScriptService.Server.Services

local modules = Loader.LoadDescendants(Services)

local RESPAWN_TIME = Players.RespawnTime

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

for _, module in modules do
    local init = module._Init
    if init then
        task.spawn(init)
    end

    local start = module._Start
    if start then
        task.spawn(start)
    end
end

local playersReady = {}

DataService._onLoaded(function(player: Player)
    playersReady[player] = true
end)

ServerEvents.ClientReady:Connect(function(player: Player)
    doFunction("_ClientReady", player)
end)

local playerTroves = {}
local function onPlayerAdded(player: Player)
    -- warn("onPlayerAdded", player.Name)
    doFunction("_PlayerAdded", player)
    local trove = Trove.new()
    playerTroves[player] = trove

    player:LoadCharacterAsync()
    while not playersReady[player] do
        task.wait()
    end

    local function characterAdded(character: Model)
        local function onDied()
            task.wait(RESPAWN_TIME)
            player:LoadCharacterAsync()
        end
        doFunction("_CharacterAdded", player)
        local humanoid = character:FindFirstChildOfClass("Humanoid")
        humanoid.Died:Connect(onDied)
    end
    trove:Add(player.CharacterAdded:Connect(characterAdded))
    characterAdded(player.Character or player.CharacterAdded:Wait())
end

for _, player in Players:GetPlayers() do
    onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player: Player)
    doFunction("_PlayerRemoving", player)
    playersReady[player] = false
    playerTroves[player]:Clean()
    playerTroves[player] = nil
end)

RunService.Heartbeat:Connect(function(dt: number)
    doFunction("_Update", dt)
end)
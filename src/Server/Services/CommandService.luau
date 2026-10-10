local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local Conch = require(ReplicatedStorage.Packages.Conch)
local Configs = require(ReplicatedStorage.Shared.Constants.Configs)

local CommandService = {}

local initialized = false
function CommandService._Init()
    CommandService.initialize()

    Conch.set_role_permissions("admin", "data-destructive", "moderator")
end

function CommandService._Start()
    for _, cmd in ServerScriptService.Server.Commands:GetDescendants() do
        if not cmd:IsA("ModuleScript") then
            continue
        end

        require(cmd)
    end
end

function CommandService.initialize()
    if initialized then
        return
    end
    initialized = true
    Conch.initiate_default_lifecycle()
end

function CommandService._PlayerAdded(player: Player)
    CommandService.initialize()
    local userId = tostring(player.UserId)
    if table.find(Configs.ConchAdmins, userId) or RunService:IsStudio() then
        local user = Conch.get_user(player)
        Conch.give_roles(user, "admin")
    end
end

return CommandService
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Notification = require(StarterPlayer.StarterPlayerScripts.Client.Components.Notification)
local Red = require(ReplicatedStorage.Packages.Red)
local Data = require(ReplicatedStorage.Shared.Constants.Data)
local PerformType = require(ReplicatedStorage.Shared.Types.PerformType)

return {
    -- Server -> Client
    Update_Player_Attributes = Red.Event("Update_Player_Attributes", function(attributes)
        return attributes :: Data.PlayerState
    end),

    Display_Crate_Rewards = Red.Event("Display_Crate_Rewards", function(context)
        return context :: {
            crateType: string,
            rewardSeed: number,
        }
    end),

    -- Client -> Server
    Client_AntiCheat_Detected = Red.Event("Client_AntiCheat_Detected", function()
        return
    end),
    
    Apply_Environment = Red.Event("Apply_Environment", function(lightingType)
        assert(typeof(lightingType) == "string", "Lighting type must be a string")
        return lightingType :: string
    end),

    Pressed_Key = Red.Event("Pressed_Key", function()
        return
    end),
    
    Send_Notification = Red.Event("Send_Notification", function(notification)
        return notification :: Notification.notificationProps
    end),
    
    Complete_Tutorial_Step = Red.Event("Complete_Tutorial_Step", function(step)
        assert(typeof(step) == "string", "Step must be a string")
        return step :: string
    end),

    Show_RewardObtainment = Red.Event("Show_RewardObtainment", function(rewards)
        return rewards :: PerformType.Perform
    end),

    Prompt_Purchase = Red.Function("Prompt_Purchase", function(gamepassType)
        return gamepassType :: string
    end, function(success, errorMessage, promptProductId, promptIsProduct)
        return success, errorMessage :: string, promptProductId :: number?, promptIsProduct :: boolean?
    end),

    Claim_Level_Milestone = Red.Function("Claim_Level_Milestone", function(index)
        return index :: number
    end, function(success, errorMessage)
        return success :: boolean, errorMessage :: string
    end),

    Claim_All_Level_Milestones = Red.Function("Claim_All_Level_Milestones", function()
        return
    end, function(success, errorMessage)
        return success :: boolean, errorMessage :: string
    end),

    Adjust_Setting = Red.Function("Adjust_Setting", function(settingType, value)
        return settingType :: string, value :: any
    end, function(success, errorMessage)
        return success :: boolean, errorMessage :: string
    end),

    Claim_Group_Rewards = Red.Function("Claim_Group_Rewards", function()
        return
    end, function(success, errorMessage)
        return success :: boolean, errorMessage :: string
    end),

    Toggle_Equip_Title = Red.Function("Toggle_Equip_Title", function(titleType)
        return titleType :: string
    end, function(success, errorMessage)
        return success :: boolean, errorMessage :: string
    end),
}
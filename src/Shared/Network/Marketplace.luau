local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Red = require(ReplicatedStorage.Packages.Red)
return {
    PromptPurchase = Red.Event("Prompt-Purchase", function(gamepassType)
        assert(typeof(gamepassType) == "string", "gamepassType must be a string")
        return gamepassType :: string
    end),

    ValidatePurchase = Red.Function("Validate-Purchase", function(gamepassId)
        assert(typeof(gamepassId) == "string", "gamepassId must be a string")
        return gamepassId :: string
    end, function(success, errorMessage, promptProductId, promptIsProduct)
        return success, errorMessage :: string, promptProductId :: number?, promptIsProduct :: boolean?
    end),

    ValidateGift = Red.Function("Validate-Gift", function(gamepassId, targetUserId)
        assert(typeof(gamepassId) == "string", "gamepassId must be a string")
        assert(typeof(targetUserId) == "string", "targetUserId must be a string")
        return gamepassId :: string, targetUserId :: string
        end, function(success, errorMessage, promptProductId, promptIsProduct)
        return success, errorMessage :: string, promptProductId :: number?, promptIsProduct :: boolean?
    end),

    CancelGift = Red.Function("Cancel-Gift", function()
        return
    end, function(success, errorMessage)
        return success, errorMessage :: string
    end),

    DisplayAward = Red.Event("Display-Award", function(gamepassType, gifterUserId)
        assert(typeof(gamepassType) == "string", "gamepassType must be a string")
        assert(gifterUserId == nil or typeof(gifterUserId) == "string", "gifterUserId must be a string or nil")
        return gamepassType :: string, gifterUserId :: string?
    end),
}
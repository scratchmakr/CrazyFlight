local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PurchaseHistory = require(ReplicatedStorage.Shared.Constants.Data.PurchaseHistory)
local Gamepasses = require(ReplicatedStorage.Shared.Constants.Gamepasses)

local GamepassUtil = {}
GamepassUtil.gamepassCache = {} :: { [string]: { [number]: boolean } }
GamepassUtil.gamepassMetadataMap = {}
GamepassUtil.gamepassPriceMap = {}

for _, metadata in Gamepasses.METADATA do
	GamepassUtil.gamepassMetadataMap[metadata.gamepassId] = metadata
end

function GamepassUtil.getGamepassPrice(gamepassType: string): number?
	local metadata = Gamepasses.METADATA[gamepassType]
	if not metadata then
		return nil
	end

	if GamepassUtil.gamepassPriceMap[gamepassType] then
		return GamepassUtil.gamepassPriceMap[gamepassType]
	end

	local isProduct = metadata and metadata.isProduct

	local success, result = pcall(function(...)
		return MarketplaceService:GetProductInfoAsync(
			metadata.gamepassId,
			if isProduct then Enum.InfoType.Product else Enum.InfoType.GamePass
		)
	end)

	if success then
		GamepassUtil.gamepassPriceMap[gamepassType] = result.PriceInRobux
		return result.PriceInRobux
	end

	return nil
end

function GamepassUtil.getGamepassMetadata(gamepassId: number)
	return GamepassUtil.gamepassMetadataMap[gamepassId]
end

function GamepassUtil.hasInternalEntitlement(purchaseHistory: PurchaseHistory.Schema, gamepassType: string): boolean
	local metadata = Gamepasses.METADATA[gamepassType]
	if not metadata then
		return false
	end

	local gamepassId = metadata.gamepassId
	for _, purchaseInfo in purchaseHistory do
		if purchaseInfo.gamepassId == tostring(gamepassId) then
			return true
		end
	end

	return false
end

function GamepassUtil.hasGamepass(player: Player, purchaseHistory: PurchaseHistory.Schema, gamepassType: string)
	local metadata = Gamepasses.METADATA[gamepassType]
	if not metadata then
		return false
	end

	if GamepassUtil.hasInternalEntitlement(purchaseHistory, gamepassType) then
		return true
	end

	local gamepassId = metadata.gamepassId
	local playerId = tostring(player.UserId)
	if not GamepassUtil.gamepassCache[playerId] then
		GamepassUtil.gamepassCache[playerId] = {}
	end

	if GamepassUtil.gamepassCache[playerId][gamepassId] then
		return true
	end

	if metadata.isProduct then
		return false
	end

	local success, hasGamepass = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	end)
	if success and hasGamepass then
		GamepassUtil.gamepassCache[playerId][gamepassId] = true
		return true
	end

	local altGamepassType = metadata.altGamepassType
	if altGamepassType then
		return GamepassUtil.hasGamepass(player, purchaseHistory, altGamepassType)
	end

	return false
end

return GamepassUtil

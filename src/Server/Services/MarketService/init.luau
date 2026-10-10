local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local DataService = require(script.Parent.DataService)
local PerformProduct = require(script.PerformProduct)
local DataStore = require(ServerScriptService.Server.Stores.DataStore)
local Gamepasses = require(ReplicatedStorage.Shared.Constants.Gamepasses)
local Network = require(ReplicatedStorage.Shared.Network)
local RblxUtils = require(ReplicatedStorage.Packages.RblxUtils)
local Data = require(ReplicatedStorage.Shared.Constants.Data)
local MarketplaceData = require(ReplicatedStorage.Shared.Constants.Data.Marketplace)
local PurchaseHistoryData = require(ReplicatedStorage.Shared.Constants.Data.PurchaseHistory)
local PerformType = require(ReplicatedStorage.Shared.Types.PerformType)
local TrackedStatType = require(ReplicatedStorage.Shared.Types.TrackedStatType)
local GamepassUtil = require(ReplicatedStorage.Shared.Utilities.GamepassUtil)

local GIFT_UI_LOCK_SECONDS = 600

local MarketService = {
	outgoingGifts = {} :: { [string]: number },
}

local function getMarketplaceState(state: Data.PlayerData): MarketplaceData.Schema
	return state.marketplace or RblxUtils.Table.deepCopy(MarketplaceData.TEMPLATE)
end

local function purchaseAlreadyRecorded(state: Data.PlayerData, purchaseId: string): boolean
	if purchaseId == "" then
		return false
	end

	if state.purchaseHistory[purchaseId] then
		return true
	end

	for _, receipt in state.purchaseHistory do
		if receipt.purchaseId == purchaseId then
			return true
		end
	end

	return false
end

local function gamepassHistoryKey(gamepassId: number): string
	return `gamepass:{gamepassId}`
end

local function gamepassEntitlementRecorded(state: Data.PlayerData, gamepassId: number): boolean
	local historyKey = gamepassHistoryKey(gamepassId)
	if state.purchaseHistory[historyKey] then
		return true
	end

	for _, receipt in state.purchaseHistory do
		if receipt.gamepassId == tostring(gamepassId) then
			return true
		end
	end

	return false
end

local function countPurchasesForGamepass(
	purchaseHistory: PurchaseHistoryData.Schema,
	gamepassId: number
): number
	local purchases = 0
	for _, receipt in purchaseHistory do
		if tostring(receipt.gamepassId) == tostring(gamepassId) then
			purchases += 1
		end
	end
	return purchases
end

local function mergePerformIntoState(state: Data.PlayerData, perform: PerformType.Perform?): Data.PlayerData
	if not perform or next(perform) == nil then
		return state
	end

	local patch = {} :: { [string]: any }

	-- for rewardType, amount in perform do
	-- 	local tabType = ItemUtil.getTabType(rewardType)
	-- 	if not tabType then
	-- 		continue
	-- 	end

	-- 	if ItemUtil.isCosmetic(rewardType) then
	-- 		patch.cosmetics = patch.cosmetics or RblxUtils.Table.deepCopy(state.cosmetics)
	-- 		local tabState = patch.cosmetics[tabType]
	-- 		if not tabState then
	-- 			tabState = RblxUtils.Table.deepCopy(state.cosmetics[tabType] or {})
	-- 			patch.cosmetics[tabType] = tabState
	-- 		end
	-- 		tabState[rewardType] = {
	-- 			equipped = false,
	-- 			owned = true,
	-- 		}
	-- 	else
	-- 		local tabState = patch[tabType] or RblxUtils.Table.deepCopy(state[tabType])
	-- 		patch[tabType] = tabState
	-- 		tabState[rewardType] = (tabState[rewardType] or 0) + amount
	-- 	end
	-- end

	return RblxUtils.Table.merge(state, patch)
end

local function mergePersistentEntitlementsIntoState(state: Data.PlayerData, gamepassType: string): Data.PlayerData
	-- if table.find(LevelMilestones.SKIP_GAMEPASSES, gamepassType) then
	-- 	local milestoneState = RblxUtils.Table.deepCopy(state.milestones)
	-- 	local nextLevelIndex = #milestoneState + 1
	-- 	milestoneState[nextLevelIndex] = {
	-- 		purchased = true,
	-- 	}
	-- 	return RblxUtils.Table.merge(state, {
	-- 		milestones = milestoneState,
	-- 	})
	-- end

	-- if gamepassType == GamepassType.VIP then
	-- 	local titlesState = RblxUtils.Table.deepCopy(state.titles)
	-- 	if not titlesState[TitleType.VIP] then
	-- 		titlesState[TitleType.VIP] = {
	-- 			equipped = false,
	-- 		}
	-- 	end
	-- 	return RblxUtils.Table.merge(state, {
	-- 		titles = titlesState,
	-- 	})
	-- end

	-- if gamepassType == GamepassType.ABILITY_SLOT_3 then
	-- 	local abilitiesState = RblxUtils.Table.deepCopy(state.abilities)
	-- 	abilitiesState.slots[3] = {
	-- 		type = AbilityType.LOCKED_IN,
	-- 		locked = false,
	-- 	}
	-- 	return RblxUtils.Table.merge(state, {
	-- 		abilities = abilitiesState,
	-- 	})
	-- end

	-- if gamepassType == GamepassType.STYLE_SLOT_4 then
	-- 	local styleStatsState = RblxUtils.Table.deepCopy(state.styleStats)
	-- 	styleStatsState.slots[4] = {
	-- 		style = StyleType.ROOKIE,
	-- 		seed = Random.new():NextInteger(0, 1000000),
	-- 		locked = false,
	-- 	}
	-- 	return RblxUtils.Table.merge(state, {
	-- 		styleStats = styleStatsState,
	-- 	})
	-- end

	return state
end

local function showRewardObtainment(player: Player, gamepassType: string)
	local metadata = Gamepasses.getMetadata(gamepassType)
	local perform = metadata and metadata.perform
	if not perform or next(perform) == nil then
		return
	end

	Network.Player.Show_RewardObtainment:Server():Fire(player, perform)
end

local function isClaimFinalized(claim: any): boolean
	if claim.finalized ~= nil then
		return claim.finalized
	end

	return claim.statsFinalized == true
end

local function clearExpiredUiGiftLock(playerUserId: string)
	local lockTimestamp = MarketService.outgoingGifts[playerUserId]
	if not lockTimestamp then
		return
	end

	if os.time() - lockTimestamp > GIFT_UI_LOCK_SECONDS then
		MarketService.outgoingGifts[playerUserId] = nil
	end
end

local function hasActiveUiGiftLock(playerUserId: string): boolean
	clearExpiredUiGiftLock(playerUserId)
	return MarketService.outgoingGifts[playerUserId] ~= nil
end

local function validatePaidRandomPolicy(player: Player, gamepassMetadata: Gamepasses.Metadata): (boolean, string?)
	local success, policyInfo = pcall(function()
		return PolicyService:GetPolicyInfoForPlayerAsync(player)
	end)

	if success and policyInfo.ArePaidRandomItemsRestricted and gamepassMetadata.isPaidRandomItem then
		return false, "Your country doesn't allow paid random items!"
	end

	return true
end

local function validateTargetUserId(player: Player, targetUserId: string): (number?, string?)
	local targetId = tonumber(targetUserId)
	if not targetId or targetId ~= math.floor(targetId) or targetId <= 0 then
		return nil, "Invalid target user!"
	end

	if targetId == player.UserId then
		return nil, "You cannot gift to yourself!"
	end

	local nameOk = pcall(function()
		return Players:GetNameFromUserIdAsync(targetId)
	end)
	if not nameOk then
		return nil, "Target user not found!"
	end

	return targetId
end

local function getAccountForUserId(userId: number): Data.PlayerData?
	local targetPlayer = Players:GetPlayerByUserId(userId)
	if targetPlayer then
		return DataStore.getAccount(targetPlayer)
	end

	return DataService.getOfflineAccount(userId)
end

local function applyRecipientReceiptState(
	state: Data.PlayerData,
	gamepassType: string,
	receiptInfo: {
		PurchaseId: string,
		CurrencySpent: number?,
		PlayerId: number,
		ProductId: number,
	},
	purchaseKind: Gamepasses.PurchaseKind,
	isGift: boolean,
	gifterUserId: string?,
	queueOfflineGiftNotification: boolean
): Data.PlayerData
	local metadata = Gamepasses.getMetadata(gamepassType)
	if not metadata then
		error("Invalid gamepass type for receipt")
	end

	local purchaseId = receiptInfo.PurchaseId
	if purchaseId == "" then
		error("Developer product receipt missing PurchaseId")
	end

	local currencySpent = receiptInfo.CurrencySpent or 0
	local historyPurchaseId = purchaseId
	local newHistory = RblxUtils.Table.deepCopy(state.purchaseHistory)
	local paymentProductId = if purchaseKind == "GiftProduct"
		then metadata.giftProductId
		else metadata.gamepassId

	newHistory[historyPurchaseId] = {
		gamepassId = tostring(metadata.gamepassId),
		timestamp = os.time(),
		price = currencySpent,
		purchaseId = purchaseId,
		productId = paymentProductId and tostring(paymentProductId) or nil,
		gifted = if isGift then true else nil,
		gifterUserId = gifterUserId,
	}

	local nextState = RblxUtils.Table.merge(state, {
		purchaseHistory = newHistory,
	})

	if metadata.perform then
		nextState = mergePerformIntoState(nextState, metadata.perform)
	end

	nextState = mergePersistentEntitlementsIntoState(nextState, gamepassType)

	if queueOfflineGiftNotification and gifterUserId then
		local pending = RblxUtils.Table.deepCopy(nextState.pendingGiftNotifications or {})
		table.insert(pending, {
			gamepassType = gamepassType,
			gifterUserId = gifterUserId,
		})
		nextState = RblxUtils.Table.merge(nextState, {
			pendingGiftNotifications = pending,
		})
	end

	return nextState
end

type ResolvedClaim = MarketplaceData.ReceiptClaim

local function claimReceiptOnPurchaser(
	purchaserState: Data.PlayerData,
	purchaseId: string,
	productId: number,
	gamepassType: string,
	purchaseKind: Gamepasses.PurchaseKind,
	purchaserUserId: string,
	currencySpent: number
): (Data.PlayerData?, ResolvedClaim?, boolean)
	local marketplace = getMarketplaceState(purchaserState)
	local existingClaim = marketplace.receiptClaims[purchaseId]
	if existingClaim then
		if isClaimFinalized(existingClaim) then
			return nil, existingClaim, true
		end

		return nil, existingClaim, false
	end

	local marketplaceCopy = RblxUtils.Table.deepCopy(marketplace)
	local intent = marketplaceCopy.pendingGiftIntents[tostring(productId)]
	local isGift = intent ~= nil
	if purchaseKind == "GiftProduct" and not isGift then
		return nil, nil, false
	end

	if isGift then
		if intent.gamepassType ~= gamepassType or intent.purchaserUserId ~= purchaserUserId then
			return nil, nil, false
		end
	end

	local recipientUserId = if isGift then intent.recipientUserId else purchaserUserId
	local claim: ResolvedClaim = {
		productId = productId,
		gamepassType = gamepassType,
		recipientUserId = recipientUserId,
		purchaseKind = purchaseKind,
		isGift = isGift,
		gifterUserId = if isGift then purchaserUserId else nil,
		currencySpent = currencySpent,
		finalized = false,
		timestamp = os.time(),
	}
	marketplaceCopy.receiptClaims[purchaseId] = claim

	return RblxUtils.Table.merge(purchaserState, {
		marketplace = marketplaceCopy,
	}), claim, false
end

local function finalizePurchaserReceipt(
	purchaserState: Data.PlayerData,
	purchaseId: string
): Data.PlayerData?
	local marketplace = getMarketplaceState(purchaserState)
	local claim = marketplace.receiptClaims[purchaseId]
	if not claim then
		return nil
	end

	if isClaimFinalized(claim) then
		return purchaserState
	end

	local marketplaceCopy = RblxUtils.Table.deepCopy(marketplace)
	local finalizedClaim = marketplaceCopy.receiptClaims[purchaseId]
	finalizedClaim.finalized = true
	marketplaceCopy.receiptClaims[purchaseId] = finalizedClaim
	marketplaceCopy.pendingGiftIntents[tostring(finalizedClaim.productId)] = nil

	local trackedStatsState = RblxUtils.Table.deepCopy(purchaserState.trackedStats)
	trackedStatsState[TrackedStatType.ROBUX_SPENT] = (trackedStatsState[TrackedStatType.ROBUX_SPENT] or 0)
		+ finalizedClaim.currencySpent

	return RblxUtils.Table.merge(purchaserState, {
		marketplace = marketplaceCopy,
		trackedStats = trackedStatsState,
	})
end

local function runRecipientRuntimeEffects(recipientPlayer: Player, gamepassType: string, isGift: boolean, gifterUserId: string?)
	local performProduct = PerformProduct[gamepassType]
	if performProduct then
		performProduct(recipientPlayer)
	end

	showRewardObtainment(recipientPlayer, gamepassType)

	if isGift then
		Network.Marketplace.DisplayAward:Server():Fire(recipientPlayer, gamepassType, gifterUserId)
	end
end

function MarketService.processReceipt(
	receiptInfo: {
		PlayerId: number,
		ProductId: number,
		PurchaseId: string,
		CurrencySpent: number?,
	}
): Enum.ProductPurchaseDecision
	local purchaseId = receiptInfo.PurchaseId
	if purchaseId == "" then
		warn("MarketService.processReceipt: empty PurchaseId", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseInfo = Gamepasses.getPurchaseInfoByRobloxId(receiptInfo.ProductId)
	if not purchaseInfo then
		warn("MarketService.processReceipt: unknown ProductId", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if purchaseInfo.purchaseKind == "GamePass" then
		warn("MarketService.processReceipt: GamePass receipt routed through ProcessReceipt", receiptInfo.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local gamepassType = purchaseInfo.gamepassType
	local purchaserUserId = tostring(receiptInfo.PlayerId)
	local currencySpent = receiptInfo.CurrencySpent or 0

	local resolvedClaim: ResolvedClaim? = nil
	local alreadyFinalized = false

	local purchaserAccount = getAccountForUserId(receiptInfo.PlayerId)
	local existingClaim = purchaserAccount
		and purchaserAccount.marketplace
		and purchaserAccount.marketplace.receiptClaims[purchaseId]

	if existingClaim and isClaimFinalized(existingClaim) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	if existingClaim then
		resolvedClaim = existingClaim
	else
		local claimOk = DataService.updateAndSaveForUserId(receiptInfo.PlayerId, function(state)
			local nextState, claim, complete = claimReceiptOnPurchaser(
				state,
				purchaseId,
				receiptInfo.ProductId,
				gamepassType,
				purchaseInfo.purchaseKind,
				purchaserUserId,
				currencySpent
			)
			if complete then
				alreadyFinalized = true
				resolvedClaim = claim
				return false
			end
			if not nextState or not claim then
				return false
			end

			resolvedClaim = claim
			return nextState
		end)

		if alreadyFinalized then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		if not claimOk or not resolvedClaim then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end

	local claim = resolvedClaim :: ResolvedClaim
	local recipientUserId = tonumber(claim.recipientUserId)
	if not recipientUserId then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local recipientPlayer = Players:GetPlayerByUserId(recipientUserId)
	local queueOfflineGiftNotification = claim.isGift and recipientPlayer == nil
	local grantedThisAttempt = false

	local recipientOk = DataService.updateAndSaveForUserId(recipientUserId, function(state)
		if purchaseAlreadyRecorded(state, purchaseId) then
			return state
		end

		grantedThisAttempt = true
		return applyRecipientReceiptState(
			state,
			gamepassType,
			receiptInfo,
			purchaseInfo.purchaseKind,
			claim.isGift,
			claim.gifterUserId,
			queueOfflineGiftNotification
		)
	end)

	if not recipientOk then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local finalizeOk = DataService.updateAndSaveForUserId(receiptInfo.PlayerId, function(state)
		return finalizePurchaserReceipt(state, purchaseId)
	end)
	if not finalizeOk then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	MarketService.outgoingGifts[purchaserUserId] = nil

	local purchaserPlayer = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if grantedThisAttempt and recipientPlayer then
		runRecipientRuntimeEffects(recipientPlayer, gamepassType, claim.isGift, claim.gifterUserId)
	end

	if purchaserPlayer then
		if claim.isGift then
			Network.Player.Send_Notification:Server():Fire(purchaserPlayer, {
				message = "Gift purchase successful!",
				type = "success",
				duration = 5,
			})
		else
			Network.Player.Send_Notification:Server():Fire(purchaserPlayer, {
				message = "Purchase successful!",
				type = "success",
				duration = 5,
			})
		end

		if purchaserPlayer ~= recipientPlayer then
			DataService.updatePlayerState(purchaserPlayer, "trackedStats", { TrackedStatType.ROBUX_SPENT })
		end
	end

	if recipientPlayer and recipientPlayer ~= purchaserPlayer then
		DataService.updatePlayerState(recipientPlayer, "trackedStats")
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function MarketService.processGamepassPurchase(player: Player, gamepassId: number): boolean
	local purchaseInfo = Gamepasses.getPurchaseInfoByRobloxId(gamepassId)
	if not purchaseInfo or purchaseInfo.purchaseKind ~= "GamePass" then
		return false
	end

	local gamepassType = purchaseInfo.gamepassType
	local metadata = Gamepasses.getMetadata(gamepassType)
	if not metadata then
		return false
	end

	local ownsGamepass = RunService:IsStudio() or MarketplaceService:UserOwnsGamePassAsync(player.UserId, gamepassId)
	if not ownsGamepass then
		return false
	end

	local alreadyRecorded = false
	local ok = DataService.updateAndSaveForUserId(player.UserId, function(state)
		if gamepassEntitlementRecorded(state, metadata.gamepassId) then
			alreadyRecorded = true
			return false
		end

		local newHistory = RblxUtils.Table.deepCopy(state.purchaseHistory)
		newHistory[gamepassHistoryKey(metadata.gamepassId)] = {
			gamepassId = tostring(metadata.gamepassId),
			timestamp = os.time(),
			price = 0,
		}

		local nextState = RblxUtils.Table.merge(state, {
			purchaseHistory = newHistory,
		})
		nextState = mergePersistentEntitlementsIntoState(nextState, gamepassType)
		return nextState
	end)

	if alreadyRecorded then
		return true
	end

	if not ok then
		return false
	end

	runRecipientRuntimeEffects(player, gamepassType, false, nil)
	return true
end

function MarketService._Init()
	Network.Marketplace.ValidatePurchase:SetCallback(function(player, gamepassType: string)
		return MarketService.validatePurchase(player, gamepassType)
	end)

	Network.Marketplace.ValidateGift:SetCallback(function(player, gamepassType: string, targetUserId: string)
		return MarketService.validateGift(player, gamepassType, targetUserId)
	end)

	Network.Marketplace.CancelGift:SetCallback(function(player)
		return MarketService.cancelGift(player)
	end)

	Network.Player.Prompt_Purchase:SetCallback(function(player, gamepassType: string)
		return MarketService.validatePurchase(player, gamepassType)
	end)

	MarketplaceService.ProcessReceipt = function(receiptInfo: {
		PlayerId: number,
		ProductId: number,
		PurchaseId: string,
		CurrencySpent: number?,
	})
		return MarketService.processReceipt(receiptInfo)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, gamepassId: number, wasPurchased: boolean)
		if wasPurchased then
			MarketService.processGamepassPurchase(player, gamepassId)
		else
			MarketService.cancelGift(player)
		end
	end)

	DataService._onLoaded(function(player: Player)
		local captured: { { gamepassType: string, gifterUserId: string } } = {}
		local ok = DataService.store:updateImmutableAsync(player, function(state)
			local pending = state.pendingGiftNotifications
			if not pending or #pending == 0 then
				return false
			end
			captured = table.clone(pending)
			return RblxUtils.Table.merge(state, { pendingGiftNotifications = {} })
		end)
		if ok then
			for _, entry in captured do
				Network.Marketplace.DisplayAward:Server():Fire(player, entry.gamepassType, entry.gifterUserId)
				showRewardObtainment(player, entry.gamepassType)
			end
		end
	end)
end

function MarketService._getPurchasesPerGamepassType(player: Player, gamepassType: string)
	local metadata = Gamepasses.getMetadata(gamepassType)
	if not metadata then
		warn("Invalid gamepass type", gamepassType)
		return 0
	end

	local account = DataStore.getAccount(player)
	return countPurchasesForGamepass(account.purchaseHistory, metadata.gamepassId)
end

function MarketService._getPurchasesPerGamepassTypeFromHistory(
	purchaseHistory: PurchaseHistoryData.Schema,
	gamepassType: string
)
	local metadata = Gamepasses.getMetadata(gamepassType)
	if not metadata then
		return 0
	end

	return countPurchasesForGamepass(purchaseHistory, metadata.gamepassId)
end

function MarketService.validatePurchase(player: Player, gamepassType: string)
	local gamepassMetadata = Gamepasses.getMetadata(gamepassType)
	if not gamepassMetadata then
		return false, "Something went wrong, please try again!"
	end

	local purchaseTimes = MarketService._getPurchasesPerGamepassType(player, gamepassType)
	local maxPurchases = gamepassMetadata.maxPurchases
	if maxPurchases and purchaseTimes >= maxPurchases then
		return false, "You have reached the maximum number of purchases for this gamepass!"
	end

	local playerUserId = tostring(player.UserId)
	if hasActiveUiGiftLock(playerUserId) then
		return false, "You are already in the process of gifting a gamepass!"
	end

	local policyOk, policyMessage = validatePaidRandomPolicy(player, gamepassMetadata)
	if not policyOk then
		return false, policyMessage
	end

	local promptProductId = Gamepasses.getPaymentProductId(gamepassType, false)
	if not promptProductId then
		return false, "Something went wrong, please try again!"
	end

	local account = DataStore.getAccount(player)
	local marketplace = account and account.marketplace
	if marketplace and marketplace.pendingGiftIntents[tostring(promptProductId)] then
		return false, "You already have a pending gift for this item!"
	end

	local promptIsProduct = gamepassMetadata.isProduct == true
	return true, nil, promptProductId, promptIsProduct
end

function MarketService.validateGift(player: Player, gamepassType: string, targetUserId: string)
	local playerUserId = tostring(player.UserId)
	local gamepassMetadata = Gamepasses.getMetadata(gamepassType)
	if not gamepassMetadata then
		return false, "Something went wrong, please try again!"
	end

	local targetId, targetError = validateTargetUserId(player, targetUserId)
	if not targetId then
		return false, targetError
	end

	if not gamepassMetadata.isProduct and not gamepassMetadata.giftProductId then
		return false, "This gamepass cannot be gifted!"
	end

	local paymentProductId = Gamepasses.getPaymentProductId(gamepassType, true)
	if not paymentProductId then
		return false, "This gamepass cannot be gifted!"
	end

	if hasActiveUiGiftLock(playerUserId) then
		return false, "You are already in the process of gifting a gamepass!"
	end

	local policyOk, policyMessage = validatePaidRandomPolicy(player, gamepassMetadata)
	if not policyOk then
		return false, policyMessage
	end

	local targetAccount = getAccountForUserId(targetId)
	if not targetAccount then
		return false, "Target user not found!"
	end

	local recipientPurchases = MarketService._getPurchasesPerGamepassTypeFromHistory(targetAccount.purchaseHistory, gamepassType)
	local maxPurchases = gamepassMetadata.maxPurchases
	if maxPurchases and recipientPurchases >= maxPurchases then
		return false, "The recipient already owns this!"
	end

	local targetPlayer = Players:GetPlayerByUserId(targetId)
	if targetPlayer and GamepassUtil.hasGamepass(targetPlayer, targetAccount.purchaseHistory, gamepassType) then
		return false, "The recipient already owns this!"
	end

	local intentSaved = false
	local intentOk = DataService.updateAndSaveForUserId(player.UserId, function(state)
		local marketplace = RblxUtils.Table.deepCopy(getMarketplaceState(state))
		if marketplace.pendingGiftIntents[tostring(paymentProductId)] then
			return false
		end

		marketplace.pendingGiftIntents[tostring(paymentProductId)] = {
			purchaserUserId = playerUserId,
			recipientUserId = tostring(targetId),
			gamepassType = gamepassType,
			productId = paymentProductId,
			purchaseKind = "Gift",
			timestamp = os.time(),
		}

		intentSaved = true
		return RblxUtils.Table.merge(state, {
			marketplace = marketplace,
		})
	end)

	if not intentOk or not intentSaved then
		return false, "You already have a pending gift for this item!"
	end

	MarketService.outgoingGifts[playerUserId] = os.time()

	return true, nil, paymentProductId, true
end

function MarketService.cancelGift(player: Player)
	local playerUserId = tostring(player.UserId)
	MarketService.outgoingGifts[playerUserId] = nil
	return true, "Gift cancelled!"
end

function MarketService.ownsGamepass(player: Player, gamepassType: string)
	local account = DataStore.getAccount(player)
	local purchaseHistory = account and account.purchaseHistory
	if not purchaseHistory then
		return false
	end

	return GamepassUtil.hasGamepass(player, purchaseHistory, gamepassType)
end

return MarketService

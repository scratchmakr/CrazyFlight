local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gt = require(ReplicatedStorage.Packages.gt)

export type GiftIntent = {
	purchaserUserId: string,
	recipientUserId: string,
	gamepassType: string,
	productId: number,
	purchaseKind: string,
	timestamp: number,
}

export type ReceiptClaim = {
	productId: number,
	gamepassType: string,
	recipientUserId: string,
	purchaseKind: string,
	isGift: boolean,
	gifterUserId: string?,
	currencySpent: number,
	finalized: boolean,
	timestamp: number,
}

export type Schema = {
	pendingGiftIntents: { [string]: GiftIntent },
	receiptClaims: { [string]: ReceiptClaim },
}

local GiftIntentCheck = gt.build({
	purchaserUserId = gt.string(),
	recipientUserId = gt.string(),
	gamepassType = gt.string(),
	productId = gt.number(),
	purchaseKind = gt.string(),
	timestamp = gt.number(),
})

local ReceiptClaimCheck = gt.build({
	productId = gt.number(),
	gamepassType = gt.string(),
	recipientUserId = gt.string(),
	purchaseKind = gt.string(),
	isGift = gt.boolean(),
	gifterUserId = gt.optional(gt.string()),
	currencySpent = gt.number(),
	finalized = gt.optional(gt.boolean()),
	timestamp = gt.number(),
})

local Marketplace = {}

Marketplace.TEMPLATE = {
	pendingGiftIntents = {} :: { [string]: GiftIntent },
	receiptClaims = {} :: { [string]: ReceiptClaim },
} :: Schema

Marketplace.DataCheck = gt.build({
	pendingGiftIntents = gt.dictionary(gt.string(), GiftIntentCheck),
	receiptClaims = gt.dictionary(gt.string(), ReceiptClaimCheck),
})

return Marketplace

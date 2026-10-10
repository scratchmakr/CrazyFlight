local ReplicatedStorage = game:GetService("ReplicatedStorage")
local gt = require(ReplicatedStorage.Packages.gt)

export type Receipt = {
	gamepassId: string,
	timestamp: number,
	price: number?,
	purchaseId: string?,
	productId: string?,
	gifted: boolean?,
	gifterUserId: string?,
}

export type Schema = {
	[string]: Receipt,
}

local PurchaseHistory = {}
PurchaseHistory.TEMPLATE = {} :: Schema

function PurchaseHistory.addReceipt(gamepassId: string, timestamp: number)
	PurchaseHistory.TEMPLATE[gamepassId] = {
		gamepassId = gamepassId,
		timestamp = timestamp or os.time(),
	}
end

PurchaseHistory.DataCheck = gt.build(gt.dictionary(
	gt.string(),
	gt.build({
		gamepassId = gt.string(),
		timestamp = gt.number(),
		price = gt.optional(gt.number()),
		purchaseId = gt.optional(gt.string()),
		productId = gt.optional(gt.string()),
		gifted = gt.optional(gt.boolean()),
		gifterUserId = gt.optional(gt.string()),
	})
))

return PurchaseHistory

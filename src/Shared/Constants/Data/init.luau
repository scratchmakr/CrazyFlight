local ReplicatedStorage = game:GetService("ReplicatedStorage")

local gt = require(ReplicatedStorage.Packages.gt)

local Items = require(script.Items)
local PurchaseHistory = require(script.PurchaseHistory)
local TrackedStats = require(script.TrackedStats)
local Marketplace = require(script.Marketplace)

local Data = {}

Data.TEMPLATE = {
	inventory = Items.TEMPLATE,
	purchaseHistory = PurchaseHistory.TEMPLATE,

	trackedStats = TrackedStats.TEMPLATE,

	lastLeave = 0,

	pendingGiftNotifications = {} :: {
		{
			gamepassType: string,
			gifterUserId: string,
		}
	},

	marketplace = Marketplace.TEMPLATE,
}

Data.DataCheck = gt.build({
	inventory = Items.DataCheck,
	purchaseHistory = PurchaseHistory.DataCheck,
	trackedStats = TrackedStats.DataCheck,

	lastLeave = gt.number(),

	pendingGiftNotifications = gt.array(gt.build({
		gamepassType = gt.string(),
		gifterUserId = gt.string(),
	})),

	marketplace = Marketplace.DataCheck,
})

Data.STATE_TEMPLATE = {
	trackedStats = TrackedStats.TEMPLATE,
	inventory = Items.TEMPLATE, -- exp for titles
}

export type PlayerData = typeof(Data.TEMPLATE)
export type PlayerState = typeof(Data.STATE_TEMPLATE)

return Data

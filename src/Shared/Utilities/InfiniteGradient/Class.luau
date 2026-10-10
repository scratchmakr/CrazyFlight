local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local module = {}
module.__index = module

export type props = {
	Colors: {Color3},
	Gradient: UIGradient,
	RenderTable: any,
	MasterTrove: Trove.Trove,
	Period: number?,
}

function module.new(props: props)
	local colors = props.Colors
	local gradient = props.Gradient
	local renderTable = props.RenderTable
	local masterTrove = props.MasterTrove
	local period = props.Period
	
	local self = setmetatable({}, module)
	
	self.Colors = colors
	self.Gradient = gradient
	self.MasterTrove = masterTrove
	self.UUID = game.HttpService:GenerateGUID()
	self.RenderTable = renderTable
	self.Period = period
	
	self.AncestryChangedConnection = gradient.AncestryChanged:Connect(function(child, parent)
		if not parent then
			self:Dispose()
		end
	end)

	self.MasterTrove:Add(self.AncestryChangedConnection)
	return self
end

function module:Animate()
	self.RenderTable[self.UUID] = self
end

function module:Stop()
	self.RenderTable[self.UUID] = nil
end

function module:Dispose()
	self.MasterTrove:Destroy()
	self.RenderTable[self.UUID] = nil
	self = nil
end

return module

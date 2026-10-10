local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Trove = require(ReplicatedStorage.Packages.Trove)
local module = {}
module.__index = module

export type props = {
	gradient: UIGradient,
	speed: number,
}

function module.new(props: props, RenderTable, masterTrove: Trove.Trove)
	local gradient = props.gradient
	local speed = props.speed
	local self = setmetatable({}, module)
	
	self.TimeElapsed = 0
	self.Gradient = gradient
	self.Speed = speed
	self.MasterTrove = masterTrove
	self.UUID = game.HttpService:GenerateGUID()
	self.RenderTable = RenderTable
	
	self.AncestryChangedConnection = gradient.AncestryChanged:Connect(function(child, parent)
		if not parent then
			self:Dispose()
		end
	end)

	self.MasterTrove:Add(self.AncestryChangedConnection)
	return self
end

export type Class = typeof(module.new(...))

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

local module = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local renderTable = {}

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Class = require(script.Class)

export type props = {
	gradient: UIGradient,
	show: Fusion.Computed<boolean>?,
	speed: number?,
}

function module:CreateEffect(props: props)	
	local gradient = props.gradient
	local show = props.show
	local speed = props.speed or 10
	local masterTrove = Trove.new()	

	local classProps = {
		gradient = gradient,
		speed = speed,
	}
	local _CreatedClass = Class.new(classProps, renderTable, masterTrove)
	_CreatedClass:Animate()

	if show then
		local function toggleEffects()
			local show = show:get()
			if show then
				_CreatedClass:Animate()
			else
				_CreatedClass:Stop()	
			end
		end
		masterTrove:Add(Fusion.Observer(show):onChange(toggleEffects))
		toggleEffects()
	end
	return _CreatedClass
end

function module:Animate(Class: Class.Class)
	local gradient = Class.Gradient
	local timeElapsed = Class.TimeElapsed
	local speed = Class.Speed
	-- if true then return end
	gradient.Rotation = (timeElapsed * speed) % 360
end

RunService.PostSimulation:Connect(function(dt)
	for _, Class in renderTable do
		Class.TimeElapsed += dt
		module:Animate(Class)
	end
end)

return module



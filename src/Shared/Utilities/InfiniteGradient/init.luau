local module = {}

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RenderTable = {}

local Trove = require(ReplicatedStorage.Packages.Trove)
local Vide = require(ReplicatedStorage.Packages.Vide)
local Class = require(script.Class)
export type props = {
	Gradient: UIGradient,
	Show: Vide.source<boolean>?,
	Period: number?,
}

function module:CreateEffect(props: props)	
	local Gradient = props.Gradient
	local Show = props.Show
	local Period = props.Period

	local masterTrove = Trove.new()
	local colorValues = {}

	for i = 1, #Gradient.Color.Keypoints do
		colorValues[i] = Gradient.Color.Keypoints[i].Value
	end
	
	local _CreatedClass = Class.new({
		Colors = colorValues,
		Gradient = Gradient,
		RenderTable = RenderTable,
		MasterTrove = masterTrove,
		Period = Period,
	})
	_CreatedClass:Animate()

	if Show then
		local function toggleEffects()
			local show = Show()
			if show then
				_CreatedClass:Animate()
			else
				_CreatedClass:Stop()	
			end
		end
		Vide.effect(toggleEffects)
		toggleEffects()
	end
	return _CreatedClass
end

function module:Animate(props: Class.props)
	-- if true then return end
	local colors = props.Colors
	local gradient = props.Gradient
	local period = props.Period or 1.4

	local num_colors = #colors
	local color_length = 1 / num_colors
	local progress = (tick() % period) / period 
	local newColors = {}
	local wrapColor = false

	for i = 1, num_colors + 1 do 
		local color = colors[i] or colors[i-num_colors]
		local position = progress + (i-1)/num_colors 

		if position > 1 then position = position - 1 end 
		if position == 0 or position == 1 then wrapColor = true end 

		table.insert(newColors, ColorSequenceKeypoint.new(position, color))
	end

	if not wrapColor then 
		local indexProgress = ((1 - progress) / color_length) + 1
		local col1 = colors[math.floor(indexProgress)]
		local col2 = colors[math.ceil(indexProgress)] or colors[1]
		local finalCol = col1:Lerp(col2, indexProgress % 1) 

		table.insert(newColors, ColorSequenceKeypoint.new(0, finalCol))
		table.insert(newColors, ColorSequenceKeypoint.new(1, finalCol))
	end

	table.sort(newColors, function(a, b)
		return a.Time < b.Time
	end)
	
	newColors[1]= ColorSequenceKeypoint.new(0, newColors[1].Value) 
	newColors[#newColors]= ColorSequenceKeypoint.new(1, newColors[#newColors].Value) 
	gradient.Color = ColorSequence.new(newColors)
end

RunService.PostSimulation:Connect(function()
	for _, Class in RenderTable do
		module:Animate(Class)
	end
end)

return module



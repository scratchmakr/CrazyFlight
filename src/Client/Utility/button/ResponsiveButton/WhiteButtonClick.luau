local TweenService = game:GetService("TweenService")
local StarterPlayer = game:GetService("StarterPlayer")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIContainer = require(StarterPlayer.StarterPlayerScripts.Client.Constants.UIContainer)
local whiteFrameTemplate = UIContainer.Components.WhiteFrame
local Trove = require(ReplicatedStorage.Packages.Trove)
local Fusion = require(ReplicatedStorage.Packages.Fusion)

export type WhiteOnClick = {
	CornerRadius: UDim,
	Parent: Instance | GuiButton,
	FadeTime: number?,
}

return function(props, click)
	local whiteOnClick = props.WhiteOnClick
	if not whiteOnClick.Parent then whiteOnClick.Parent = props.Button end
	if not whiteOnClick.CornerRadius then whiteOnClick.CornerRadius = UDim.new(0, 0) end
	if not whiteOnClick.FadeTime then whiteOnClick.FadeTime = 0.2 end
	local mainTrove = Trove.new()
	local whiteFrame = props.Button:FindFirstChild("WhiteFrame", true)
	local uiCorner = whiteFrame and whiteFrame:FindFirstChildOfClass("UICorner")
	if not uiCorner then
		whiteFrame = whiteFrameTemplate:Clone()
		whiteFrame.UICorner.CornerRadius = whiteOnClick.CornerRadius
		whiteFrame.Parent = whiteOnClick.Parent
	end
	whiteFrame.BackgroundTransparency = 1
	whiteFrame.Visible = true
	mainTrove:Add(
		Fusion.Observer(click):onChange(function()
			if click:get() == true then
				----print("WHITE FRAME", whiteFrame)
				local subTrove = mainTrove:Extend()
				local fadeTime = whiteOnClick.FadeTime
				local tween = TweenService:Create(whiteFrame, TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 1,
				})
				whiteFrame.BackgroundTransparency = 0.5
				tween:Play()
				subTrove:Add(tween)
				task.delay(fadeTime, function()
					subTrove:Clean()
				end)
			end
		end)
	)
	
	return mainTrove
end

--!strict

--[[
	Name: Shime
	Version: 1.0.1
	Description: Shime is a module that allows you to easily create a shimmer effect on any GuiObject.
	By: @WinnersTakesAll on Roblox & @RyanLua on GitHub

	Creator Marketplace: https://create.roblox.com/marketplace/asset/12959615382
	GitHub: https://github.com/RyanLua/Shime

	Wiki: https://github.com/RyanLua/Shime/wiki
	Getting Started: https://github.com/RyanLua/Shime/wiki/Getting-Started
	Documentation: https://github.com/RyanLua/Shime/wiki/Documentation
]]

--[[
	Copyright 2023 RyanLua
	
	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at
	
		http://www.apache.org/licenses/LICENSE-2.0
	
	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.
]]

local Shime = {}
Shime.__index = Shime

local TweenService = game:GetService("TweenService")
local SHIMMER_START_OFFSET = Vector2.new(-1, 0)
local SHIMMER_END_OFFSET = Vector2.new(1, 0)

-- Create a shimmer frame and return it
local function createShimmer(parent: GuiObject, Gradient: ColorSequence?): Frame
	-- Create a new frame to hold the shimmer
	local frame = Instance.new("Frame")
	frame.Name = "UIShimmer"
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.BackgroundTransparency = 0
	frame.ClipsDescendants = true
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.new(0.5, 0, 0.5, 0)
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = parent

	-- Update the corner radius of the frame when the UICorner or Parent changes
	local function updateCornerRadius()
		if not frame.Parent then return end
		
		if frame.Parent:FindFirstChildOfClass("UICorner") then
			local parentCorner = frame.Parent:FindFirstChildOfClass("UICorner")
			if not parentCorner then return end
			
			-- Create a new UICorner for the frame
			local corner = Instance.new("UICorner")
			corner.CornerRadius = parentCorner.CornerRadius
			corner.Parent = frame

			-- Update the corner radius of the frame when the UICorner changes
			corner:GetPropertyChangedSignal("CornerRadius"):Connect(updateCornerRadius)
		end
	end
	
	frame:GetPropertyChangedSignal("Parent"):Connect(updateCornerRadius)
	updateCornerRadius()
	-- Update the size of the frame when the UIPadding changes
	local function updatePaddingOffset()
		if not frame.Parent then return end
		
		if frame.Parent:FindFirstChildOfClass("UIPadding") then
			local padding = frame.Parent:FindFirstChildOfClass("UIPadding")
			if not padding then return end 
			
			local widthScale = padding.PaddingLeft.Scale + padding.PaddingRight.Scale
			local heightScale = padding.PaddingTop.Scale + padding.PaddingBottom.Scale
			local widthOffset = padding.PaddingLeft.Offset + padding.PaddingRight.Offset
			local heightOffset = padding.PaddingTop.Offset + padding.PaddingBottom.Offset
			local heightDiffOffset = padding.PaddingTop.Offset - padding.PaddingBottom.Offset
			local widthDiffOffset = padding.PaddingLeft.Offset - padding.PaddingRight.Offset
			local widthSize = 1 / (1 - widthScale)
			local heightSize = 1 / (1 - heightScale)

			frame.Size = UDim2.new(widthSize, widthOffset, heightSize, heightOffset)

			-- Update the position of the frame so it is centered
			frame.Position = UDim2.new(0.5, -widthDiffOffset / 2, 0.5, -heightDiffOffset / 2)
			--print(frame.Position)

			-- Update the padding offset when the UIPadding changes
			padding:GetPropertyChangedSignal("PaddingLeft"):Connect(updatePaddingOffset)
			padding:GetPropertyChangedSignal("PaddingRight"):Connect(updatePaddingOffset)
			padding:GetPropertyChangedSignal("PaddingTop"):Connect(updatePaddingOffset)
			padding:GetPropertyChangedSignal("PaddingBottom"):Connect(updatePaddingOffset)
		end
	end
	frame:GetPropertyChangedSignal("Parent"):Connect(updatePaddingOffset)
	updatePaddingOffset()

	-- Create a new gradient for the frame
	local gradient = Instance.new("UIGradient")
	gradient.Rotation = 15
	gradient.Color = Gradient or ColorSequence.new(Color3.new(1, 1, 1))
	gradient.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 1),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(0.85, 1),
		NumberSequenceKeypoint.new(1, 1),
	})
	gradient.Offset = SHIMMER_START_OFFSET
	gradient.Parent = frame

	return frame
end

-- Playback state of the shimmer
Shime.PlaybackState = nil

-- Create a new Shimmer object
function Shime.new(
	parent: GuiObject,
	time: number?,
	style: Enum.EasingStyle?,
	direction: Enum.EasingDirection?,
	repeatCount: number?,
	reverses: boolean?,
	delayTime: number?,
	Gradient: ColorSequence?
)
	-- Parameter validation
	assert(typeof(parent) == "Instance" and parent:IsA("GuiObject"), "Invalid parent argument. Expected GuiObject.")

	time = time or 1
	assert(typeof(time) == "number", "Invalid time argument. Expected number.")

	style = style or Enum.EasingStyle.Exponential
	assert(
		typeof(style) == "EnumItem" and style.EnumType == Enum.EasingStyle,
		"Invalid style argument. Expected EasingStyle enum."
	)

	direction = direction or Enum.EasingDirection.Out
	assert(
		typeof(direction) == "EnumItem" and direction.EnumType == Enum.EasingDirection,
		"Invalid direction argument. Expected EasingDirection enum."
	)

	repeatCount = repeatCount or -1
	assert(typeof(repeatCount) == "number", "Invalid repeatCount argument. Expected number.")

	reverses = reverses or false
	assert(typeof(reverses) == "boolean", "Invalid reverses argument. Expected boolean.")

	delayTime = delayTime or 5
	assert(typeof(delayTime) == "number", "Invalid delayTime argument. Expected number.")

	local self = setmetatable({}, Shime)
	-- Create the shimmer frame and animation
	local shimmer = createShimmer(parent, Gradient)
	self._frame = shimmer
	self._frame.Visible = false
	self._gradient = shimmer:FindFirstChildOfClass("UIGradient")
	self._corner = shimmer:FindFirstChildOfClass("UICorner")
	self._time = time
	self._style = style
	self._direction = direction
	self._repeatCount = repeatCount
	self._reverses = reverses
	self._delayTime = delayTime
	self._restoreDefaultTweenOnComplete = false
	self:_rebuildTween(self:_getDefaultTweenInfo())
	
	return self
end

function Shime:_getDefaultTweenInfo(): TweenInfo
	local this = self :: any
	return TweenInfo.new(this._time, this._style, this._direction, this._repeatCount, this._reverses, this._delayTime)
end

function Shime:_rebuildTween(tweenInfo: TweenInfo)
	local this = self :: any

	if this._tween then
		local playbackState = this._tween.PlaybackState
		if playbackState ~= Enum.PlaybackState.Completed and playbackState ~= Enum.PlaybackState.Cancelled then
			this._tween:Cancel()
		end

		this._tween:Destroy()
	end

	this._tween = TweenService:Create(this._gradient, tweenInfo, { Offset = SHIMMER_END_OFFSET })
	this._tween.Completed:Connect(function(playbackState)
		this:_TweenCompleted(playbackState)
	end)
end

-- Setup tween completion callback
function Shime:_TweenCompleted(playbackState: Enum.PlaybackState)
	local this = self :: any
	this.PlaybackState = playbackState

	if playbackState == Enum.PlaybackState.Completed then
		this._frame.Visible = false

		if this._restoreDefaultTweenOnComplete then
			this._restoreDefaultTweenOnComplete = false
			this:_rebuildTween(this:_getDefaultTweenInfo())
			this._gradient.Offset = SHIMMER_START_OFFSET
		end
	end
end

-- Get the shimmer frame
function Shime:GetFrame(): Frame
	return self._frame
end

-- Get the shimmer gradient
function Shime:GetGradient(): UIGradient
	return self._gradient
end

-- Get the ui corner of the shimmer frame
function Shime:GetCorner(Radius): UICorner
	if not self._corner then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = Radius
		corner.Parent = self:GetFrame()
		return corner
	end
	
	return self._corner
end

-- Start shimmering. Finite tweens reset first so repeated Play() calls remain visible.
function Shime:Play()
	----print("Play")
	self.PlaybackState = Enum.PlaybackState.Begin

	local tweenPlaybackState = self._tween.PlaybackState
	if tweenPlaybackState == Enum.PlaybackState.Completed or tweenPlaybackState == Enum.PlaybackState.Cancelled then
		self._gradient.Offset = SHIMMER_START_OFFSET
	end

	self._frame.Visible = true
	self._tween:Play()
	self.PlaybackState = Enum.PlaybackState.Playing
	return self
end

-- Force exactly one shimmer sweep, useful for hover or opening UI.
function Shime:PlayOnce(time: number?, delayTime: number?)
	if time ~= nil then
		assert(typeof(time) == "number", "Invalid time argument. Expected number.")
	end

	if delayTime ~= nil then
		assert(typeof(delayTime) == "number", "Invalid delayTime argument. Expected number.")
	end

	self._restoreDefaultTweenOnComplete = true
	self:_rebuildTween(TweenInfo.new(time or self._time, self._style, self._direction, 0, false, delayTime or 0))
	self._gradient.Offset = SHIMMER_START_OFFSET

	return self:Play()
end

-- Pause shimmering
function Shime:Pause()
	----print("Pause")
	if self.PlaybackState == Enum.PlaybackState.Playing then
		self._tween:Pause()
		self.PlaybackState = Enum.PlaybackState.Paused
	end
end

function Shime:Destroy()
	----print("Destroying")
	self:Cancel()
	self._tween:Destroy()
	self._frame:Destroy()
end

-- Cancel shimmering
function Shime:Cancel()
	----print("Cancel")
	self._tween:Cancel()
	self._frame.Visible = false
	self.PlaybackState = Enum.PlaybackState.Cancelled
end

return Shime

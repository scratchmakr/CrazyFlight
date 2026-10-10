local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local Fusion = require(ReplicatedStorage.Packages.Fusion)
local UIContainer = require(StarterPlayer.StarterPlayerScripts.Client.Constants.UIContainer)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type Context = {
    screenGui: ScreenGui?,
    color: Color3,
    duration: number,
    fadeTime: {
        fadeIn: number?,
        fadeOut: number?,
    }?,
    onBlackout: (() -> ())?,
}

local FRAME = UIContainer.Effects.Fade
local DEFAULT_FADE_TIME = 0.25
local Fade = {}
Fade.__index = Fade

function Fade.new(context: Context)
    local self = setmetatable({
        masterTrove = Trove.new(),
        context = context,
        frame = nil :: Frame?,
    }, Fade)
    
    self:initialize()
    return self
end

export type Self = typeof(Fade.new(...))

function Fade.initialize(self: Self)
    local masterTrove = self.masterTrove
    local context = self.context
    local screenGui = context.screenGui
    local color = context.color
    local frame = Fusion.Hydrate(FRAME:Clone()) {
        BackgroundColor3 = color,
        Parent = screenGui,
        BackgroundTransparency = 1,
    }

    self.frame = frame
    masterTrove:Add(frame)
end

function Fade.play(self: Self, config: any)
    local masterTrove = self.masterTrove
    local context = self.context
    local frame = self.frame
    local duration = context.duration
    local fadeTime = context.fadeTime
    local onBlackout = context.onBlackout

    local fadeIn = fadeTime.fadeIn or DEFAULT_FADE_TIME
    local fadeOut = fadeTime.fadeOut or DEFAULT_FADE_TIME

    local fadeInTween = TweenService:Create(frame, TweenInfo.new(fadeIn, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {
        BackgroundTransparency = 0,
    })
    local fadeOutTween = TweenService:Create(frame, TweenInfo.new(fadeOut, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut), {
        BackgroundTransparency = 1,
    })
    masterTrove:Add(fadeInTween)
    masterTrove:Add(fadeOutTween)

    fadeInTween:Play()
    if onBlackout then
        task.delay(fadeIn, function()
            onBlackout()
        end)
    end
    task.wait(duration)
    fadeOutTween:Play()
    task.wait(fadeOut)
    self:destroy()
end

function Fade.destroy(self: Self)
    local masterTrove = self.masterTrove
    masterTrove:Destroy()
    setmetatable(self, nil)
end

return Fade
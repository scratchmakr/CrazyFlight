local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")
local Signal = require(ReplicatedStorage.Packages.Signal)
local Spring = require(ReplicatedStorage.Packages.Spring)
local UIContainer = require(StarterPlayer.StarterPlayerScripts.Client.Constants.UIContainer)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Vide = require(ReplicatedStorage.Packages.Vide)
local HitmarkerFormat = require(ReplicatedStorage.Shared.Formats.HitmarkerFormat)

local HitmarkerUITemplate = UIContainer.Components.HitmarkerUI

export type ClassContext = {
    markerId: string,
    adornee: Instance,
}

local Source = Vide.source
local Apply = Vide.apply
local Create = Vide.create

local Hitmarker = {}
Hitmarker.__index = Hitmarker

function Hitmarker.new(context: ClassContext)
    local self = setmetatable({
        masterTrove = Trove.new(),
        markerId = context.markerId,
        adornee = context.adornee,
        attributes = {
            totalMarker = 0,
            activationTimestamp = -1,
            threads = {} :: { thread },
            hitmarkerUI = nil :: typeof(HitmarkerUITemplate)?,
        },
        signals = {
            onDestroy = Signal.new(),
        }
    }, Hitmarker)
    self.activationTrove = self.masterTrove:Extend()
    self:initialize()
    return self
end

export type Self = typeof(Hitmarker.new(...))

function Hitmarker.initialize(self: Self)
    local attributes = self.attributes
    local newHitmarkerUI = HitmarkerUITemplate:Clone()
    Apply(newHitmarkerUI) {
        Adornee = self.adornee,
        Parent = LocalPlayer:FindFirstChild("PlayerGui")
    }

    attributes.hitmarkerUI = newHitmarkerUI
end

function Hitmarker.onSignal<T...>(self: Self, signal: Signal.Signal<T...>, callback: (T...) -> ())
    local connection = signal:Connect(callback)
    self.masterTrove:Add(connection)
    return connection
end

function Hitmarker.activate(self: Self, context: HitmarkerFormat.ActivateHitmarkerContext)
    local activationTrove = self.activationTrove
    local damage = context.damage
    local isCritical = context.isCritical
    local attributes = self.attributes
    local hitmarkerUI = attributes.hitmarkerUI
    local templatesFolder = hitmarkerUI.Templates
    local markerTemplate = templatesFolder:FindFirstChild("MarkerTemplate")
    if not markerTemplate then
        return
    end

    local mainFrame = hitmarkerUI.Main
    local mainUIScale = mainFrame:FindFirstChildOfClass("UIScale")

    local adornee = self.adornee
    local rig = adornee and adornee:FindFirstAncestorOfClass("Model")
    if not rig then
        return
    end

    self:_cleanup()
    local alpha = Source(0)
    local alphaSpring = Vide.spring(alpha, 0.75, 1)
    for _, child in rig:GetChildren() do
        if child:IsA("Highlight") then
            child:Destroy()
        end
    end
    Apply(Instance.new("Highlight")) {
        OutlineColor = Color3.fromRGB(255, 0, 0),
        FillColor = Vide.derive(function()
            return Color3.fromRGB(255, 0, 0):Lerp(Color3.fromRGB(255, 114, 114), alpha() * 0.5)
        end),
        FillTransparency = alphaSpring,
        OutlineTransparency = alphaSpring,
        DepthMode = Enum.HighlightDepthMode.Occluded,
        Parent = rig,
    }

    local newMarker = Apply(markerTemplate:Clone()) {
        Visible = true,
        Parent = mainFrame,
        Position = markerTemplate.Position + UDim2.fromScale(Random.new():NextNumber(-0.5, 0.5), Random.new():NextNumber(0, 0.25))
    }
    local markerUIScale = newMarker:FindFirstChildOfClass("UIScale")
    local markerTitle = newMarker.Title
    local criticalGradient = markerTitle:FindFirstChildOfClass("UIGradient")

    attributes.totalMarker += damage
    markerTitle.Text = tostring(math.floor(attributes.totalMarker))
    criticalGradient.Enabled = isCritical
    attributes.activationTimestamp = workspace:GetServerTimeNow()
    activationTrove:Add(newMarker)
    local direction = Random.new():NextInteger(1, 2) == 1 and 1 or -1
    local threads = attributes.threads
    local newThread = task.spawn(function()
        alpha(1)
        Spring.stop(mainUIScale)
        mainUIScale.Scale = 0.5
        Spring.target(mainUIScale, 2.5, 2.5, {
            Scale = 1,
        })
        Spring.stop(mainFrame)
        mainFrame.Position = UDim2.fromScale(0.5, 0.5)
        Spring.target(mainFrame, 2.5, 0.5, {
            Position = mainFrame.Position + UDim2.fromScale(0.5 * direction, 0),
        })
        mainFrame.Rotation = 0
        local mainRotationTween = TweenService:Create(mainFrame,
            TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
            {
                Rotation = 180 * direction,
            }
        )
        mainRotationTween:Play()
        Debris:AddItem(mainRotationTween, 1)
        task.wait(0.35)
        -- size down
        Spring.stop(markerUIScale)
        markerUIScale.Scale = 1
        Spring.target(markerUIScale, 1, 1, {
            Scale = 0,
        })
        task.wait(0.1)
        Spring.target(newMarker, 0.7, 1, {
            Rotation = 135 * direction,
        })
        task.wait(0.5)
        attributes.totalMarker = 0
    end)
    table.insert(threads, newThread)
end

function Hitmarker._cleanup(self: Self)
    local activationTrove = self.activationTrove
    activationTrove:Clean()

    local attributes = self.attributes
    local threads = attributes.threads
    for _, thread in threads do
        if thread == coroutine.running() then
            continue
        end

        task.cancel(thread)
    end
    attributes.threads = {}
end

function Hitmarker.destroy(self: Self)
    self.masterTrove:Destroy()
end

return Hitmarker
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local PageController = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.PageController)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local RblxUtils = require(ReplicatedStorage.Packages.RblxUtils)
local UIEffectsController = require(StarterPlayer.StarterPlayerScripts.Client.Controllers.UIEffectsController)
local Trove = require(ReplicatedStorage.Packages.Trove)
local AnimationUtil = require(ReplicatedStorage.Shared.Utilities.AnimationUtil)
local BaseCutscene = require(script.Parent.BaseCutscene)
local Signal = require(ReplicatedStorage.Packages.Signal)

local AssetsFolder = ReplicatedStorage.Assets
local TutorialFolder = AssetsFolder.Tutorial
local TutorialScene = TutorialFolder.Scene

local Camera = workspace.CurrentCamera

local ANIMATION_TYPES = {
    CAMERA = "Tutorial:Camera",
    LOSER = "Tutorial:Loser",
    WINNER = "Tutorial:Winner",
}

local ANIMATION_INFOS = {
    [ANIMATION_TYPES.CAMERA] = {
        animation = AnimationUtil.getAnimation(ANIMATION_TYPES.CAMERA),
        rig = TutorialScene.Rigs.CameraRig,
    },
    [ANIMATION_TYPES.LOSER] = {
        animation = AnimationUtil.getAnimation(ANIMATION_TYPES.LOSER),
        rig = TutorialScene.Rigs.Loser,
    },
    [ANIMATION_TYPES.WINNER] = {
        animation = AnimationUtil.getAnimation(ANIMATION_TYPES.WINNER),
        rig = TutorialScene.Rigs.Winner,
    },
}

local Tutorial = {}
Tutorial.__index = Tutorial

export type Context = {
    screenGui: ScreenGui?, -- for story
}

function Tutorial.new(context: Context?)
    context = context or {}
    local self = setmetatable({
        masterTrove = Trove.new(),
        frozen = Fusion.Value(false),
        camera = nil,
        animationCache = {} :: { [string]: AnimationTrack },
        sceneInstance = nil :: Instance?,
        screenGui = context.screenGui,
        signals = {
            onAnimationComplete = Signal.new(),
            onTutorialComplete = Signal.new(),
        }
    }, Tutorial)
    self.cameraTrove = self.masterTrove:Extend()

    self:initialize()
    return self
end

export type Self = typeof(Tutorial.new(...))

function Tutorial.initialize(self: Self)
    local animationCache = self.animationCache
    local masterTrove = self.masterTrove
    local newScene = TutorialScene:Clone()
    self.sceneInstance = newScene
    newScene.Parent = workspace

    for animType, animInfo in ANIMATION_INFOS do
        local animation = animInfo.animation
        local rigName = animInfo.rig.Name
        local rig = newScene.Rigs:FindFirstChild(rigName)
        local animationTrack = AnimationUtil.loadAnimation(rig, animation)
        animationCache[animType] = animationTrack
        masterTrove:Add(animationTrack)
    end

    
    masterTrove:Add(newScene)
end

function Tutorial.start(self: Self)
    local screenGui = self.screenGui
    local masterTrove = self.masterTrove
    local sceneInstance = self.sceneInstance
    local animationCache = self.animationCache

    local animationCount = 0
    local totalAnimations = #RblxUtils.Table.keys(animationCache)
    local function onAnimationComplete()
        animationCount = animationCount + 1
        if animationCount >= totalAnimations then
            self.signals.onAnimationComplete:Fire()
        end
    end
    for animType, animationTrack in animationCache do
        AnimationUtil.playAnimation({
            animationTrack = animationTrack,
            onComplete = onAnimationComplete,
            freezeOnComplete = true,
        })
    end
    self:setCamera(sceneInstance.Rigs.CameraRig.camera)
    PageController.toggleHUD(false)
    local blinkAlpha = Fusion.Value(0)
    local blinkAlphaTween = Fusion.Spring(blinkAlpha, 1, 1)
    local blinkClass = UIEffectsController.playBlink({
        alpha = blinkAlphaTween,
        screenGui = screenGui,
    })

    blinkAlpha:set(0.75)
    task.wait(1)
    blinkAlpha:set(0)
    task.wait(2.5)
    blinkAlpha:set(0.75)
    task.wait(1)
    blinkAlpha:set(0)
    task.wait(1.5)
    blinkAlpha:set(0.85)
    task.wait(1)
    blinkAlpha:set(0)
    task.wait(1.5)
    blinkAlpha:set(0.75)
    task.wait(1)
    blinkAlpha:set(0.45)
    task.wait(1)
    blinkAlpha:set(0.85)
    task.wait(1)
    blinkAlpha:set(0.55)
    task.wait(1)
    blinkAlpha:set(0.95)
    task.wait(1)
    blinkAlpha:set(0.65)
    task.wait(0.5)
    blinkAlpha:set(1.2)
    masterTrove:Add(function()
        blinkClass:destroy()
    end)
end

function Tutorial.setCamera(self: Self, camera: Camera)
    local trove = self.cameraTrove
    trove:Clean()
    self.camera = camera
    if camera then
        Camera.CameraType = Enum.CameraType.Scriptable
        trove:Add(RunService.Heartbeat:Connect(function(dt: number)
            local currentCamera = self.camera
            if not currentCamera then
                Camera.CameraType = Enum.CameraType.Custom
                trove:Clean()
                return
            end

            Camera.CFrame = currentCamera.CFrame
        end))
    else    
        Camera.CameraType = Enum.CameraType.Custom
    end
end

function Tutorial.setFreeze(self: Self, toggle: boolean)
    self.frozen:set(toggle)

    local animationCache = self.animationCache
    for _, animationTrack in animationCache do
        animationTrack:Play(0, 1, toggle and 0 or 1)
    end
end

function Tutorial.destroy(self: Self)
    self:setCamera(nil)
    PageController.toggleHUD(true)
    self.masterTrove:Destroy()
end

return Tutorial

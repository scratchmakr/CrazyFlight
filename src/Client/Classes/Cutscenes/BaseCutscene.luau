local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Camera = workspace.CurrentCamera

local Cutscene = {}
Cutscene.__index = Cutscene

export type Self = typeof(setmetatable({} :: {
    masterTrove: typeof(Trove.new()),
    cameraTrove: typeof(Trove.new()),
    frozen: Fusion.Value<boolean>,
    camera: Camera?,
    animationCache: { [string]: AnimationTrack },
}, Cutscene))

function Cutscene.new(): Self
    local self = setmetatable({
        masterTrove = Trove.new(),
        frozen = Fusion.Value(false),
        camera = nil,
        animationCache = {} :: { [string]: AnimationTrack },
    }, Cutscene)
    self.cameraTrove = self.masterTrove:Extend()

    -- self:initialize()
    return self :: Self
end

function Cutscene.setCamera(self: Self, camera: Camera)
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
    end
end

function Cutscene.setFreeze(self: Self, toggle: boolean)
    self.frozen:set(toggle)

    local animationCache = self.animationCache
    for _, animationTrack in animationCache do
        animationTrack:Play(0, 1, toggle and 0 or 1)
    end
end

return Cutscene

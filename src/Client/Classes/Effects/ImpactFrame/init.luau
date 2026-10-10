
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Trove = require(ReplicatedStorage.Packages.Trove)
local Format = require(script.Format)
local Presets = require(script.Presets)

local ImpactFrame = {}
ImpactFrame.__index = ImpactFrame

function ImpactFrame.new(context: Format.ImpactFrameContext)
    local preset = context.preset
    local impactConfig = context.impactConfig
    local self = setmetatable({
        masterTrove = Trove.new(),
        preset = preset,
        impactConfig = impactConfig,
        impactFX = nil :: ColorCorrectionEffect?,
    }, ImpactFrame)

    self:initialize()
    return self
end

export type Self = typeof(ImpactFrame.new(...))

function ImpactFrame.getImpactConfig(self: Self)
    local preset = self.preset
    local impactConfig = self.impactConfig
    if preset then
        return Presets[preset]
    end
    
    return impactConfig
end

function ImpactFrame.initialize(self: Self)
    local masterTrove = self.masterTrove
    local impactFX = Instance.new("ColorCorrectionEffect")
    impactFX.Brightness = 0
    impactFX.Contrast = -100
    impactFX.Saturation = -0.9
    impactFX.Parent = Lighting
    self.impactFX = impactFX
    masterTrove:Add(impactFX)
end

function ImpactFrame.start(self: Self)
    local impactConfig = self:getImpactConfig()
    local intervalLength = impactConfig.intervalLength
    local flickerAmount = impactConfig.flickerAmount
    local impactFX = self.impactFX

    impactFX.Enabled = true
    local flickers = 0
    repeat
      flickers += 1
      impactFX.Contrast = -impactFX.Contrast
      task.wait(intervalLength)
    until flickers >= flickerAmount
    impactFX.Enabled = false
end

function ImpactFrame.destroy(self: Self)
    self.masterTrove:Destroy()
end

return ImpactFrame
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Trove = require(ReplicatedStorage.Packages.Trove)

local Camera = workspace.CurrentCamera

export type Context = {
    viewmodel: Model | BasePart,
    cframeOffset: CFrame?,
    spawnOffset: CFrame?,
    reactToMouse: {
        maxTiltX: number,
        maxTiltY: number,
    }?,

    spring: {
        speed: number,
        damping: number,
    }?,

    float: {
        height: number?,
        frequency: number?,
    }?,

    postProcessing: {
        disabled: boolean?,
    }?,
}

local TILT_INTENSITY = 4
local TILT_SPEED = 2
local FLOAT_HEIGHT = 0.5
local FLOAT_FREQUENCY = 1
local SPAWN_OFFSET = CFrame.new(0, -8, 0)
local DEFAULT_OFFSET = CFrame.new(0, 0, -6)

local CameraViewmodel = {}
CameraViewmodel.__index = CameraViewmodel

local function getMouseAxis(maxValue: number): (number, number)
	if not Camera then
		return 0, 0
	end

	local viewport = Camera.ViewportSize
	local mouse = UserInputService:GetMouseLocation()

	local x = ((mouse.X / viewport.X) * 2 - 1) * maxValue
	local y = -((mouse.Y / viewport.Y) * 2 - 1) * maxValue
	return math.clamp(x, -maxValue, maxValue), math.clamp(y, -maxValue, maxValue)
end

function CameraViewmodel.new(context: Context)
    local self = setmetatable({
        masterTrove = Trove.new(),
        viewmodel = context.viewmodel,
        cframeOffset = context.cframeOffset or CFrame.new(),
        spawnOffset = context.spawnOffset or SPAWN_OFFSET,
        reactToMouse = context.reactToMouse,
        postProcessing = context.postProcessing,
        floatInfo = context.float,
        alpha = Fusion.Value(0),
        cleaned = false,
        postProcessingEnabled = Fusion.Value(false),
    }, CameraViewmodel)

    local springInfo = context.spring or {
        speed = 14,
        damping = 0.55,
    }
    self.alphaSpring = Fusion.Spring(self.alpha, springInfo.speed, springInfo.damping)

    self.tiltAlphas = {
        x = Fusion.Value(0),
        y = Fusion.Value(0),
    }
    self.tiltSprings = {
        x = Fusion.Spring(self.tiltAlphas.x, 20, 0.4),
        y = Fusion.Spring(self.tiltAlphas.y, 20, 0.4),
    }
    self.postProcessingEnabled = Fusion.Value(false)
    self:initialize()
    return self
end

export type Self = typeof(CameraViewmodel.new(...))

function CameraViewmodel.initialize(self: Self)
    local viewmodel = self.viewmodel
    local primaryPart = viewmodel:IsA("Model") and viewmodel.PrimaryPart or viewmodel:FindFirstChildWhichIsA("BasePart")
    primaryPart = primaryPart or viewmodel
    if primaryPart then
        primaryPart.Anchored = true
    end 
    self.masterTrove:Add(viewmodel)
    self.masterTrove:Add(RunService.PreRender:Connect(function(dt)
        self:update(dt)
    end))

    local depthOfField = Fusion.New("DepthOfFieldEffect") {
        FarIntensity = Fusion.Spring(Fusion.Computed(function()
            local enabled = self.postProcessingEnabled:get()
            return enabled and 1 or 0
        end), 14, 1),
        FocusDistance = 0,
        InFocusRadius = 6,
        NearIntensity = 1,
        Parent = Lighting
    }
    self.masterTrove:Add(depthOfField)
    self.masterTrove:Add(viewmodel)
end

function CameraViewmodel.show(self: Self)
    self.alpha:set(1)
    
    self:togglePostProcessing(true)
end

function CameraViewmodel.togglePostProcessing(self: Self, enabled: boolean)
    local postProcessingInfo = self.postProcessing
    if postProcessingInfo and postProcessingInfo.disabled then
        return
    end

    self.postProcessingEnabled:set(enabled)
end

function CameraViewmodel._getTiltOffset(self: Self): CFrame
    local tiltAlphas = self.tiltAlphas
    local tiltSprings = self.tiltSprings

    local reactToMouse = self.reactToMouse
    local maxTiltX = reactToMouse and reactToMouse.maxTiltX or 0
    local maxTiltY = reactToMouse and reactToMouse.maxTiltY or 0
	local tickTime = tick()
	local tiltX = math.rad(math.sin(tickTime * TILT_SPEED) * TILT_INTENSITY)
	local tiltY = math.rad(math.cos(tickTime * TILT_SPEED) * TILT_INTENSITY)
    
    local mouseTiltX = getMouseAxis(maxTiltX)
    local _, mouseTiltY = getMouseAxis(maxTiltY)
    mouseTiltX = math.rad(mouseTiltX)
    mouseTiltY = math.rad(mouseTiltY)

    tiltAlphas.x:set(mouseTiltX)
    tiltAlphas.y:set(mouseTiltY)

	return CFrame.Angles(-tiltSprings.y:get(), tiltSprings.x:get(), 0)
        * CFrame.Angles(tiltX, tiltY, 0)
end

function CameraViewmodel._getFloatOffset(self: Self)
    local floatInfo = self.floatInfo
    local height = floatInfo and floatInfo.height or FLOAT_HEIGHT
    local frequency = floatInfo and floatInfo.frequency or FLOAT_FREQUENCY
    local tickTime = tick()
    local posY = math.sin(tickTime * frequency) * height
    return CFrame.new(0, posY, 0)
end

function CameraViewmodel.update(self: Self)
    local viewmodel = self.viewmodel
    local alphaSpring = self.alphaSpring
    local tiltOffset = self:_getTiltOffset()
    local floatOffset = self:_getFloatOffset()
    local cframeOffset = self.cframeOffset
    local offset = tiltOffset * floatOffset
    local spawnOffset = self.spawnOffset
    
    local alphaProgress = 1 - alphaSpring:get()
    local animationOffset = CFrame.identity:Lerp(spawnOffset, alphaProgress)
    local finalCFrame = Camera.CFrame
        * DEFAULT_OFFSET -- apply default offset
        * cframeOffset -- apply cframe offset from context
        * animationOffset -- apply spawn offset
        * offset -- apply tilt and float offsets
        * CFrame.Angles(0, math.pi, 0) -- turn around

    if viewmodel:IsA("BasePart") then
        viewmodel.CFrame = finalCFrame
    else
        viewmodel:PivotTo(finalCFrame)
    end
end

function CameraViewmodel.hide(self: Self)
    self.alpha:set(0)
    self:togglePostProcessing(false)
end

function CameraViewmodel.cleanup(self: Self)
    if self.cleaned then
        return
    end
    self.cleaned = true
    self:hide()
    task.delay(1, function()
        local masterTrove = self.masterTrove
        masterTrove:Destroy()
        
        setmetatable(self, nil)
    end)
end

return CameraViewmodel
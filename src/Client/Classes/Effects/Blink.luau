local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local UIContainer = require(StarterPlayer.StarterPlayerScripts.Client.Constants.UIContainer)
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Trove = require(ReplicatedStorage.Packages.Trove)

local BLINK_FRAME = UIContainer.Effects.Blink

export type Context = {
    alpha: Fusion.Value<number>,
    screenGui: ScreenGui?,
}
local Blink = {}
Blink.__index = Blink

function Blink.new(context: Context)
    local self = setmetatable({
        masterTrove = Trove.new(),
        screenGui = context.screenGui,
        alpha = context.alpha,
        blinkFrame = nil :: Frame?,
    }, Blink)

    self:initialize()
    return self
end

export type Self = typeof(Blink.new(...))

function Blink:initialize()
    local masterTrove = self.masterTrove
    local screenGui = self.screenGui
    local alpha = self.alpha

    local newBlink = Fusion.Hydrate(BLINK_FRAME:Clone()) {
        Parent = screenGui,
    }

    local lidInfo = {
        [newBlink.LowerLid] = {
            current = {
                size = newBlink.LowerLid.Size,
                position = newBlink.LowerLid.Position,
            },
            target = { -- max alpha
                size = UDim2.fromScale(1, 1),
                position = UDim2.fromScale(0.5, 1.5),
            },
        },
        [newBlink.UpperLid] = {
            current = {
                size = newBlink.UpperLid.Size,
                position = newBlink.UpperLid.Position,
            },
            target = { -- max alpha
                size = UDim2.fromScale(1, 1),
                position = UDim2.fromScale(0.5, -0.5),
            },
        },
    }

    local function getLidSizeAndPosition(lid: Frame, alpha: number)
        local lidInfo = lidInfo[lid]
        if not lidInfo then
            return nil
        end

        local current = lidInfo.current
        local target = lidInfo.target
        local sizeDifference = target.size - current.size
        local positionDifference = target.position - current.position
        local updatedSize = UDim2.fromScale(
            current.size.X.Scale + sizeDifference.X.Scale * alpha,
            current.size.Y.Scale + sizeDifference.Y.Scale * alpha
        )
        local updatedPosition = UDim2.fromScale(
            current.position.X.Scale + positionDifference.X.Scale * alpha,
            current.position.Y.Scale + positionDifference.Y.Scale * alpha
        )
        return updatedSize, updatedPosition
    end

    for lid in lidInfo do
        Fusion.Hydrate(lid) {
            Position = Fusion.Computed(function()
                local _, pos = getLidSizeAndPosition(lid, alpha:get())
                return pos
            end),
            Size = Fusion.Computed(function()
                local size = getLidSizeAndPosition(lid, alpha:get())
                return size
            end),
        }
    end

    self.blinkFrame = newBlink

    local blurEffect = Fusion.New("BlurEffect") {
        Size = Fusion.Computed(function()
            return 25 * (1 - alpha:get())
        end),
        Parent = Lighting,
    }

    masterTrove:Add(blurEffect)
    masterTrove:Add(newBlink)
end

function Blink:destroy()
    local masterTrove = self.masterTrove
    masterTrove:Destroy()
end



return Blink
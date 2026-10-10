local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Trove = require(ReplicatedStorage.Packages.Trove)

export type Props = {
    cframeOffset: CFrame?,
    viewmodel: Model | BasePart,
    viewportFrame: ViewportFrame,
}

local DEFAULT_OFFSET = CFrame.new(0, 0, 10)

return function(props: Props)
    local masterTrove = Trove.new()
    local viewportFrame = props.viewportFrame
    local viewmodel = props.viewmodel
    local cframeOffset = props.cframeOffset or CFrame.new()
    
    if not (viewportFrame and viewmodel) then
        return
    end

    local cameraView = Fusion.New("Camera") {
        FieldOfView = 35,
        Parent = viewportFrame,
    }
    Fusion.New("WorldModel") {
        Parent = cameraView,
        [Fusion.Children] = viewmodel,
    }

    local targetCFrame = cameraView.CFrame
        * CFrame.Angles(0, math.pi, 0)
        * DEFAULT_OFFSET
        * cframeOffset
    if viewmodel:IsA("Model") then
        viewmodel:PivotTo(targetCFrame)
    elseif viewmodel:IsA("BasePart") then
        viewmodel.CFrame = targetCFrame
    end
    
    masterTrove:Add(cameraView)
    return Fusion.Hydrate(viewportFrame) {
        CurrentCamera = cameraView,
    }, masterTrove
end
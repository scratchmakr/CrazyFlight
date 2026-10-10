local PartUtil = {}
local RAMP_SHAPES = {
    Enum.PartType.Wedge,
	Enum.PartType.CornerWedge,
}

function PartUtil.toggleVisibility(model: Model, enabled: boolean)
    for _, descendant in model:GetDescendants() do
        if descendant:IsA("BasePart") or descendant:IsA("Decal") or descendant:IsA("Texture") then
            if descendant:IsA("BasePart") then
                local previousCanCollide = descendant:GetAttribute("PreviousCanCollide")
                if not previousCanCollide then
                    descendant:SetAttribute("PreviousCanCollide", descendant.CanCollide)
                    previousCanCollide = descendant.CanCollide
                end
                descendant.CanCollide = enabled and previousCanCollide or false
            end
            local previousTransparency = descendant:GetAttribute("PreviousTransparency")
            if not previousTransparency then
                descendant:SetAttribute("PreviousTransparency", descendant.Transparency)
                previousTransparency = descendant.Transparency
            end
            descendant.Transparency = enabled and previousTransparency or 1
        end
    end
end

function PartUtil.attachTo(instance: BasePart | Model, instanceToAttachTo: BasePart)
    local part = instance
    if instance:IsA("Model") then
        part = instance.PrimaryPart
    end
    local weldConstraint = Instance.new("WeldConstraint")
    weldConstraint.Parent = part
    weldConstraint.Part0 = part
    weldConstraint.Part1 = instanceToAttachTo
    return weldConstraint
end

function PartUtil.isRamp(normal: Vector3)
    local angle = math.deg(math.acos(
        math.clamp(normal:Dot(Vector3.yAxis), -1, 1)
    ))

    -- print(angle)
    return angle > 5 and angle < 75
end

function PartUtil.mutateCFrameFromPivot(rootCFrame: CFrame, pivotCFrame: CFrame, mutateCFrame: CFrame): CFrame
	local pivotOffset = rootCFrame:ToObjectSpace(pivotCFrame)

	return pivotOffset * mutateCFrame * pivotOffset:Inverse()
end

return PartUtil
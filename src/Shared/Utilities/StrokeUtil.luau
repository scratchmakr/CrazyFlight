local StrokeUtil = {}

function StrokeUtil.convertToScaled(stroke: UIStroke)
	if stroke.StrokeSizingMode == Enum.StrokeSizingMode.ScaledSize then
		return
	end

	local guiObject = stroke.Parent

	if not guiObject or not guiObject:IsA("GuiObject") then
		warn(`UIStroke {stroke:GetFullName()} is not parented to a GuiObject`)
		return
	end

	local absoluteSize = guiObject.AbsoluteSize
	local referenceSize = math.min(absoluteSize.X, absoluteSize.Y)

	if referenceSize <= 0 then
		warn(`Cannot scale {stroke:GetFullName()} because its parent has no AbsoluteSize`)
		return
	end

	local fixedThickness = stroke.Thickness
	local scaledThickness = fixedThickness / referenceSize

	stroke.StrokeSizingMode = Enum.StrokeSizingMode.ScaledSize
	stroke.Thickness = scaledThickness
end

function StrokeUtil.convertAll(root: Instance)
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("UIStroke") then
			StrokeUtil.convertToScaled(descendant)
		end
	end
end

return StrokeUtil
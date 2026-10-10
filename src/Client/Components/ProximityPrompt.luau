local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fusion = require(ReplicatedStorage.Packages.Fusion)
local Trove = require(ReplicatedStorage.Packages.Trove)
local Assets = ReplicatedStorage.Assets
local ProximityTemplate = Assets.UI.Components.ProximityTemplate

export type props = {
    ActionText: string,
    ObjectText: string,
    HoldDuration: number?,
    Enabled: Fusion.Value<boolean>,
    Offset: Vector3,
    KeyCode: Enum.KeyCode,
    GamepadKeyCode: Enum.KeyCode,
    Parent: Instance,
    Callback: (player: Player) -> ()?,
}

return function(props: props)
    local masterTrove = Trove.new()
    local parent = props.Parent
    local newPromptPart = Fusion.Hydrate(ProximityTemplate:Clone()) {
        Anchored = false,
        CFrame = parent.CFrame + props.Offset,
        Parent = parent,
        [Fusion.Cleanup] = function()
            masterTrove:Destroy()
        end,
    }
    Fusion.Hydrate(newPromptPart:FindFirstChildOfClass("ProximityPrompt")) {
        Name = props.ActionText,
        Enabled = props.Enabled,
        ActionText = props.ActionText,
        ObjectText = props.ObjectText,
        HoldDuration = props.HoldDuration or 0.5,
        KeyboardKeyCode = props.KeyCode or Enum.KeyCode.E,
        GamepadKeyCode = props.GamepadKeyCode or Enum.KeyCode.ButtonX,
        [Fusion.Cleanup] = function()
            masterTrove:Destroy()
        end,
        [Fusion.OnEvent("Triggered")] = props.Callback,
    }

    local weldConstraint = Instance.new("WeldConstraint") :: WeldConstraint
    weldConstraint.Part0 = parent
    weldConstraint.Part1 = newPromptPart
    weldConstraint.Parent = newPromptPart

    return newPromptPart
end
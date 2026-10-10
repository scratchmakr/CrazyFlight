local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Arms = require(StarterPlayer.StarterPlayerScripts.Client.Classes.Character.Arms)
local Signal = require(ReplicatedStorage.Packages.Signal)
local Trove = require(ReplicatedStorage.Packages.Trove)
local ActivationGateway = require(ReplicatedStorage.Shared.Classes.ActivationGateway)
local CombatCharacter = require(ReplicatedStorage.Shared.Classes.CombatCharacter)
export type BehaviorContext = {
    combatCharacter: CombatCharacter.Self?,
    arms: Arms.Self?,
    userId: number?,
    timestamp: number?,
}

export type Behavior = {
    masterTrove: Trove.Trove?,
    activationTrove: Trove.Trove?,
    signals: {
        onActivate: Signal.Signal<() -> ()>,
        onDeactivate: Signal.Signal<(timestamp: number?) -> ()>,
        onAttributesChanged: Signal.Signal<{ [string]: any }>,
    },
    activationGateway: ActivationGateway.Self?,

    onSignal: (self: Behavior, signal: Signal.Signal<() -> ()>, callback: () -> ()) -> (),
    initialize: (self: Behavior) -> (),
    handleInput: ((self: Behavior, inputState: Enum.UserInputState, timestamp: number) -> ())?,

    update: (self: Behavior, dt: number) -> (),
    _updateClient: (self: Behavior, dt: number) -> (),
    _updateServer: (self: Behavior, dt: number) -> (),

    activate: (self: Behavior, timestamp: number?) -> (),
    _activateObserver: (self: Behavior) -> (),
    _activateClient: (self: Behavior) -> (),
    _activateServer: (self: Behavior) -> (),

    deactivate: (self: Behavior, timestamp: number?) -> (),
    _deactivateObserver: (self: Behavior) -> (),
    _deactivateClient: (self: Behavior) -> (),
    _deactivateServer: (self: Behavior) -> (),

    destroy: (self: Behavior) -> (),
}

export type ActivatedRequest = {
    equipmentType: string,
    timestamp: number,
    userId: number?,
}

export type BehaviorClass = {
    new: (context: BehaviorContext) -> Behavior,
}

return {}
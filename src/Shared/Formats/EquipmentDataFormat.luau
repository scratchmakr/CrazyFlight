local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RigFormat = require(script.Parent.RigFormat)
local ArmsFormat = require(ReplicatedStorage.Shared.Formats.ArmsFormat)

export type GatewayType = "Hold" | "Single" | "Drawback" | "OnEquip"
export type ReloadType = "cycle" | "oneshot"
export type BallisticType = "projectile" | "hitscan"

export type ActivationGateway = {
    type: GatewayType,
    maximumDrawbackTime: number?, -- more drawback more power
    windupTime: number?,
}

export type ChamberInfo = {
    delay: number?,
    chamberTime: number?,
}
export type ReloadInfo = {
    type: ReloadType,
    tacticalTime: number?, -- can be used for shotgun cycle reload
    fullTime: number?,

    startTime: number?,
    loopTime: number?,
}

export type EquipmentPrefabs = {
    viewmodel: Model?,
    arms: Model,
    sounds: {
        activate: Sound?,
        reload: Sound?,
        reloadTactical: Sound?,
        empty: Sound?,
    }
}
export type BallisticInfo = {
    type: BallisticType,
    speed: number?,
    gravity: number?,
    lifespan: number?,
    spread: number,
    headshotMultiplier: number?,
    bulletsPerShot: number?,
    recoil: number?,
}

export type BehaviorInfo = {
    duration: number?,
    boosts: {
        walkSpeed: number?,
        jumpPower: number?,
        health: number?,
        shield: number?,
    }?,

    -- ability specific info
    cancelInfo: {
        keybinds: { Enum.KeyCode | Enum.UserInputType },
    }?,
}

export type ADSInfo = {
    subtractedFOV: number,
    isSniper: boolean?,
}

export type RNGInfo = {
    chance: number,
    locked: boolean?,
}
export type ViewportInfo = {
    image: string?,
    cframeOffset: CFrame?,
}
export type EquipmentInfo = {
    name: string,
    rarity: string?,
    description: string?,

    damage: number?,
    useRate: number?, -- rpm
    resources: {
        usesPerReserve: number,
        reserves: number?,
    },
    equipTime: number?, -- time in seconds to equip the equipment
    rngInfo: RNGInfo?,

    adsInfo: ADSInfo?,
    behaviorInfo: BehaviorInfo?,
    ballisticInfo: BallisticInfo?,
    chamberInfo: ChamberInfo?,
    activationGateway: ActivationGateway,
    reloadInfo: ReloadInfo?,
    prefabs: EquipmentPrefabs,
    viewportArms: ArmsFormat.ArmsFormat?,
    rigInfo: RigFormat.RigInfo?,
    viewportInfo: ViewportInfo?,
    isPassive: boolean?, -- if true, the equipment is passive and does not need to be equipped
}

local Format = {}

function Format.build(info: EquipmentInfo)
    return info
end

return Format
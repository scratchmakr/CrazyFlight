export type DamageContext = {
    damage: number,
    inflictedBy: number,
    inflictedOn: number,
    equipmentType: string,
    raycastResult: RaycastResult?,
}

export type ballisticDamageContext = {
    equipmentType: string,
    raycastResult: RaycastResult,
}

return {}
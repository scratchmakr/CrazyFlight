export type EquipmentVFXContext = {
    equipmentType: string,
    userId: number?,
    origin: Vector3?,
    direction: Vector3?,
    seed: number?,
}

export type MuzzleAttachmentContext = {
    equipmentType: string,
    userId: number?,
}

export type TracerContext = {
    equipmentType: string,
    origin: Vector3,
    hitscanResult: RaycastResult,
    userId: number?,
}

return {}
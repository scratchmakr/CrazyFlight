
export type ReloadState = "start" | "loop" | "end" | "one_cycle"
export type ReconcileContext = {
    acknowledgedActionSequence: number,
    resources: {
        current: number,
        reserve: number?,
    },
}

export type ActionType = "Shot" | "Reload" | "Activate" | "Reload"

export type DisplayEquipmentContext = {
    equipmentType: string,
    origin: Vector3,
    tracerHitPositions: { Vector3 },
    seed: number,
}
export type ActionRequest = {
    userId: number?,
    equipmentType: string,
    actionSequence: number,
    chamber: boolean?,
    timestamp: number,
    type: ActionType,
    origin: Vector3?,
    direction: Vector3?,
    seed: number?,
}
export type ReloadCancelRequest = {
    equipmentType: string,
    timestamp: number,
}

export type ReloadStartRequest = {
    isTactical: boolean,
    equipmentType: string,
    timestamp: number,
    state: ReloadState,
    reloadTime: number,
}

export type InputRequest = {
    equipmentType: string?,
    timestamp: number?,
    state: boolean,
}

return {}
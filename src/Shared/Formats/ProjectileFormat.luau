export type Snapshot = {
    timestamp: number,
    players: {
        [number]: {
            [string]: {
                CFrame: CFrame,
            },
        },
    },
}

export type SnapshotHistory = {Snapshot}

export type FireContext = {
    userId: number?,
    equipmentType: string,
    origin: Vector3,
    direction: Vector3,
    seed: number,
    timestamp: number,
}

return {}
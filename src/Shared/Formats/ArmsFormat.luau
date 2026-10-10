export type ArmsFormat = {
    offsets: {
        root: CFrame?,
        runOffset: CFrame?,
        leftHand: CFrame?,
        rightHand: CFrame?,
    },

    weight: number?,

    animations: {
        [string]: {
            animation: Animation,
            looped: boolean?,
        },
    },
}

return {}
export type RigToggleContext = {
    userId: number,
    equipmentType: string,
    isEquipped: boolean,
}

export type RigInfo = {
    
    animations: {
        [string]: {
            animation: Animation,
            looped: boolean?,
        },
    },
}

return {}
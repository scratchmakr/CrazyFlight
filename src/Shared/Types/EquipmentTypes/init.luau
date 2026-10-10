local EquipmentTypes = {}

EquipmentTypes.ReloadType = {
    Cycle = "cycle",
    Oneshot = "oneshot",
}

EquipmentTypes.TabType = {
    PRIMARY = "primary",
    UTILITY = "utility",
    ABILITY = "ability",
    ALL = "all",
}

EquipmentTypes.TabMap = {
    [EquipmentTypes.TabType.PRIMARY] = 1,
    [EquipmentTypes.TabType.UTILITY] = 2,
    [EquipmentTypes.TabType.ABILITY] = 3,
}

EquipmentTypes.ActionType = {
    SHOT = "shot",
    RELOAD = "reload",
    ACTIVATE = "activate",
    DEACTIVATE = "deactivate",
}

return EquipmentTypes
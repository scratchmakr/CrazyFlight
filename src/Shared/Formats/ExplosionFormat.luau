local DamageFormat = require(script.Parent.DamageFormat)
export type CreateContext = {
    inflictedBy: number,
    equipmentType: string,
    origin: Vector3,
    radius: number,
    maxDamage: number,
}

return {}
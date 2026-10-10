export type Schema = {
    banned: boolean,
    reason: string,
    timestamp: number,
}

local Ban = {}
Ban.TEMPLATE = {
    banned = false,
    reason = "No reason provided.",
    timestamp = 0,
} :: Schema

return Ban
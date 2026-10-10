local Format = require(script.Parent.Format)

local Presets = {
    mercy = {
        intervalLength = 0.03,
        flickerAmount = 4,
    }
} :: { [string]: Format.ImpactConfig }

return Presets
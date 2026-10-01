-- Pure math helpers shared by client (tooltips / HUD) and server (authority).
local Config = require(script.Parent.Config)

local Formulas = {}

-- Haste is "ability haste" style: 100 haste = half the cooldown.
function Formulas.CooldownWithHaste(baseCooldown: number, haste: number): number
	return baseCooldown * 100 / (100 + math.max(haste, -50))
end

-- Armor mitigation. `pen` is a 0-1 fraction of the target's armor that is ignored.
function Formulas.DamageMultiplier(armor: number, pen: number): number
	local effective = armor
	if effective > 0 then
		effective = effective * (1 - math.clamp(pen, 0, 1))
	end
	if effective >= 0 then
		return 100 / (100 + effective)
	end
	return 2 - 100 / (100 - effective)
end

-- Characters can supply `PowerCurve(level) -> number` to shape how quickly their
-- per-level growth is earned (early / mid / late game power curves).
-- The default is linear (factor == level).
function Formulas.LevelFactor(characterDef, level: number): number
	if characterDef and characterDef.PowerCurve then
		return characterDef.PowerCurve(level)
	end
	return level
end

-- Reads a value that can either be a number or a per-rank table.
function Formulas.RankValue(value, rank: number)
	if type(value) == "table" then
		return value[math.clamp(rank, 1, #value)]
	end
	return value
end

function Formulas.FormatStat(statName: string, value: number): string
	local def = Config.Stats[statName]
	local fmt = def and def.Format or "int"
	if fmt == "pct" then
		return string.format("%d%%", math.floor(value * 100 + 0.5))
	elseif fmt == "dec1" then
		return string.format("%.1f", value)
	elseif fmt == "dec2" then
		return string.format("%.2f", value)
	end
	return tostring(math.floor(value + 0.5))
end

return Formulas

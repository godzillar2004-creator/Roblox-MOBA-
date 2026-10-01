-- Summoner abilities. They use the exact same ability format as character abilities
-- (see CharacterRegistry for the full schema) but are shared between characters.
-- A character picks one with `Summoner = "Flash"`.

local Summoners = {}

Summoners.Flash = {
	Id = "Flash",
	Name = "Flash",
	Description = "Instantly blink a short distance toward your cursor.",
	DamageType = nil, -- deals no damage
	MaxRank = 1,
	RankLevels = { 0 },
	Cooldown = 60,
	Cost = 0,
	Targeting = "Point",
	Range = 12,
	Effects = {
		{ Kind = "Dash", Mode = "Blink", Distance = 12 },
	},
}

Summoners.Ghost = {
	Id = "Ghost",
	Name = "Ghost",
	Description = "Gain +40% move speed for 5 seconds.",
	MaxRank = 1,
	RankLevels = { 0 },
	Cooldown = 75,
	Cost = 0,
	Targeting = "Self",
	Effects = {
		{ Kind = "Buff", Name = "Ghost", Duration = 5, Stats = { MoveSpeed = { Percent = 0.4 } } },
	},
}

return Summoners

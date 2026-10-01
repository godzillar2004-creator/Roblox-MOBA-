-- ReplicatedStorage.Shared.AbilitySystem.AbilitySchema

local AbilitySchema = {}

AbilitySchema.Default = {
	Id = "",
	Name = "",
	Description = "",

	-- Passive, RightClick, Q, E, R, Z
	Slot = "Q",

	-- Physical, Magical, Hybrid, None
	DamageType = "None",

	-- Tags from AbilityTags
	Tags = {},

	-- Damage/scaling values
	Scaling = {
		AD = 0,
		AP = 0,
		Health = 0,
		MaxHealth = 0,
		MissingHealth = 0,
	},

	-- Basic ability values
	BaseDamage = 0,
	Cooldown = 0,
	ManaCost = 0,
	HealthCostPercent = 0,

	Range = 0,
	Duration = 0,
	CastTime = 0,

	-- Optional recast information
	Recast = nil,

	-- Optional extra behavior/settings
	Properties = {},
}

function AbilitySchema.Validate(ability)
	assert(type(ability) == "table", "Ability must be a table")

	assert(type(ability.Id) == "string", "Ability.Id must be a string")
	assert(type(ability.Name) == "string", "Ability.Name must be a string")
	assert(type(ability.Description) == "string", "Ability.Description must be a string")

	assert(type(ability.Tags) == "table", "Ability.Tags must be a table")
	assert(type(ability.Scaling) == "table", "Ability.Scaling must be a table")

	return true
end

return AbilitySchema
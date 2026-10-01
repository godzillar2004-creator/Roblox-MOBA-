-- ReplicatedStorage.Shared.AbilitySystem.AbilityTags

local AbilityTags = {
	Ability = {
		Ranged = {
			Projectile = "Projectile",
			Beam = "Beam",
			AOE = "AOE",
			SingleTarget = "SingleTarget",
			Cone = "Cone",
			Line = "Line",
			GroundTarget = "GroundTarget",
		},

		Melee = {
			AOE = "AOE",
			SingleTarget = "SingleTarget",
			Cone = "Cone",
			OnHit = "OnHit",
			BasicAttackModifier = "BasicAttackModifier",
		},

		Recast = "Recast",
	},

	Movement = {
		Dash = "Dash",
		Blink = "Blink",
		Teleport = "Teleport",
		TerrainTraversal = "TerrainTraversal",
	},

	Effects = {
		Buff = "Buff",
		Transformation = "Transformation",
		Debuff = "Debuff",
		TrueSight = "TrueSight",
		Lockout = "Lockout",

		CC = {
			Slow = "Slow",
			Silence = "Silence",
			Stun = "Stun",
			Root = "Root",
			Knockback = "Knockback",
			Knockup = "Knockup",
			Fear = "Fear",
			Airborne = "Airborne",
		},
	},

	Damage = {
		DamageType = {
			Physical = "Physical",
			Magical = "Magical",
			True = "True",
			Hybrid = "Hybrid",
			None = "None",
		},

		Execute = "Execute",
		DamageOverTime = "DamageOverTime",
		PercentHealth = "PercentHealth",
		MissingHealth = "MissingHealth",
		DamageModifier = "DamageModifier",
		CriticalStrikeModifier = "CriticalStrikeModifier",
	},

	Objects = {
		Summon = "Summon",
		Deployable = "Deployable",
		Trap = "Trap",
		ProjectileObject = "ProjectileObject",
	},
}

return AbilityTags
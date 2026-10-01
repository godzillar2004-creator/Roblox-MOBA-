-- RED MAN - the base / test character (standard R6 rig).
--
-- To add a new character: duplicate this module into this folder and change the data.
-- CharacterRegistry auto-discovers every ModuleScript in the Characters folder.

return {
	Id = "RedMan",
	DisplayName = "Red Man",
	Description = "The base test character. Standard R6 rig, simple kit.",
	RigType = "R6",
	BodyColor = Color3.fromRGB(196, 40, 28),

	Resource = { Name = "Mana", Color = Color3.fromRGB(70, 130, 255) },

	-- Stats at level 0
	BaseStats = {
		MaxHealth = 600, MaxMana = 300, ManaRegen = 4,
		AttackDamage = 55, AbilityPower = 25,
		PhysicalArmor = 25, MagicArmor = 25,
		AttackSpeed = 1.0, Haste = 0, CritChance = 0, MoveSpeed = 16,
		-- hidden stats
		CritDamage = 1.75, ArmorPen = 0, MagicPen = 0, PassiveHealing = 2, Omnivamp = 0, LifeSteal = 0,
	},

	-- Stats gained per "level factor". Linear by default (factor == level).
	StatGrowth = {
		MaxHealth = 90, MaxMana = 30, ManaRegen = 0.5,
		AttackDamage = 4, AbilityPower = 3,
		PhysicalArmor = 3.5, MagicArmor = 1.25,
		AttackSpeed = 0.02, PassiveHealing = 0.2,
	},

	-- OPTIONAL power curve. PowerCurve(level) returns the growth multiplier for that level.
	--   Early-game character : concave, e.g. function(l) return 20 * math.sqrt(l / 20) end
	--   Late-game character  : convex,  e.g. function(l) return 20 * (l / 20) ^ 1.6 end
	-- Left nil = linear growth.
	PowerCurve = nil,

	BasicAttack = {
		Range = 7,
		Angle = 120,
		DamageType = "Physical",
		CanCrit = true,
		Components = {
			{ Type = "Physical", Base = 0, Scaling = { { Stat = "AttackDamage", Ratio = 1.0 } } },
		},
	},

	Passive = {
		Name = "Bloodlust",
		Description = "Gain 3% Omnivamp.",
		-- Permanent stat modifiers granted while the character is alive
		Modifiers = { Omnivamp = { Flat = 0.03 } },
	},

	Summoner = "Flash",

	Abilities = {
		-- ===== Ability 1 (Right Click) ==================================================
		Ability1 = {
			Id = "RedSlash",
			Name = "Red Slash",
			Description = "Slash in a cone, dealing Physical damage and slowing enemies. Recast within 3s for a wider follow-up slash.",
			DamageType = "Physical",
			MaxRank = 5,
			RankLevels = { 1, 3, 5, 7, 9 },
			Cooldown = { 6, 5.5, 5, 4.5, 4 },
			Cost = { 30, 35, 40, 45, 50 },
			Targeting = "Direction",
			Effects = {
				{
					Kind = "Area", Shape = "Cone", Range = 11, Angle = 100,
					Color = Color3.fromRGB(255, 70, 70),
					Damage = { Components = {
						{ Type = "Physical", Base = { 60, 90, 120, 150, 180 }, Scaling = { { Stat = "AttackDamage", Ratio = 0.8 } } },
					} },
					Statuses = { { Name = "Slow", Duration = 1.5, Magnitude = 0.3 } },
				},
			},
			Recast = {
				MaxCasts = 2, Window = 3,
				Effects = {
					{
						Kind = "Area", Shape = "Cone", Range = 13, Angle = 160,
						Color = Color3.fromRGB(255, 120, 60),
						Damage = { Components = {
							{ Type = "Physical", Base = { 36, 54, 72, 90, 108 }, Scaling = { { Stat = "AttackDamage", Ratio = 0.5 } } },
						} },
					},
				},
			},
		},

		-- ===== Ability 2 (Q) ===========================================================
		Ability2 = {
			Id = "CrimsonBolt",
			Name = "Crimson Bolt",
			Description = "Fire a bolt that deals Magical damage to the first enemy hit.",
			DamageType = "Magical",
			MaxRank = 5,
			RankLevels = { 1, 3, 5, 7, 9 },
			Cooldown = { 7, 6.5, 6, 5.5, 5 },
			Cost = { 40, 45, 50, 55, 60 },
			Targeting = "Direction",
			Effects = {
				{
					Kind = "Projectile", Speed = 90, Range = 50, Radius = 2.5, Pierce = 0,
					Color = Color3.fromRGB(255, 60, 120),
					Damage = { Components = {
						{ Type = "Magical", Base = { 70, 110, 150, 190, 230 }, Scaling = { { Stat = "AbilityPower", Ratio = 0.7 } } },
					} },
				},
			},
		},

		-- ===== Ability 3 (E) ===========================================================
		Ability3 = {
			Id = "Shockwave",
			Name = "Shockwave",
			Description = "Slam the ground, dealing Hybrid damage (Physical + Magical) around you and briefly stunning enemies.",
			DamageType = "Hybrid",
			MaxRank = 5,
			RankLevels = { 1, 3, 5, 7, 9 },
			Cooldown = { 14, 13, 12, 11, 10 },
			Cost = { 60, 65, 70, 75, 80 },
			Targeting = "Self",
			Effects = {
				{
					Kind = "Area", Shape = "Circle", Center = "Caster", Radius = 13,
					Color = Color3.fromRGB(255, 170, 40),
					Damage = { Components = {
						{ Type = "Physical", Base = { 30, 45, 60, 75, 90 }, Scaling = { { Stat = "AttackDamage", Ratio = 0.4 } } },
						{ Type = "Magical", Base = { 30, 45, 60, 75, 90 }, Scaling = { { Stat = "AbilityPower", Ratio = 0.4 } } },
					} },
					Statuses = { { Name = "Stun", Duration = 0.6 } },
				},
			},
		},

		-- ===== Ultimate (R) - unlocks at level 6 =======================================
		Ultimate = {
			Id = "CrimsonStorm",
			Name = "Crimson Storm",
			Description = "Call a storm at the target area, dealing heavy Magical damage, slowing enemies and suppressing their Magical abilities for 3s.",
			DamageType = "Magical",
			MaxRank = 3,
			RankLevels = { 6, 11, 16 },
			Cooldown = { 90, 75, 60 },
			Cost = { 100, 125, 150 },
			Targeting = "Point",
			Range = 40,
			Effects = {
				{
					Kind = "Area", Shape = "Circle", Center = "AimPoint", Radius = 16,
					Color = Color3.fromRGB(190, 30, 60),
					Damage = { Components = {
						{ Type = "Magical", Base = { 200, 350, 500 }, Scaling = { { Stat = "AbilityPower", Ratio = 1.0 } } },
					} },
					Statuses = {
						{ Name = "Slow", Duration = 2, Magnitude = 0.4 },
						{ Name = "SuppressMagical", Duration = 3 },
					},
				},
			},
		},
	},
}

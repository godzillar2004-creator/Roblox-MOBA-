-- ReplicatedStorage.Shared.Characters.Frieren
-- Frieren: scaling poke Mage.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AbilityTags = require(ReplicatedStorage.Shared.AbilitySystem.AbilityTags)

local C = AbilityTags.Ability
local D = AbilityTags.Damage.DamageType
local CC = AbilityTags.Effects.CC

return {
	Id = "Frieren",
	DisplayName = "Frieren",
	Description = "A scaling poke Mage who trades early power for Mana, range, and increasingly dangerous spellcasting.",
	RigType = "R6",
	BodyColor = Color3.fromRGB(223, 216, 230),
	Resource = { Name = "Mana", Color = Color3.fromRGB(70, 130, 255) },

	BaseStats = {
		MaxHealth = 525,
		MaxMana = 500,
		ManaRegen = 4,
		AttackDamage = 48,
		AbilityPower = 0,
		PhysicalArmor = 22,
		MagicArmor = 30,
		AttackSpeed = 0.60,
		Haste = 0,
		CritChance = 0,
		MoveSpeed = 16,
		CritDamage = 1.75,
		ArmorPen = 0,
		MagicPen = 0,
		PassiveHealing = 1,
		Omnivamp = 0,
		LifeSteal = 0,
	},

	StatGrowth = {
		MaxHealth = 80,
		MaxMana = 80,
		ManaRegen = 0.5,
		AttackDamage = 2.4,
		AbilityPower = 0,
		PhysicalArmor = 3.2,
		MagicArmor = 1.3,
		AttackSpeed = 0.015,
		PassiveHealing = 0,
	},

	BasicAttack = {
		Mode = "Projectile",
		Range = 550,
		Speed = 180,
		ProjectileRadius = 0.75,
		Color = Color3.fromRGB(245, 240, 255),
		MaxTargets = 1,
		DamageType = "Physical",
		CanCrit = true,
		Components = {
			{ Type = "Physical", Base = 0, Scaling = { { Stat = "AttackDamage", Ratio = 1.0 } } },
		},
	},

	Passive = {
		Name = "Zoltraak Mastery",
		Description = "Every 20 bonus Mana grants 1 Ability Power. Mana gained from levels and items counts; Frieren's base 500 Mana does not.",
		ManaPerAP = 20,
		ReferenceMana = 500,

		UI = {
			Mode = "Value",
			Title = "ZOLTRAAK",
			Subtitle = "MASTERY",

			GetValue = function(player, character)
				local maxMana = player:GetAttribute("MaxMana") or 500
				local bonusMana = math.max(0, maxMana - 500)

				return math.floor(bonusMana / 20)
			end,

			Format = function(value)
				return "+" .. tostring(value) .. " AP"
			end,
		},

		DynamicStats = function(player, state, stats)
			local bonusMana = math.max(0, (stats.MaxMana or 0) - 500)
			stats.AbilityPower = (stats.AbilityPower or 0) + math.floor(bonusMana / 20)
		end,
	},

	Summoner = "Flash",

	Abilities = {
		Ability1 = {
			Id = "Zoltraak",
			Name = "Zoltraak",
			Description = "Charge briefly, then fire an enormous magical beam in the mouse direction. At rank 5, it executes enemy champions below 5% maximum Health.",
			DamageType = "Magical",
			MaxRank = 5,
			RankLevels = { 1, 3, 5, 7, 9 },
			Cooldown = { 10, 9, 8, 7, 5.5 },
			Cost = { 70, 80, 90, 100, 110 },
			Targeting = "Direction",
			Tags = {
				[C.Ranged.Beam] = true,
				[C.Ranged.Line] = true,
				[D.Magical] = true,
			},
			Effects = {
				{
					Kind = "Beam",
					Visual = "Zoltraak",
					Range = 1050,
					Width = 14,
					Color = Color3.fromRGB(191, 145, 255),
					CastTime = { 1.20, 1.10, 1.00, 0.90, 0.80 },
					SelfSlow = 0.40,
					Damage = {
						Components = {
							{
								Type = "Magical",
								Base = { 60, 95, 130, 165, 200 },
								Scaling = { { Stat = "AbilityPower", Ratio = 0.70 } },
							},
						},
					},
					ExecuteBelowPercentMaxHealth = 0.05,
					ExecuteChampionsOnly = true,
				},
			},
		},

		Ability2 = {
			Id = "Restraint",
			Name = "Restraint",
			Description = "Send a magical golden restraint through the mouse direction. The first enemy hit takes damage and is Rooted.",
			DamageType = "Magical",
			MaxRank = 5,
			RankLevels = { 1, 3, 5, 7, 9 },
			Cooldown = { 14, 13, 12, 11, 10 },
			Cost = { 80, 90, 100, 110, 120 },
			Targeting = "Direction",
			Tags = {
				[C.Ranged.Projectile] = true,
				[C.Ranged.Line] = true,
				[CC.Root] = true,
				[D.Magical] = true,
			},
			Effects = {
				{
					Kind = "Projectile",
					Visual = "Restraint",
					Speed = 110,
					Range = 600,
					Radius = 3.5,
					Pierce = 0,
					ProjectileShape = "Ring",
					Color = Color3.fromRGB(255, 214, 82),
					Damage = {
						Components = {
							{
								Type = "Magical",
								Base = { 70, 100, 130, 160, 190 },
								Scaling = { { Stat = "AbilityPower", Ratio = 0.50 } },
							},
						},
					},
					Statuses = {
						{ Name = "Root", Duration = { 1.0, 1.15, 1.30, 1.45, 1.60 } },
					},
				},
			},
		},

		Ability3 = {
			Id = "DefensiveMagic",
			Name = "Defensive Magic",
			Description = "Place a magical barrier in the mouse direction. The barrier blocks projectiles and beams for a short duration.",
			DamageType = "Magical",
			MaxRank = 5,
			RankLevels = { 1, 3, 5, 7, 9 },
			Cooldown = { 26, 24, 22, 20, 18 },
			Cost = { 110, 125, 140, 155, 170 },
			Targeting = "Point",
			Range = 450,
			Tags = {
				[C.Ranged.GroundTarget] = true,
				[D.Magical] = true,
			},
			Effects = {
				{
					Kind = "Barrier",
					Duration = { 2.0, 2.25, 2.50, 2.75, 3.0 },
					Width = 14,
					Height = 10,
					Thickness = 2,
					Color = Color3.fromRGB(190, 225, 255),
				},
			},
		},

		Ultimate = {
			Id = "HeightOfMagic",
			Name = "Height of Magic",
			Description = "Unleash overwhelming magic around Frieren, damaging and Fearing nearby enemies. All basic abilities currently on cooldown are refreshed immediately.",
			DamageType = "Magical",
			MaxRank = 3,
			RankLevels = { 6, 11, 16 },
			Cooldown = { 100, 85, 70 },
			Cost = { 100, 125, 150 },
			Targeting = "Self",
			Tags = {
				[C.Melee.AOE] = true,
				[CC.Fear] = true,
				[D.Magical] = true,
			},
			Effects = {
				{
					Kind = "Area",
					Shape = "Circle",
					Center = "Caster",
					Radius = 8,
					RangeIndicator = true,
					Visual = "HeightOfMagic",
					AuraColor = Color3.fromRGB(110, 165, 255),
					IndicatorDuration = 0.80,
					IndicatorThickness = 0.8,
					Color = Color3.fromRGB(171, 120, 255),
					Damage = {
						Components = {
							{
								Type = "Magical",
								Base = { 140, 225, 310 },
								Scaling = { { Stat = "AbilityPower", Ratio = 0.70 } },
							},
						},
					},
					Statuses = {
						{ Name = "Fear", Duration = { 1.0, 1.25, 1.50 } },
					},
				},
				{
					Kind = "Custom",
					Run = function(ctx, services)
						local abilityService = services.Ability
						if abilityService and abilityService.ResetBasicAbilityCooldowns then
							abilityService.ResetBasicAbilityCooldowns(ctx.Player)
						end
					end,
				},
			},
		},
	},
}

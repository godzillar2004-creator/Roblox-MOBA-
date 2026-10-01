-- Item database: Tier 3 components, Tier 2 intermediates, and Tier 1 completed items.
--
-- Build paths are data only. The shop can read BuildFrom for the recipe and BuildsInto
-- (generated below) for the reverse "Builds Into" view. Unique item effects are stored as
-- metadata in Effects and are intentionally not implemented by the item database itself yet.
--
-- Stat mapping kept compatible with the current prototype:
--   Health -> MaxHealth, Mana -> MaxMana, Armor -> PhysicalArmor, MR -> MagicArmor
--   Health Regen -> PassiveHealing, Movement Speed % -> PercentStats.MoveSpeed
--   Attack Speed % -> PercentStats.AttackSpeed, Crit/Lifesteal -> fractional Stats values

local Items = {}
Items.List = {
	{
		Id = "IronBlade",
		Name = "Iron Blade",
		Tier = 3,
		Rarity = "Component",
		Class = "Component",
		Purpose = "Basic Component",
		Cost = 350,
		Description = "+Attack Damage",
		Icon = "",
		BuildFrom = {},
		Stats = {
			AttackDamage = 10,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "ArcaneTome",
		Name = "Arcane Tome",
		Tier = 3,
		Rarity = "Component",
		Class = "Component",
		Purpose = "Basic Component",
		Cost = 400,
		Description = "+Ability Power",
		Icon = "",
		BuildFrom = {},
		Stats = {
			AbilityPower = 20,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "SwiftGloves",
		Name = "Swift Gloves",
		Tier = 3,
		Rarity = "Component",
		Class = "Component",
		Purpose = "Basic Component",
		Cost = 300,
		Description = "+Attack Speed",
		Icon = "",
		BuildFrom = {},
		Stats = {},
		PercentStats = {
			AttackSpeed = 0.1,
		},
		Effects = {},
	},
	{
		Id = "IronPlate",
		Name = "Iron Plate",
		Tier = 3,
		Rarity = "Component",
		Class = "Component",
		Purpose = "Basic Component",
		Cost = 300,
		Description = "+Armor",
		Icon = "",
		BuildFrom = {},
		Stats = {
			PhysicalArmor = 15,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "WardCloak",
		Name = "Ward Cloak",
		Tier = 3,
		Rarity = "Component",
		Class = "Component",
		Purpose = "Basic Component",
		Cost = 350,
		Description = "+Magic Armor",
		Icon = "",
		BuildFrom = {},
		Stats = {
			MagicArmor = 20,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "VitalityCrystal",
		Name = "Vitality Crystal",
		Tier = 3,
		Rarity = "Component",
		Class = "Component",
		Purpose = "Basic Component",
		Cost = 400,
		Description = "+Health",
		Icon = "",
		BuildFrom = {},
		Stats = {
			MaxHealth = 150,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "KeenEdge",
		Name = "Keen Edge",
		Tier = 3,
		Rarity = "Component",
		Class = "Component",
		Purpose = "Basic Component",
		Cost = 400,
		Description = "+Critical Strike Chance",
		Icon = "",
		BuildFrom = {},
		Stats = {
			CritChance = 0.1,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "SapphireShard",
		Name = "Sapphire Shard",
		Tier = 3,
		Rarity = "Component",
		Class = "Component",
		Purpose = "Basic Component",
		Cost = 350,
		Description = "+Mana",
		Icon = "",
		BuildFrom = {},
		Stats = {
			MaxMana = 250,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "FlowingPendant",
		Name = "Flowing Pendant",
		Tier = 3,
		Rarity = "Component",
		Class = "Component",
		Purpose = "Basic Component",
		Cost = 250,
		Description = "+Mana Regen",
		Icon = "",
		BuildFrom = {},
		Stats = {},
		PercentStats = {
			ManaRegen = 0.25,
		},
		Effects = {},
	},
	{
		Id = "RegenerationCharm",
		Name = "Regeneration Charm",
		Tier = 3,
		Rarity = "Component",
		Class = "Component",
		Purpose = "Basic Component",
		Cost = 250,
		Description = "+Health Regen",
		Icon = "",
		BuildFrom = {},
		Stats = {},
		PercentStats = {
			PassiveHealing = 0.25,
		},
		Effects = {},
	},
	{
		Id = "TravelersBoots",
		Name = "Traveler's Boots",
		Tier = 3,
		Rarity = "Component",
		Class = "Component",
		Purpose = "Basic Component",
		Cost = 300,
		Description = "+Movement Speed %",
		Icon = "",
		BuildFrom = {},
		Stats = {},
		PercentStats = {
			MoveSpeed = 0.03,
		},
		Effects = {},
	},
	{
		Id = "FocusShard",
		Name = "Focus Shard",
		Tier = 3,
		Rarity = "Component",
		Class = "Component",
		Purpose = "Basic Component",
		Cost = 300,
		Description = "+Haste",
		Icon = "",
		BuildFrom = {},
		Stats = {
			Haste = 5,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "Greatblade",
		Name = "Greatblade",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 700,
		Description = "Attack Damage",
		Icon = "",
		BuildFrom = {"IronBlade", "IronBlade"},
		Stats = {
			AttackDamage = 20,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "GrandTome",
		Name = "Grand Tome",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 800,
		Description = "Ability Power",
		Icon = "",
		BuildFrom = {"ArcaneTome", "ArcaneTome"},
		Stats = {
			AbilityPower = 40,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "BattleCleaver",
		Name = "Battle Cleaver",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 650,
		Description = "AD + Haste",
		Icon = "",
		BuildFrom = {"IronBlade", "FocusShard"},
		Stats = {
			AttackDamage = 10,
			Haste = 5,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "VitalCore",
		Name = "Vital Core",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 650,
		Description = "Health + Health Regen",
		Icon = "",
		BuildFrom = {"VitalityCrystal", "RegenerationCharm"},
		Stats = {
			MaxHealth = 150,
		},
		PercentStats = {
			PassiveHealing = 0.25,
		},
		Effects = {},
	},
	{
		Id = "EnduranceCore",
		Name = "Endurance Core",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 700,
		Description = "Health + Haste",
		Icon = "",
		BuildFrom = {"VitalityCrystal", "FocusShard"},
		Stats = {
			MaxHealth = 150,
			Haste = 5,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "ArcaneFocus",
		Name = "Arcane Focus",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 950,
		Description = "AP + Mana Regen + Haste",
		Icon = "",
		BuildFrom = {"ArcaneTome", "FlowingPendant", "FocusShard"},
		Stats = {
			AbilityPower = 20,
			Haste = 5,
		},
		PercentStats = {
			ManaRegen = 0.25,
		},
		Effects = {},
	},
	{
		Id = "MysticCore",
		Name = "Mystic Core",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 1050,
		Description = "Mana + AP + Haste",
		Icon = "",
		BuildFrom = {"SapphireShard", "ArcaneTome", "FocusShard"},
		Stats = {
			MaxMana = 250,
			AbilityPower = 20,
			Haste = 5,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "ReinforcedPlate",
		Name = "Reinforced Plate",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 600,
		Description = "Armor",
		Icon = "",
		BuildFrom = {"IronPlate", "IronPlate"},
		Stats = {
			PhysicalArmor = 30,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "WardingMantle",
		Name = "Warding Mantle",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 700,
		Description = "Magic Armor",
		Icon = "",
		BuildFrom = {"WardCloak", "WardCloak"},
		Stats = {
			MagicArmor = 40,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "SpellFocus",
		Name = "Spell Focus",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 700,
		Description = "AP + Haste",
		Icon = "",
		BuildFrom = {"ArcaneTome", "FocusShard"},
		Stats = {
			AbilityPower = 20,
			Haste = 5,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "Warplate",
		Name = "Warplate",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 950,
		Description = "AD + Haste + Armor",
		Icon = "",
		BuildFrom = {"IronBlade", "FocusShard", "IronPlate"},
		Stats = {
			AttackDamage = 10,
			Haste = 5,
			PhysicalArmor = 15,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "EnchantedMantle",
		Name = "Enchanted Mantle",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 750,
		Description = "Magic Armor + AP",
		Icon = "",
		BuildFrom = {"WardCloak", "ArcaneTome"},
		Stats = {
			MagicArmor = 20,
			AbilityPower = 20,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "HuntersEdge",
		Name = "Hunter's Edge",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 650,
		Description = "AD + Movement Speed %",
		Icon = "",
		BuildFrom = {"IronBlade", "TravelersBoots"},
		Stats = {
			AttackDamage = 10,
		},
		PercentStats = {
			MoveSpeed = 0.03,
		},
		Effects = {},
	},
	{
		Id = "WardedVitality",
		Name = "Warded Vitality",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 1000,
		Description = "Health + Magic Armor + Health Regen",
		Icon = "",
		BuildFrom = {"VitalityCrystal", "WardCloak", "RegenerationCharm"},
		Stats = {
			MaxHealth = 150,
			MagicArmor = 20,
		},
		PercentStats = {
			PassiveHealing = 0.25,
		},
		Effects = {},
	},
	{
		Id = "ArcaneLens",
		Name = "Arcane Lens",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 800,
		Description = "AP + Magic Penetration",
		Icon = "",
		BuildFrom = {"ArcaneTome", "ArcaneTome"},
		Stats = {
			AbilityPower = 40,
			MagicPen = 15,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "SorcerersFocus",
		Name = "Sorcerer's Focus",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 700,
		Description = "AP + Movement Speed %",
		Icon = "",
		BuildFrom = {"ArcaneTome", "TravelersBoots"},
		Stats = {
			AbilityPower = 20,
		},
		PercentStats = {
			MoveSpeed = 0.03,
		},
		Effects = {},
	},
	{
		Id = "Bloodblade",
		Name = "Bloodblade",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 700,
		Description = "AD + Life Steal",
		Icon = "",
		BuildFrom = {"IronBlade", "IronBlade"},
		Stats = {
			AttackDamage = 20,
			LifeSteal = 0.08,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "BloodTome",
		Name = "Blood Tome",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 800,
		Description = "AP + Life Steal",
		Icon = "",
		BuildFrom = {"ArcaneTome", "ArcaneTome"},
		Stats = {
			AbilityPower = 40,
			LifeSteal = 0.05,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "ExecutionersEdge",
		Name = "Executioner's Edge",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 700,
		Description = "AD + Lethality",
		Icon = "",
		BuildFrom = {"IronBlade", "IronBlade"},
		Stats = {
			AttackDamage = 20,
			Lethality = 10,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "Keenblade",
		Name = "Keenblade",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 750,
		Description = "AD + Crit Chance",
		Icon = "",
		BuildFrom = {"IronBlade", "KeenEdge"},
		Stats = {
			AttackDamage = 10,
			CritChance = 0.1,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "WarriorsEdge",
		Name = "Warrior's Edge",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 650,
		Description = "AD + Attack Speed",
		Icon = "",
		BuildFrom = {"IronBlade", "SwiftGloves"},
		Stats = {
			AttackDamage = 10,
		},
		PercentStats = {
			AttackSpeed = 0.1,
		},
		Effects = {},
	},
	{
		Id = "Swiftblade",
		Name = "Swiftblade",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 1000,
		Description = "Crit Chance + Attack Speed + Movement Speed %",
		Icon = "",
		BuildFrom = {"KeenEdge", "SwiftGloves", "TravelersBoots"},
		Stats = {
			CritChance = 0.1,
		},
		PercentStats = {
			AttackSpeed = 0.1,
			MoveSpeed = 0.03,
		},
		Effects = {},
	},
	{
		Id = "AssassinsEdge",
		Name = "Assassin's Edge",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 650,
		Description = "AD + Haste + Lethality",
		Icon = "",
		BuildFrom = {"IronBlade", "FocusShard"},
		Stats = {
			AttackDamage = 10,
			Haste = 5,
			Lethality = 10,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "VitalBoots",
		Name = "Vital Boots",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 700,
		Description = "Health + Movement Speed %",
		Icon = "",
		BuildFrom = {"VitalityCrystal", "TravelersBoots"},
		Stats = {
			MaxHealth = 150,
		},
		PercentStats = {
			MoveSpeed = 0.03,
		},
		Effects = {},
	},
	{
		Id = "RapidEdge",
		Name = "Rapid Edge",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 700,
		Description = "Attack Speed + Crit Chance",
		Icon = "",
		BuildFrom = {"SwiftGloves", "KeenEdge"},
		Stats = {
			CritChance = 0.1,
		},
		PercentStats = {
			AttackSpeed = 0.1,
		},
		Effects = {},
	},
	{
		Id = "RendingEdge",
		Name = "Rending Edge",
		Tier = 2,
		Rarity = "Intermediate",
		Class = "Component",
		Purpose = "Intermediate Component",
		Cost = 700,
		Description = "AD + Armor Penetration",
		Icon = "",
		BuildFrom = {"IronBlade", "IronBlade"},
		Stats = {
			AttackDamage = 20,
			ArmorPen = 0.12,
		},
		PercentStats = {},
		Effects = {},
	},
	{
		Id = "ColossusCuirass",
		Name = "Colossus' Cuirass",
		Tier = 1,
		Rarity = "Mythic",
		Class = "Tank",
		Purpose = nil,
		Cost = 5200,
		Description = "",
		Icon = "",
		BuildFrom = {"EnduranceCore", "Warplate", "VitalityCrystal"},
		Stats = {
			MaxHealth = 850,
			PhysicalArmor = 30,
			AttackDamage = 20,
			Haste = 20,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Colossus Mark",
				Description = [[While within 700 units of an enemy champion, gain 1 Mark per second on that target, up to 3.
At 3 Marks, your next basic attack consumes them to deal:
70 + 5% maximum Health bonus physical damage
and grants:
8% of the bonus damage dealt as permanent maximum Health.
30-second cooldown per target.]],
			},
		},
	},
	{
		Id = "VerdantBastion",
		Name = "Verdant Bastion",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Tank",
		Purpose = "Sustain Tank",
		Cost = 4000,
		Description = "Sustain Tank",
		Icon = "",
		BuildFrom = {"WardedVitality", "VitalityCrystal", "RegenerationCharm"},
		Stats = {
			MaxHealth = 500,
			MagicArmor = 40,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Verdant Recovery",
				Description = [[Increase all healing, shielding, and Health Regen received by 25%.
This includes healing and shielding received from:
Character abilities
Items
Natural Health Regen
Other sources of regeneration or healing
Verdant Recovery increases the final amount received rather than increasing the strength of the original healing or shielding source multiple times.]],
			},
		},
	},
	{
		Id = "BastionsResolve",
		Name = "Bastion's Resolve",
		Tier = 1,
		Rarity = "Mythic",
		Class = "Tank",
		Purpose = "Resistance-Stacking / All-Rounder Tank",
		Cost = 5200,
		Description = "Resistance-Stacking / All-Rounder Tank",
		Icon = "",
		BuildFrom = {"ReinforcedPlate", "WardingMantle", "VitalityCrystal"},
		Stats = {
			MaxHealth = 800,
			PhysicalArmor = 50,
			MagicArmor = 50,
			Haste = 10,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Resolve",
				Description = [[Entering combat with an enemy champion generates 1 Resolve stack every second, up to 5 stacks.
At maximum stacks:
Increase your bonus Armor by 25%.
Increase your bonus Magic Armor by 25%.
The effect lasts until you leave combat with enemy champions.]],
			},
		},
	},
	{
		Id = "IronReprisal",
		Name = "Iron Reprisal",
		Tier = 1,
		Rarity = "Epic",
		Class = "Tank",
		Purpose = "Anti-Crit Tank",
		Cost = 3200,
		Description = "Anti-Crit Tank",
		Icon = "",
		BuildFrom = {"Warplate", "ReinforcedPlate", "VitalityCrystal"},
		Stats = {
			MaxHealth = 400,
			PhysicalArmor = 35,
			AttackDamage = 10,
			Haste = 10,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Resilience",
				Description = [[Reduce damage taken from Critical Strikes by 20%.
This reduction applies after the Critical Strike modifier is calculated.]],
			},
			Active = {
				Name = "Reprisal",
				Description = [[Release a shockwave around yourself that Slows nearby enemies by 70% for 2 seconds.
600-unit radius.
Reprisal deals no damage.
The purpose of the active is to make attacking or diving the Tank more difficult by allowing the Tank to heavily disrupt nearby enemies rather than simply adding another source of burst damage.]],
			},
		},
	},
	{
		Id = "FrostfireTempest",
		Name = "Frostfire Tempest",
		Tier = 1,
		Rarity = "Epic",
		Class = "Tank",
		Purpose = "Tank Ultimate-Haste / Teamfight Tank",
		Cost = 3200,
		Description = "Tank Ultimate-Haste / Teamfight Tank",
		Icon = "",
		BuildFrom = {"EnduranceCore", "WardingMantle", "TravelersBoots"},
		Stats = {
			MaxHealth = 300,
			MagicArmor = 20,
			Haste = 10,
			UltimateHaste = 15,
		},
		PercentStats = {
			MoveSpeed = 0.04,
		},
		Effects = {
			Active = {
				Name = "Frostfire Storm",
				Description = [[Casting your Ultimate summons a storm of fire and ice around you for 5 seconds.
The storm:
Deals repeated magic damage to enemy champions and NPCs within 350 units.
Slows enemies inside the storm by 30%.
Remains centered on you and moves with you.
The storm begins immediately when your Ultimate is cast.
Item Cooldown: 45 seconds
The cooldown begins when the Ultimate is cast.]],
			},
		},
	},
	{
		Id = "HeartOfTheColossus",
		Name = "Heart of the Colossus",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Tank",
		Purpose = "Sustained-Fighting Tank",
		Cost = 4000,
		Description = "Sustained-Fighting Tank",
		Icon = "",
		BuildFrom = {"ReinforcedPlate", "BattleCleaver", "RegenerationCharm"},
		Stats = {
			PhysicalArmor = 50,
			Haste = 20,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Devouring Presence",
				Description = [[After entering combat with an enemy champion, begin building Devour stacks.
After remaining in combat for 4 seconds, consume the stacks and release a pulse around yourself that:
Deals magic damage equal to 3% of your bonus Health to nearby enemy champions.
Heals you for 150% of the post-mitigation damage dealt.
The effect can trigger once every 4 seconds while you remain in combat.]],
			},
		},
	},
	{
		Id = "AegisEngine",
		Name = "Aegis Engine",
		Tier = 1,
		Rarity = "Epic",
		Class = "Tank",
		Purpose = "All-Rounder Shielding Tank",
		Cost = 3200,
		Description = "All-Rounder Shielding Tank",
		Icon = "",
		BuildFrom = {"EnduranceCore", "WardedVitality", "RegenerationCharm"},
		Stats = {
			MaxHealth = 300,
			MagicArmor = 20,
			Haste = 10,
		},
		PercentStats = {},
		Effects = {
			Active = {
				Name = "Bastion Shield",
				Description = [[Activate to gain a shield that absorbs:
250 + 10% of your bonus Health
The shield lasts for 5 seconds and gradually decays over its duration.
Cooldown: 30 seconds]],
			},
		},
	},
	{
		Id = "NullguardAegis",
		Name = "Nullguard Aegis",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Tank",
		Purpose = "Anti-Mage Tank",
		Cost = 4000,
		Description = "Anti-Mage Tank",
		Icon = "",
		BuildFrom = {"WardingMantle", "WardedVitality", "EnduranceCore"},
		Stats = {
			MaxHealth = 450,
			MagicArmor = 70,
			Haste = 10,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Null Ward",
				Description = [[After taking no Magic Damage for 15 seconds, gain a Magic Shield that absorbs:
15% of your maximum Health
in Magic Damage.
The shield remains until it is fully consumed or replaced by a new Null Ward shield.
Taking Magic Damage removes the requirement and places Null Ward on cooldown.]],
			},
		},
	},
	{
		Id = "EchoingCodex",
		Name = "Echoing Codex",
		Tier = 1,
		Rarity = "Mythic",
		Class = "Mage",
		Purpose = "Burst Mage",
		Cost = 5200,
		Description = "Burst Mage",
		Icon = "",
		BuildFrom = {"MysticCore", "GrandTome", "SapphireShard"},
		Stats = {
			AbilityPower = 120,
			Haste = 30,
			MaxMana = 500,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Echo",
				Description = [[Damaging an enemy with an ability builds Echo charges.
A subsequent ability consumes the stored charges to deal additional magic damage to the primary target and nearby enemies.
This makes the item strongest when the Mage can consistently land abilities across multiple targets.]],
			},
		},
	},
	{
		Id = "SearingCrown",
		Name = "Searing Crown",
		Tier = 1,
		Rarity = "Mythic",
		Class = "Mage",
		Purpose = "Sustained-Damage Mage",
		Cost = 5200,
		Description = "Sustained-Damage Mage",
		Icon = "",
		BuildFrom = {"GrandTome", "SpellFocus", "EnduranceCore"},
		Stats = {
			AbilityPower = 110,
			Haste = 30,
			MaxHealth = 500,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Burning Focus",
				Description = [[Remaining in combat with enemy champions increases your damage over time.
At maximum stacks, gain additional sustain and increased AP scaling based on bonus health.]],
			},
		},
	},
	{
		Id = "LifeburnCodex",
		Name = "Lifeburn Codex",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Mage",
		Purpose = "Percent-Health Mage",
		Cost = 4000,
		Description = "Percent-Health Mage",
		Icon = "",
		BuildFrom = {"GrandTome", "SpellFocus", "FocusShard"},
		Stats = {
			AbilityPower = 90,
			Haste = 25,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Lifeburn",
				Description = [[Ability damage applies a delayed magic burn based on the target's maximum health.
This item should be particularly effective against high-health Tanks without becoming an automatic anti-Tank item for every Mage.
This keeps it focused on AP + ability cycling + percent-health damage, rather than giving it built-in Magic Penetration and making it too universally effective against every target.]],
			},
		},
	},
	{
		Id = "ScorchedOracle",
		Name = "Scorched Oracle",
		Tier = 1,
		Rarity = "Epic",
		Class = "Mage",
		Purpose = "Mage Ultimate Interaction / Ultimate Haste",
		Cost = 3200,
		Description = "Mage Ultimate Interaction / Ultimate Haste",
		Icon = "",
		BuildFrom = {"GrandTome", "SpellFocus", "FocusShard"},
		Stats = {
			AbilityPower = 70,
			Haste = 20,
			UltimateHaste = 20,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Scorched Ground",
				Description = [[Damaging enemies with your ultimate creates a temporary magical zone beneath them.
Enemies inside the zone take recurring magic damage and have their Magic Armor reduced.
The item's Ultimate Haste reinforces an ultimate-centric Mage build.]],
			},
		},
	},
	{
		Id = "ChronoPrism",
		Name = "Chrono Prism",
		Tier = 1,
		Rarity = "Mythic",
		Class = "Mage",
		Purpose = "Stasis Mage",
		Cost = 5200,
		Description = "Stasis Mage",
		Icon = "",
		BuildFrom = {"EnchantedMantle", "WardingMantle", "GrandTome"},
		Stats = {
			AbilityPower = 100,
			MagicArmor = 60,
		},
		PercentStats = {},
		Effects = {
			Active = {
				Name = "Time Stop",
				Description = [[Enter Stasis for a short duration.
While in Stasis, the player cannot move, attack, cast abilities, use Summoner abilities, or activate other items.
This should remain a powerful defensive tool with a long cooldown.
Cooldown: 120 seconds]],
			},
		},
	},
	{
		Id = "VoidwakeScepter",
		Name = "Voidwake Scepter",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Mage",
		Purpose = "Magic Penetration Mage",
		Cost = 4000,
		Description = "Magic Penetration Mage",
		Icon = "",
		BuildFrom = {"ArcaneLens", "GrandTome", "RegenerationCharm"},
		Stats = {
			AbilityPower = 90,
			MagicPen = 25,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Life From Death",
				Description = [[Scoring a takedown shortly after damaging an enemy champion creates a magical nova at their death location.
The nova heals the holder and nearby allied champions.]],
			},
		},
	},
	{
		Id = "EverflowReliquary",
		Name = "Everflow Reliquary",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Mage",
		Purpose = "Mana / Sustained Mage",
		Cost = 4000,
		Description = "Mana / Sustained Mage",
		Icon = "",
		BuildFrom = {"MysticCore", "GrandTome", "VitalityCrystal"},
		Stats = {
			AbilityPower = 95,
			MaxHealth = 500,
			MaxMana = 600,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Everflow",
				Description = [[A portion of damage taken from enemy champions restores Mana.
Casting abilities also provides small amounts of sustain
The item should gradually accumulate additional Mana, Health, and AP over the match.
At maximum stacks, it provides a permanent power milestone rather than simply continuing to accumulate indefinitely.]],
			},
		},
	},
	{
		Id = "SoulwellGrimoire",
		Name = "Soulwell Grimoire",
		Tier = 1,
		Rarity = "Epic",
		Class = "Mage",
		Purpose = "Mage Healing / Support Hybrid",
		Cost = 3200,
		Description = "Mage Healing / Support Hybrid",
		Icon = "",
		BuildFrom = {"ArcaneFocus", "SpellFocus", "RegenerationCharm"},
		Stats = {
			AbilityPower = 50,
			Haste = 20,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Soul Siphon",
				Description = [[Dealing damage to enemy champions generates Soul Charges.
Healing or shielding an allied champion consumes the stored charges to restore their health.]],
			},
		},
	},
	{
		Id = "ShadowRequiem",
		Name = "Shadow Requiem",
		Tier = 1,
		Rarity = "Mythic",
		Class = "Assassin",
		Purpose = "Burst / Reset Assassin",
		Cost = 5200,
		Description = "Burst / Reset Assassin",
		Icon = "",
		BuildFrom = {"AssassinsEdge", "Greatblade", "HuntersEdge"},
		Stats = {
			AttackDamage = 90,
			Haste = 20,
			Lethality = 20,
		},
		PercentStats = {
			MoveSpeed = 0.06,
		},
		Effects = {
			Passive = {
				Name = "Predator",
				Description = [[Your abilities deal increased damage against enemy champions based on their missing Health.
The bonus damage scales from:
0% increased damage at full Health
to
15% increased damage against extremely low-health targets.
The bonus scales continuously with the target's missing Health.
Predator does not increase damage dealt to structures or NPCs.]],
			},
			Special = {
				Name = "Vanish",
				Description = [[After damaging an enemy champion, securing a takedown against that champion within 3 seconds causes you to become Untargetable for 1.5 seconds.
Vanish ends immediately if you:
Deal damage to an enemy
Cast an ability that affects an enemy
Perform a basic attack
Use an offensive item effect
Movement and non-offensive actions do not end Vanish.]],
			},
		},
	},
	{
		Id = "TrophyBlade",
		Name = "Trophy Blade",
		Tier = 1,
		Rarity = "Epic",
		Class = "Assassin",
		Purpose = "Snowball Assassin",
		Cost = 3200,
		Description = "Snowball Assassin",
		Icon = "",
		BuildFrom = {"AssassinsEdge", "Greatblade", "IronBlade"},
		Stats = {
			AttackDamage = 35,
			Haste = 10,
			Lethality = 10,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Trophy",
				Description = [[Scoring a takedown against an enemy champion permanently grants 1 Trophy stack.
Each Trophy stack grants:
+5 Attack Damage
There is no maximum number of Trophy stacks.]],
			},
		},
	},
	{
		Id = "ReapersMark",
		Name = "Reaper's Mark",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Assassin",
		Purpose = "Execute Assassin / Crit Assassin",
		Cost = 4000,
		Description = "Execute Assassin / Crit Assassin",
		Icon = "",
		BuildFrom = {"ExecutionersEdge", "Keenblade", "IronBlade"},
		Stats = {
			AttackDamage = 70,
			Lethality = 20,
			CritChance = 0.25,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Reap",
				Description = [[When your damage would reduce an enemy champion below 5% of their maximum Health, execute them.
Reap does not trigger against targets above the threshold and provides no additional damage against healthy enemies.]],
			},
		},
	},
	{
		Id = "PursuersStep",
		Name = "Pursuer's Step",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Assassin",
		Purpose = "Mobility Assassin",
		Cost = 4000,
		Description = "Mobility Assassin",
		Icon = "",
		BuildFrom = {"ExecutionersEdge", "HuntersEdge", "IronBlade"},
		Stats = {
			AttackDamage = 65,
			Lethality = 20,
		},
		PercentStats = {
			MoveSpeed = 0.08,
		},
		Effects = {
			Active = {
				Name = "Pursue",
				Description = [[Dash through or beyond a target enemy champion.
Upon completing the dash:
Deal physical damage to the target.
Gain 20% increased damage against that target for 3 seconds.
The increased damage applies to damage dealt by both basic attacks and abilities.
Pursue cannot target structures.
Cooldown: 25 seconds]],
			},
		},
	},
	{
		Id = "Gravehook",
		Name = "Gravehook",
		Tier = 1,
		Rarity = "Mythic",
		Class = "Assassin",
		Purpose = "Anti-Armor / Anti-Low-Health Assassin",
		Cost = 5200,
		Description = "Anti-Armor / Anti-Low-Health Assassin",
		Icon = "",
		BuildFrom = {"ExecutionersEdge", "AssassinsEdge", "Greatblade"},
		Stats = {
			AttackDamage = 85,
			Lethality = 30,
			Haste = 15,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Crippling Cut",
				Description = [[Damaging an enemy champion with a basic attack or ability while they are at or below 50% of their maximum Health applies Cripple for 1 second.
Cripple: Slow the target by 30%.
Damaging the same target again while Cripple is active refreshes its duration rather than increasing the Slow.]],
			},
		},
	},
	{
		Id = "ArcaneReaver",
		Name = "Arcane Reaver",
		Tier = 1,
		Rarity = "Epic",
		Class = "Assassin",
		Purpose = "AP Snowball Assassin / Hybrid Assassin",
		Cost = 3200,
		Description = "AP Snowball Assassin / Hybrid Assassin",
		Icon = "",
		BuildFrom = {"BloodTome", "SorcerersFocus", "TravelersBoots"},
		Stats = {
			AbilityPower = 30,
			LifeSteal = 0.05,
		},
		PercentStats = {
			MoveSpeed = 0.04,
		},
		Effects = {
			Passive = {
				Name = "Arcane Trophy",
				Description = [[Scoring a takedown against an enemy champion permanently grants 1 Arcane Trophy stack.
Each Arcane Trophy stack grants:
+5 Ability Power
There is no maximum number of Arcane Trophy stacks.
At 10 stacks, gain:
10% bonus Movement Speed
The Movement Speed bonus is lost if Arcane Reaver falls below 10 stacks.
Death Penalty
When you die, you permanently lose 50% of your current Arcane Trophy stacks, rounded down.
Example:
9 stacks → lose 4 → remain at 5
10 stacks → lose 5 → remain at 5
21 stacks → lose 10 → remain at 11
Any Ability Power and Movement Speed gained from lost stacks is immediately removed.]],
			},
		},
	},
	{
		Id = "HexstepBlade",
		Name = "Hexstep Blade",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Assassin",
		Purpose = "Hybrid Assassin",
		Cost = 4000,
		Description = "Hybrid Assassin",
		Icon = "",
		BuildFrom = {"Greatblade", "GrandTome", "SorcerersFocus"},
		Stats = {
			AttackDamage = 40,
			AbilityPower = 50,
		},
		PercentStats = {
			MoveSpeed = 0.07,
		},
		Effects = {
			Passive = {
				Name = "Hexstep",
				Description = [[Damaging an enemy champion with a basic attack or ability deals:
60 + 20% AP bonus magic damage
and grants 30% bonus Movement Speed for 1.5 seconds.
The effect has a 10-second cooldown per enemy champion.
Subsequent triggers against the same target while the Movement Speed effect is active refresh its duration rather than stacking the Movement Speed.]],
			},
		},
	},
	{
		Id = "VenomFang",
		Name = "Venom Fang",
		Tier = 1,
		Rarity = "Epic",
		Class = "Assassin",
		Purpose = "Anti-Shield / Anti-Armor Assassin",
		Cost = 3200,
		Description = "Anti-Shield / Anti-Armor Assassin",
		Icon = "",
		BuildFrom = {"RendingEdge", "BattleCleaver", "IronBlade"},
		Stats = {
			AttackDamage = 40,
			Haste = 15,
			ArmorPen = 0.12,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Venom",
				Description = [[Damaging an enemy champion with a basic attack or ability applies Venom for 3 seconds.
While Venom is active:
Shields gained by the target are 35% less effective.
When Venom is first applied, 35% of the target's current shields are immediately removed.
Applying Venom to a target that is already afflicted by Venom refreshes the duration but does not repeatedly remove shields.]],
			},
		},
	},
	{
		Id = "OpeningBarrage",
		Name = "Opening Barrage",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Marksman",
		Purpose = "Marksman Ultimate-Interaction Item",
		Cost = 4000,
		Description = "Marksman Ultimate-Interaction Item",
		Icon = "",
		BuildFrom = {"RapidEdge", "Swiftblade", "TravelersBoots"},
		Stats = {
			CritChance = 0.25,
		},
		PercentStats = {
			AttackSpeed = 0.4,
			MoveSpeed = 0.05,
		},
		Effects = {
			Passive = {
				Name = "Opening Barrage",
				Description = [[After casting your ultimate, your next 5 basic attacks become empowered.
Gain 30% bonus Attack Speed for the empowered attacks.
Empowered attacks gain 20% increased Critical Strike Damage.
If an empowered attack already critically strikes, the additional critical modifier still applies]],
			},
		},
	},
	{
		Id = "ImperialEdge",
		Name = "Imperial Edge",
		Tier = 1,
		Rarity = "Mythic",
		Class = "Marksman",
		Purpose = "Critical Damage Item",
		Cost = 5200,
		Description = "Critical Damage Item",
		Icon = "",
		BuildFrom = {"Greatblade", "Keenblade", "IronBlade"},
		Stats = {
			AttackDamage = 85,
			CritChance = 0.3,
			CritDamage = 0.25,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Perfect Edge",
				Description = "Increases your Critical Strike Damage by 25%.",
			},
		},
	},
	{
		Id = "Stormrider",
		Name = "Stormrider",
		Tier = 1,
		Rarity = "Mythic",
		Class = "Marksman",
		Purpose = "Crit / Mobility Marksman",
		Cost = 5200,
		Description = "Crit / Mobility Marksman",
		Icon = "",
		BuildFrom = {"Swiftblade", "Keenblade", "HuntersEdge"},
		Stats = {
			AttackDamage = 65,
			CritChance = 0.25,
		},
		PercentStats = {
			AttackSpeed = 0.3,
			MoveSpeed = 0.07,
		},
		Effects = {
			Passive = {
				Name = "Energized",
				Description = [[Movement and basic attacks build toward an Energized attack.
The Energized attack:
Deals 75 bonus magic damage.
Grants 25% bonus Movement Speed for 1.5 seconds.]],
			},
		},
	},
	{
		Id = "TripleDraw",
		Name = "Triple Draw",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Marksman",
		Purpose = "Multi-Attack Marksman",
		Cost = 4000,
		Description = "Multi-Attack Marksman",
		Icon = "",
		BuildFrom = {"WarriorsEdge", "HuntersEdge", "SwiftGloves"},
		Stats = {
			AttackDamage = 55,
		},
		PercentStats = {
			AttackSpeed = 0.35,
			MoveSpeed = 0.05,
		},
		Effects = {
			Passive = {
				Name = "Loaded Sequence",
				Description = [[Basic attacks build Loaded stacks.
At maximum stacks, the next basic attack consumes all stacks to deal bonus physical damage.
The bonus damage is increased against targets with lower current health.]],
			},
		},
	},
	{
		Id = "ArcaneVolley",
		Name = "Arcane Volley",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Marksman",
		Purpose = "AP Marksman / On-Hit Hybrid",
		Cost = 4000,
		Description = "AP Marksman / On-Hit Hybrid",
		Icon = "",
		BuildFrom = {"GrandTome", "WarriorsEdge", "FocusShard"},
		Stats = {
			AbilityPower = 70,
			Haste = 20,
		},
		PercentStats = {
			AttackSpeed = 0.3,
		},
		Effects = {
			Passive = {
				Name = "Arcane Ammunition",
				Description = "Basic attacks deal additional magic damage based partly on AP.",
			},
		},
	},
	{
		Id = "Bloodshot",
		Name = "Bloodshot",
		Tier = 1,
		Rarity = "Mythic",
		Class = "Marksman",
		Purpose = "Life Steal / Ability-Weaving Marksman",
		Cost = 5200,
		Description = "Life Steal / Ability-Weaving Marksman",
		Icon = "",
		BuildFrom = {"Bloodblade", "Keenblade", "IronBlade"},
		Stats = {
			AttackDamage = 80,
			CritChance = 0.25,
			LifeSteal = 0.15,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Blood Draw",
				Description = [[After casting an ability, your next basic attack becomes empowered.
The empowered attack:
Deals 60 + 25% AP bonus magic damage.
Heals the user for 75% of the bonus damage dealt.
Has a 3-second internal cooldown.]],
			},
		},
	},
	{
		Id = "PhantomCircuit",
		Name = "Phantom Circuit",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Marksman",
		Purpose = "Hybrid On-Hit Marksman",
		Cost = 4000,
		Description = "Hybrid On-Hit Marksman",
		Icon = "",
		BuildFrom = {"GrandTome", "SpellFocus", "WarriorsEdge"},
		Stats = {
			AttackDamage = 45,
			AbilityPower = 50,
			Haste = 15,
		},
		PercentStats = {
			AttackSpeed = 0.25,
		},
		Effects = {
			Passive = {
				Name = "Phantom Sequence",
				Description = [[Basic attacks grant bonus Attack Speed stacks.
At maximum Attack Speed stacks, the player begins building Phantom stacks.
When enough Phantom stacks are reached, the next basic attack creates a Phantom Hit that repeats selected on-hit effects.]],
			},
		},
	},
	{
		Id = "LastlightAegis",
		Name = "Lastlight Aegis",
		Tier = 1,
		Rarity = "Epic",
		Class = "Marksman",
		Purpose = "Defensive Crit Marksman",
		Cost = 3200,
		Description = "Defensive Crit Marksman",
		Icon = "",
		BuildFrom = {"Keenblade", "EnduranceCore", "FocusShard"},
		Stats = {
			CritChance = 0.25,
			Haste = 15,
			MaxHealth = 300,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Last Stand",
				Description = [[When incoming damage would reduce the user below 30% maximum health, gain a temporary shield equal to 20% maximum health for 4 seconds.
Cooldown: 90 seconds]],
			},
		},
	},
	{
		Id = "RavenousFang",
		Name = "Ravenous Fang",
		Tier = 1,
		Rarity = "Mythic",
		Class = "Warrior",
		Purpose = "Sustained Fighting / Self-Healing Warrior",
		Cost = 5200,
		Description = "Sustained Fighting / Self-Healing Warrior",
		Icon = "",
		BuildFrom = {"Greatblade", "BattleCleaver", "VitalityCrystal"},
		Stats = {
			AttackDamage = 75,
			MaxHealth = 500,
			Haste = 20,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Ravenous Strike",
				Description = [[Every 10 seconds, your next basic attack against an enemy champion is guaranteed to Critical Strike.
The empowered attack:
Deals increased Critical Strike damage.
Heals you based on your Attack Damage and missing Health.
Converts any healing that exceeds your maximum Health into temporary bonus Health for 8 seconds.
The guaranteed Critical Strike is only granted to the first eligible basic attack after the cooldown is ready.
Healing
The attack heals for an amount based on:
90% bonus AD + 4% of your missing Health
The healing cannot be triggered against structures.]],
			},
		},
	},
	{
		Id = "FocusedAssault",
		Name = "Focused Assault",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Warrior",
		Purpose = "Haste / Ability-Damage Warrior",
		Cost = 4000,
		Description = "Haste / Ability-Damage Warrior",
		Icon = "",
		BuildFrom = {"BattleCleaver", "Greatblade", "FocusShard"},
		Stats = {
			AttackDamage = 40,
			Haste = 45,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Focused Will",
				Description = [[Dealing damage to an enemy champion with an ability generates 1 Focus stack, up to 4 stacks.
Each Focus stack increases your ability damage by 3%.
At maximum stacks, gain:
12% increased ability damage.
Focused Will lasts for 6 seconds and refreshes whenever you gain a new stack.
Each individual ability cast can only generate 1 Focus stack.]],
			},
		},
	},
	{
		Id = "SecondDawn",
		Name = "Second Dawn",
		Tier = 1,
		Rarity = "Mythic",
		Class = "Warrior",
		Purpose = "Warrior Revive",
		Cost = 5200,
		Description = "Warrior Revive",
		Icon = "",
		BuildFrom = {"Warplate", "EnchantedMantle", "VitalityCrystal"},
		Stats = {
			AttackDamage = 35,
			AbilityPower = 35,
			Haste = 20,
			MaxHealth = 400,
			PhysicalArmor = 25,
			MagicArmor = 25,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Second Dawn",
				Description = [[Upon taking lethal damage, enter a brief resurrection state.
During this state:
The user becomes untargetable.
The user cannot move, attack, cast abilities, use Summoner abilities, or activate items.
After the resurrection state ends, the user returns with 30% of their maximum Health.
Cooldown: 120 seconds
Second Dawn is intentionally a generalist Mythic, giving a little offensive power, ability uptime, durability, and access to both physical and magical defenses. Its main source of power is still Second Dawn, so the individual stat values stay relatively moderate.]],
			},
		},
	},
	{
		Id = "AscendantCore",
		Name = "Ascendant Core",
		Tier = 1,
		Rarity = "Mythic",
		Class = "Warrior",
		Purpose = "Warrior Ultimate-Haste / Team-Fight Utility",
		Cost = 5200,
		Description = "Warrior Ultimate-Haste / Team-Fight Utility",
		Icon = "",
		BuildFrom = {"EnduranceCore", "VitalityCrystal", "FocusShard"},
		Stats = {
			MaxHealth = 600,
			AttackDamage = 25,
			Haste = 50,
			UltimateHaste = 20,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Transcendence",
				Description = [[Casting your Ultimate causes you to enter a Transcendent state for 9 seconds.
While Transcendent:
Increase your maximum Health by 12.5%.
You and allied champions within 1,200 units are healed for a small percentage of your maximum Health when Transcendence begins.
Every 3 seconds, you and nearby allied champions are healed again.]],
			},
		},
	},
	{
		Id = "Bloodwall",
		Name = "Bloodwall",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Warrior",
		Purpose = "AD / Defensive Warrior",
		Cost = 4000,
		Description = "AD / Defensive Warrior",
		Icon = "",
		BuildFrom = {"Greatblade", "VitalCore", "BattleCleaver"},
		Stats = {
			AttackDamage = 65,
			MaxHealth = 500,
			Haste = 20,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Bloodwall",
				Description = [[When incoming damage would reduce you below 30% of your maximum Health, gain a shield equal to 60% of your bonus Health.
Shield duration: 4.5 seconds
Shield decays over its duration
Cooldown: 90 seconds]],
			},
		},
	},
	{
		Id = "SufferingsEdge",
		Name = "Suffering's Edge",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Warrior",
		Purpose = "Damage-Cleansing Warrior",
		Cost = 4000,
		Description = "Damage-Cleansing Warrior",
		Icon = "",
		BuildFrom = {"BattleCleaver", "ReinforcedPlate", "IronBlade"},
		Stats = {
			AttackDamage = 55,
			PhysicalArmor = 30,
			Haste = 25,
		},
		PercentStats = {},
		Effects = {
			Passive = {
				Name = "Ignore Pain",
				Description = [[Reduce incoming post-mitigation physical and magic damage by 20%.
The prevented damage is stored as Pain instead of being dealt immediately.
Over the next 3 seconds, the stored Pain is dealt to you as true damage, divided evenly over the duration.
If an enemy champion dies within 3 seconds of you damaging them:
Remove all remaining stored Pain.
Heal for 75% of your bonus Attack Damage over 2 seconds.]],
			},
		},
	},
	{
		Id = "WarboundStride",
		Name = "Warbound Stride",
		Tier = 1,
		Rarity = "Mythic",
		Class = "Warrior",
		Purpose = "Warrior Gap Closer",
		Cost = 5200,
		Description = "Warrior Gap Closer",
		Icon = "",
		BuildFrom = {"BattleCleaver", "WarriorsEdge", "HuntersEdge"},
		Stats = {
			AttackDamage = 70,
			Haste = 20,
		},
		PercentStats = {
			AttackSpeed = 0.25,
			MoveSpeed = 0.05,
		},
		Effects = {
			Active = {
				Name = "Warbound Charge",
				Description = [[Perform a short-range movement attack that damages and slows enemies around you.
The user can move while casting.
Each enemy champion hit grants temporary Movement Speed.
The movement portion of the ability carries the user through the attack rather than rooting them in place.]],
			},
		},
	},
	{
		Id = "TitansEdge",
		Name = "Titan's Edge",
		Tier = 1,
		Rarity = "Legendary",
		Class = "Warrior",
		Purpose = "Percent-Health Warrior",
		Cost = 4000,
		Description = "Percent-Health Warrior",
		Icon = "",
		BuildFrom = {"Greatblade", "WarriorsEdge", "Bloodblade"},
		Stats = {
			AttackDamage = 65,
			LifeSteal = 0.1,
		},
		PercentStats = {
			AttackSpeed = 0.25,
		},
		Effects = {
			Passive = {
				Name = "Titanbreaker",
				Description = [[Basic attacks deal additional physical damage equal to 3% of the target's current Health.
Against minions and neutral monsters, Titanbreaker's bonus damage is reduced by 50%.]],
			},
		},
	},
}

Items.ById = {}
for _, item in ipairs(Items.List) do
	Items.ById[item.Id] = item
	item.BuildsInto = item.BuildsInto or {}
end

-- Build the reverse recipe list used by the shop's "BUILDs INTO" section.
for _, item in ipairs(Items.List) do
	for _, componentId in ipairs(item.BuildFrom or {}) do
		local component = Items.ById[componentId]
		if component then
			component.BuildsInto = component.BuildsInto or {}
			table.insert(component.BuildsInto, item.Id)
		end
	end
end

function Items.Get(id: string)
	return Items.ById[id]
end

function Items.GetBuildPath(id: string)
	local item = Items.Get(id)
	return item and item.BuildFrom or {}
end

function Items.GetBuildsInto(id: string)
	local item = Items.Get(id)
	return item and item.BuildsInto or {}
end

return Items
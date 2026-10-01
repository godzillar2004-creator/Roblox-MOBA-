--!strict
-- Central tuning + constants shared by client and server.
-- Everything gameplay-relevant that is likely to be rebalanced lives here.

local Config = {}

-- ===== Damage types ==========================================================
-- Damage type is an EXPLICIT property on every ability / damage component.
-- It is never inferred from what stat the ability scales with.
Config.DamageType = {
	Physical = "Physical",
	Magical = "Magical",
	Hybrid = "Hybrid", -- ability contains both Physical and Magical components
	True = "True", -- ignores armor and magic armor entirely
}

-- ===== Teams =================================================================
Config.Teams = {
	{ Name = "Blue", Color = BrickColor.new("Bright blue") },
	{ Name = "Red", Color = BrickColor.new("Bright red") },
}

-- ===== Progression ===========================================================
Config.StartLevel = 0
Config.MaxLevel = 20
Config.UltimateUnlockLevel = 6
Config.StartingGold = 500
Config.InventorySlots = 6
Config.SellRefundRatio = 0.7

-- XP needed to go from `level` to `level + 1` (level 0 -> 1 is intentionally quick).
-- Total XP for 0 -> 20 is ~8,800 which is tuned for a 15-20 minute match.
function Config.XpToNextLevel(level: number): number
	return 60 + 40 * level
end

Config.Rewards = {
	PlayerKill = { Gold = 300, XpBase = 120, XpPerVictimLevel = 20 },
	AssistRatio = { Gold = 0.5, Xp = 0.5 },
	AssistWindow = 10, -- seconds a damage contribution counts for an assist
}

-- Respawn timer = Base + PerLevel * level
Config.Respawn = { Base = 4, PerLevel = 1.2 }

-- ===== Combat =================================================================
Config.Block = {
	DamageReduction = 0.5, -- fraction of damage removed when hit from the front
	FrontArcDot = 0.0, -- dot(facing, toAttacker) must be > this to count as "front"
	MoveSpeedMultiplier = 0.5,
}

Config.HitRadius = 1.75 -- generous leniency added to targets when testing shapes
Config.VerticalTolerance = 10 -- studs of Y difference allowed for area checks

-- ===== Input (rebind here) ====================================================
-- NOTE: the design doc lists Right Click as both Block and Ability 1.
-- Right Click is Ability 1 (per the Ability Controls section) and Block is on F.
Config.Keybinds = {
	Basic = Enum.UserInputType.MouseButton1,
	Ability1 = Enum.UserInputType.MouseButton2,
	Ability2 = Enum.KeyCode.Q,
	Ability3 = Enum.KeyCode.E,
	Ultimate = Enum.KeyCode.R,
	Summoner = Enum.KeyCode.Z,
	Block = Enum.KeyCode.F,
	Scoreboard = Enum.KeyCode.Tab,
	Shop = Enum.KeyCode.P,
}

-- Order abilities appear on the ability bar
Config.AbilitySlots = { "Ability1", "Ability2", "Ability3", "Ultimate", "Summoner" }
Config.AllSlots = { "Basic", "Ability1", "Ability2", "Ability3", "Ultimate", "Summoner" }

Config.SlotKeyLabels = {
	Basic = "LMB",
	Ability1 = "RMB",
	Ability2 = "Q",
	Ability3 = "E",
	Ultimate = "R",
	Summoner = "Z",
}

-- Default rank-up levels (character abilities can override with RankLevels)
Config.DefaultRankLevels = {
	Standard = { 1, 3, 5, 7, 9 },
	Ultimate = { 6, 11, 16 },
}

-- ===== Stats ==========================================================================
-- Format: "int" | "dec1" | "dec2" | "pct"   (pct values are stored as 0-1 fractions)
Config.Stats = {
	MaxHealth = { Display = "Max Health", Format = "int" },
	MaxMana = { Display = "Max Mana", Format = "int" },
	ManaRegen = { Display = "Mana Regen", Format = "dec1" },

	AttackDamage = { Display = "Attack Damage", Format = "int" }, -- AD: scaling stat, NOT a damage type
	AbilityPower = { Display = "Ability Power", Format = "int" }, -- AP: scaling stat, NOT a damage type
	PhysicalArmor = { Display = "Physical Armor", Format = "int" },
	MagicArmor = { Display = "Magic Armor", Format = "int" },
	AttackSpeed = { Display = "Attack Speed", Format = "dec2" },
	Haste = { Display = "Haste", Format = "int" },
	CritChance = { Display = "Crit Chance", Format = "pct" },
	MoveSpeed = { Display = "Move Speed", Format = "int" },

	-- Hidden stats (exist internally, not shown on the HUD)
	CritDamage = { Display = "Crit Damage", Format = "pct", Hidden = true },
	ArmorPen = { Display = "Armor Penetration", Format = "pct", Hidden = true },
	MagicPen = { Display = "Magic Penetration", Format = "pct", Hidden = true },
	PassiveHealing = { Display = "Passive Healing", Format = "dec1", Hidden = true },
	Omnivamp = { Display = "Omnivamp", Format = "pct", Hidden = true },
	LifeSteal = { Display = "Life Steal", Format = "pct", Hidden = true },
}

-- Every stat name (used to iterate and to write replicated attributes)
Config.StatList = {
	"MaxHealth", "MaxMana", "ManaRegen",
	"AttackDamage", "AbilityPower", "PhysicalArmor", "MagicArmor",
	"AttackSpeed", "Haste", "CritChance", "MoveSpeed",
	"CritDamage", "ArmorPen", "MagicPen", "PassiveHealing", "Omnivamp", "LifeSteal",
}

-- Stats shown in the HUD stat panel, in order
Config.DisplayedStats = {
	"AttackDamage", "AbilityPower", "PhysicalArmor", "MagicArmor",
	"AttackSpeed", "Haste", "CritChance", "MoveSpeed",
}

-- Defaults used when a character definition omits a stat
Config.StatDefaults = {
	MaxHealth = 500, MaxMana = 200, ManaRegen = 3,
	AttackDamage = 50, AbilityPower = 0, PhysicalArmor = 20, MagicArmor = 20,
	AttackSpeed = 1, Haste = 0, CritChance = 0, MoveSpeed = 16,
	CritDamage = 1.75, ArmorPen = 0, MagicPen = 0, PassiveHealing = 1, Omnivamp = 0, LifeSteal = 0,
}

--- ===== Status effects =================================================================
-- Statuses are plain names; abilities apply them with a duration (+ optional magnitude).
Config.Statuses = {
	"Stun",
	"Root",
	"Slow",
	"Silence",
	"SuppressPhysical",
	"SuppressMagical",
	"Fear",
	"Airborne",
	"Lockout",
}

-- ===== Misc =========================================================================
Config.Remotes = {
	"CastAbility", "BasicAttack", "SetBlocking", "RankUpAbility",
	"ShopBuy", "ShopSell", "MoveItem",
	"DamageNumber", "MoveCommand", "Notify",
}
Config.RemoteFunctions = { "RequestDeploy" }

Config.Camera = {
	Distance = 64, -- distance from the focus point to the camera
	Pitch = 56, -- degrees below horizontal (League-style: ~56° below horizontal / 34° from top-down)
	FieldOfView = 40,
}

return Config

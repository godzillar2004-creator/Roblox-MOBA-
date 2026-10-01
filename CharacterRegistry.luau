--[[
	CharacterRegistry
	Loads every character module under Shared/Characters, normalises + validates it,
	and resolves abilities (including the shared Summoner spells).

	ABILITY SCHEMA (all fields optional unless noted)
	-------------------------------------------------
	Id, Name, Description                         (required: Name)
	DamageType   = "Physical" | "Magical" | "Hybrid"   explicit; nil = deals no damage
	MaxRank, RankLevels = {levels at which each rank may be learned}
	Cooldown, Cost = number or per-rank table
	Targeting    = "Self" | "Direction" | "Point"
	Range        = max cast range for Point targeting
	Effects      = list of effects (run in order when cast):
	  { Kind = "Area", Shape = "Circle"|"Cone"|"Line", Center = "Caster"|"AimPoint",
	    Radius | Range+Angle | Length+Width, Damage = {Components}, Statuses = {...}, Color = Color3,
	    Condition = function(ctx) -> bool }
	  { Kind = "Projectile", Speed, Range, Radius, Pierce, Damage, Statuses, Color }
	  { Kind = "Dash", Mode = "Blink"|"Dash", Distance, Duration }
	  { Kind = "Buff", Name, Duration, Stats = { Stat = {Flat=, Percent=} } }
	  { Kind = "Heal", Amount = number|table, Scaling = {...} }
	  { Kind = "Custom", Run = function(ctx) end }     <- character specific logic hook
	Recast       = { MaxCasts, Window, Effects }      extra casts (no cost, no cooldown until finished)

	DAMAGE COMPONENT
	  { Type = "Physical"|"Magical", Base = number|table, Scaling = { {Stat=, Ratio=}, ... } }
	  Hybrid abilities simply contain both a Physical and a Magical component, so future
	  mechanics can interact with each component separately.

	Future-facing hooks already supported by the runtime: Recast, per-effect Condition,
	Custom effects, damage modifiers (DamageService.RegisterModifier), suppression via
	DamageType (see StatusService), per-rank values.
]]

local Config = require(script.Parent.Config)
local Formulas = require(script.Parent.Formulas)
local Summoners = require(script.Parent.SummonerSpells)

local Registry = {}

local characters: { [string]: any } = {}
local ordered: { any } = {}

local function collectComponentTypes(effects, found)
	for _, effect in ipairs(effects or {}) do
		if effect.Damage and effect.Damage.Components then
			for _, comp in ipairs(effect.Damage.Components) do
				found[comp.Type] = true
		end
		end
	end
end

local function validateAbility(charId: string, slot: string, ability)
	if not ability.Name then
		warn(("[CharacterRegistry] %s.%s has no Name"):format(charId, slot))
	end
	local found = {}
	collectComponentTypes(ability.Effects, found)
	if ability.Recast then
		collectComponentTypes(ability.Recast.Effects, found)
	end
	local hasPhys, hasMag = found.Physical == true, found.Magical == true
	local expected = nil
	if hasPhys and hasMag then
		expected = Config.DamageType.Hybrid
	elseif hasPhys then
		expected = Config.DamageType.Physical
	elseif hasMag then
		expected = Config.DamageType.Magical
	end
	if expected and ability.DamageType ~= expected then
		warn(("[CharacterRegistry] %s.%s DamageType is '%s' but its damage components imply '%s'"):format(
			charId, slot, tostring(ability.DamageType), expected))
	end
end

local function normalizeAbility(slot: string, ability)
	ability.Slot = slot
	if not ability.MaxRank then
		ability.MaxRank = (slot == "Ultimate") and 3 or 5
	end
	if not ability.RankLevels then
		ability.RankLevels = (slot == "Ultimate") and Config.DefaultRankLevels.Ultimate or Config.DefaultRankLevels.Standard
	end
	if slot == "Ultimate" then
		-- The ultimate can never be learned before the unlock level
		for i, lvl in ipairs(ability.RankLevels) do
			if lvl < Config.UltimateUnlockLevel then
				ability.RankLevels[i] = Config.UltimateUnlockLevel
			end
		end
	end
	ability.Targeting = ability.Targeting or "Direction"
	return ability
end

local function register(def)
	assert(def.Id, "character is missing an Id")
	def.Abilities = def.Abilities or {}
	for _, slot in ipairs({ "Ability1", "Ability2", "Ability3", "Ultimate" }) do
		local ability = def.Abilities[slot]
		if ability then
			normalizeAbility(slot, ability)
			validateAbility(def.Id, slot, ability)
		end
	end

	if def.Summoner then
		local summoner = Summoners[def.Summoner]
		if summoner then
			def.Abilities.Summoner = normalizeAbility("Summoner", summoner)
		else
			warn(("[CharacterRegistry] %s references unknown summoner '%s'"):format(def.Id, def.Summoner))
		end
	end

	def.BaseStats = def.BaseStats or {}
	def.StatGrowth = def.StatGrowth or {}
	characters[def.Id] = def
	table.insert(ordered, def)
end

for _, child in ipairs(script.Parent.Characters:GetChildren()) do
	if child:IsA("ModuleScript") then
		local ok, def = pcall(require, child)
		if ok then
			register(def)
		else
			warn(("[CharacterRegistry] failed to load %s: %s"):format(child.Name, tostring(def)))
		end
	end
end

table.sort(ordered, function(a, b)
	return (a.DisplayName or a.Id) < (b.DisplayName or b.Id)
end)

function Registry.List()
	return ordered
end

function Registry.Get(id: string?)
	if not id then
		return nil
	end
	return characters[id]
end

function Registry.GetAbility(def, slot: string)
	if not def then
		return nil
	end
	return def.Abilities[slot]
end

-- Base + growth for a given level (no items / buffs).
function Registry.ComputeLevelStats(def, level: number)
	local factor = Formulas.LevelFactor(def, level)
	local out = {}
	for _, stat in ipairs(Config.StatList) do
		local base = def.BaseStats[stat]
		if base == nil then
			base = Config.StatDefaults[stat] or 0
		end
		out[stat] = base + (def.StatGrowth[stat] or 0) * factor
	end
	return out
end

return Registry

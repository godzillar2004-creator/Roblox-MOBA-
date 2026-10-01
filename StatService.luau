-- ServerScriptService.Server.StatService
-- Drop-in replacement with support for character-specific dynamic stats.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CharacterRegistry = require(ReplicatedStorage.Shared.CharacterRegistry)
local PlayerState = require(script.Parent.PlayerState)

local StatService = {}

-- Set by StatusService so move speed can account for slows/roots without a circular require.
StatService.OnRecomputed = nil

local function clampStats(stats)
	stats.AttackSpeed = math.clamp(stats.AttackSpeed, 0.2, 3)
	stats.CritChance = math.clamp(stats.CritChance, 0, 1)
	stats.Haste = math.max(stats.Haste, -50)
	stats.MoveSpeed = math.clamp(stats.MoveSpeed, 0, 40)
	stats.MaxHealth = math.max(stats.MaxHealth, 1)
	stats.MaxMana = math.max(stats.MaxMana, 0)
	stats.ArmorPen = math.clamp(stats.ArmorPen, 0, 1)
	stats.MagicPen = math.clamp(stats.MagicPen, 0, 1)
end

function StatService.Get(model: Model?, stat: string): number
	if not model then
		return Config.StatDefaults[stat] or 0
	end

	local player = Players:GetPlayerFromCharacter(model)
	if player then
		local state = PlayerState.Get(player)
		if state and state.Stats[stat] ~= nil then
			return state.Stats[stat]
		end
		return 0
	end

	local attr = model:GetAttribute("Stat_" .. stat)
	if attr ~= nil then
		return attr
	end

	if stat == "CritDamage" then
		return Config.StatDefaults.CritDamage
	end

	return 0
end

function StatService.Recompute(player: Player)
	local state = PlayerState.Get(player)
	if not state then
		return
	end

	local def = CharacterRegistry.Get(state.CharacterId)
	if not def then
		return
	end

	local stats = CharacterRegistry.ComputeLevelStats(def, state.Level)
	local flat, pct = {}, {}

	for _, mods in pairs(state.Modifiers) do
		for stat, mod in pairs(mods) do
			if stat ~= "_Expire" and type(mod) == "table" then
				flat[stat] = (flat[stat] or 0) + (mod.Flat or 0)
				pct[stat] = (pct[stat] or 0) + (mod.Percent or 0)
			end
		end
	end

	for _, stat in ipairs(Config.StatList) do
		stats[stat] = (stats[stat] + (flat[stat] or 0)) * (1 + (pct[stat] or 0))
	end

	-- Character-specific dynamic passive hooks run after item/passive modifiers,
	-- allowing passives such as Frieren's Mana -> AP conversion to include item Mana.
	if def.Passive and type(def.Passive.DynamicStats) == "function" then
		local ok, err = pcall(def.Passive.DynamicStats, player, state, stats)
		if not ok then
			warn(("[StatService] DynamicStats failed for %s: %s"):format(tostring(state.CharacterId), tostring(err)))
		end
	end

	clampStats(stats)
	state.Stats = stats

	for stat, value in pairs(stats) do
		player:SetAttribute("Stat_" .. stat, value)
	end

	local oldMaxMana = player:GetAttribute("MaxMana") or 0
	if stats.MaxMana > oldMaxMana then
		state.Mana += stats.MaxMana - oldMaxMana
	end
	state.Mana = math.min(state.Mana, stats.MaxMana)
	player:SetAttribute("MaxMana", stats.MaxMana)
	player:SetAttribute("Mana", state.Mana)

	local _, humanoid = PlayerState.GetLiveCharacter(player)
	if humanoid then
		local oldMax = humanoid.MaxHealth
		humanoid.MaxHealth = stats.MaxHealth
		if stats.MaxHealth > oldMax then
			humanoid.Health += stats.MaxHealth - oldMax
		end
		player:SetAttribute("MaxHealth", stats.MaxHealth)
	end

	if StatService.OnRecomputed then
		StatService.OnRecomputed(player)
	end
end

function StatService.SetModifier(player: Player, key: string, mods, duration: number?)
	local state = PlayerState.Get(player)
	if not state then
		return
	end

	local copy = {}
	for stat, mod in pairs(mods) do
		copy[stat] = {
			Flat = mod.Flat,
			Percent = mod.Percent,
		}
	end

	if duration then
		copy._Expire = workspace:GetServerTimeNow() + duration
	end

	state.Modifiers[key] = copy
	StatService.Recompute(player)
end

function StatService.ClearModifier(player: Player, key: string)
	local state = PlayerState.Get(player)
	if state and state.Modifiers[key] then
		state.Modifiers[key] = nil
		StatService.Recompute(player)
	end
end

function StatService.ClearAllModifiers(player: Player)
	local state = PlayerState.Get(player)
	if state then
		state.Modifiers = {}
		StatService.Recompute(player)
	end
end

function StatService.HasMana(player: Player, amount: number): boolean
	local state = PlayerState.Get(player)
	return state ~= nil and state.Mana >= amount
end

function StatService.SpendMana(player: Player, amount: number): boolean
	local state = PlayerState.Get(player)
	if not state or state.Mana < amount then
		return false
	end

	state.Mana -= amount
	player:SetAttribute("Mana", state.Mana)
	return true
end

function StatService.RestoreFull(player: Player)
	local state = PlayerState.Get(player)
	if not state then
		return
	end

	state.Mana = state.Stats.MaxMana or 0
	player:SetAttribute("Mana", state.Mana)
end

function StatService.Step(dt: number)
	local now = workspace:GetServerTimeNow()

	for player, state in pairs(PlayerState.All()) do
		if state.Deployed and state.Alive then
			local expired = false

			for key, mods in pairs(state.Modifiers) do
				if mods._Expire and mods._Expire <= now then
					state.Modifiers[key] = nil
					expired = true
				end
			end

			if expired then
				StatService.Recompute(player)
			end

			local stats = state.Stats
			if stats.MaxMana then
				local newMana = math.min(
					stats.MaxMana,
					state.Mana + (stats.ManaRegen or 0) * dt
				)
				if newMana ~= state.Mana then
					state.Mana = newMana
					player:SetAttribute("Mana", newMana)
				end
			end

			local _, humanoid = PlayerState.GetLiveCharacter(player)
			if humanoid
				and (stats.PassiveHealing or 0) > 0
				and humanoid.Health < humanoid.MaxHealth
			then
				humanoid.Health = math.min(
					humanoid.MaxHealth,
					humanoid.Health + stats.PassiveHealing * dt
				)
			end
		end
	end
end

return StatService

--[[
	ProgressionService - match-only progression.

	XP  -> character/ability power (levels 0-20, skill points, stat growth)
	Gold -> item power (spent in the shop)
	The two systems are separate. Everything here is reset by ResetPlayer() when a match
	starts or ends, so nothing carries over between matches.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CharacterRegistry = require(ReplicatedStorage.Shared.CharacterRegistry)

local PlayerState = require(script.Parent.PlayerState)
local StatService = require(script.Parent.StatService)
local DamageService = require(script.Parent.DamageService)
local AbilityService = require(script.Parent.AbilityService)

local ProgressionService = {}

local function xpNeeded(level: number): number
	if level >= Config.MaxLevel then
		return 0
	end
	return Config.XpToNextLevel(level)
end

local function publishProgress(player: Player, state)
	PlayerState.Publish(player, "Level", state.Level)
	PlayerState.Publish(player, "Xp", state.Xp)
	PlayerState.Publish(player, "XpNeeded", xpNeeded(state.Level))
	PlayerState.Publish(player, "SkillPoints", state.SkillPoints)
end

local function publishScore(player: Player, state)
	PlayerState.Publish(player, "Kills", state.Kills)
	PlayerState.Publish(player, "Deaths", state.Deaths)
	PlayerState.Publish(player, "Assists", state.Assists)
end

function ProgressionService.PublishScore(player: Player)
	local state = PlayerState.Get(player)
	if state then
		publishScore(player, state)
	end
end

-- Returns everything to the level-0 starting state (call after CharacterId is set/cleared).
function ProgressionService.ResetPlayer(player: Player)
	local state = PlayerState.Get(player)
	if not state then
		return
	end
	state.Level = Config.StartLevel
	state.Xp = 0
	state.SkillPoints = 0
	state.Kills, state.Deaths, state.Assists = 0, 0, 0
	state.Items = {}
	state.Modifiers = {}
	state.Stats = {}
	state.Mana = 0
	state.Blocking = false
	state.NextBasicAttack = 0

	local def = CharacterRegistry.Get(state.CharacterId)
	state.Ranks = {}
	for _, slot in ipairs(Config.AbilitySlots) do
		local ability = def and def.Abilities[slot]
		-- Summoner ability is available from the start; everything else must be learned
		state.Ranks[slot] = (ability and slot == "Summoner") and 1 or 0
		PlayerState.Publish(player, "Rank_" .. slot, state.Ranks[slot])
	end
	AbilityService.ResetCooldowns(player)

	for i = 1, Config.InventorySlots do
		PlayerState.Publish(player, "Item_" .. i, "")
	end
	PlayerState.Publish(player, "MaxMana", 0)
	PlayerState.Publish(player, "Mana", 0)
	PlayerState.Publish(player, "MaxHealth", 0)
	for _, stat in ipairs(Config.StatList) do
		PlayerState.Publish(player, "Stat_" .. stat, nil)
	end
	publishProgress(player, state)
	publishScore(player, state)
end

-- Gold now lives entirely in GoldService (passive income, kill/assist/bounty gold, the
-- Gold attribute itself). ProgressionService only owns XP/levels and K/D/A counts.

function ProgressionService.AddXp(player: Player, amount: number)
	local state = PlayerState.Get(player)
	if not state or not state.Deployed or amount <= 0 then
		return
	end
	local leveled = false
	state.Xp += amount
	while state.Level < Config.MaxLevel and state.Xp >= xpNeeded(state.Level) do
		state.Xp -= xpNeeded(state.Level)
		state.Level += 1
		state.SkillPoints += 1
		leveled = true
	end
	if state.Level >= Config.MaxLevel then
		state.Xp = 0
	end
	publishProgress(player, state)
	if leveled then
		StatService.Recompute(player)
	end
end

function ProgressionService.SetLevel(player: Player, level: number)
	local state = PlayerState.Get(player)
	if not state or not state.Deployed then
		return
	end
	level = math.clamp(math.floor(level), 0, Config.MaxLevel)
	if level > state.Level then
		state.SkillPoints += level - state.Level
	end
	state.Level = level
	state.Xp = 0
	publishProgress(player, state)
	StatService.Recompute(player)
end

-- ===== Kill rewards ===========================================================
local function onKilled(victim: Model, killer: Model?, assists: { Player })
	local killerPlayer = killer and Players:GetPlayerFromCharacter(killer)
	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	local rewards = Config.Rewards

	local gold, xp = 0, 0
	if victimPlayer then
		local victimState = PlayerState.Get(victimPlayer)
		xp = rewards.PlayerKill.XpBase + rewards.PlayerKill.XpPerVictimLevel * (victimState and victimState.Level or 0)
	else
		xp = victim:GetAttribute("XpValue") or 0
	end

	if killerPlayer then
		local state = PlayerState.Get(killerPlayer)
		if state then
			if victimPlayer then
				state.Kills += 1
				publishScore(killerPlayer, state)
			end
			ProgressionService.AddXp(killerPlayer, xp)
		end
	end

	if victimPlayer then
		for _, assister in ipairs(assists) do
			local state = PlayerState.Get(assister)
			if state and state.Deployed then
				state.Assists += 1
				publishScore(assister, state)
				ProgressionService.AddXp(assister, xp * rewards.AssistRatio.Xp)
			end
		end
	end
end

function ProgressionService.Init()
	DamageService.OnKilled(onKilled)
end

return ProgressionService

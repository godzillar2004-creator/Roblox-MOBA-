--[[
	GoldService - handles all match gold and kill streak rewards.

	Current economy:
	Starting Gold: 500
	Passive Gold: 5 per second while deployed
	Kill Gold: 250
	Assist Gold: 100
	Max Assist Rewards: 3

	Bounties:
	2 kill streak  = +50
	3 kill streak  = +100
	4 kill streak  = +150
	5+ kill streak = +200
]]

local Players = game:GetService("Players")

local GoldService = {}

--==================================================
-- ECONOMY CONFIG
--==================================================

GoldService.StartingGold = 500
GoldService.PassiveGoldPerSecond = 5

GoldService.KillGold = 250
GoldService.AssistGold = 100
GoldService.MaxAssistRecipients = 3

GoldService.BountyByStreak = {
	[1] = 0,
	[2] = 50,
	[3] = 100,
	[4] = 150,
	[5] = 200,
}

--==================================================
-- INTERNAL
--==================================================

local passiveLoops = {}

local function getGold(player: Player): number
	return player:GetAttribute("Gold") or 0
end

local function getKillStreak(player: Player): number
	return player:GetAttribute("KillStreak") or 0
end

local function setKillStreak(player: Player, amount: number)
	player:SetAttribute("KillStreak", math.max(0, math.floor(amount)))
end

local function getBountyForStreak(streak: number): number
	if streak >= 5 then
		return GoldService.BountyByStreak[5]
	end

	return GoldService.BountyByStreak[streak] or 0
end

--==================================================
-- BASIC GOLD FUNCTIONS
--==================================================

function GoldService.GetGold(player: Player): number
	return getGold(player)
end

function GoldService.SetGold(player: Player, amount: number): boolean
	if not player or not player:IsA("Player") then
		return false
	end

	amount = math.max(0, math.floor(amount))
	player:SetAttribute("Gold", amount)

	return true
end

function GoldService.AddGold(player: Player, amount: number): boolean
	if not player or not player:IsA("Player") then
		return false
	end

	amount = math.floor(amount)

	if amount <= 0 then
		return false
	end

	GoldService.SetGold(player, getGold(player) + amount)

	return true
end

function GoldService.RemoveGold(player: Player, amount: number): boolean
	if not player or not player:IsA("Player") then
		return false
	end

	amount = math.floor(amount)

	if amount <= 0 then
		return false
	end

	local currentGold = getGold(player)

	if currentGold < amount then
		return false
	end

	GoldService.SetGold(player, currentGold - amount)

	return true
end

function GoldService.CanAfford(player: Player, amount: number): boolean
	return getGold(player) >= amount
end

--==================================================
-- MATCH RESET
--==================================================

function GoldService.ResetForMatch(player: Player)
	if not player or not player:IsA("Player") then
		return
	end

	GoldService.SetGold(player, GoldService.StartingGold)
	setKillStreak(player, 0)
end

function GoldService.ResetForMenu(player: Player)
	if not player or not player:IsA("Player") then
		return
	end

	GoldService.SetGold(player, 0)
	setKillStreak(player, 0)
end

function GoldService.ResetKillStreak(player: Player)
	if not player or not player:IsA("Player") then
		return
	end

	setKillStreak(player, 0)
end

--==================================================
-- CHAMPION KILL REWARDS
--==================================================

function GoldService.HandleChampionKill(
	victimCharacter: Model,
	killerCharacter: Model?,
	assists: { Player }
)
	local victimPlayer = Players:GetPlayerFromCharacter(victimCharacter)

	local killerPlayer = killerCharacter
		and Players:GetPlayerFromCharacter(killerCharacter)
		or nil

	-- Capture the victim's streak BEFORE resetting it.
	local victimStreak = 0

	if victimPlayer then
		victimStreak = getKillStreak(victimPlayer)
		setKillStreak(victimPlayer, 0)
	else
		-- Not a champion kill (e.g. a training dummy) - route those through
		-- GoldService.AwardMinionGold instead, never through the champion-kill economy.
		return
	end

	-- No player killer means there is no champion-kill
	-- gold reward. The victim's streak is still reset.
	if not killerPlayer then
		return
	end

	-- Calculate shutdown bounty from the victim's
	-- previous kill streak.
	local bounty = getBountyForStreak(victimStreak)

	-- Base kill gold + shutdown bounty.
	GoldService.AddGold(
		killerPlayer,
		GoldService.KillGold + bounty
	)

	-- Increase killer's streak.
	setKillStreak(
		killerPlayer,
		getKillStreak(killerPlayer) + 1
	)

	--==================================================
	-- ASSISTS
	--==================================================

	local rewarded = 0
	local seen = {}

	for _, player in ipairs(assists or {}) do
		if rewarded >= GoldService.MaxAssistRecipients then
			break
		end

		if player
			and player:IsA("Player")
			and player ~= killerPlayer
			and player.Parent == Players
			and not seen[player]
		then
			seen[player] = true

			GoldService.AddGold(
				player,
				GoldService.AssistGold
			)

			rewarded += 1
		end
	end
end

--==================================================
-- MINIONS / OBJECTIVES
--==================================================

function GoldService.AwardMinionGold(
	player: Player,
	amount: number
): boolean
	if not player or not player:IsA("Player") then
		return false
	end

	if not amount or amount <= 0 then
		return false
	end

	return GoldService.AddGold(player, amount)
end

function GoldService.AwardObjectiveGold(
	player: Player,
	amount: number
): boolean
	if not player or not player:IsA("Player") then
		return false
	end

	if not amount or amount <= 0 then
		return false
	end

	return GoldService.AddGold(player, amount)
end

function GoldService.AwardTeamGold(
	team: Team,
	amount: number
)
	if not team or not amount or amount <= 0 then
		return
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Team == team then
			GoldService.AddGold(player, amount)
		end
	end
end

--==================================================
-- PASSIVE GOLD
--==================================================

local function startPassiveGold(player: Player)
	if passiveLoops[player] then
		return
	end

	passiveLoops[player] = true

	task.spawn(function()
		while player.Parent do
			task.wait(1)

			if not player.Parent then
				break
			end

			-- Passive gold only while deployed.
			if player:GetAttribute("Deployed") == true then
				GoldService.AddGold(
					player,
					GoldService.PassiveGoldPerSecond
				)
			end
		end

		passiveLoops[player] = nil
	end)
end

--==================================================
-- INITIALIZATION
--==================================================

function GoldService.Init()
	-- Existing players
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("Gold") == nil then
			GoldService.SetGold(player, 0)
		end

		if player:GetAttribute("KillStreak") == nil then
			setKillStreak(player, 0)
		end

		player:GetAttributeChangedSignal("Deployed"):Connect(function()
			if player:GetAttribute("Deployed") == true then
				GoldService.ResetForMatch(player)
			else
				GoldService.ResetForMenu(player)
			end
		end)

		startPassiveGold(player)
	end

	-- New players
	Players.PlayerAdded:Connect(function(player)
		GoldService.SetGold(player, 0)
		setKillStreak(player, 0)

		player:GetAttributeChangedSignal("Deployed"):Connect(function()
			if player:GetAttribute("Deployed") == true then
				GoldService.ResetForMatch(player)
			else
				GoldService.ResetForMenu(player)
			end
		end)

		startPassiveGold(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		passiveLoops[player] = nil
	end)

	print("[GoldService] initialized")
end

return GoldService
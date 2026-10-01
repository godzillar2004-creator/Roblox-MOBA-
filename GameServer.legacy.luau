-- GameServer: boots every server module and runs the ~10Hz gameplay tick.
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Server = script.Parent:WaitForChild("Server")

require(Server.Remotes) -- create remotes before any client connects

local StatService = require(Server.StatService)
local StatusService = require(Server.StatusService)
local AbilityService = require(Server.AbilityService)
local CombatService = require(Server.CombatService)
local DamageService = require(Server.DamageService)
local ProgressionService = require(Server.ProgressionService)
local InventoryService = require(Server.InventoryService)
local GoldService = require(Server.GoldService)
local MatchService = require(Server.MatchService)
local DummyService = require(Server.DummyService)
local DevCommands = require(Server.DevCommands)
local PlayerState = require(Server.PlayerState)

-- Johnny is loaded defensively: if his module ever errors, the rest of the game still boots.
local okJohnny, JohnnyService = pcall(require, Server:WaitForChild("JohnnyService", 5))
if not okJohnny then
	warn("[GameServer] JohnnyService failed to load: " .. tostring(JohnnyService))
end

DamageService.OnKilled(function(victim, killer, assists)
	-- Champion (player) kills go through the full kill/bounty/assist economy; a dummy or
	-- future minion isn't a champion, so it only ever pays flat minion gold to the killer.
	local victimPlayer = Players:GetPlayerFromCharacter(victim)
	if victimPlayer then
		GoldService.HandleChampionKill(
			victim,
			killer,
			assists
		)
	elseif killer then
		local killerPlayer = Players:GetPlayerFromCharacter(killer)
		if killerPlayer then
			GoldService.AwardMinionGold(killerPlayer, victim:GetAttribute("GoldValue") or 0)
		end
	end
end)

MatchService.Init()
AbilityService.Init()
CombatService.Init()
ProgressionService.Init()
InventoryService.Init()
GoldService.Init()
DummyService.Init()
DevCommands.Init()

if okJohnny then
	local ok, err = pcall(JohnnyService.Init)
	if not ok then
		warn("[GameServer] JohnnyService.Init failed: " .. tostring(err))
	end
end

local TICK = 0.1
local accumulator = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < TICK then
		return
	end
	local step = accumulator
	accumulator = 0

	StatService.Step(step)
	StatusService.Step()
	AbilityService.Step()

	-- Kill anyone who falls out of the world
	for player, state in pairs(PlayerState.All()) do
		if state.Alive then
			local _, humanoid, root = PlayerState.GetLiveCharacter(player)
			if humanoid and root and root.Position.Y < -60 then
				humanoid.Health = 0
			end
		end
	end
end)

print("[GameServer] MOBA framework ready")

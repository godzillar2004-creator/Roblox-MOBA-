--[[
	DevCommands - chat commands for testing. ONLY ACTIVE INSIDE ROBLOX STUDIO.

	/gold <n>     add gold                 /xp <n>      add xp
	/level <n>    jump to a level          /cd          reset cooldowns + refill mana
	/heal         restore full health      /endmatch    end match (resets everyone)
]]

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local PlayerState = require(script.Parent.PlayerState)
local StatService = require(script.Parent.StatService)
local ProgressionService = require(script.Parent.ProgressionService)
local GoldService = require(script.Parent.GoldService)
local AbilityService = require(script.Parent.AbilityService)
local MatchService = require(script.Parent.MatchService)

local DevCommands = {}

local function handle(player: Player, message: string)
	local cmd, arg = message:match("^/(%a+)%s*(%-?%d*%.?%d*)")
	if not cmd then
		return
	end
	local n = tonumber(arg)
	cmd = cmd:lower()

	if cmd == "gold" and n then
		if n >= 0 then
			GoldService.AddGold(player, n)
		else
			GoldService.RemoveGold(player, -n)
		end
	elseif cmd == "xp" and n then
		ProgressionService.AddXp(player, n)
	elseif cmd == "level" and n then
		ProgressionService.SetLevel(player, n)
	elseif cmd == "cd" then
		AbilityService.ResetCooldowns(player)
		StatService.RestoreFull(player)
	elseif cmd == "heal" then
		local _, humanoid = PlayerState.GetLiveCharacter(player)
		if humanoid then
			humanoid.Health = humanoid.MaxHealth
		end
	elseif cmd == "endmatch" then
		MatchService.EndMatch()
	end
end

function DevCommands.Init()
	if not RunService:IsStudio() then
		return
	end
	local function hook(player: Player)
		player.Chatted:Connect(function(message)
			handle(player, message)
		end)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		hook(player)
	end
	Players.PlayerAdded:Connect(hook)
end

return DevCommands

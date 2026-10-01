--[[
	MatchService - joining, deployment, teams, spawning, death/respawn and match reset.

	Flow: Join -> (deployment menu on the client) -> RequestDeploy(team, character)
	      -> progression reset -> character spawns at the team spawn.
	Players never spawn automatically (CharacterAutoLoads = false).
]]

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local CharacterRegistry = require(ReplicatedStorage.Shared.CharacterRegistry)

local PlayerState = require(script.Parent.PlayerState)
local StatService = require(script.Parent.StatService)
local StatusService = require(script.Parent.StatusService)
local AbilityService = require(script.Parent.AbilityService)
local ProgressionService = require(script.Parent.ProgressionService)
local Overhead = require(script.Parent.Overhead)
local DummyService = require(script.Parent.DummyService)
local Remotes = require(script.Parent.Remotes)

local MatchService = {}

-- Character-specific spawn hooks. A module (e.g. JohnnyService) registers a callback and it is
-- invoked once a deployed character is fully set up (alive, positioned, overhead attached).
--   fn(player, character, characterDef)
local setupHooks = {}

function MatchService.OnCharacterSetup(fn)
	table.insert(setupHooks, fn)
end

local function teamConfig(name: string)
	for _, team in ipairs(Config.Teams) do
		if team.Name == name then
			return team
		end
	end
	return nil
end

local function createTeams()
	for _, cfg in ipairs(Config.Teams) do
		local team = Teams:FindFirstChild(cfg.Name)
		if not team then
			team = Instance.new("Team")
			team.Name = cfg.Name
			team.Parent = Teams
		end
		team.TeamColor = cfg.Color
		team.AutoAssignable = false
	end
end

local function pickSpawn(teamName: string): CFrame
	local map = workspace:FindFirstChild("Map")
	local spawns = map and map:FindFirstChild("Spawns")
	local candidates = {}
	if spawns then
		for _, part in ipairs(spawns:GetChildren()) do
			if part:IsA("BasePart") and part:GetAttribute("Team") == teamName then
				table.insert(candidates, part)
			end
		end
	end
	if #candidates == 0 then
		return CFrame.new(0, 10, 0)
	end
	local part = candidates[math.random(1, #candidates)]
	local offset = Vector3.new((math.random() - 0.5) * (part.Size.X - 3), 4, (math.random() - 0.5) * (part.Size.Z - 3))
	-- Lane runs along X (Blue spawns at +X, Red at -X), so face back toward the lane center.
	local facing = (teamName == Config.Teams[1].Name) and Vector3.new(-1, 0, 0) or Vector3.new(1, 0, 0)
	local position = part.Position + offset
	return CFrame.lookAt(position, position + facing)
end

local function paintCharacter(character: Model, color: Color3)
	for _, child in ipairs(character:GetDescendants()) do
		if child:IsA("Accessory") or child:IsA("Shirt") or child:IsA("Pants") or child:IsA("ShirtGraphic") then
			child:Destroy()
		end
	end
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if not bodyColors then
		bodyColors = Instance.new("BodyColors")
		bodyColors.Parent = character
	end
	bodyColors.HeadColor3 = color
	bodyColors.TorsoColor3 = color
	bodyColors.LeftArmColor3 = color
	bodyColors.RightArmColor3 = color
	bodyColors.LeftLegColor3 = color
	bodyColors.RightLegColor3 = color
end

function MatchService.OnDied(player: Player, character: Model, session: number)
	local state = PlayerState.Get(player)
	if not state or state.Session ~= session then
		return
	end
	state.Alive = false
	state.Blocking = false
	state.Deaths += 1
	ProgressionService.PublishScore(player)
	AbilityService.OnDeath(player)
	StatusService.Clear(character)

	local respawnTime = Config.Respawn.Base + Config.Respawn.PerLevel * state.Level
	PlayerState.Publish(player, "RespawnAt", workspace:GetServerTimeNow() + respawnTime)

	task.delay(respawnTime, function()
		if PlayerState.Get(player) == state and state.Session == session and state.Deployed and not state.Alive then
			MatchService.Respawn(player)
		end
	end)
end

function MatchService.SetupCharacter(player: Player, character: Model)
	local state = PlayerState.Get(player)
	if not state or not state.Deployed then
		return
	end
	local humanoid = character:WaitForChild("Humanoid", 5)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	local def = CharacterRegistry.Get(state.CharacterId)
	if not humanoid or not root or not def then
		return
	end

	paintCharacter(character, def.BodyColor or Color3.new(1, 1, 1))
	humanoid.AutoRotate = false -- facing is driven by the mouse (client)
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 0

	local cfg = teamConfig(state.TeamName)
	character:PivotTo(pickSpawn(state.TeamName))
	character:SetAttribute("TeamName", state.TeamName)
	StatusService.Clear(character)

	state.Blocking = false
	if def.Passive and def.Passive.Modifiers then
		StatService.SetModifier(player, "Passive", def.Passive.Modifiers)
	else
		StatService.Recompute(player)
	end
	humanoid.Health = humanoid.MaxHealth
	StatService.RestoreFull(player)
	state.Alive = true
	PlayerState.Publish(player, "RespawnAt", 0)

	local color = cfg and cfg.Color.Color or Color3.fromRGB(255, 255, 255)
	Overhead.Attach(character, player.DisplayName, color, player)

	local session = state.Session
	humanoid.Died:Once(function()
		MatchService.OnDied(player, character, session)
	end)

	for _, hook in ipairs(setupHooks) do
		task.spawn(hook, player, character, def)
	end
end

function MatchService.Respawn(player: Player)
	local state = PlayerState.Get(player)
	if state and state.Deployed then
		player:LoadCharacter()
	end
end

function MatchService.Deploy(player: Player, teamName: any, characterId: any): (boolean, string?)
	local state = PlayerState.Get(player)
	if not state then
		return false, "No player state"
	end
	if state.Deployed then
		return false, "Already deployed"
	end
	if typeof(teamName) ~= "string" or not teamConfig(teamName) or not Teams:FindFirstChild(teamName) then
		return false, "Invalid team"
	end
	if typeof(characterId) ~= "string" or not CharacterRegistry.Get(characterId) then
		return false, "Invalid character"
	end

	state.Session += 1
	state.CharacterId = characterId
	state.TeamName = teamName
	player.Team = Teams:FindFirstChild(teamName) :: Team
	ProgressionService.ResetPlayer(player) -- new match entry always starts from level 0
	state.Deployed = true
	PlayerState.Publish(player, "CharacterId", characterId)
	PlayerState.Publish(player, "TeamName", teamName)
	PlayerState.Publish(player, "Deployed", true)

	task.spawn(function()
		player:LoadCharacter()
	end)
	return true, nil
end

-- Sends one player back to the deployment menu and wipes all match progression.
function MatchService.ReturnToMenu(player: Player)
	local state = PlayerState.Get(player)
	if not state then
		return
	end
	state.Session += 1
	state.Deployed = false
	state.Alive = false
	local character = player.Character
	if character then
		character:Destroy()
		player.Character = nil
	end
	state.CharacterId = nil
	state.TeamName = nil
	player.Team = nil
	ProgressionService.ResetPlayer(player)
	PlayerState.Publish(player, "CharacterId", "")
	PlayerState.Publish(player, "TeamName", "")
	PlayerState.Publish(player, "RespawnAt", 0)
	PlayerState.Publish(player, "Deployed", false)
end

-- Ends the match for everyone: level, XP, gold, items, ability ranks, buffs, K/D/A all reset.
function MatchService.EndMatch()
	for player in pairs(PlayerState.All()) do
		MatchService.ReturnToMenu(player)
	end
	DummyService.Reset()
end

function MatchService.Init()
	Players.CharacterAutoLoads = false
	createTeams()

	local function onPlayerAdded(player: Player)
		PlayerState.Create(player)
		PlayerState.Publish(player, "Deployed", false)
		PlayerState.Publish(player, "CharacterId", "")
		PlayerState.Publish(player, "TeamName", "")
		PlayerState.Publish(player, "RespawnAt", 0)
		ProgressionService.ResetPlayer(player)
		player.CharacterAdded:Connect(function(character)
			MatchService.SetupCharacter(player, character)
		end)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		PlayerState.Remove(player)
	end)

	Remotes.RequestDeploy.OnServerInvoke = function(player, teamName, characterId)
		return MatchService.Deploy(player, teamName, characterId)
	end
end

return MatchService

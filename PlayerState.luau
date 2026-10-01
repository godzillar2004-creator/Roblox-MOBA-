-- Authoritative per-player match state (server only). Values the client needs are mirrored
-- to Player attributes so the HUD can read them without extra remotes.

local PlayerState = {}

local states: { [Player]: any } = {}

function PlayerState.Create(player: Player)
	local state = {
		Deployed = false,
		Alive = false,
		Session = 0, -- bumped whenever a deploy/match-end happens so stale timers can bail
		TeamName = nil,
		CharacterId = nil,

		Level = 0,
		Xp = 0,
		SkillPoints = 0,
		Kills = 0,
		Deaths = 0,
		Assists = 0,

		Ranks = {},
		Cooldowns = {},
		Recasts = {},
		Items = {}, -- [1..InventorySlots] = itemId
		Modifiers = {}, -- [sourceKey] = { [stat] = {Flat=, Percent=}, Expire = serverTime? }
		Stats = {},

		Mana = 0,
		Blocking = false,
		NextBasicAttack = 0,
		TickAccumulator = 0,
	}
	states[player] = state
	return state
end

function PlayerState.Get(player: Player)
	return states[player]
end

function PlayerState.Remove(player: Player)
	states[player] = nil
end

function PlayerState.All()
	return states
end

-- Returns character, humanoid, root when the player has a live character; otherwise nil.
function PlayerState.GetLiveCharacter(player: Player)
	local character = player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end
	return character, humanoid, root
end

function PlayerState.Publish(player: Player, name: string, value: any)
	if player.Parent then
		player:SetAttribute(name, value)
	end
end

return PlayerState

--[[
	DamageService - the single place where damage is applied.

	Damage packet structure:

	{
		Components = {
			{
				Type = "Physical" | "Magical",
				Amount = 100,
				CanCrit = true, -- Optional; falls back to packet.CanCrit if omitted
			},

			{
				Type = "Magical",
				Amount = 50,
				CanCrit = false,
			},
		},

		Source = {
			Kind = "BasicAttack" | "Ability",
			Slot = "Ability1",
			AbilityId = "...",
			DamageType = "Hybrid",
		},

		CanCrit = false, -- Default fallback for components
ForceCrit = false, -- Forces the damage component to Critical Strike
IsBasicAttack = false,

-- Optional callback fired after a successful hit.
-- Signature:
-- OnHit(packet, attacker, target, result)
OnHit = nil,
	}

	Important architecture rules:

	1. Damage Type and Scaling are separate systems.
	2. Physical and Magical components are mitigated independently.
	3. Crit is evaluated independently for each damage component.
	4. Damage modifiers run through a deterministic priority pipeline.
	5. Damage packets must be created on the server with CreatePacket().
	6. Untargetable targets cannot be damaged.
	7. Invulnerable targets can be targeted but cannot receive damage.
]]

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local StatService = require(script.Parent.StatService)
local PlayerState = require(script.Parent.PlayerState)
local Remotes = require(script.Parent.Remotes)

local DamageService = {}

local DAMAGEABLE_TAG = "Damageable"

-- ============================================================================
-- SERVER AUTHENTICATION
-- ============================================================================

-- Private token.
-- A client cannot construct a packet containing this same table reference.
local SERVER_PACKET_TOKEN = {}

-- Private table key so other scripts cannot accidentally fake the token.
local PACKET_AUTH_KEY = {}

-- Creates a server-authoritative packet.
function DamageService.CreatePacket(packet)
	assert(
		RunService:IsServer(),
		"DamageService.CreatePacket() must only be called on the server."
	)

	assert(type(packet) == "table", "Damage packet must be a table.")

	local out = {}

	for key, value in pairs(packet) do
		out[key] = value
	end

	-- Clone Components so callers cannot accidentally share mutable
	-- component tables between different damage instances.
	if packet.Components then
		out.Components = {}

		for index, component in ipairs(packet.Components) do
			out.Components[index] = table.clone(component)
		end
	end

	-- Clone Source so modifiers cannot accidentally alter the original source.
	if packet.Source then
		out.Source = table.clone(packet.Source)
	end

	-- Private server authentication marker.
	out[PACKET_AUTH_KEY] = SERVER_PACKET_TOKEN

	return out
end

local function validatePacket(packet)
	assert(
		RunService:IsServer(),
		"DamageService.Deal() must only execute on the server."
	)

	assert(
		type(packet) == "table",
		"DamageService.Deal() received an invalid packet."
	)

	assert(
		packet[PACKET_AUTH_KEY] == SERVER_PACKET_TOKEN,
		"Unauthenticated damage packet. Use DamageService.CreatePacket() on the server."
	)

	assert(
		type(packet.Components) == "table",
		"Damage packet must contain Components."
	)
end

-- Creates a fresh working copy for each damage instance.
local function clonePacket(packet)
	local copy = {}

	for key, value in pairs(packet) do
		copy[key] = value
	end

	if packet.Components then
		copy.Components = {}

		for index, component in ipairs(packet.Components) do
			copy.Components[index] = table.clone(component)
		end
	end

	if packet.Source then
		copy.Source = table.clone(packet.Source)
	end

	return copy
end

-- ============================================================================
-- MODIFIER REGISTRATION
-- ============================================================================

-- Modifiers are sorted by priority.
-- Lower priority values execute first.
--
-- Example:
-- DamageService.RegisterModifier(MyModifier, 100)
-- DamageService.RegisterModifier(MyOtherModifier, 200)
--
-- MyModifier runs before MyOtherModifier.
local modifiers = {}
local modifierRegistrationOrder = 0

function DamageService.RegisterModifier(fn: (any, Model, Model) -> (), priority: number?)
	assert(type(fn) == "function", "Damage modifier must be a function.")

	modifierRegistrationOrder += 1

	table.insert(modifiers, {
		Callback = fn,
		Priority = priority or 100,
		Order = modifierRegistrationOrder,
	})

	table.sort(modifiers, function(a, b)
		if a.Priority == b.Priority then
			return a.Order < b.Order
		end

		return a.Priority < b.Priority
	end)
end

local function applyModifiers(packet, attacker, target)
	for _, modifier in ipairs(modifiers) do
		modifier.Callback(packet, attacker, target)
	end
end

-- ============================================================================
-- DAMAGE ABSORBERS
-- ============================================================================

-- An absorber sits between "damage was calculated" and "the humanoid loses health".
--   fn(target, amount, packet, attacker) -> amount that should still reach the humanoid
-- Used for shields / mounts, e.g. Johnny's Slow Dancer soaks all damage while mounted.
-- Absorbers run after armor, blocking and modifiers, so they see final damage.
local absorbers = {}

function DamageService.RegisterAbsorber(fn: (Model, number, any, Model) -> number)
	assert(type(fn) == "function", "Damage absorber must be a function.")
	table.insert(absorbers, fn)
end

local function applyAbsorbers(packet, attacker: Model, target: Model, amount: number): number
	for _, absorber in ipairs(absorbers) do
		local ok, remaining = pcall(absorber, target, amount, packet, attacker)
		if ok then
			if type(remaining) == "number" then
				amount = math.max(0, remaining)
			end
		else
			warn("[DamageService] absorber failed: " .. tostring(remaining))
		end
	end
	return amount
end

-- ============================================================================
-- KILL CALLBACKS
-- ============================================================================

local killedCallbacks: { (Model, Model?, { Player }) -> () } = {}

function DamageService.OnKilled(fn: (Model, Model?, { Player }) -> ())
	table.insert(killedCallbacks, fn)
end

-- ============================================================================
-- DAMAGEABLE TAGGING
-- ============================================================================

function DamageService.TagDamageable(model: Model)
	CollectionService:AddTag(model, DAMAGEABLE_TAG)
end

-- ============================================================================
-- TARGET HELPERS
-- ============================================================================

function DamageService.GetTeam(model: Model): string?
	local player = Players:GetPlayerFromCharacter(model)

	if player then
		local state = PlayerState.Get(player)
		return state and state.TeamName or nil
	end

	return model:GetAttribute("TeamName")
end

function DamageService.IsAlive(model: Model): boolean
	local humanoid = model:FindFirstChildOfClass("Humanoid")

	return humanoid ~= nil and humanoid.Health > 0
end

function DamageService.IsEnemy(a: Model, b: Model): boolean
	if a == b then
		return false
	end

	local teamA = DamageService.GetTeam(a)
	local teamB = DamageService.GetTeam(b)

	if teamA == nil or teamB == nil then
		return true
	end

	return teamA ~= teamB
end

-- Every live model that can currently be damaged.
--
-- Player characters and tagged NPCs are collected separately.
-- Deduplication prevents a player character that also has the
-- Damageable tag from being included twice.
function DamageService.GetDamageables(): { Model }
	local list = {}
	local seen: { [Model]: boolean } = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local state = PlayerState.Get(player)

		if state and state.Deployed and state.Alive then
			local character = PlayerState.GetLiveCharacter(player)

			if character and not seen[character] then
				seen[character] = true
				table.insert(list, character)
			end
		end
	end

	for _, model in ipairs(CollectionService:GetTagged(DAMAGEABLE_TAG)) do
		if model:IsA("Model")
			and DamageService.IsAlive(model)
			and not seen[model]
		then
			seen[model] = true
			table.insert(list, model)
		end
	end

	return list
end

function DamageService.GetRoot(model: Model): BasePart?
	return model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
end

-- testFn(rootPosition, model) -> boolean
function DamageService.FindEnemies(
	source: Model,
	testFn: (Vector3, Model) -> boolean
): { Model }

	local found = {}

	for _, model in ipairs(DamageService.GetDamageables()) do
		if DamageService.IsEnemy(source, model)
			and not model:GetAttribute("Untargetable")
		then
			local root = DamageService.GetRoot(model)

			if root and testFn(root.Position, model) then
				table.insert(found, model)
			end
		end
	end

	return found
end

-- ============================================================================
-- DAMAGE MATH
-- ============================================================================

-- Turns:
--
-- {
--     Components = {
--         { Type = "Physical", Base = 100, Scaling = {...} }
--     }
-- }
--
-- into:
--
-- {
--     { Type = "Physical", Amount = 150 }
-- }
function DamageService.BuildComponents(sourceModel: Model, damageSpec, rank: number)
	local out = {}

	for _, comp in ipairs(damageSpec.Components) do
		local amount = Formulas.RankValue(comp.Base or 0, rank) or 0

		for _, scale in ipairs(comp.Scaling or {}) do
			amount += StatService.Get(sourceModel, scale.Stat) * scale.Ratio
		end

		local builtComponent = {
			Type = comp.Type,
			Amount = amount,
		}

		-- Preserve explicit per-component crit settings.
		if comp.CanCrit ~= nil then
			builtComponent.CanCrit = comp.CanCrit
		end

		table.insert(out, builtComponent)
	end

	return out
end

-- ============================================================================
-- CONTRIBUTIONS / KILLS
-- ============================================================================

local contributors: { [Model]: { [Player]: number } } = {}

local function recordContribution(target: Model, attacker: Model)
	local player = Players:GetPlayerFromCharacter(attacker)

	if not player then
		return
	end

	local entry = contributors[target]

	if not entry then
		entry = {}
		contributors[target] = entry
	end

	entry[player] = workspace:GetServerTimeNow()
end

function DamageService.Heal(model: Model, amount: number)
	local humanoid = model:FindFirstChildOfClass("Humanoid")

	if humanoid and humanoid.Health > 0 and amount > 0 then
		humanoid.Health = math.min(
			humanoid.MaxHealth,
			humanoid.Health + amount
		)
	end
end

local function processKill(victim: Model, killer: Model?)
	if victim:GetAttribute("KillProcessed") then
		return
	end

	victim:SetAttribute("KillProcessed", true)

	local killerPlayer = killer and Players:GetPlayerFromCharacter(killer)
	local assists = {}

	local entry = contributors[victim]

	if entry then
		local now = workspace:GetServerTimeNow()

		for player, time in pairs(entry) do
			if player ~= killerPlayer
				and now - time <= Config.Rewards.AssistWindow
			then
				table.insert(assists, player)
			end
		end
	end

	contributors[victim] = nil

	for _, callback in ipairs(killedCallbacks) do
		task.spawn(callback, victim, killer, assists)
	end
end

function DamageService.Execute(attacker: Model, target: Model): boolean
	if not attacker or not attacker:IsA("Model") then
		return false
	end

	if not target or not target:IsA("Model") then
		return false
	end

	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	if target:GetAttribute("Untargetable") or target:GetAttribute("Invulnerable") then
		return false
	end

	if not DamageService.IsEnemy(attacker, target) then
		return false
	end

	humanoid.Health = 0
	processKill(target, attacker)

	return true
end
-- ============================================================================
-- DAMAGE APPLICATION
-- ============================================================================

-- Applies a damage packet.
--
-- Returns:
--     final damage dealt after mitigation.
function DamageService.GiveShield(model: Model, amount: number, duration: number?)
	if not model or not model:IsA("Model") or amount <= 0 then
		return
	end

	local added = amount
	local current = model:GetAttribute("Shield") or 0
	model:SetAttribute("Shield", current + added)

	if duration and duration > 0 then
		task.delay(duration, function()
			if not model.Parent then
				return
			end

			local shield = model:GetAttribute("Shield") or 0
			shield = math.max(0, shield - added)
			model:SetAttribute("Shield", shield > 0 and shield or nil)
		end)
	end
end
humanoid.Health = math.max(
	0,
	humanoid.Health - total
)

Insert:

	local shield = target:GetAttribute("Shield") or 0
if shield > 0 then
	local absorbed = math.min(shield, total)
	shield -= absorbed
	total -= absorbed

	target:SetAttribute("Shield", shield > 0 and shield or nil)
end

if total <= 0 then
	return 0
end

function DamageService.Deal(
	attacker: Model,
	target: Model,
	packet
): number

	validatePacket(packet)

	if not attacker or not attacker:IsA("Model") then
		return 0
	end

	if not target or not target:IsA("Model") then
		return 0
	end

	local humanoid = target:FindFirstChildOfClass("Humanoid")

	if not humanoid or humanoid.Health <= 0 then
		return 0
	end

	-- Target cannot receive direct damage while Untargetable.
	if target:GetAttribute("Untargetable") then
		return 0
	end

	-- Target can still be selected while Invulnerable,
	-- but damage does not go through.
	if target:GetAttribute("Invulnerable") then
		return 0
	end

	if not DamageService.IsEnemy(attacker, target) then
		return 0
	end

	-- Work on a unique packet copy.
	--
	-- This prevents modifier mutations for one target from
	-- leaking into another target when the same base packet
	-- is reused for AOE or multi-target abilities.
	local workingPacket = clonePacket(packet)

	-- =========================================================================
	-- Modifier pipeline
	-- =========================================================================

	-- All registered modifiers are deterministic because RegisterModifier()
	-- sorts them by priority.
	applyModifiers(workingPacket, attacker, target)

	-- =========================================================================
	-- Crit + per-component mitigation
	-- =========================================================================

	local total = 0
	local physical = 0
	local magical = 0
	local critOccurred = false

	local componentCrits = {}

	for index, comp in ipairs(workingPacket.Components) do
		local amount = comp.Amount or 0

		if amount > 0 then
			-- Component-level CanCrit takes priority.
			--
			-- If the component does not specify CanCrit,
			-- inherit packet.CanCrit.
			local canCrit = comp.CanCrit

			if canCrit == nil then
				canCrit = workingPacket.CanCrit == true
			end

			local componentCrit = false
			local critMultiplier = 1

			local forceCrit = comp.ForceCrit

			if forceCrit == nil then
				forceCrit = workingPacket.ForceCrit == true
			end

			if comp.FollowCrit ~= nil then
				-- Linked component (e.g. Johnny's Act 3 True damage): it never rolls on its
				-- own, it only inherits whether the component it follows critically struck.
				if componentCrits[comp.FollowCrit] then
					componentCrit = true
					critMultiplier = math.max(
						StatService.Get(attacker, "CritDamage"),
						1
					)
				end

			elseif forceCrit then
				componentCrit = true
				critOccurred = true

				critMultiplier = math.max(
					StatService.Get(attacker, "CritDamage"),
					1
				)

			elseif canCrit then
				local critChance = math.clamp(
					StatService.Get(attacker, "CritChance"),
					0,
					1
				)

				if math.random() < critChance then
					componentCrit = true
					critOccurred = true

					critMultiplier = math.max(
						StatService.Get(attacker, "CritDamage"),
						1
					)
				end
			end

			amount *= critMultiplier

			componentCrits[index] = componentCrit

			local multiplier = 1

			if comp.Type == Config.DamageType.Physical then

				multiplier = Formulas.DamageMultiplier(
					StatService.Get(target, "PhysicalArmor"),
					StatService.Get(attacker, "ArmorPen")
				)

				physical += amount * multiplier

			elseif comp.Type == Config.DamageType.Magical then

				multiplier = Formulas.DamageMultiplier(
					StatService.Get(target, "MagicArmor"),
					StatService.Get(attacker, "MagicPen")
				)

				magical += amount * multiplier

			elseif comp.Type == Config.DamageType.True then

				-- True damage ignores armor / magic armor entirely.
				-- (Counted with physical for the damage-number color.)
				multiplier = 1

				physical += amount

			else
				-- Unknown damage types should never silently
				-- deal full unmitigated damage.
				warn(
					string.format(
						"[DamageService] Unknown damage type '%s' from packet '%s'. Component ignored.",
						tostring(comp.Type),
						tostring(
							workingPacket.Source
								and workingPacket.Source.AbilityId
								or "Unknown"
						)
					)
				)

				continue
			end

			total += amount * multiplier
		end
	end

	-- =========================================================================
	-- Blocking
	-- =========================================================================

	local blocked = false

	if target:GetAttribute("Blocking") then
		local targetRoot = DamageService.GetRoot(target)
		local attackerRoot = DamageService.GetRoot(attacker)

		if targetRoot and attackerRoot then
			local toAttacker = attackerRoot.Position - targetRoot.Position
			toAttacker = Vector3.new(toAttacker.X, 0, toAttacker.Z)

			if toAttacker.Magnitude > 0.01 then
				local facing = targetRoot.CFrame.LookVector
				facing = Vector3.new(facing.X, 0, facing.Z)

				if facing.Magnitude > 0.01 then
					facing = facing.Unit

					if facing:Dot(toAttacker.Unit) > Config.Block.FrontArcDot then
						blocked = true

						total *= (
							1 - Config.Block.DamageReduction
						)
					end
				end
			end
		end
	end

	if total <= 0 then
		return 0
	end
	
	workingPacket.CritOccurred = critOccurred

	-- =========================================================================
	-- Apply damage
	-- =========================================================================

	recordContribution(target, attacker)

	-- Absorbers (shields, mounts...) may soak some or all of the damage. `total` stays the
	-- full post-mitigation amount for sustain, damage numbers and OnHit; only what is left
	-- over after absorption actually reaches the humanoid.
	local applied = applyAbsorbers(workingPacket, attacker, target, total)

	humanoid.Health = math.max(
		0,
		humanoid.Health - applied
	)

	-- =========================================================================
	-- Sustain
	-- =========================================================================

	-- Omnivamp heals from all damage.
	-- Life Steal additionally applies to Basic Attacks.
	local healRatio = StatService.Get(attacker, "Omnivamp")

	if workingPacket.IsBasicAttack then
		healRatio += StatService.Get(attacker, "LifeSteal")
	end

	if healRatio > 0 then
		DamageService.Heal(
			attacker,
			total * healRatio
		)
	end
	if workingPacket.OnHit then
		local ok, err = pcall(
			workingPacket.OnHit,
			workingPacket,
			attacker,
			target,
			{
				Damage = total,
				Crit = critOccurred,
				Blocked = blocked,
			}
		)

		if not ok then
			warn("[DamageService] OnHit callback failed:", err)
		end
	end

	-- =========================================================================
	-- Damage number
	-- =========================================================================

	local attackerPlayer = Players:GetPlayerFromCharacter(attacker)

	if attackerPlayer then
		local dominant = "Physical"

		if magical > physical then
			dominant = "Magical"
		end

		Remotes.DamageNumber:FireClient(
			attackerPlayer,
			target,
			total,
			dominant,
			critOccurred,
			blocked
		)
	end

	-- =========================================================================
	-- Kill
	-- =========================================================================

	if humanoid.Health <= 0 then
		processKill(target, attacker)
	end

	return total
end

-- ============================================================================
-- CONTRIBUTION CLEANUP
-- ============================================================================

function DamageService.ClearContributors(model: Model)
	contributors[model] = nil
end

return DamageService	
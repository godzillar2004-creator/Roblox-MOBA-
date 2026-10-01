-- ReplicatedStorage.Shared.Characters.Johnny
-- Johnny: ranged AD Marksman who rides Slow Dancer and fires spinning nails.
--
-- The horse itself (spawn mounting, damage soaking, breaking / remounting) lives in
-- ServerScriptService.Server.JohnnyService. This module only holds the data and the
-- ability logic that can run through the normal AbilityService / CombatService hooks.
-- Everything balance-related is a plain number in this file so it is easy to retune.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityTags = require(ReplicatedStorage.Shared.AbilitySystem.AbilityTags)

local C = AbilityTags.Ability
local M = AbilityTags.Movement
local D = AbilityTags.Damage.DamageType
local CC = AbilityTags.Effects.CC
local Effects = AbilityTags.Effects

-- ============================================================================
-- Helpers
-- ============================================================================

local GOLD = Color3.fromRGB(255, 208, 120)
local GOLD_BRIGHT = Color3.fromRGB(255, 236, 170)

local function rankValue(value, rank: number)
	if type(value) == "table" then
		return value[math.clamp(rank, 1, #value)]
	end

	return value
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function isMounted(character: Model): boolean
	return character:GetAttribute("Johnny_Mounted") == true
end

local function mapRaycastParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include

	local include = {}
	local map = workspace:FindFirstChild("Map")
	local effects = workspace:FindFirstChild("Effects")

	if map then table.insert(include, map) end
	if effects then table.insert(include, effects) end

	params.FilterDescendantsInstances = include
	return params
end

-- Server-only: the character modules are also required on the client, where this path does
-- not exist, so the lookup happens lazily inside ability code that only ever runs on the server.
local function getJohnnyService()
	local ok, service = pcall(function()
		return require(game:GetService("ServerScriptService").Server.JohnnyService)
	end)

	return ok and service or nil
end

-- Johnny's signature damage: a Physical component that can crit, plus a linked True component
-- that never rolls on its own (FollowCrit = 1 -> it crits exactly when component #1 did).
local function dealLinked(services, attacker: Model, target: Model, ability, slot: string, physical: number, trueAmount: number)
	local packet = services.Damage.CreatePacket({
		Components = {
			{ Type = "Physical", Amount = physical, CanCrit = true },
			{ Type = "True", Amount = trueAmount, FollowCrit = 1 },
		},

		Source = {
			Kind = "Ability",
			Slot = slot,
			AbilityId = ability.Id,
			DamageType = "Physical",
		},

		CanCrit = false,
		IsBasicAttack = false,
	})

	return services.Damage.Deal(attacker, target, packet)
end

-- ============================================================================
-- Ultimate targeting (shared by the CanCast gate and the cast itself)
-- ============================================================================

local ULT_RANGE = 40 -- how far the aim point may be from Johnny
local ULT_AIM_RADIUS = 8 -- an enemy must be within this of the aim point to be chosen
local ULT_STOP_DISTANCE = 4 -- Slow Dancer pulls up this far from the target
local ULT_TICKS = 4 -- the rotation barrage lands as this many hits
local ULT_TICK_INTERVAL = 0.12

-- Champions are preferred over other targets (dummies, future minions) when both are near the aim.
local function findUltimateTarget(character: Model, rootPosition: Vector3, aimPoint: Vector3, services): Model?
	local aim = aimPoint
	local offset = flat(aimPoint - rootPosition)

	if offset.Magnitude > ULT_RANGE then
		aim = rootPosition + offset.Unit * ULT_RANGE
	end

	local candidates = services.Damage.FindEnemies(character, function(pos)
		return flat(pos - aim).Magnitude <= ULT_AIM_RADIUS
	end)

	local best: Model? = nil
	local bestScore = math.huge

	for _, model in ipairs(candidates) do
		local root = services.Damage.GetRoot(model)

		if root then
			local score = flat(root.Position - aim).Magnitude

			if Players:GetPlayerFromCharacter(model) then
				score -= 4
			end

			if score < bestScore then
				best = model
				bestScore = score
			end
		end
	end

	return best
end

return {
	Id = "Johnny",

	DisplayName = "Johnny",

	Description =
		"A ranged AD Marksman who rides his horse Slow Dancer. Slow Dancer soaks all incoming damage while Johnny is mounted, and his spinning nails pair Physical damage with linked True damage.",

	Class = "Marksman",

	RigType = "R6",

	BodyColor = Color3.fromRGB(234, 184, 146),

	Resource = {
		Name = "Mana",
		Color = Color3.fromRGB(70, 130, 255),
	},

	-- ============================================================
	-- Base Stats
	-- ============================================================

	BaseStats = {
		MaxHealth = 540,
		MaxMana = 320,
		ManaRegen = 3.8,

		AttackDamage = 60,
		AbilityPower = 0,

		PhysicalArmor = 26,
		MagicArmor = 28,

		AttackSpeed = 0.80,

		Haste = 0,
		CritChance = 0,
		CritDamage = 1.75,

		MoveSpeed = 16,

		ArmorPen = 0,
		MagicPen = 0,

		PassiveHealing = 1,
		Omnivamp = 0,
		LifeSteal = 0,
	},

	StatGrowth = {
		MaxHealth = 82,
		MaxMana = 36,
		ManaRegen = 0.32,

		AttackDamage = 3.6,
		AbilityPower = 0,

		PhysicalArmor = 3.0,
		MagicArmor = 1.3,

		AttackSpeed = 0.022,

		PassiveHealing = 0,
	},

	-- ============================================================
	-- Basic Attack: spinning nails
	-- ============================================================

	BasicAttack = {
		Mode = "Projectile",

		Range = 28,
		Speed = 110,
		ProjectileRadius = 0.9,
		Pierce = 0,

		-- VFX.JohnnySpinNail (clones ServerStorage.JohnnyAssets.Spin)
		Visual = "JohnnySpinNail",

		Color = GOLD,

		DamageType = "Physical",

		CanCrit = true,

		Components = {
			{
				Type = "Physical",

				Base = 0,

				Scaling = {
					{
						Stat = "AttackDamage",
						Ratio = 1.0,
					},
				},
			},
		},
	},

	-- ============================================================
	-- Passive
	-- ============================================================

	-- Behaviour is implemented by JohnnyService (mount, absorber, remount).
	Passive = {
		Name = "Slow Dancer",

		Description =
			"Johnny rides Slow Dancer, who soaks all damage Johnny would take and grants bonus Move Speed while mounted. When Slow Dancer's health runs out he bolts, and returns at full health after 20 seconds. Slow Dancer grows stronger as Johnny levels up.",
	},

	-- ============================================================
	-- Summoner
	-- ============================================================

	Summoner = "Flash",

	-- ============================================================
	-- Abilities
	-- ============================================================

	Abilities = {

		-- ========================================================
		-- RMB - Tusk: Act 1
		-- ========================================================

		Ability1 = {
			Id = "TuskAct1",

			Name = "Tusk: Act 1",

			Description =
				"Johnny fires a charged nail that deals Physical damage and slows the first enemy hit.",

			DamageType = "Physical",

			MaxRank = 5,

			RankLevels = { 1, 3, 5, 7, 9 },

			Cooldown = { 7, 6.5, 6, 5.5, 5 },

			Cost = { 40, 45, 50, 55, 60 },

			Targeting = "Direction",

			Tags = {
				[C.Ranged.Projectile] = true,
				[C.Ranged.SingleTarget] = true,
				[CC.Slow] = true,
				[D.Physical] = true,
			},

			Effects = {
				{
					Kind = "Projectile",

					Speed = 85,
					Range = 34,
					Radius = 1.3,
					Pierce = 0,

					Color = GOLD,

					CanCrit = true,

					Damage = {
						Components = {
							{
								Type = "Physical",
								Base = { 55, 85, 115, 145, 175 },
								Scaling = {
									{ Stat = "AttackDamage", Ratio = 0.75 },
								},
							},
						},
					},

					Statuses = {
						{
							Name = "Slow",
							Duration = 1.5,
							Magnitude = { 0.25, 0.30, 0.35, 0.40, 0.45 },
						},
					},
				},
			},
		},

		-- ========================================================
		-- Q - Gallop
		-- ========================================================

		Ability2 = {
			Id = "Gallop",

			Name = "Gallop",

			Description =
				"Slow Dancer gallops forward in the aimed direction and Johnny gains 25% Move Speed for 2.5 seconds. On foot, Johnny only makes a short hop and gets no Move Speed.",

			DamageType = "None",

			MaxRank = 5,

			RankLevels = { 1, 3, 5, 7, 9 },

			Cooldown = { 11, 10, 9, 8, 7 },

			Cost = { 40, 45, 50, 55, 60 },

			Targeting = "Direction",

			Tags = {
				[M.Dash] = true,
				[Effects.Buff] = true,
			},

			Effects = {
				-- Mounted: full gallop + speed buff.
				{
					Kind = "Dash",
					Mode = "Dash",
					Distance = { 13, 14, 15, 16, 17 },
					Duration = 0.22,
					Condition = function(ctx)
						return isMounted(ctx.Character)
					end,
				},

				{
					Kind = "Buff",
					Name = "Gallop",
					Duration = 2.5,
					Stats = {
						MoveSpeed = { Percent = 0.25 },
					},
					Condition = function(ctx)
						return isMounted(ctx.Character)
					end,
				},

				-- On foot: short hop.
				{
					Kind = "Dash",
					Mode = "Dash",
					Distance = 7,
					Duration = 0.2,
					Condition = function(ctx)
						return not isMounted(ctx.Character)
					end,
				},
			},
		},

		-- ========================================================
		-- E - Tusk: Act 3
		-- ========================================================

		Ability3 = {
			Id = "TuskAct3",

			Name = "Tusk: Act 3",

			Description =
				"Johnny fires a piercing nail in a line, dealing Physical damage plus linked True damage. The True damage critically strikes whenever the Physical damage does.",

			DamageType = "Physical",

			MaxRank = 5,

			RankLevels = { 1, 3, 5, 7, 9 },

			Cooldown = { 12, 11, 10, 9, 8 },

			Cost = { 55, 60, 65, 70, 75 },

			Targeting = "Direction",

			Tags = {
				[C.Ranged.Line] = true,
				[D.Physical] = true,
				[D.True] = true,
				[AbilityTags.Damage.CriticalStrikeModifier] = true,
			},

			Effects = {
				{
					Kind = "Custom",

					Run = function(ctx, services)
						local LENGTH = 30
						local WIDTH = 3.5

						local origin = ctx.Origin
						local direction = ctx.Direction
						local rank = ctx.Rank

						-- The nail stops at walls / map geometry.
						local length = LENGTH
						local wall = workspace:Raycast(origin, direction * LENGTH, mapRaycastParams())
						if wall then
							length = math.max(0.5, (wall.Position - origin).Magnitude)
						end

						services.VFX.Line(origin, direction, length, WIDTH, GOLD, 0.2)
						services.VFX.Burst(origin + direction * length, GOLD_BRIGHT, 0.8)

						local attackDamage = services.Stats.Get(ctx.Character, "AttackDamage")

						local physical = rankValue({ 70, 105, 140, 175, 210 }, rank) + attackDamage * 0.80
						local trueAmount = rankValue({ 20, 30, 40, 50, 60 }, rank) + attackDamage * 0.15

						local targets = services.Damage.FindEnemies(ctx.Character, function(pos)
							return services.Ability.Shapes.Line(origin, direction, length, WIDTH, pos)
						end)

						for _, target in ipairs(targets) do
							dealLinked(services, ctx.Character, target, ctx.Ability, ctx.Slot, physical, trueAmount)
						end
					end,
				},
			},
		},

		-- ========================================================
		-- R - Tusk: Act 4
		-- ========================================================

		Ultimate = {
			Id = "TuskAct4",

			Name = "Tusk: Act 4",

			Description =
				"Requires Slow Dancer and an enemy near the aim point. Johnny charges the target on Slow Dancer, stuns them, and unleashes an Infinite Rotation barrage of nails: Physical damage plus linked True damage that crit together.",

			DamageType = "Physical",

			MaxRank = 3,

			RankLevels = { 6, 11, 16 },

			Cooldown = { 100, 85, 70 },

			Cost = { 100, 125, 150 },

			Targeting = "Point",

			Range = ULT_RANGE,

			Tags = {
				[C.Melee.SingleTarget] = true,
				[M.Dash] = true,
				[CC.Stun] = true,
				[D.Physical] = true,
				[D.True] = true,
				[AbilityTags.Damage.CriticalStrikeModifier] = true,
			},

			-- Runs before mana is spent / cooldown starts (see AbilityService.Cast).
			CanCast = function(ctx, services)
				if not isMounted(ctx.Character) then
					return false, "Slow Dancer isn't with you"
				end

				local target = findUltimateTarget(ctx.Character, ctx.Root.Position, ctx.AimPoint, services)
				if not target then
					return false, "No target"
				end

				return true
			end,

			Effects = {
				{
					Kind = "Custom",

					Run = function(ctx, services)
						local rank = ctx.Rank
						local target = findUltimateTarget(ctx.Character, ctx.Origin, ctx.AimPoint, services)
						local targetRoot = target and services.Damage.GetRoot(target)

						if not target or not targetRoot then
							return
						end

						-- ---- Charge ------------------------------------------------------
						local toTarget = flat(targetRoot.Position - ctx.Origin)
						local direction = toTarget.Magnitude > 0.05 and toTarget.Unit or ctx.Direction
						local travel = math.max(toTarget.Magnitude - ULT_STOP_DISTANCE, 0)

						local wall = workspace:Raycast(ctx.Origin, direction * (travel + 2), mapRaycastParams())
						if wall then
							travel = math.max(0, (wall.Position - ctx.Origin).Magnitude - 3)
						end

						local chargeTime = math.clamp(travel / 90, 0.15, 0.55)
						local johnnyService = getJohnnyService()

						if johnnyService and travel > 0.5 then
							johnnyService.Charge(ctx.Player, ctx.Character, ctx.Origin + direction * travel, chargeTime)
						end

						services.VFX.Line(ctx.Origin, direction, math.max(travel, 1), 4, GOLD, chargeTime + 0.15)

						-- ---- Impact + barrage -------------------------------------------
						local attackDamage = services.Stats.Get(ctx.Character, "AttackDamage")

						local physicalPerTick = (rankValue({ 200, 320, 440 }, rank) + attackDamage * 1.2) / ULT_TICKS
						local truePerTick = (rankValue({ 60, 100, 140 }, rank) + attackDamage * 0.3) / ULT_TICKS

						local stunDuration = rankValue({ 0.9, 1.1, 1.3 }, rank)

						task.delay(chargeTime, function()
							if not ctx.Character.Parent or ctx.Humanoid.Health <= 0 then
								return
							end

							if not services.Damage.IsAlive(target) then
								return
							end

							local currentRoot = services.Damage.GetRoot(target)
							local casterRoot = ctx.Character:FindFirstChild("HumanoidRootPart")

							-- The target slipped away (blink, death, untargetable) before we got there.
							if not currentRoot or not casterRoot
								or flat(currentRoot.Position - casterRoot.Position).Magnitude > ULT_STOP_DISTANCE + 10
							then
								return
							end

							services.Status.Apply(target, "Stun", stunDuration)
							services.VFX.Burst(currentRoot.Position, GOLD_BRIGHT, 1.4)

							for tick = 1, ULT_TICKS do
								task.delay((tick - 1) * ULT_TICK_INTERVAL, function()
									if not ctx.Character.Parent or ctx.Humanoid.Health <= 0 then
										return
									end

									if not services.Damage.IsAlive(target) then
										return
									end

									dealLinked(
										services,
										ctx.Character,
										target,
										ctx.Ability,
										ctx.Slot,
										physicalPerTick,
										truePerTick
									)

									local root = services.Damage.GetRoot(target)
									if root then
										services.VFX.Burst(root.Position, GOLD, 0.7)
									end
								end)
							end
						end)
					end,
				},
			},
		},
	},
}

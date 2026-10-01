-- ReplicatedStorage.Shared.Characters.Itadori
-- Itadori: close-combat AD Warrior built around Cursed Reinforcement and Black Flash.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AbilityTags = require(
	ReplicatedStorage.Shared.AbilitySystem.AbilityTags
)

local C = AbilityTags.Ability
local D = AbilityTags.Damage.DamageType
local Damage = AbilityTags.Damage
local CC = AbilityTags.Effects.CC
local Effects = AbilityTags.Effects

local function addTemporaryHighlight(
	character: Model,
	fillColor: Color3,
	outlineColor: Color3,
	duration: number
)
	if not character or not character.Parent then
		return
	end

	local existing = character:FindFirstChild("ItadoriHitHighlight")
	if existing then
		existing:Destroy()
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "ItadoriHitHighlight"
	highlight.FillColor = fillColor
	highlight.OutlineColor = outlineColor
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.Parent = character

	task.delay(duration, function()
		if highlight and highlight.Parent then
			highlight:Destroy()
		end
	end)
end

local function getPlayerStats(ctx, services)
	local playerStateService = services and services.PlayerState
	local state = playerStateService and playerStateService.Get(ctx.Player)

	local stats = state and state.Stats or {}
	local level = state and state.Level or 1

	-- Character's base AD at the current level, before items/modifiers.
	local baseAD = 61 + ((level - 1) * 3.2)

	local totalAD = stats.AttackDamage or baseAD
	local bonusAD = math.max(0, totalAD - baseAD)

	return state, stats, bonusAD
end

-- ============================================================================
-- BLOOD SPRAY
-- ============================================================================

local function performBloodSpray(ctx, services, effect)
	local damageService = services.Damage
	local statusService = services.Status
	local abilityService = services.Ability
	local statService = services.Stats
	local vfx = services.VFX

	local range = effect.Range or 325
	local angle = effect.Angle or 70
	local tickCount = effect.Ticks or 4
	local tickInterval = effect.TickInterval or 0.5

	local slowValues =
		effect.Slow
		or { 0.20, 0.25, 0.30, 0.35, 0.40 }

	local damageValues =
		effect.Base
		or { 18, 26, 34, 42, 50 }

	local apRatio = effect.APRatio or 0.20

	local function applyTick(tickIndex)
		if ctx.Character.Parent and vfx and vfx.ItadoriBloodSpray then
			vfx.ItadoriBloodSpray(ctx.Origin, ctx.Direction, range, angle, (tickIndex == 0) and 18 or 9)
		end

		if not ctx.Character.Parent then
			return
		end

		local targets = damageService.FindEnemies(
			ctx.Character,
			function(pos)
				return abilityService.Shapes.Cone(
					ctx.Origin,
					ctx.Direction,
					range,
					angle,
					pos
				)
			end
		)

		local baseDamage =
			damageValues[ctx.Rank]
			or damageValues[#damageValues]

		local damage =
			baseDamage
			+ statService.Get(ctx.Character, "AbilityPower") * apRatio

		local slow =
			slowValues[ctx.Rank]
			or slowValues[#slowValues]

		for _, target in ipairs(targets) do
			local packet = damageService.CreatePacket({
				Components = {
					{
						Type = "Magical",
						Amount = damage,
						CanCrit = false,
					},
				},

				Source = {
					Kind = "Ability",
					Slot = ctx.Slot,
					AbilityId = ctx.Ability.Id,
					DamageType = ctx.Ability.DamageType,
				},

				CanCrit = false,
				IsBasicAttack = false,
			})

			damageService.Deal(
				ctx.Character,
				target,
				packet
			)

			statusService.Apply(
				target,
				"Slow",
				1.5,
				slow
			)

			local hitRoot = damageService.GetRoot(target)
			if hitRoot and vfx and vfx.ItadoriBloodHit then
				vfx.ItadoriBloodHit(hitRoot.Position)
			end
		end
	end

	-- Blood splatter VFX is spawned per tick (see applyTick).

	for tick = 0, tickCount - 1 do
		task.delay(tick * tickInterval, function()
			applyTick(tick)
		end)
	end
end

-- ============================================================================
-- DISMANTLE
-- ============================================================================

local function performDismantle(ctx, services, effect)
	local damageService = services.Damage
	local statusService = services.Status
	local abilityService = services.Ability
	local statService = services.Stats
	local vfx = services.VFX

	local targets = damageService.FindEnemies(
		ctx.Character,
		function(pos)
			return abilityService.Shapes.Cone(
				ctx.Origin,
				ctx.Direction,
				effect.Range or 250,
				60,
				pos
			)
		end
	)

	table.sort(targets, function(a, b)
		return (
			damageService.GetRoot(a).Position - ctx.Origin
		).Magnitude < (
			damageService.GetRoot(b).Position - ctx.Origin
		).Magnitude
	end)

	local target = targets[1]
	if not target then
		return
	end

	local targetRoot = damageService.GetRoot(target)
	if not targetRoot then
		return
	end

	-- The grab itself deals no damage.
	-- Pull the target into melee range.
	local pullPosition = ctx.Origin + ctx.Direction * 4

	if vfx and vfx.ItadoriDust then
		vfx.ItadoriDust(targetRoot.Position, 1)
		vfx.ItadoriDust(pullPosition, 1.15)
	end

	targetRoot.CFrame =
		CFrame.new(pullPosition)
		* targetRoot.CFrame.Rotation

	statusService.Apply(
		target,
		"Stun",
		effect.StunDuration or 0.70,
		0
	)

	local _, stats, bonusAD = getPlayerStats(ctx, services)

	local attackDamage = stats.AttackDamage or 61
	local hitCount = effect.Hits or 5
	local interval = effect.Interval or 0.12

	local baseValues =
		effect.Base
		or { 18, 27, 36, 45, 54 }

	local bonusADRatio = effect.BonusADRatio or 0.22

	for hit = 1, hitCount do
		task.delay(
			(hit - 1) * interval,
			function()
				local humanoid =
					target:FindFirstChildOfClass("Humanoid")

				if not target.Parent
					or not humanoid
					or humanoid.Health <= 0
				then
					return
				end

				local base =
					baseValues[ctx.Rank]
					or baseValues[#baseValues]

				local amount =
					base
					+ (
						(bonusAD > 0 and bonusAD or attackDamage)
						* bonusADRatio
					)

				local toTarget = Vector3.new(
					targetRoot.Position.X - ctx.Origin.X,
					0,
					targetRoot.Position.Z - ctx.Origin.Z
				)

				if toTarget.Magnitude > 0.05 then
					if vfx.ItadoriDismantleSlash then
						vfx.ItadoriDismantleSlash(targetRoot.Position, 1)
					end
				end

				local packet = damageService.CreatePacket({
					Components = {
						{
							Type = "Physical",
							Amount = amount,
							CanCrit = false,
						},
					},

					Source = {
						Kind = "Ability",
						Slot = ctx.Slot,
						AbilityId = ctx.Ability.Id,
						DamageType = ctx.Ability.DamageType,
					},

					CanCrit = false,
					IsBasicAttack = false,
				})

				damageService.Deal(
					ctx.Character,
					target,
					packet
				)
			end
		)
	end
end

-- ============================================================================
-- MAX OUTPUT DISMANTLE
-- ============================================================================

local function performMaxOutputDismantle(ctx, services, effect)
	local damageService = services.Damage
	local statService = services.Stats
	local abilityService = services.Ability
	local vfx = services.VFX

	local range = effect.Range or 1600
	local width = effect.Width or 12

	local maxMissingBonus =
		effect.MissingHealthBonus
		or { 0.40, 0.55, 0.70 }

	local baseValues =
		effect.Base
		or { 180, 300, 420 }

	local bonusADRatio = effect.BonusADRatio or 1.00
	local apRatio = effect.APRatio or 0.35

	vfx.ItadoriMaxDismantle(ctx.Origin, ctx.Direction, range, width)

	local targets = damageService.FindEnemies(
		ctx.Character,
		function(pos)
			return abilityService.Shapes.Line(
				ctx.Origin,
				ctx.Direction,
				range,
				width,
				pos
			)
		end
	)

	for _, target in ipairs(targets) do
		local humanoid =
			target:FindFirstChildOfClass("Humanoid")

		if humanoid and humanoid.Health > 0 then
			local _, stats, bonusAD =
				getPlayerStats(ctx, services)

			local totalAD = stats.AttackDamage or 61
			local ap =
				statService.Get(
					ctx.Character,
					"AbilityPower"
				)

			local rankBase =
				baseValues[ctx.Rank]
				or baseValues[#baseValues]

			local raw =
				rankBase
				+ (bonusAD * bonusADRatio)
				+ (ap * apRatio)

			if bonusAD <= 0 then
				raw =
					rankBase
					+ (totalAD * 0.35)
					+ (ap * apRatio)
			end

			local missingHealth =
				1 - (
					humanoid.Health
					/ math.max(humanoid.MaxHealth, 1)
				)

			local bonus =
				maxMissingBonus[ctx.Rank]
				or maxMissingBonus[#maxMissingBonus]

			raw *= 1 + (missingHealth * bonus)

			local packet = damageService.CreatePacket({
				Components = {
					{
						Type = "Physical",
						Amount = raw,
						CanCrit = false,
					},
				},

				Source = {
					Kind = "Ability",
					Slot = ctx.Slot,
					AbilityId = ctx.Ability.Id,
					DamageType = ctx.Ability.DamageType,
				},

				CanCrit = false,
				IsBasicAttack = false,
			})

			damageService.Deal(
				ctx.Character,
				target,
				packet
			)
		end
	end
end

-- ============================================================================
-- CHARACTER DEFINITION
-- ============================================================================

return {
	Id = "Itadori",
	DisplayName = "Itadori",

	Description =
		"A close-combat AD Warrior who relies on Cursed Reinforcement and Black Flash to overwhelm enemies at melee range.",

	Class = "Warrior",

	RigType = "R6",

	BodyColor = Color3.fromRGB(214, 151, 112),

	Resource = {
		Name = "Mana",
		Color = Color3.fromRGB(70, 130, 255),
	},

	-- =========================================================================
	-- BASE STATS
	-- =========================================================================

	BaseStats = {
		MaxHealth = 630,
		MaxMana = 380,
		ManaRegen = 4.5,

		AttackDamage = 61,
		AbilityPower = 0,

		PhysicalArmor = 34,
		MagicArmor = 30,

		AttackSpeed = 0.68,

		Haste = 0,
		CritChance = 0,

		MoveSpeed = 16.5,

		CritDamage = 1.75,

		ArmorPen = 0,
		MagicPen = 0,

		PassiveHealing = 1,
		Omnivamp = 0,
		LifeSteal = 0,
	},

	StatGrowth = {
		MaxHealth = 90,
		MaxMana = 45,
		ManaRegen = 0.4,

		AttackDamage = 3.2,
		AbilityPower = 0,

		PhysicalArmor = 3.5,
		MagicArmor = 1.4,

		AttackSpeed = 0.018,

		PassiveHealing = 0,
	},

	-- =========================================================================
	-- BASIC ATTACK
	-- =========================================================================

	BasicAttack = {
		Mode = "Melee",

		Range = 8,

		Color = Color3.fromRGB(
			238,
			228,
			220
		),

		MaxTargets = 1,

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

	-- =========================================================================
	-- PASSIVE — BLACK FLASH
	-- =========================================================================

	Passive = {
		Name = "Black Flash",

		Description =
			"When Cursed Reinforcement produces a Black Flash, immediately refresh Cursed Reinforcement. This can trigger up to 3 times before Black Flash enters a 25-second cooldown.",

		MaxRefreshes = 3,
		Cooldown = 25,

		UI = {
			Mode = "Cooldown",
			Title = "BLACK",
			Subtitle = "FLASH",

			CooldownUntilAttribute =
				"Itadori_BlackFlashPassiveCooldownUntil",

			CounterAttribute =
				"Itadori_BlackFlashRefreshes",

			MaxCounter = 3,

			ReadyText = "READY",
		},
	},

	Summoner = "Flash",

	-- =========================================================================
	-- ABILITIES
	-- =========================================================================

	Abilities = {

		-- =====================================================================
		-- ABILITY 1 — CURSED REINFORCEMENT
		-- =====================================================================

		Ability1 = {
			Id = "CursedReinforcement",

			Name = "Cursed Reinforcement",

			Description =
				"Enhance your next landed basic attack and gain movement speed. If the empowered attack critically strikes, it becomes a Black Flash that stuns and heals you.",

			DamageType = "Physical",

			MaxRank = 5,

			RankLevels = {
				1,
				3,
				5,
				7,
				9,
			},

			Cooldown = {
				12,
				11,
				10,
				9,
				8,
			},

			Cost = {
				55,
				60,
				65,
				70,
				75,
			},

			Targeting = "Self",

			Tags = {
				[C.Melee.BasicAttackModifier] = true,
				[C.Melee.OnHit] = true,
				[C.Melee.SingleTarget] = true,

				[Effects.Buff] = true,

				[D.Physical] = true,

				[CC.Stun] = true,
			},

			Effects = {

				-- Movement speed
				{
					Kind = "Buff",

					Name = "CursedReinforcementMoveSpeed",

					Duration = 2.5,

					Stats = {
						MoveSpeed = {
							Percent = 0.20,
						},
					},
				},

				-- Mark the next basic attack as empowered.
				{
					Kind = "Custom",

					Run = function(ctx, services)
						ctx.Character:SetAttribute(
							"Itadori_CursedReinforcement",
							true
						)

						ctx.Character:SetAttribute(
							"Itadori_CursedReinforcementRank",
							ctx.Rank
						)

						local fireVfx = services and services.VFX
						if fireVfx and fireVfx.ItadoriArmFire then
							fireVfx.ItadoriArmFire(ctx.Character, 2.5)
						end

						task.delay(2.5, function()
							if ctx.Character.Parent then
								ctx.Character:SetAttribute(
									"Itadori_CursedReinforcement",
									nil
								)

								ctx.Character:SetAttribute(
									"Itadori_CursedReinforcementRank",
									nil
								)
							end
						end)
					end,
				},
			},
		},

		-- =====================================================================
		-- ABILITY 2 — BLOOD SPRAY
		-- =====================================================================

		Ability2 = {
			Id = "BloodSpray",

			Name = "Blood Spray",

			Description =
				"Spray blood through a short cone, dealing repeated magical damage and slowing enemies caught inside.",

			DamageType = "Magical",

			MaxRank = 5,

			RankLevels = {
				1,
				3,
				5,
				7,
				9,
			},

			Cooldown = {
				15,
				14,
				13,
				12,
				11,
			},

			Cost = {
				60,
				65,
				70,
				75,
				80,
			},

			Targeting = "Direction",

			Tags = {
				[C.Ranged.Cone] = true,

				[D.Magical] = true,
				[Damage.DamageOverTime] = true,

				[CC.Slow] = true,
			},

			Effects = {
				{
					Kind = "Custom",

					Range = 18,
					Angle = 55,

					Ticks = 4,
					TickInterval = 0.5,

					Base = {
						18,
						26,
						34,
						42,
						50,
					},

					APRatio = 0.20,

					Slow = {
						0.20,
						0.25,
						0.30,
						0.35,
						0.40,
					},

					Run = function(ctx, services)
						performBloodSpray(
							ctx,
							services,
							ctx.Ability.Effects[1]
						)
					end,
				},
			},
		},

		-- =====================================================================
		-- ABILITY 3 — DISMANTLE
		-- =====================================================================

		Ability3 = {
			Id = "Dismantle",

			Name = "Dismantle",

			Description =
				"Grab a nearby enemy, pull them into melee range, and unleash a rapid flurry of physical Dismantles.",

			DamageType = "Physical",

			MaxRank = 5,

			RankLevels = {
				1,
				3,
				5,
				7,
				9,
			},

			Cooldown = {
				18,
				17,
				16,
				15,
				14,
			},

			Cost = {
				70,
				80,
				90,
				100,
				110,
			},

			Targeting = "Direction",

			Tags = {
				[C.Melee.SingleTarget] = true,
				[D.Physical] = true,
			},

			Effects = {
				{
					Kind = "Custom",

					Range = 250,

					Hits = 5,
					Interval = 0.12,

					Base = {
						18,
						27,
						36,
						45,
						54,
					},

					BonusADRatio = 0.22,

					StunDuration = 0.70,

					Run = function(ctx, services)
						performDismantle(
							ctx,
							services,
							ctx.Ability.Effects[1]
						)
					end,
				},
			},
		},

		-- =====================================================================
		-- ULTIMATE — IN THE ZONE
		-- =====================================================================

		Ultimate = {
			Id = "InTheZone",

			Name = "In the Zone",

			Description =
				"Enter an enhanced state for 15 seconds, empowering your fists and greatly increasing Black Flash healing. Recast to fire Max Output Dismantle.",

			DamageType = "Physical",

			MaxRank = 3,

			RankLevels = {
				6,
				11,
				16,
			},

			Cooldown = {
				110,
				95,
				80,
			},

			Cost = {
				100,
				125,
				150,
			},

			Targeting = "Self",

			Tags = {
				[Effects.Transformation] = true,

				[C.Melee.BasicAttackModifier] = true,

				[C.Ranged.Line] = true,

				[C.Recast] = true,

				[D.Physical] = true,
				[Damage.MissingHealth] = true,
			},

			Recast = {
				MaxCasts = 2,
				Window = 15,

				Effects = {
					{
						Kind = "Custom",

						Range = 1600,
						Width = 12,

						Base = {
							180,
							300,
							420,
						},

						BonusADRatio = 1.00,
						APRatio = 0.35,

						MissingHealthBonus = {
							0.40,
							0.55,
							0.70,
						},

						Run = function(ctx, services)
							performMaxOutputDismantle(
								ctx,
								services,
								ctx.Ability.Recast.Effects[1]
							)
						end,
					},
				},
			},

			Effects = {

				-- +20% Attack Damage for 15 seconds.
				{
					Kind = "Buff",

					Name = "InTheZone",

					Duration = 15,

					Stats = {
						AttackDamage = {
							Percent = 0.20,
						},
					},
				},

				-- Blue aura + attack range + Black Flash healing.
				{
					Kind = "Custom",

					Run = function(ctx)
						local rankMultipliers = {
							1.75,
							2.25,
							2.75,
						}

						local healMultiplier =
							rankMultipliers[ctx.Rank]
							or rankMultipliers[#rankMultipliers]

						ctx.Character:SetAttribute(
							"Itadori_BasicAttackRangeBonus",
							3
						)

						ctx.Character:SetAttribute(
							"Itadori_BlackFlashHealMultiplier",
							healMultiplier
						)

						local aura =
							ctx.Character:FindFirstChild(
								"ItadoriZoneAura"
							)

						if aura then
							aura:Destroy()
						end

						aura = Instance.new("Highlight")

						aura.Name = "ItadoriZoneAura"

						aura.FillColor =
							Color3.fromRGB(
								70,
								140,
								255
							)

						aura.OutlineColor =
							Color3.fromRGB(
								190,
								225,
								255
							)

						aura.FillTransparency = 0.60
						aura.OutlineTransparency = 0.05

						aura.DepthMode =
							Enum.HighlightDepthMode.AlwaysOnTop

						aura.Parent = ctx.Character

						task.delay(15, function()
							if ctx.Character.Parent then
								ctx.Character:SetAttribute(
									"Itadori_BasicAttackRangeBonus",
									nil
								)

								ctx.Character:SetAttribute(
									"Itadori_BlackFlashHealMultiplier",
									nil
								)

								local currentAura =
									ctx.Character:FindFirstChild(
										"ItadoriZoneAura"
									)

								if currentAura then
									currentAura:Destroy()
								end
							end
						end)
					end,
				},
			},
		},
	},

	-- =========================================================================
	-- BASIC ATTACK HOOK
	-- =========================================================================
	--
	-- This is called by CombatService only after an actual basic attack target
	-- has been selected. That means Cursed Reinforcement is consumed by a
	-- successful landed attack rather than by simply clicking.
	--
	-- The base basic attack remains a normal 100% AD physical attack.
	-- Cursed Reinforcement adds its bonus damage to that attack.
	--
	-- If the attack Crits:
	--      normal empowered hit
	--             ↓
	--         Black Flash
	--             ↓
	--     bonus physical damage
	--     stun
	--     healing
	--     passive refresh
	-- =========================================================================

	OnBasicAttack = function(ctx, rawPacket)
		local character = ctx.Character

		if not character:GetAttribute(
			"Itadori_CursedReinforcement"
			) then
			return
		end

		local services = ctx.Services

		if not services then
			return
		end

		local rank =
			character:GetAttribute(
				"Itadori_CursedReinforcementRank"
			)
			or ctx.Rank
			or 1

		local _, stats, bonusAD =
			getPlayerStats(ctx, services)

		local abilityPower =
			stats.AbilityPower or 0

		local baseValues = {
			30,
			45,
			60,
			75,
			90,
		}

		local blackFlashBase = {
			35,
			55,
			75,
			95,
			115,
		}

		local empoweredBase =
			baseValues[rank]
			or baseValues[#baseValues]

		local empoweredAmount =
			empoweredBase
			+ (bonusAD * 0.55)
			+ (abilityPower * 0.30)

		table.insert(
			rawPacket.Components,
			{
				Type = "Physical",
				Amount = empoweredAmount,
				CanCrit = false,
			}
		)

		-- Consume the reinforcement on the first landed basic attack.
		character:SetAttribute(
			"Itadori_CursedReinforcement",
			nil
		)

		character:SetAttribute(
			"Itadori_CursedReinforcementRank",
			nil
		)

		-- Normal Cursed Reinforcement visual.
		-- Hit visuals (blue splash / Black Flash) are spawned in OnHit below.

		local previousOnHit = rawPacket.OnHit

		rawPacket.OnHit = function(
			packet,
			attacker,
			target,
			result
		)
			if previousOnHit then
				previousOnHit(
					packet,
					attacker,
					target,
					result
				)
			end

			local vfx = services.VFX
			local targetRoot = target:FindFirstChild("HumanoidRootPart")

			if not result.Crit then
				if vfx and vfx.ItadoriBlueSplash and targetRoot then
					vfx.ItadoriBlueSplash(targetRoot.Position)
				end
				return
			end

			-- Black Flash visual.
			if vfx and vfx.ItadoriBlackFlash and targetRoot then
				vfx.ItadoriBlackFlash(targetRoot.Position)
			end

			local stunValues = {
				0.60,
				0.65,
				0.70,
				0.75,
				0.80,
			}

			local blackFlashBaseDamage =
				blackFlashBase[rank]
				or blackFlashBase[#blackFlashBase]

			local blackFlashAmount =
				blackFlashBaseDamage
				+ (bonusAD * 0.25)
				+ (abilityPower * 0.25)

			local blackFlashPacket =
				services.Damage.CreatePacket({
					Components = {
						{
							Type = "Physical",
							Amount = blackFlashAmount,
							CanCrit = false,
						},
					},

					Source = {
						Kind = "Ability",
						Slot = "Ability1",
						AbilityId = "CursedReinforcement",
						DamageType = "Physical",
					},

					CanCrit = false,
					IsBasicAttack = false,
				})

			local blackFlashDamage =
				services.Damage.Deal(
					attacker,
					target,
					blackFlashPacket
				)

			services.Status.Apply(
				target,
				"Stun",
				stunValues[rank]
					or stunValues[#stunValues],
				0
			)

			local healMultiplier =
				character:GetAttribute(
					"Itadori_BlackFlashHealMultiplier"
				)
				or 1

			services.Damage.Heal(
				character,
				blackFlashDamage
					* 0.25
					* healMultiplier
			)

			-- ================================================================
			-- BLACK FLASH PASSIVE REFRESH
			-- ================================================================

			local count =
				character:GetAttribute(
					"Itadori_BlackFlashRefreshes"
				)
				or 0

			local passiveReady =
				character:GetAttribute(
					"Itadori_BlackFlashPassiveReady"
				)

			if passiveReady == nil then
				passiveReady = true
			end

			if passiveReady and count < 3 then
				character:SetAttribute(
					"Itadori_BlackFlashRefreshes",
					count + 1
				)

				local player =
					game:GetService("Players")
					:GetPlayerFromCharacter(attacker)

				if player
					and services.Ability.ResetCooldown
				then
					services.Ability.ResetCooldown(
						player,
						"Ability1"
					)
				end

				if count + 1 >= 3 then
					character:SetAttribute(
						"Itadori_BlackFlashPassiveReady",
						false
					)

					local cooldownUntil =
						workspace:GetServerTimeNow() + 25

					character:SetAttribute(
						"Itadori_BlackFlashPassiveCooldownUntil",
						cooldownUntil
					)

					task.delay(25, function()
						if character.Parent then
							character:SetAttribute(
								"Itadori_BlackFlashRefreshes",
								0
							)

							character:SetAttribute(
								"Itadori_BlackFlashPassiveReady",
								true
							)

							character:SetAttribute(
								"Itadori_BlackFlashPassiveCooldownUntil",
								0
							)
						end
					end)
				end
			end
		end
	end,
}
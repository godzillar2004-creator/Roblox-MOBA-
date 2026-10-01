-- ReplicatedStorage.Shared.Characters.Levi
-- Levi: early-game AD Assassin focused on rapid movement, Airborne setup,
-- and explosive close-range burst.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local AbilityTags = require(ReplicatedStorage.Shared.AbilitySystem.AbilityTags)

local C = AbilityTags.Ability
local D = AbilityTags.Damage.DamageType
local Damage = AbilityTags.Damage
local CC = AbilityTags.Effects.CC
local Effects = AbilityTags.Effects
local Movement = AbilityTags.Movement

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function getStats(ctx, services)
	local stats = services.Stats
	local attackDamage = stats.Get(ctx.Character, "AttackDamage")
	local player = Players:GetPlayerFromCharacter(ctx.Character)
	local level = player and (player:GetAttribute("Level") or 1) or 1
	local baseAD = 62 + math.max(0, level - 1) * 3.5
	local bonusAD = math.max(0, attackDamage - baseAD)
	return stats, attackDamage, bonusAD
end

local function makePacket(damageService, amount, damageType, slot, abilityId, canCrit)
	return damageService.CreatePacket({
		Components = {
			{
				Type = damageType,
				Amount = amount,
				CanCrit = canCrit == true,
			},
		},
		Source = {
			Kind = "Ability",
			Slot = slot,
			AbilityId = abilityId,
			DamageType = damageType,
		},
		CanCrit = canCrit == true,
		IsBasicAttack = false,
	})
end

local function findHookOrigin(character, side: number): Vector3
	local gearName = side == 1 and "Levi_ODM_Left" or "Levi_ODM_Right"
	local gear = character:FindFirstChild(gearName)
	if gear and gear:IsA("BasePart") then
		local attachment = gear:FindFirstChild("HookOrigin")
		if attachment and attachment:IsA("Attachment") then
			return attachment.WorldPosition
		end
		return gear.Position
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	return root and root.Position or Vector3.zero
end

local function isAirborne(statusService, model): boolean
	if statusService.Has(model, "Airborne") then
		return true
	end

	return (model:GetAttribute("Levi_AirborneUntil") or 0) > workspace:GetServerTimeNow()
end

local function moveCharacterOverTime(character: Model, destination: Vector3, lookAtPosition: Vector3?, duration: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not character.Parent then
		return
	end

	local start = character:GetPivot()
	local startPosition = start.Position
	local flatLook = flat((lookAtPosition or (destination + start.LookVector)) - destination)
	if flatLook.Magnitude < 0.05 then
		flatLook = flat(start.LookVector)
	end
	if flatLook.Magnitude < 0.05 then
		flatLook = Vector3.new(0, 0, -1)
	end
	flatLook = flatLook.Unit

	local steps = math.max(4, math.floor(duration / 0.025))
	for i = 1, steps do
		if not character.Parent or not root.Parent then
			return
		end

		local alpha = i / steps
		local position = startPosition:Lerp(destination, alpha)
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		character:PivotTo(CFrame.lookAt(position, position + flatLook))
		task.wait(duration / steps)
	end
end

local function performGrapple(ctx, services, effect)
	local character = ctx.Character
	local damageService = services.Damage
	local statusService = services.Status
	local vfx = services.VFX
	local abilityService = services.Ability

	if not character.Parent then
		return
	end

	local side = (character:GetAttribute("Levi_HookSide") or 0) == 1 and 2 or 1
	character:SetAttribute("Levi_HookSide", side)

	local origin = findHookOrigin(character, side)
	local direction = flat(ctx.Direction)
	if direction.Magnitude < 0.05 then
		local root = character:FindFirstChild("HumanoidRootPart")
		direction = root and flat(root.CFrame.LookVector) or Vector3.new(0, 0, -1)
	end
	direction = direction.Unit

	local maxRange = effect.Range or 24
	local target = nil
	local targetDistance = maxRange + 1

	for _, enemy in ipairs(damageService.GetDamageables()) do
		local enemyPlayer = Players:GetPlayerFromCharacter(enemy)
		if enemyPlayer
			and damageService.IsEnemy(character, enemy)
			and not enemy:GetAttribute("Untargetable")
		then
			local root = damageService.GetRoot(enemy)
			if root then
				local offset = root.Position - origin
				local distance = offset.Magnitude
				if distance <= maxRange then
					local along = offset:Dot(direction)
					if along >= 0 and along <= maxRange then
						local closest = origin + direction * along
						local lateral = (root.Position - closest).Magnitude
						if lateral <= 1.8 and distance < targetDistance then
							target = enemy
							targetDistance = distance
						end
					end
				end
			end
		end
	end

	local wallParams = RaycastParams.new()
	wallParams.FilterType = Enum.RaycastFilterType.Include

	local include = {}
	local map = workspace:FindFirstChild("Map")
	if map then table.insert(include, map) end
	if workspace.Terrain then table.insert(include, workspace.Terrain) end
	wallParams.FilterDescendantsInstances = include

	local wall = workspace:Raycast(origin, direction * maxRange, wallParams)
	local hookDistance = maxRange
	local hookPoint = origin + direction * maxRange

	if wall and math.abs(wall.Normal.Y) < 0.65 then
		hookDistance = (wall.Position - origin).Magnitude
		hookPoint = wall.Position
	else
		wall = nil
	end

	if target and targetDistance < hookDistance + 0.25 then
		local targetRoot = damageService.GetRoot(target)
		if not targetRoot then
			return
		end

		local _, attackDamage, bonusAD = getStats(ctx, services)
		local baseValues = { 50, 80, 110, 140, 170 }
		local rankBase = baseValues[ctx.Rank] or baseValues[#baseValues]
		local amount = rankBase + bonusAD * 0.80

		local packet = makePacket(
			damageService,
			amount,
			"Physical",
			ctx.Slot,
			ctx.Ability.Id,
			false
		)
		damageService.Deal(character, target, packet)
		local rootValues = { 0.60, 0.65, 0.70, 0.75, 0.80 }
		statusService.Apply(target, "Root", rootValues[ctx.Rank] or rootValues[#rootValues], 0)

		local pullPosition = targetRoot.Position - direction * 3
		vfx.Line(origin, direction, math.min(maxRange, targetDistance), 0.65, Color3.fromRGB(65, 65, 70), 0.12)
		moveCharacterOverTime(character, pullPosition, targetRoot.Position, 0.20)
		return
	end

	if hookDistance >= maxRange - 0.01 then
		return
	end

	local wallArrival = hookPoint - direction * 2.5
	vfx.Line(origin, direction, hookDistance, 0.65, Color3.fromRGB(65, 65, 70), 0.12)
	moveCharacterOverTime(character, wallArrival, hookPoint, 0.20)
end

local function performSpinningSlash(ctx, services, effect)
	local character = ctx.Character
	local damageService = services.Damage
	local statusService = services.Status
	local vfx = services.VFX

	local _, _, bonusAD = getStats(ctx, services)
	local radius = effect.Radius or 7
	local baseValues = effect.Base or { 70, 105, 140, 175, 210 }
	local baseDamage = baseValues[ctx.Rank] or baseValues[#baseValues]
	local amount = baseDamage + bonusAD * 1.00
	local airborneValues = effect.Airborne or { 1.00, 1.05, 1.10, 1.15, 1.20 }
	local airborneDuration = airborneValues[ctx.Rank] or airborneValues[#airborneValues]

	vfx.Circle(character:GetPivot().Position - Vector3.new(0, 2.7, 0), radius, Color3.fromRGB(190, 190, 205), 0.18)

	for _, target in ipairs(damageService.FindEnemies(character, function(pos)
			return (pos - character:GetPivot().Position).Magnitude <= radius
		end)) do
		local airborneUntil = workspace:GetServerTimeNow() + airborneDuration
		statusService.Apply(target, "Airborne", airborneDuration, 0)
		target:SetAttribute("Levi_AirborneUntil", airborneUntil)
		task.delay(airborneDuration + 0.05, function()
			if target.Parent and (target:GetAttribute("Levi_AirborneUntil") or 0) <= workspace:GetServerTimeNow() then
				target:SetAttribute("Levi_AirborneUntil", nil)
			end
		end)

		local packet = makePacket(
			damageService,
			amount,
			"Physical",
			ctx.Slot,
			ctx.Ability.Id,
			false
		)
		damageService.Deal(character, target, packet)

		local targetRoot = damageService.GetRoot(target)
		if targetRoot then
			targetRoot.AssemblyLinearVelocity = Vector3.new(
				targetRoot.AssemblyLinearVelocity.X,
				42,
				targetRoot.AssemblyLinearVelocity.Z
			)
		end
	end
end

local function performUltimate(ctx, services, effect)
	local character = ctx.Character
	local damageService = services.Damage
	local statusService = services.Status
	local vfx = services.VFX
	local _, attackDamage, bonusAD = getStats(ctx, services)

	character:SetAttribute("CriticalStrikeBonusArmorIgnore", 0.60)
	character:SetAttribute("TrueSightUntil", 0)

	local duration = effect.Duration or 15
	local startTime = workspace:GetServerTimeNow()
	local airborneSeen = {}
	local busy = false

	local connection
	connection = game:GetService("RunService").Heartbeat:Connect(function()
		if not character.Parent or workspace:GetServerTimeNow() - startTime >= duration then
			if connection then
				connection:Disconnect()
			end
			if character.Parent then
				character:SetAttribute("CriticalStrikeBonusArmorIgnore", nil)
			end
			return
		end

		local origin = character:GetPivot().Position

		for _, target in ipairs(damageService.GetDamageables()) do
			if damageService.IsEnemy(character, target) and not target:GetAttribute("Untargetable") then
				local root = damageService.GetRoot(target)
				local isAirborne = root
					and isAirborne(statusService, target)
					and (root.Position - origin).Magnitude <= (effect.TriggerRange or 24)

				if not isAirborne then
					airborneSeen[target] = nil
				elseif not airborneSeen[target] and not busy then
					airborneSeen[target] = true
					busy = true

					local approach = flat(root.Position - origin)
					if approach.Magnitude < 0.05 then
						approach = flat(character:GetPivot().LookVector)
					end
					approach = approach.Unit

					local arrival = root.Position - approach * 3
					character:PivotTo(CFrame.lookAt(arrival, root.Position))

					local nearbyAirborne = damageService.FindEnemies(character, function(pos, model)
						return isAirborne(statusService, model)
							and (pos - root.Position).Magnitude <= (effect.Radius or 7)
					end)

					for _, victim in ipairs(nearbyAirborne) do
						local victimRoot = damageService.GetRoot(victim)
						if victimRoot then
							statusService.Apply(victim, "Airborne", 1.0, 0)
							victimRoot.AssemblyLinearVelocity = Vector3.new(
								victimRoot.AssemblyLinearVelocity.X,
								42,
								victimRoot.AssemblyLinearVelocity.Z
							)

							victim:SetAttribute("TrueSightUntil", workspace:GetServerTimeNow() + 1.0)
						end

						local damageValues = effect.Base or { 80, 120, 160 }
						local slashBase = damageValues[ctx.Rank] or damageValues[#damageValues]
						local slashAmount = (slashBase + bonusAD * 1.20) / 3
						for tick = 1, 3 do
							task.delay((tick - 1) * 0.25, function()
								if victim.Parent then
									local packet = makePacket(
										damageService,
										slashAmount,
										"Physical",
										ctx.Slot,
										ctx.Ability.Id,
										false
									)
									damageService.Deal(character, victim, packet)
								end
							end)
						end
					end

					statusService.Apply(character, "Lockout", effect.Lockout or 0.75, 0)
					vfx.Circle(root.Position - Vector3.new(0, 2.7, 0), effect.Radius or 7, Color3.fromRGB(190, 190, 205), 0.40)

					task.delay(effect.Lockout or 0.75, function()
						busy = false
					end)
				end
			end
		end
	end)
end

return {
	Id = "Levi",
	DisplayName = "Levi",
	Description = "An extremely mobile AD Assassin who chains movement, Airborne setup, and burst damage to eliminate fragile targets.",
	Class = "Assassin",
	RigType = "R6",
	BodyColor = Color3.fromRGB(176, 189, 199),
	Resource = { Name = "None", Color = Color3.fromRGB(90, 90, 95) },

	BaseStats = {
		MaxHealth = 470,
		MaxMana = 0,
		ManaRegen = 0,
		AttackDamage = 62,
		AbilityPower = 0,
		PhysicalArmor = 21,
		MagicArmor = 28,
		AttackSpeed = 0.72,
		Haste = 0,
		CritChance = 0,
		MoveSpeed = 17,
		CritDamage = 1.75,
		ArmorPen = 0,
		MagicPen = 0,
		PassiveHealing = 1,
		Omnivamp = 0,
		LifeSteal = 0,
	},

	StatGrowth = {
		MaxHealth = 72,
		MaxMana = 0,
		ManaRegen = 0,
		AttackDamage = 3.5,
		AbilityPower = 0,
		PhysicalArmor = 2.5,
		MagicArmor = 1.2,
		AttackSpeed = 0.025,
		PassiveHealing = 0,
	},

	BasicAttack = {
		Mode = "Melee",
		Range = 6,
		Angle = 100,
		Color = Color3.fromRGB(225, 230, 235),
		MaxTargets = 1,
		DamageType = "Physical",
		CanCrit = true,
		Components = {
			{
				Type = "Physical",
				Base = 0,
				Scaling = {
					{ Stat = "AttackDamage", Ratio = 1.0 },
				},
			},
		},
	},

	Passive = {
		Name = "Twin Blades",
		Description = "Every 5 seconds, Levi's next basic attack becomes an empowered circular slash, dealing 120% AD physical damage and healing him for a small amount.",
		Cooldown = 5,
	},

	Summoner = "Flash",

	Abilities = {
		Ability1 = {
			Id = "ODMDash",
			Name = "ODM Dash",
			Description = "Levi dashes a short distance.",
			DamageType = "Physical",
			MaxRank = 5,
			RankLevels = { 1, 3, 5, 7, 9 },
			Cooldown = { 8, 7, 6, 5, 4 },
			Cost = { 0, 0, 0, 0, 0 },
			Targeting = "Direction",
			Tags = {
				[Movement.Dash] = true,
			},
			Effects = {
				{
					Kind = "Dash",
					Distance = 10,
					Duration = 0.12,
				},
			},
		},

		Ability2 = {
			Id = "GrapplingHook",
			Name = "Grappling Hook",
			Description = "Fire a hook from Levi's ODM gear. Terrain pulls Levi to the point; enemy champions are briefly Rooted and Levi is pulled to them.",
			DamageType = "Physical",
			MaxRank = 5,
			RankLevels = { 1, 3, 5, 7, 9 },
			Cooldown = { 13, 12, 11, 10, 9 },
			Cost = { 0, 0, 0, 0, 0 },
			Targeting = "Direction",
			Tags = {
				[C.Ranged.Projectile] = true,
				[C.Ranged.SingleTarget] = true,
				[Movement.Dash] = true,
				[Movement.TerrainTraversal] = true,
				[D.Physical] = true,
				[CC.Root] = true,
			},
			Effects = {
				{
					Kind = "Custom",
					Range = 24,
					Run = function(ctx, services)
						performGrapple(ctx, services, ctx.Ability.Effects[1])
					end,
				},
			},
		},

		Ability3 = {
			Id = "SpinningSlash",
			Name = "Spinning Slash",
			Description = "Levi performs a 360-degree spinning slash that damages and launches enemies Airborne.",
			DamageType = "Physical",
			MaxRank = 5,
			RankLevels = { 1, 3, 5, 7, 9 },
			Cooldown = { 14, 13, 12, 11, 10 },
			Cost = { 0, 0, 0, 0, 0 },
			Targeting = "Self",
			Tags = {
				[C.Melee.AOE] = true,
				[D.Physical] = true,
				[CC.Knockup] = true,
				[CC.Airborne] = true,
			},
			Effects = {
				{
					Kind = "Custom",
					Radius = 7,
					Base = { 70, 105, 140, 175, 210 },
					Airborne = { 1.00, 1.05, 1.10, 1.15, 1.20 },
					Run = function(ctx, services)
						performSpinningSlash(ctx, services, ctx.Ability.Effects[1])
					end,
				},
			},
		},

		Ultimate = {
			Id = "CaptainsAssault",
			Name = "Captain's Assault",
			Description = "Enter a 15-second state that lets Levi instantly blink to nearby Airborne enemies, briefly Lock himself out, and continue slashing them. Critical Strikes during the state ignore 60% of the target's bonus Armor.",
			DamageType = "Physical",
			MaxRank = 3,
			RankLevels = { 6, 11, 16 },
			Cooldown = { 100, 85, 70 },
			Cost = { 0, 0, 0 },
			Targeting = "Self",
			Tags = {
				[Movement.Blink] = true,
				[C.Melee.AOE] = true,
				[D.Physical] = true,
				[CC.Knockup] = true,
				[CC.Airborne] = true,
				[Effects.TrueSight] = true,
				[Effects.Lockout] = true,
				[Damage.CriticalStrikeModifier] = true,
			},
			Effects = {
				{
					Kind = "Custom",
					Duration = 15,
					TriggerRange = 24,
					Radius = 7,
					Lockout = 0.75,
					Base = { 80, 120, 160 },
					Run = function(ctx, services)
						performUltimate(ctx, services, ctx.Ability.Effects[1])
					end,
				},
			},
		},
	},

	OnBasicAttack = function(ctx, rawPacket)
		local character = ctx.Character
		local now = workspace:GetServerTimeNow()
		local readyAt = character:GetAttribute("Levi_TwinBladesNext") or 0
		if now < readyAt then
			return
		end

		local services = ctx.Services
		local previousOnHit = rawPacket.OnHit

		rawPacket.OnHit = function(packet, attacker, target, result)
			if previousOnHit then
				previousOnHit(packet, attacker, target, result)
			end

			local currentReadyAt = character:GetAttribute("Levi_TwinBladesNext") or 0
			if workspace:GetServerTimeNow() < currentReadyAt then
				return
			end

			local attackDamage = services.Stats.Get(character, "AttackDamage")
			local baseBonus = attackDamage * 0.20
			local critMultiplier = result.Crit and math.max(services.Stats.Get(character, "CritDamage"), 1) or 1
			local primaryBonus = baseBonus * critMultiplier

			local primaryPacket = services.Damage.CreatePacket({
				Components = {
					{
						Type = "Physical",
						Amount = primaryBonus,
						CanCrit = false,
					},
				},
				Source = {
					Kind = "Ability",
					Slot = "Basic",
					AbilityId = "TwinBlades",
					DamageType = "Physical",
				},
				CanCrit = false,
				IsBasicAttack = false,
			})
			services.Damage.Deal(attacker, target, primaryPacket)

			local origin = target and target.Parent and target:GetPivot().Position
			if origin then
				local nearby = services.Damage.FindEnemies(character, function(pos, model)
					return model ~= target and (pos - origin).Magnitude <= 5
				end)

				for _, nearbyTarget in ipairs(nearby) do
					local amount = attackDamage * 1.20 * critMultiplier
					local packetNearby = services.Damage.CreatePacket({
						Components = {
							{
								Type = "Physical",
								Amount = amount,
								CanCrit = false,
							},
						},
						Source = {
							Kind = "Ability",
							Slot = "Basic",
							AbilityId = "TwinBlades",
							DamageType = "Physical",
						},
						CanCrit = false,
						IsBasicAttack = false,
					})
					services.Damage.Deal(attacker, nearbyTarget, packetNearby)
				end
			end

			local _, _, bonusAD = getStats(ctx, services)
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			local missingHealth = humanoid and math.max(0, humanoid.MaxHealth - humanoid.Health) or 0
			services.Damage.Heal(character, missingHealth * 0.03)
			character:SetAttribute("Levi_TwinBladesNext", workspace:GetServerTimeNow() + 5)
		end
	end,
}

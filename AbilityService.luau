-- ServerScriptService.Server.AbilityService
-- Drop-in replacement with:
--   * Beam effects
--   * Barrier effects
--   * rank-scaled status durations
--   * basic-ability cooldown refresh for Frieren's ultimate

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local CharacterRegistry = require(ReplicatedStorage.Shared.CharacterRegistry)
local PlayerState = require(script.Parent.PlayerState)
local StatService = require(script.Parent.StatService)
local StatusService = require(script.Parent.StatusService)
local DamageService = require(script.Parent.DamageService)
local VFX = require(script.Parent.VFX)
local Remotes = require(script.Parent.Remotes)

local AbilityService = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
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

-- ===== Shape tests (XZ plane with a vertical tolerance) =====================
local function verticalOk(a: Vector3, b: Vector3): boolean
	return math.abs(a.Y - b.Y) <= Config.VerticalTolerance
end

local function inCircle(center: Vector3, radius: number, pos: Vector3): boolean
	return verticalOk(center, pos) and flat(pos - center).Magnitude <= radius + Config.HitRadius
end

local function inCone(origin: Vector3, dir: Vector3, range: number, angle: number, pos: Vector3): boolean
	if not verticalOk(origin, pos) then
		return false
	end

	local offset = flat(pos - origin)
	local dist = offset.Magnitude
	if dist > range + Config.HitRadius then
		return false
	end
	if dist < 1 then
		return true
	end

	local ang = math.deg(math.acos(math.clamp(dir:Dot(offset.Unit), -1, 1)))
	local slack = math.deg(math.atan(Config.HitRadius / dist))
	return ang <= angle / 2 + slack
end

local function inLine(origin: Vector3, dir: Vector3, length: number, width: number, pos: Vector3): boolean
	if not verticalOk(origin, pos) then
		return false
	end

	local offset = flat(pos - origin)
	local along = offset:Dot(dir)
	if along < -Config.HitRadius or along > length + Config.HitRadius then
		return false
	end

	local lateral = (offset - dir * along).Magnitude
	return lateral <= width / 2 + Config.HitRadius
end

AbilityService.Shapes = {
	Circle = inCircle,
	Cone = inCone,
	Line = inLine,
}

-- ===== Hit application ======================================================
local function applyHit(ctx, effect, target: Model)
	if effect.Damage then
		local components = DamageService.BuildComponents(ctx.Character, effect.Damage, ctx.Rank)
		local packet = DamageService.CreatePacket({
			Components = components,
			Source = {
				Kind = "Ability",
				Slot = ctx.Slot,
				AbilityId = ctx.Ability.Id,
				DamageType = ctx.Ability.DamageType,
			},
			CanCrit = effect.CanCrit == true,
			IsBasicAttack = false,
		})

		DamageService.Deal(ctx.Character, target, packet)
	end

	for _, status in ipairs(effect.Statuses or {}) do
		local duration = Formulas.RankValue(status.Duration or 0, ctx.Rank) or 0
		local magnitude = Formulas.RankValue(status.Magnitude or 0, ctx.Rank) or 0
		StatusService.Apply(target, status.Name, duration, magnitude)

		-- Restraint: gold bands wrap the target for the length of the Root.
		if effect.Visual == "Restraint" and status.Name == "Root" then
			VFX.RestraintBind(target, duration, effect.Color or Color3.fromRGB(255, 214, 82))
		end
	end

	if effect.ExecuteBelowPercentMaxHealth then
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		local targetPlayer = game:GetService("Players"):GetPlayerFromCharacter(target)
		local championsOnly = effect.ExecuteChampionsOnly ~= false
		local isValidTarget = (not championsOnly) or targetPlayer ~= nil

		if humanoid
			and humanoid.Health > 0
			and isValidTarget
			and humanoid.Health <= humanoid.MaxHealth * effect.ExecuteBelowPercentMaxHealth
		then
			if DamageService.Execute then
				DamageService.Execute(ctx.Character, target)
			end
		end
	end
end

local projectiles = {}
local EffectHandlers = {}

-- ===== Area =================================================================
EffectHandlers.Area = function(ctx, effect)
	local shape = effect.Shape or "Circle"
	local color = effect.Color or Color3.new(1, 1, 1)
	local origin, dir = ctx.Origin, ctx.Direction
	local test

	if shape == "Circle" then
		local center = (effect.Center == "AimPoint")
			and Vector3.new(ctx.AimPoint.X, origin.Y, ctx.AimPoint.Z)
			or origin
		local radius = Formulas.RankValue(effect.Radius or 10, ctx.Rank)

		local indicatorPosition = Vector3.new(
			center.X,
			origin.Y - 2.7,
			center.Z
		)

		if effect.RangeIndicator then
			VFX.RangeRing(
				indicatorPosition,
				radius,
				color,
				effect.IndicatorDuration or 0.8,
				effect.IndicatorThickness or 0.8
			)
		else
			VFX.Circle(
				indicatorPosition,
				radius,
				color,
				0.5
			)
		end

		if effect.Visual == "HeightOfMagic" and ctx.Root then
			VFX.HeightOfMagic({
				Root = ctx.Root,
				Radius = radius,
				Color = effect.AuraColor or color,
				GroundY = ctx.GroundY or (origin.Y - 3),
			})
		end

		test = function(pos)
			return inCircle(center, radius, pos)
		end

	elseif shape == "Cone" then
		local range = Formulas.RankValue(effect.Range or 10, ctx.Rank)
		local angle = effect.Angle or 90
		VFX.Cone(origin, dir, range, angle, color, 0.3)
		test = function(pos)
			return inCone(origin, dir, range, angle, pos)
		end

	elseif shape == "Line" then
		local length = Formulas.RankValue(effect.Length or 20, ctx.Rank)
		local width = effect.Width or 4
		VFX.Line(origin, dir, length, width, color, 0.3)
		test = function(pos)
			return inLine(origin, dir, length, width, pos)
		end
	else
		warn("[AbilityService] unknown Area shape: " .. tostring(shape))
		return
	end

	for _, target in ipairs(DamageService.FindEnemies(ctx.Character, test)) do
		applyHit(ctx, effect, target)
	end
end

-- ===== Beam ================================================================
-- A Beam is an instantaneous line attack. Defensive Magic barriers are included
-- in the raycast set, so the beam stops when it hits a barrier or map geometry.
EffectHandlers.Beam = function(ctx, effect)
	local castTime = Formulas.RankValue(effect.CastTime or 0, ctx.Rank) or 0
	local selfSlow = effect.SelfSlow or 0

	if castTime > 0 and selfSlow > 0 then
		StatusService.Apply(ctx.Character, "Slow", castTime, selfSlow)
	end

	-- Zoltraak: Xerath-Q style telegraph + spell circle while charging.
	local charge
	if effect.Visual == "Zoltraak" and castTime > 0 then
		local previewLength = Formulas.RankValue(effect.Range or effect.Length or 40, ctx.Rank) or 40
		local previewRay = workspace:Raycast(ctx.Origin, ctx.Direction * previewLength, mapRaycastParams())
		if previewRay then
			previewLength = math.max(0.1, (previewRay.Position - ctx.Origin).Magnitude)
		end

		charge = VFX.ZoltraakCharge({
			Root = ctx.Root,
			Humanoid = ctx.Humanoid,
			Origin = ctx.Origin,
			Direction = ctx.Direction,
			GroundY = ctx.GroundY or (ctx.Origin.Y - 3),
			Length = previewLength,
			Width = effect.Width or 6,
			CastTime = castTime,
			Color = effect.Color or Color3.fromRGB(191, 145, 255),
		})
	end

	local function fire()
		if charge then
			charge.Stop()
		end

		if not ctx.Character.Parent then
			return
		end
		if ctx.Humanoid.Health <= 0 then
			return
		end

		local maxLength = Formulas.RankValue(effect.Range or effect.Length or 40, ctx.Rank) or 40
		local width = effect.Width or 6
		local length = maxLength

		local ray = workspace:Raycast(ctx.Origin, ctx.Direction * maxLength, mapRaycastParams())
		if ray then
			length = math.max(0, (ray.Position - ctx.Origin).Magnitude)
		end

		if length <= 0.1 then
			return
		end

		if effect.Visual == "Zoltraak" then
			VFX.ZoltraakBeam(ctx.Origin, ctx.Direction, length, width, effect.Color or Color3.fromRGB(191, 145, 255))
		else
			VFX.Line(ctx.Origin, ctx.Direction, length, width, effect.Color or Color3.new(1, 1, 1), 0.18)
		end

		for _, target in ipairs(DamageService.FindEnemies(ctx.Character, function(pos)
				return inLine(ctx.Origin, ctx.Direction, length, width, pos)
			end)) do
			applyHit(ctx, effect, target)
		end
	end

	if castTime > 0 then
		task.delay(castTime, fire)
	else
		fire()
	end
end

-- ===== Projectile ===========================================================
EffectHandlers.Projectile = function(ctx, effect)
	local startPos = ctx.Origin + Vector3.new(0, 1, 0) + ctx.Direction * 2
	local radius = effect.Radius or 1.5
	local part

	if effect.Visual == "Restraint" then
		part = VFX.RestraintRing(startPos, radius, effect.Color or Color3.new(1, 1, 1), ctx.Direction)
	elseif effect.ProjectileShape == "Ring" then
		part = VFX.ProjectileRing(startPos, radius, effect.Color or Color3.new(1, 1, 1), ctx.Direction)
	else
		part = VFX.Projectile(startPos, radius, effect.Color or Color3.new(1, 1, 1))
	end

	table.insert(projectiles, {
		Ctx = ctx,
		Effect = effect,
		Part = part,
		Position = startPos,
		Traveled = 0,
		PierceLeft = effect.Pierce or 0,
		Hit = {},
	})
end

-- ===== Barrier ==============================================================
EffectHandlers.Barrier = function(ctx, effect)
	local duration = Formulas.RankValue(effect.Duration or 2, ctx.Rank) or 2
	local groundPoint = Vector3.new(ctx.AimPoint.X, ctx.GroundY or (ctx.AimPoint.Y - 3), ctx.AimPoint.Z)
	VFX.Barrier(
		groundPoint,
		ctx.Direction,
		effect.Width or 14,
		effect.Height or 10,
		effect.Thickness or 2,
		effect.Color or Color3.fromRGB(190, 225, 255),
		duration,
		ctx.Player.UserId
	)
end

-- ===== Other existing effect kinds =========================================
EffectHandlers.Dash = function(ctx, effect)
	local dist = Formulas.RankValue(effect.Distance or 10, ctx.Rank)

	if effect.Mode == "Blink" and ctx.Ability.Targeting == "Point" then
		dist = math.min(
			dist,
			flat(ctx.AimPoint - ctx.Origin).Magnitude
		)
	end

	local hit = workspace:Raycast(
		ctx.Origin,
		ctx.Direction * (dist + 2),
		mapRaycastParams()
	)

	if hit then
		dist = math.max(
			0,
			(hit.Position - ctx.Origin).Magnitude - 3
		)
	end

	local destination =
		ctx.Origin + ctx.Direction * dist

	local root = ctx.Root
	local character = ctx.Character

	if not root or not character or not character.Parent then
		return
	end

	local direction = flat(ctx.Direction)

	if direction.Magnitude < 0.05 then
		direction = flat(root.CFrame.LookVector)
	end

	if direction.Magnitude < 0.05 then
		direction = Vector3.new(0, 0, -1)
	end

	direction = direction.Unit

	local targetCFrame = CFrame.lookAt(
		destination,
		destination + direction
	)

	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero

	character:PivotTo(targetCFrame)

	task.defer(function()
		if character.Parent and root.Parent then
			root.AssemblyLinearVelocity = Vector3.zero
			root.AssemblyAngularVelocity = Vector3.zero
			character:PivotTo(targetCFrame)
		end
	end)
end

EffectHandlers.Buff = function(ctx, effect)
	StatService.SetModifier(
		ctx.Player,
		"Buff_" .. (effect.Name or ctx.Ability.Id or ctx.Slot),
		effect.Stats or {},
		effect.Duration
	)
end

EffectHandlers.Heal = function(ctx, effect)
	local amount = Formulas.RankValue(effect.Amount or 0, ctx.Rank) or 0
	for _, scale in ipairs(effect.Scaling or {}) do
		amount += StatService.Get(ctx.Character, scale.Stat) * scale.Ratio
	end
	DamageService.Heal(ctx.Character, amount)
end

EffectHandlers.Custom = function(ctx, effect)
	if effect.Run then
		effect.Run(ctx, {
			Damage = DamageService,
			Status = StatusService,
			Stats = StatService,
			VFX = VFX,
			Ability = AbilityService,
			PlayerState = PlayerState,
		})
	end
end

local function runEffects(ctx, effects)
	for _, effect in ipairs(effects or {}) do
		local function run()
			if effect.Condition and not effect.Condition(ctx) then
				return
			end

			local handler = EffectHandlers[effect.Kind]
			if not handler then
				warn("[AbilityService] unknown effect kind: " .. tostring(effect.Kind))
				return
			end

			local ok, err = pcall(handler, ctx, effect)
			if not ok then
				warn("[AbilityService] effect error: " .. tostring(err))
			end
		end

		if effect.Delay and effect.Delay > 0 then
			task.delay(effect.Delay, run)
		else
			run()
		end
	end
end

-- ===== Projectile simulation ===============================================
local function stepProjectiles(dt: number)
	if #projectiles == 0 then
		return
	end

	local params = mapRaycastParams()

	for i = #projectiles, 1, -1 do
		local p = projectiles[i]
		local effect, ctx = p.Effect, p.Ctx
		local range = Formulas.RankValue(effect.Range or 40, ctx.Rank)
		local radius = effect.Radius or 1.5
		local step = math.min((effect.Speed or 60) * dt, range - p.Traveled)

		if step <= 0 then
			VFX.Discard(p.Part)
			table.remove(projectiles, i)
			continue
		end

		local newPos = p.Position + ctx.Direction * step
		local dead = false
		local wall = workspace:Raycast(p.Position, ctx.Direction * step, params)

		if wall then
			newPos = wall.Position
			dead = true
		end

		if not dead then
			local targets = DamageService.FindEnemies(ctx.Character, function(pos, model)
				return not p.Hit[model]
					and math.abs(pos.Y - newPos.Y) <= 6
					and flat(pos - newPos).Magnitude <= radius + Config.HitRadius * 0.5
			end)

			table.sort(targets, function(a, b)
				return (DamageService.GetRoot(a).Position - newPos).Magnitude < (DamageService.GetRoot(b).Position - newPos).Magnitude
			end)

			for _, target in ipairs(targets) do
				p.Hit[target] = true
				applyHit(ctx, effect, target)

				if p.PierceLeft <= 0 then
					dead = true
					break
				end

				p.PierceLeft -= 1
			end
		end

		p.Position = newPos
		p.Traveled += step
		p.Part.Position = newPos

		if p.Traveled >= range - 0.001 then
			dead = true
		end

		if dead then
			VFX.Discard(p.Part)
			table.remove(projectiles, i)
		end
	end
end

-- ===== Cooldowns ============================================================
function AbilityService.StartCooldown(player: Player, slot: string, ability, rank: number)
	local state = PlayerState.Get(player)
	if not state then
		return
	end

	local base = Formulas.RankValue(ability.Cooldown or 0, rank) or 0
	local haste = (slot == "Ultimate") and 0 or (state.Stats.Haste or 0)
	local cooldown = Formulas.CooldownWithHaste(base, haste)
	local expire = now() + cooldown

	state.Cooldowns[slot] = expire
	PlayerState.Publish(player, "CD_" .. slot, expire)
	PlayerState.Publish(player, "CDTotal_" .. slot, cooldown)
end
function AbilityService.ResetCooldown(player: Player, slot: string): boolean
	local state = PlayerState.Get(player)
	if not state then
		return false
	end

	state.Cooldowns[slot] = nil
	state.Recasts[slot] = nil

	PlayerState.Publish(player, "CD_" .. slot, 0)
	PlayerState.Publish(player, "CDTotal_" .. slot, 0)
	PlayerState.Publish(player, "Recast_" .. slot, 0)
	PlayerState.Publish(player, "RecastLeft_" .. slot, 0)

	return true
end

function AbilityService.IsOnCooldown(player: Player, slot: string): boolean
	local state = PlayerState.Get(player)
	return state ~= nil and (state.Cooldowns[slot] or 0) > now()
end

function AbilityService.ResetCooldowns(player: Player)
	local state = PlayerState.Get(player)
	if not state then
		return
	end

	state.Cooldowns = {}
	state.Recasts = {}

	for _, slot in ipairs(Config.AllSlots) do
		PlayerState.Publish(player, "CD_" .. slot, 0)
		PlayerState.Publish(player, "CDTotal_" .. slot, 0)
		PlayerState.Publish(player, "Recast_" .. slot, 0)
		PlayerState.Publish(player, "RecastLeft_" .. slot, 0)
	end
end

function AbilityService.ResetBasicAbilityCooldowns(player: Player)
	local state = PlayerState.Get(player)
	if not state then
		return
	end

	for _, slot in ipairs({ "Ability1", "Ability2", "Ability3" }) do
		state.Cooldowns[slot] = nil
		state.Recasts[slot] = nil
		PlayerState.Publish(player, "CD_" .. slot, 0)
		PlayerState.Publish(player, "CDTotal_" .. slot, 0)
		PlayerState.Publish(player, "Recast_" .. slot, 0)
		PlayerState.Publish(player, "RecastLeft_" .. slot, 0)
	end
end

local function endRecast(player: Player, slot: string)
	local state = PlayerState.Get(player)
	if not state or not state.Recasts[slot] then
		return
	end

	state.Recasts[slot] = nil
	PlayerState.Publish(player, "Recast_" .. slot, 0)
	PlayerState.Publish(player, "RecastLeft_" .. slot, 0)

	local def = CharacterRegistry.Get(state.CharacterId)
	local ability = def and def.Abilities[slot]
	if ability then
		AbilityService.StartCooldown(player, slot, ability, state.Ranks[slot] or 1)
	end
end

-- ===== Ranking up ==========================================================
function AbilityService.RankUp(player: Player, slot: string): boolean
	local state = PlayerState.Get(player)
	if not state or not state.Deployed or slot == "Summoner" or slot == "Basic" then
		return false
	end

	local def = CharacterRegistry.Get(state.CharacterId)
	local ability = def and def.Abilities[slot]
	if not ability or state.SkillPoints <= 0 then
		return false
	end

	local rank = state.Ranks[slot] or 0
	if rank >= ability.MaxRank then
		return false
	end

	local requiredLevel = ability.RankLevels[rank + 1] or math.huge
	if state.Level < requiredLevel then
		return false
	end

	if slot == "Ultimate" and state.Level < Config.UltimateUnlockLevel then
		return false
	end

	state.Ranks[slot] = rank + 1
	state.SkillPoints -= 1
	PlayerState.Publish(player, "Rank_" .. slot, state.Ranks[slot])
	PlayerState.Publish(player, "SkillPoints", state.SkillPoints)
	return true
end

-- ===== Casting =============================================================
function AbilityService.Cast(player: Player, slot: string, aimPoint: Vector3)
	local state = PlayerState.Get(player)
	if not state or not state.Deployed or not state.Alive then
		return
	end

	local character, humanoid, root = PlayerState.GetLiveCharacter(player)
	if not character or not humanoid or not root then
		return
	end

	local def = CharacterRegistry.Get(state.CharacterId)
	local ability = def and def.Abilities[slot]
	if not ability then
		return
	end

	local rank = state.Ranks[slot] or 0
	if rank < 1 then
		return
	end

	if slot == "Ultimate" and state.Level < Config.UltimateUnlockLevel then
		return
	end

	local t = now()
	local recast = state.Recasts[slot]
	if recast and recast.Expire <= t then
		endRecast(player, slot)
		recast = nil
	end

	local canCast, reason = StatusService.CanCast(character, ability)
	if not canCast then
		Remotes.Notify:FireClient(player, reason or "Can't cast right now")
		return
	end

	-- Optional per-ability gate (e.g. Johnny's ultimate needs a mount and a target). Runs
	-- before mana is spent or a cooldown starts, so a refused cast costs nothing.
	if ability.CanCast then
		local okGate, allowed, gateReason = pcall(ability.CanCast, {
			Player = player,
			Character = character,
			Humanoid = humanoid,
			Root = root,
			Slot = slot,
			Ability = ability,
			Rank = rank,
			AimPoint = aimPoint,
		}, {
			Damage = DamageService,
			Status = StatusService,
			Stats = StatService,
			VFX = VFX,
			Ability = AbilityService,
			PlayerState = PlayerState,
		})
		if not okGate then
			warn("[AbilityService] CanCast error: " .. tostring(allowed))
			return
		end
		if not allowed then
			Remotes.Notify:FireClient(player, gateReason or "Can't cast right now")
			return
		end
	end

	local effects
	if recast then
		effects = ability.Recast.Effects
		if (state.Cooldowns[slot] or 0) > t then
			return
		end
	else
		local cost = Formulas.RankValue(ability.Cost or 0, rank) or 0
		if cost > 0 and not StatService.SpendMana(player, cost) then
			Remotes.Notify:FireClient(player, "Not enough " .. (def.Resource and def.Resource.Name or "resource"))
			return
		end
		effects = ability.Effects
	end

	local origin = root.Position
	local direction = flat(aimPoint - origin)
	if direction.Magnitude < 0.05 then
		direction = flat(root.CFrame.LookVector)
	end
	if direction.Magnitude < 0.05 then
		direction = Vector3.new(0, 0, -1)
	end
	direction = direction.Unit

	local aim = aimPoint
	if ability.Targeting == "Point" then
		local range = ability.Range or 30
		local offset = flat(aimPoint - origin)
		if offset.Magnitude > range then
			aim = origin + direction * range
		end
	else
		aim = origin + direction * 10
	end

	-- Ground height under the caster, used to place telegraphs and walls on the floor.
	local groundY = origin.Y - 3
	local downRay = workspace:Raycast(origin, Vector3.new(0, -12, 0), mapRaycastParams())
	if downRay then
		groundY = downRay.Position.Y
	end

	local ctx = {
		GroundY = groundY,
		Player = player,
		Character = character,
		Humanoid = humanoid,
		Root = root,
		Slot = slot,
		Ability = ability,
		Rank = rank,
		Origin = origin,
		Direction = direction,
		AimPoint = aim,
		IsRecast = recast ~= nil,
	}

	if recast then
		recast.CastsLeft -= 1
		PlayerState.Publish(player, "RecastLeft_" .. slot, recast.CastsLeft)
		if recast.CastsLeft <= 0 then
			endRecast(player, slot)
		end
	elseif ability.Recast then
		local extra = math.max((ability.Recast.MaxCasts or 2) - 1, 1)
		state.Recasts[slot] = {
			CastsLeft = extra,
			Expire = t + (ability.Recast.Window or 3),
		}
		PlayerState.Publish(player, "Recast_" .. slot, state.Recasts[slot].Expire)
		PlayerState.Publish(player, "RecastLeft_" .. slot, extra)
	else
		AbilityService.StartCooldown(player, slot, ability, rank)
	end

	runEffects(ctx, effects)
end

function AbilityService.Step()
	local t = now()
	for player, state in pairs(PlayerState.All()) do
		for slot, recast in pairs(state.Recasts) do
			if recast.Expire <= t then
				endRecast(player, slot)
			end
		end
	end
end

function AbilityService.OnDeath(player: Player)
	local state = PlayerState.Get(player)
	if not state then
		return
	end

	for slot in pairs(state.Recasts) do
		endRecast(player, slot)
	end
end

function AbilityService.Init()
	RunService.Heartbeat:Connect(stepProjectiles)

	Remotes.CastAbility.OnServerEvent:Connect(function(player, slot, aimPoint)
		if typeof(slot) ~= "string" or typeof(aimPoint) ~= "Vector3" then
			return
		end
		if slot == "Basic" or not table.find(Config.AbilitySlots, slot) then
			return
		end
		if aimPoint.X ~= aimPoint.X or aimPoint.Y ~= aimPoint.Y or aimPoint.Z ~= aimPoint.Z then
			return
		end
		AbilityService.Cast(player, slot, aimPoint)
	end)

	Remotes.RankUpAbility.OnServerEvent:Connect(function(player, slot)
		if typeof(slot) == "string" then
			AbilityService.RankUp(player, slot)
		end
	end)
end

return AbilityService

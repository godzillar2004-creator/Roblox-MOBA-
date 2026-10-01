-- ServerScriptService.Server.CombatService
-- Drop-in replacement with optional ranged basic-attack projectiles.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Formulas = require(ReplicatedStorage.Shared.Formulas)
local CharacterRegistry = require(ReplicatedStorage.Shared.CharacterRegistry)
local PlayerState = require(script.Parent.PlayerState)
local StatService = require(script.Parent.StatService)
local StatusService = require(script.Parent.StatusService)
local DamageService = require(script.Parent.DamageService)
local AbilityService = require(script.Parent.AbilityService)
local VFX = require(script.Parent.VFX)
local Remotes = require(script.Parent.Remotes)

local CombatService = {}

local basicProjectiles = {}

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

local function setBlockVisual(character: Model, on: boolean)
	local highlight = character:FindFirstChild("BlockHighlight")
	if on and not highlight then
		highlight = Instance.new("Highlight")
		highlight.Name = "BlockHighlight"
		highlight.FillColor = Color3.fromRGB(90, 170, 255)
		highlight.OutlineColor = Color3.fromRGB(200, 230, 255)
		highlight.FillTransparency = 0.55
		highlight.Parent = character
	elseif not on and highlight then
		highlight:Destroy()
	end
end

function CombatService.SetBlocking(player: Player, wantBlock: boolean)
	local state = PlayerState.Get(player)
	if not state then
		return
	end

	local character = PlayerState.GetLiveCharacter(player)
	if not character or not state.Deployed then
		state.Blocking = false
		return
	end

	if wantBlock and not StatusService.CanAct(character) then
		wantBlock = false
	end

	if state.Blocking == wantBlock then
		return
	end

	state.Blocking = wantBlock
	character:SetAttribute("Blocking", wantBlock or nil)
	setBlockVisual(character, wantBlock)
	StatusService.RefreshMovement(character)
end

local function buildBasicPacket(def, character, player, target)
	local basic = def.BasicAttack
	local rawPacket = {
		Components = DamageService.BuildComponents(character, { Components = basic.Components }, 1),
		Source = {
			Kind = "BasicAttack",
			DamageType = basic.DamageType,
		},
		CanCrit = basic.CanCrit ~= false,
		IsBasicAttack = true,
	}

	if def.OnBasicAttack then
		local state = PlayerState.Get(player)

		def.OnBasicAttack({
			Player = player,
			Character = character,
			Target = target,

			-- Itadori needs the current rank of Cursed Reinforcement.
			Rank = state and (state.Ranks.Ability1 or 1) or 1,

			-- Server-side services available to character-specific combat hooks.
			Services = {
				Damage = DamageService,
				Stats = StatService,
				Status = StatusService,
				Ability = AbilityService,
				VFX = VFX,
				PlayerState = PlayerState,
			},
		}, rawPacket)
	end

	return DamageService.CreatePacket(rawPacket)
end

local function launchBasicProjectile(player: Player, character: Model, root: BasePart, def, basic, direction: Vector3)
	local radius = basic.ProjectileRadius or 1.5
	local startPos = root.Position + Vector3.new(0, 1.25, 0) + direction * 2
	local color = basic.Color or Color3.fromRGB(255, 255, 255)
	local part
	local customVisual = basic.Visual and VFX[basic.Visual]
	if customVisual then
		-- Character-specific projectile visual (e.g. Johnny's spinning nails).
		-- Falls back to the plain projectile if the visual module failed to load.
		part = customVisual(startPos, radius, color, direction, character)
	else
		part = VFX.Projectile(startPos, radius, color)
	end

	table.insert(basicProjectiles, {
		Player = player,
		Character = character,
		Def = def,
		Basic = basic,
		Part = part,
		Position = startPos,
		Direction = direction,
		Traveled = 0,
		Hit = {},
		PierceLeft = basic.Pierce or 0,
	})
end

local function stepBasicProjectiles(dt: number)
	if #basicProjectiles == 0 then
		return
	end

	local params = mapRaycastParams()

	for i = #basicProjectiles, 1, -1 do
		local p = basicProjectiles[i]
		local basic = p.Basic
		local range = basic.Range or 6
		local radius = basic.ProjectileRadius or 1.5
		local speed = basic.Speed or 180
		local step = math.min(speed * dt, range - p.Traveled)

		if step <= 0 then
			VFX.Discard(p.Part)
			table.remove(basicProjectiles, i)
			continue
		end

		local newPos = p.Position + p.Direction * step
		local blocked = false
		local wall = workspace:Raycast(p.Position, p.Direction * step, params)

		if wall then
			newPos = wall.Position
			blocked = true
		end

		local targets = {}
		if not blocked then
			for _, target in ipairs(DamageService.GetDamageables()) do
				if DamageService.IsEnemy(p.Character, target)
					and not target:GetAttribute("Untargetable")
					and not p.Hit[target]
				then
					local targetRoot = DamageService.GetRoot(target)
					if targetRoot
						and math.abs(targetRoot.Position.Y - newPos.Y) <= 6
						and flat(targetRoot.Position - newPos).Magnitude <= radius + Config.HitRadius * 0.5
					then
						table.insert(targets, target)
					end
				end
			end
		end

		table.sort(targets, function(a, b)
			return (DamageService.GetRoot(a).Position - newPos).Magnitude < (DamageService.GetRoot(b).Position - newPos).Magnitude
		end)

		for _, target in ipairs(targets) do
			p.Hit[target] = true
			DamageService.Deal(p.Character, target, buildBasicPacket(p.Def, p.Character, p.Player, target))

			if p.PierceLeft <= 0 then
				blocked = true
				break
			end

			p.PierceLeft -= 1
		end

		p.Position = newPos
		p.Traveled += step
		p.Part.Position = newPos

		if p.Traveled >= range - 0.001 or blocked then
			VFX.Discard(p.Part)
			table.remove(basicProjectiles, i)
		end
	end
end

function CombatService.BasicAttack(player: Player, aimPoint: Vector3)
	local state = PlayerState.Get(player)
	if not state or not state.Deployed or not state.Alive then
		return
	end

	local character, _, root = PlayerState.GetLiveCharacter(player)
	if not character or not root then
		return
	end

	if state.Blocking or not StatusService.CanAct(character) then
		return
	end

	local t = workspace:GetServerTimeNow()
	if t < state.NextBasicAttack - 0.05 then
		return
	end

	local def = CharacterRegistry.Get(state.CharacterId)
	local basic = def and def.BasicAttack
	if not basic then
		return
	end

	local interval = 1 / math.max(StatService.Get(character, "AttackSpeed"), 0.1)
	state.NextBasicAttack = t + interval
	PlayerState.Publish(player, "CD_Basic", t + interval)
	PlayerState.Publish(player, "CDTotal_Basic", interval)

	local origin = root.Position
	local direction = flat(aimPoint - origin)
	if direction.Magnitude < 0.05 then
		direction = flat(root.CFrame.LookVector)
	end
	if direction.Magnitude < 0.05 then
		direction = Vector3.new(0, 0, -1)
	end
	direction = direction.Unit

	if basic.Mode == "Projectile" then
		launchBasicProjectile(player, character, root, def, basic, direction)
		return
	end

	local range =
		(basic.Range or 6)
		+ (character:GetAttribute("Itadori_BasicAttackRangeBonus") or 0)

	local angle = basic.Angle or 120
	VFX.Cone(origin, direction, range, angle, basic.Color or Color3.fromRGB(255, 255, 255), 0.15)

	local targets = DamageService.FindEnemies(character, function(pos)
		return AbilityService.Shapes.Cone(origin, direction, range, angle, pos)
	end)

	table.sort(targets, function(a, b)
		return (DamageService.GetRoot(a).Position - origin).Magnitude < (DamageService.GetRoot(b).Position - origin).Magnitude
	end)

	local maxTargets = basic.MaxTargets or 1
	for i = 1, math.min(maxTargets, #targets) do
		DamageService.Deal(character, targets[i], buildBasicPacket(def, character, player, targets[i]))
	end
end

function CombatService.Init()
	RunService.Heartbeat:Connect(stepBasicProjectiles)

	Remotes.BasicAttack.OnServerEvent:Connect(function(player, aimPoint)
		if typeof(aimPoint) == "Vector3"
			and aimPoint.X == aimPoint.X
			and aimPoint.Z == aimPoint.Z
		then
			CombatService.BasicAttack(player, aimPoint)
		end
	end)

	Remotes.SetBlocking.OnServerEvent:Connect(function(player, wantBlock)
		if typeof(wantBlock) == "boolean" then
			CombatService.SetBlocking(player, wantBlock)
		end
	end)
end

return CombatService

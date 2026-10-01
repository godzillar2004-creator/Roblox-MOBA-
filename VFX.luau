-- ServerScriptService.Server.VFX
-- Placeholder VFX (Circle / Cone / Line / Projectile) + Frieren's ability visuals:
--   * Zoltraak  : Xerath-Q style telegraph, spell circle while charging, big beam
--   * Restraint : Neeko-E style glowing ring projectile + binding rings on the rooted target
--   * Barrier   : wall of semi-transparent hexagons (Defensive Magic)
-- Every effect part is anchored/unanchored-but-welded, CanQuery = false (except the barrier),
-- so none of it interferes with ability raycasts.

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local VFX = {}

local TEX = {
	SpellCircle = "rbxassetid://127136365842392",
	HexTile = "rbxassetid://77861816260866",
	Spark = "rbxasset://textures/particles/sparkles_main.dds",
}

local folder = workspace:FindFirstChild("Effects")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Effects"
	folder.Parent = workspace
end

-- ============================================================================
-- Helpers
-- ============================================================================

local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

local function tween(inst: Instance, seconds: number, props, style: Enum.EasingStyle?, dir: Enum.EasingDirection?)
	local t = TweenService:Create(
		inst,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out),
		props
	)
	t:Play()
	return t
end

local function seq(a: number, b: number): NumberSequence
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, b) })
end

-- Generic neon effect part: never collides and is never hit by raycasts.
local function fxPart(size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?, transparency: number?)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = transparency or 0
	part.Size = size
	part.CFrame = cframe
	if shape then
		part.Shape = shape
	end
	return part
end

local function makePart(size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?)
	local part = fxPart(size, cframe, color, shape, 0.45)
	part.Parent = folder
	return part
end

local function fade(part: BasePart, duration: number)
	TweenService:Create(part, TweenInfo.new(duration), { Transparency = 1 }):Play()
	Debris:AddItem(part, duration + 0.1)
end

-- Fades every part under `root` (and the root) and stops emitters/trails.
local function fadeAll(root: Instance, duration: number)
	local list = root:GetDescendants()
	table.insert(list, root)
	for _, d in ipairs(list) do
		if d:IsA("BasePart") then
			if d.Transparency < 1 then
				tween(d, duration, { Transparency = 1 })
			end
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") then
			d.Enabled = false
		end
	end
end

local function emitterSparks(color: Color3, rate: number, lifetime: NumberRange, speed: NumberRange, size: number)
	local e = Instance.new("ParticleEmitter")
	e.Texture = TEX.Spark
	e.Color = ColorSequence.new(lighten(color, 0.6), color)
	e.LightEmission = 1
	e.Rate = rate
	e.Lifetime = lifetime
	e.Speed = speed
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = seq(size, 0)
	e.Transparency = seq(0.05, 1)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-120, 120)
	e.Drag = 2
	return e
end

-- Quick spark burst + expanding flash ring at a position.
function VFX.Burst(position: Vector3, color: Color3, scale: number?)
	scale = scale or 1

	local holder = fxPart(Vector3.one * 0.2, CFrame.new(position), color, nil, 1)
	holder.Parent = folder

	local e = emitterSparks(color, 0, NumberRange.new(0.3, 0.6), NumberRange.new(16 * scale, 34 * scale), 1.6 * scale)
	e.Parent = holder
	e:Emit(26)

	local flash = fxPart(Vector3.one * 1, CFrame.new(position), lighten(color, 0.35), Enum.PartType.Ball, 0.35)
	flash.Parent = folder
	tween(flash, 0.3, { Size = Vector3.one * 10 * scale, Transparency = 1 })

	Debris:AddItem(flash, 0.4)
	Debris:AddItem(holder, 1)
end

-- A ring of overlapping balls (a "bead torus"). The ring lies in the XY plane of `root`,
-- so its axis is root's LookVector. Beads are welded to `root`.
local function addBeads(root: BasePart, radius: number, tube: number, count: number, color: Color3, transparency: number)
	for i = 1, count do
		local ang = ((i - 1) / count) * math.pi * 2
		local bead = fxPart(
			Vector3.one * tube * 2,
			root.CFrame * CFrame.new(math.cos(ang) * radius, math.sin(ang) * radius, 0),
			color,
			Enum.PartType.Ball,
			transparency
		)
		bead.Parent = root

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = bead
		weld.Parent = bead

		bead.Anchored = false
	end
end

local function newRingRoot(cframe: CFrame): BasePart
	local root = fxPart(Vector3.one * 0.2, cframe, Color3.new(1, 1, 1), nil, 1)
	root.Parent = folder
	return root
end

-- ============================================================================
-- Existing placeholder effects
-- ============================================================================

function VFX.Circle(position: Vector3, radius: number, color: Color3, duration: number?)
	local part = makePart(
		Vector3.new(0.3, radius * 2, radius * 2),
		CFrame.new(position.X, position.Y + 0.2, position.Z) * CFrame.Angles(0, 0, math.rad(90)),
		color,
		Enum.PartType.Cylinder
	)
	fade(part, duration or 0.45)
end

function VFX.Cone(origin: Vector3, direction: Vector3, range: number, angleDeg: number, color: Color3, duration: number?)
	local half = math.rad(math.clamp(angleDeg, 10, 170) / 2)
	local width = math.min(2 * range * math.sin(half), range * 2)
	local center = origin + direction * (range * 0.5)
	local part = makePart(
		Vector3.new(width, 0.3, range),
		CFrame.lookAt(
			Vector3.new(center.X, origin.Y - 2.5, center.Z),
			Vector3.new(center.X, origin.Y - 2.5, center.Z) + direction
		),
		color
	)
	fade(part, duration or 0.3)
end

function VFX.Line(origin: Vector3, direction: Vector3, length: number, width: number, color: Color3, duration: number?)
	local center = origin + direction * (length * 0.5)
	local part = makePart(
		Vector3.new(width, 0.3, length),
		CFrame.lookAt(
			Vector3.new(center.X, origin.Y - 2.5, center.Z),
			Vector3.new(center.X, origin.Y - 2.5, center.Z) + direction
		),
		color
	)
	fade(part, duration or 0.3)
end

function VFX.Projectile(position: Vector3, radius: number, color: Color3): BasePart
	return makePart(
		Vector3.new(radius * 2, radius * 2, radius * 2),
		CFrame.new(position),
		color,
		Enum.PartType.Ball
	)
end

function VFX.ProjectileRing(position: Vector3, radius: number, color: Color3, direction: Vector3): BasePart
	local dir = direction.Magnitude > 0.001 and direction.Unit or Vector3.new(0, 0, -1)
	local part = makePart(
		Vector3.new(0.6, radius * 2, radius * 2),
		CFrame.lookAt(position, position + dir) * CFrame.Angles(0, math.rad(90), 0),
		color,
		Enum.PartType.Cylinder
	)
	return part
end

-- Used by the ultimate's range indicator. (Previously nested inside Discard, so it only
-- existed after a projectile had been discarded.)
function VFX.RangeRing(position: Vector3, radius: number, color: Color3, duration: number?, thickness: number?)
	local segments = 40
	local ringThickness = thickness or 0.6
	local ringDuration = duration or 0.8

	-- Slight overlap between segments prevents visible gaps.
	local segmentLength = ((2 * math.pi * radius) / segments) * 1.12

	for i = 1, segments do
		local angle = ((i - 1) / segments) * (2 * math.pi)

		local point = Vector3.new(
			position.X + math.cos(angle) * radius,
			position.Y + 0.08,
			position.Z + math.sin(angle) * radius
		)

		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))

		local segment = makePart(
			Vector3.new(ringThickness, 0.12, segmentLength),
			CFrame.lookAt(point, point + tangent),
			color
		)

		fade(segment, ringDuration)
	end
end

function VFX.Discard(part: BasePart, duration: number?)
	if not part or not part.Parent then
		return
	end

	local d = duration or 0.15

	-- Composite effects (e.g. the Restraint ring) fade every child and pop on the way out.
	if part:GetAttribute("BurstOnDiscard") then
		VFX.Burst(part.Position, part.Color, part:GetAttribute("BurstScale") or 1)
		fadeAll(part, d)
		Debris:AddItem(part, d + 0.6)
		return
	end

	fade(part, d)
end

-- ============================================================================
-- ZOLTRAAK  (Ability 1)
-- ============================================================================

-- params: Root, Humanoid, Origin, Direction, GroundY, Length, Width, CastTime, Color
-- Returns { Stop = function } - call Stop() when the beam fires (or it stops itself).
function VFX.ZoltraakCharge(params)
	local root: BasePart = params.Root
	local humanoid: Humanoid = params.Humanoid
	local dir: Vector3 = params.Direction
	local length: number = params.Length
	local width: number = params.Width
	local castTime: number = math.max(params.CastTime, 0.1)
	local color: Color3 = params.Color
	local bright = lighten(color, 0.55)

	local container = Instance.new("Folder")
	container.Name = "ZoltraakCharge"
	container.Parent = folder

	-- ----- Telegraph (Xerath Q style: outlined lane that fills forward) -----
	local y = params.GroundY + 0.06
	local start = Vector3.new(params.Origin.X, y, params.Origin.Z)

	local function laneCF(alongCenter: number): CFrame
		local p = start + dir * alongCenter
		return CFrame.lookAt(p, p + dir)
	end

	local innerWidth = math.max(width - 1.2, 1)
	local fill = fxPart(Vector3.new(innerWidth, 0.05, 0.1), laneCF(0.05), color, nil, 0.75)
	fill.Parent = container
	tween(fill, castTime, { Size = Vector3.new(innerWidth, 0.05, length), CFrame = laneCF(length / 2), Transparency = 0.4 }, Enum.EasingStyle.Linear)

	local lane = laneCF(length / 2)
	local edgeOffset = width / 2 - 0.2
	local outline = {}

	for _, side in ipairs({ -1, 1 }) do
		local edge = fxPart(Vector3.new(0.4, 0.08, length), lane * CFrame.new(side * edgeOffset, 0, 0), bright, nil, 1)
		edge.Parent = container
		table.insert(outline, edge)
	end

	local startCap = fxPart(Vector3.new(width, 0.08, 0.4), laneCF(0) , bright, nil, 1)
	startCap.Parent = container
	table.insert(outline, startCap)

	local endCap = fxPart(Vector3.new(width, 0.08, 0.4), laneCF(length), bright, nil, 1)
	endCap.Parent = container
	table.insert(outline, endCap)

	-- Arrowhead chevron past the end of the lane.
	local tipPoint = start + dir * (length + width * 0.45)
	local right = dir:Cross(Vector3.yAxis).Unit
	local chevronLen = width * 0.75
	for _, side in ipairs({ -1, 1 }) do
		local back = (-dir * 0.707) + (right * side * 0.707)
		local center = tipPoint + back * (chevronLen / 2)
		center = Vector3.new(center.X, y, center.Z)
		local strip = fxPart(Vector3.new(0.45, 0.08, chevronLen), CFrame.lookAt(center, center + back), bright, nil, 1)
		strip.Parent = container
		table.insert(outline, strip)
	end

	for _, p in ipairs(outline) do
		tween(p, 0.25, { Transparency = 0.12 })
	end

	-- ----- Spell circle in front of Frieren -----
	local outerD, innerD = 11, 6.5
	local forward = 7.5
	local lift = 2

	local function makeCircle(diameter: number, tint: Color3): BasePart
		local part = fxPart(Vector3.new(diameter, diameter, 0.05), CFrame.new(), tint, nil, 1)
		part.Material = Enum.Material.SmoothPlastic
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
			local gui = Instance.new("SurfaceGui")
			gui.Face = face
			gui.LightInfluence = 0
			gui.Brightness = 2
			gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
			gui.CanvasSize = Vector2.new(512, 512)
			gui.Parent = part

			local img = Instance.new("ImageLabel")
			img.BackgroundTransparency = 1
			img.Size = UDim2.fromScale(1, 1)
			img.Image = TEX.SpellCircle
			img.ImageColor3 = tint
			img.ImageTransparency = 1
			img.Parent = gui
			tween(img, 0.2, { ImageTransparency = 0.05 })
		end
		part.Parent = container
		return part
	end

	local outer = makeCircle(outerD, bright)
	local inner = makeCircle(innerD, lighten(color, 0.85))

	local sparks = emitterSparks(color, 28, NumberRange.new(0.5, 0.9), NumberRange.new(1, 4), 0.9)
	sparks.Parent = outer

	local t0 = os.clock()
	local stopped = false
	local conn

	local function stop()
		if stopped then
			return
		end
		stopped = true
		if conn then
			conn:Disconnect()
		end
		fadeAll(container, 0.15)
		Debris:AddItem(container, 0.3)
	end

	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - t0

		if t >= castTime + 0.05 or not root.Parent or humanoid.Health <= 0 then
			stop()
			return
		end

		local pop = math.min(t / 0.25, 1)
		local scale = 1 - (1 - pop) ^ 3 -- ease-out

		local pos = root.Position + dir * forward + Vector3.new(0, lift, 0)
		local cf = CFrame.lookAt(pos, pos + dir)

		outer.Size = Vector3.new(outerD * scale, outerD * scale, 0.05)
		inner.Size = Vector3.new(innerD * scale, innerD * scale, 0.05)
		outer.CFrame = cf * CFrame.Angles(0, 0, t * 0.9)
		inner.CFrame = cf * CFrame.Angles(0, 0, -t * 1.5)
	end)

	Debris:AddItem(container, castTime + 1) -- safety net

	return { Stop = stop }
end

-- Fires the beam itself. Instant line attack, purely visual (hit detection is in AbilityService).
function VFX.ZoltraakBeam(origin: Vector3, direction: Vector3, length: number, width: number, color: Color3)
	local bright = lighten(color, 0.6)
	local height = 0.5
	local startPos = origin + direction * 3 + Vector3.new(0, height, 0)
	local len = math.max(length - 3, 1)
	local center = startPos + direction * (len / 2)
	-- Cylinder axis is local X, so rotate 90 degrees about Y to lay it along `direction`.
	local cf = CFrame.lookAt(center, center + direction) * CFrame.Angles(0, math.rad(90), 0)

	local coreD = width * 0.2
	local outerD = width * 0.45

	local core = fxPart(Vector3.new(len, 0.1, 0.1), cf, lighten(color, 0.9), Enum.PartType.Cylinder, 0)
	local shell = fxPart(Vector3.new(len, 0.1, 0.1), cf, color, Enum.PartType.Cylinder, 0.45)
	core.Parent = folder
	shell.Parent = folder

	tween(core, 0.08, { Size = Vector3.new(len, coreD, coreD) }, Enum.EasingStyle.Back)
	tween(shell, 0.1, { Size = Vector3.new(len, outerD, outerD) }, Enum.EasingStyle.Back)

	task.delay(0.22, function()
		tween(core, 0.3, { Size = Vector3.new(len, 0.1, 0.1), Transparency = 1 })
		tween(shell, 0.35, { Size = Vector3.new(len, 0.1, 0.1), Transparency = 1 })
	end)

	Debris:AddItem(core, 0.8)
	Debris:AddItem(shell, 0.8)

	-- Sparks through the beam volume.
	local volume = fxPart(Vector3.new(len, outerD, outerD), cf, color, nil, 1)
	volume.Parent = folder
	local e = emitterSparks(color, 0, NumberRange.new(0.5, 0.9), NumberRange.new(2, 8), 2)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.InAndOut
	e.Parent = volume
	e:Emit(math.clamp(math.floor(len / 3), 60, 400))
	Debris:AddItem(volume, 1.2)

	-- Ground scorch + muzzle flash.
	VFX.Line(origin, direction, length, width, color, 0.35)

	local muzzle = fxPart(Vector3.one * 2, CFrame.new(startPos), bright, Enum.PartType.Ball, 0.2)
	muzzle.Parent = folder
	tween(muzzle, 0.3, { Size = Vector3.one * width * 1.1, Transparency = 1 })
	Debris:AddItem(muzzle, 0.4)

	VFX.Burst(startPos + direction * 2, color, 1.3)
end

-- ============================================================================
-- RESTRAINT  (Ability 2)
-- ============================================================================

-- Glowing donut that flies along `direction` (Neeko E style). Returns the root part,
-- which AbilityService moves every step; all visuals are welded to it.
function VFX.RestraintRing(position: Vector3, radius: number, color: Color3, direction: Vector3): BasePart
	local dir = direction.Magnitude > 0.001 and direction.Unit or Vector3.new(0, 0, -1)
	local cf = CFrame.lookAt(position, position + dir)

	local major = radius * 0.78
	local tube = radius * 0.24

	local root = newRingRoot(cf)
	root.Name = "RestraintRing"
	root.Color = color
	root:SetAttribute("BurstOnDiscard", true)
	root:SetAttribute("BurstScale", 0.9)

	addBeads(root, major, tube, 22, color, 0.05) -- solid gold tube
	addBeads(root, major, tube * 1.8, 22, lighten(color, 0.4), 0.75) -- soft glow shell
	addBeads(root, major * 0.9, tube * 0.45, 22, Color3.new(1, 1, 1), 0.2) -- hot inner highlight

	-- Sparks shed from four points around the ring.
	for i = 0, 3 do
		local ang = (i / 4) * math.pi * 2
		local att = Instance.new("Attachment")
		att.Position = Vector3.new(math.cos(ang) * major, math.sin(ang) * major, 0)
		att.Parent = root
		local e = emitterSparks(color, 14, NumberRange.new(0.3, 0.55), NumberRange.new(0, 2), 1.1)
		e.Parent = att
	end

	-- Faint wake behind the ring.
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, major, 0)
	top.Parent = root
	local bottom = Instance.new("Attachment")
	bottom.Position = Vector3.new(0, -major, 0)
	bottom.Parent = root

	local trail = Instance.new("Trail")
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Lifetime = 0.25
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Color = ColorSequence.new(lighten(color, 0.3), color)
	trail.Transparency = seq(0.55, 1)
	trail.Parent = root

	root.Anchored = true -- the root is moved by AbilityService; beads follow via welds
	return root
end

-- Gold bands snap around a rooted target and hold for `duration`.
function VFX.RestraintBind(target: Model, duration: number, color: Color3)
	local hrp = target:FindFirstChild("HumanoidRootPart") or target.PrimaryPart
	if not hrp or duration <= 0 then
		return
	end

	local basePos = hrp.Position
	VFX.Burst(basePos, color, 0.8)

	local heights = { -2.3, -0.3, 1.7 }
	local radii = { 2.6, 2.2, 2.6 }
	local roots = {}

	for i, h in ipairs(heights) do
		-- Rotate the ring plane (XY) to lie horizontally (XZ).
		local cf = CFrame.new(basePos + Vector3.new(0, h, 0)) * CFrame.Angles(math.rad(90), 0, 0)
		local root = newRingRoot(cf)
		root.Name = "RestraintBand"
		addBeads(root, radii[i], 0.28, 20, color, 0.15)
		addBeads(root, radii[i], 0.55, 20, lighten(color, 0.4), 0.8)

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = hrp
		weld.Part1 = root
		weld.Parent = root
		root.Anchored = false

		table.insert(roots, root)
	end

	-- Ground glow under the target.
	local groundCF = CFrame.new(basePos + Vector3.new(0, -2.85, 0)) * CFrame.Angles(0, 0, math.rad(90))
	local glow = fxPart(Vector3.new(0.12, 7, 7), groundCF, color, Enum.PartType.Cylinder, 1)
	glow.Parent = folder
	local gw = Instance.new("WeldConstraint")
	gw.Part0 = hrp
	gw.Part1 = glow
	gw.Parent = glow
	glow.Anchored = false
	tween(glow, 0.2, { Transparency = 0.55 })
	table.insert(roots, glow)

	task.delay(math.max(duration - 0.3, 0.05), function()
		for _, r in ipairs(roots) do
			if r.Parent then
				fadeAll(r, 0.3)
			end
		end
	end)

	for _, r in ipairs(roots) do
		Debris:AddItem(r, duration + 0.1)
	end
end

-- ============================================================================
-- DEFENSIVE MAGIC  (Ability 3): wall of semi-transparent hexagons
-- ============================================================================

-- `position` should be the ground point where the wall stands.
function VFX.Barrier(position: Vector3, direction: Vector3, width: number, height: number, thickness: number, color: Color3, duration: number, ownerUserId: number?)
	local dir = direction.Magnitude > 0.001 and direction.Unit or Vector3.new(0, 0, -1)
	local center = Vector3.new(position.X, position.Y + (height * 0.5), position.Z)

	-- Invisible collision/query part: projectiles and beams still stop on this.
	local part = Instance.new("Part")
	part.Name = "DefensiveMagicBarrier"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = true
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(width, height, thickness)
	part.CFrame = CFrame.lookAt(center, center + dir)
	part:SetAttribute("AbilityBarrier", true)
	part:SetAttribute("BarrierOwnerUserId", ownerUserId or 0)
	part:SetAttribute("BlocksProjectile", true)
	part:SetAttribute("BlocksBeam", true)
	part.Parent = folder

	local PPS = 40 -- pixels per stud on the wall faces
	local canvasW, canvasH = width * PPS, height * PPS
	local hexLight = color:Lerp(Color3.fromRGB(70, 150, 255), 0.45)
	local faded = {}

	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = PPS
		gui.Parent = part

		-- Mask rises from the ground to reveal the wall.
		local mask = Instance.new("Frame")
		mask.BackgroundTransparency = 1
		mask.ClipsDescendants = true
		mask.AnchorPoint = Vector2.new(0.5, 1)
		mask.Position = UDim2.fromScale(0.5, 1)
		mask.Size = UDim2.fromScale(1, 0)
		mask.Parent = gui

		local canvas = Instance.new("Frame")
		canvas.BackgroundTransparency = 1
		canvas.AnchorPoint = Vector2.new(0.5, 1)
		canvas.Position = UDim2.fromScale(0.5, 1)
		canvas.Size = UDim2.fromOffset(canvasW, canvasH)
		canvas.Parent = mask

		local glass = Instance.new("Frame")
		glass.BackgroundColor3 = Color3.fromRGB(50, 110, 235)
		glass.BackgroundTransparency = 0.72
		glass.BorderSizePixel = 0
		glass.Size = UDim2.fromScale(1, 1)
		glass.Parent = canvas

		local hex = Instance.new("ImageLabel")
		hex.BackgroundTransparency = 1
		hex.Size = UDim2.fromScale(1, 1)
		hex.Image = TEX.HexTile
		hex.ImageColor3 = hexLight
		hex.ImageTransparency = 0.2
		hex.ScaleType = Enum.ScaleType.Tile
		hex.TileSize = UDim2.fromOffset(180, 104) -- tile is 3R x sqrt(3)R, R = 1.5 studs
		hex.Parent = canvas

		local border = Instance.new("Frame")
		border.BackgroundTransparency = 1
		border.Size = UDim2.fromScale(1, 1)
		border.Parent = canvas
		local stroke = Instance.new("UIStroke")
		stroke.Color = hexLight
		stroke.Thickness = 4
		stroke.Transparency = 0.1
		stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
		stroke.Parent = border

		tween(mask, 0.3, { Size = UDim2.fromScale(1, 1) })

		table.insert(faded, { Instance = glass, Prop = "BackgroundTransparency" })
		table.insert(faded, { Instance = hex, Prop = "ImageTransparency" })
		table.insert(faded, { Instance = stroke, Prop = "Transparency" })
	end

	-- Drifting motes across the wall.
	local motes = emitterSparks(hexLight, 10, NumberRange.new(0.8, 1.4), NumberRange.new(0, 1.5), 0.8)
	motes.Shape = Enum.ParticleEmitterShape.Box
	motes.ShapeInOut = Enum.ParticleEmitterShapeInOut.InAndOut
	motes.Parent = part

	-- Glowing base line where the wall meets the ground.
	local base = fxPart(
		Vector3.new(width, 0.15, thickness + 0.6),
		CFrame.lookAt(Vector3.new(position.X, position.Y + 0.08, position.Z), Vector3.new(position.X, position.Y + 0.08, position.Z) + dir),
		color,
		nil,
		0.4
	)
	base.Parent = folder

	task.delay(math.max(duration - 0.35, 0.1), function()
		motes.Enabled = false
		for _, item in ipairs(faded) do
			if item.Instance.Parent then
				tween(item.Instance, 0.3, { [item.Prop] = 1 })
			end
		end
		tween(base, 0.3, { Transparency = 1 })
	end)

	Debris:AddItem(part, duration)
	Debris:AddItem(base, duration)
	return part
end

-- ============================================================================
-- HEIGHT OF MAGIC  (Ultimate): mana aura around Frieren that pulses out to the ult radius
-- ============================================================================

-- One expanding ground ring (hollow outline with a faint fill) that grows to `radius`.
local function pulseRing(center: Vector3, y: number, radius: number, color: Color3, delay: number, duration: number)
	task.delay(delay, function()
		local startD = 6
		local part = fxPart(Vector3.new(startD, 0.1, startD), CFrame.new(center.X, y, center.Z), color, nil, 1)
		part.Material = Enum.Material.SmoothPlastic

		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.LightInfluence = 0
		gui.Brightness = 2
		gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		gui.CanvasSize = Vector2.new(512, 512)
		gui.Parent = part

		local disc = Instance.new("Frame")
		disc.Size = UDim2.fromScale(1, 1)
		disc.BackgroundColor3 = color
		disc.BackgroundTransparency = 0.85
		disc.BorderSizePixel = 0
		disc.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = disc

		local stroke = Instance.new("UIStroke")
		stroke.Color = lighten(color, 0.5)
		stroke.Thickness = 8
		stroke.Parent = disc

		part.Parent = folder

		tween(part, duration, { Size = Vector3.new(radius * 2, 0.1, radius * 2) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		tween(disc, duration, { BackgroundTransparency = 1 }, Enum.EasingStyle.Linear)
		tween(stroke, duration, { Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Debris:AddItem(part, duration + 0.1)
	end)
end

-- params: Root, Radius, Color, GroundY
function VFX.HeightOfMagic(params)
	local root: BasePart = params.Root
	local radius: number = params.Radius
	local color: Color3 = params.Color
	local y = params.GroundY + 0.12
	local bright = lighten(color, 0.5)
	local center = root.Position
	-- Aura parts scale with the ult radius (full size at 40+ studs, smaller below that).
	local s = math.clamp(radius / 40, 0.3, 1)
	for i = 0, 3 do
		pulseRing(center, y, radius, color, i * 0.14, 0.9 + i * 0.1)
	end

	-- Aura hugging Frieren: a glowing column and a pulse of light.
	local function follow(part: BasePart)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = part
		weld.Parent = part
		part.Anchored = false
	end

	local column = fxPart(Vector3.new(16 * s, 5 * s, 5 * s), CFrame.new(center) * CFrame.Angles(0, 0, math.rad(90)), color, Enum.PartType.Cylinder, 0.55)
	column.Parent = folder
	follow(column)
	tween(column, 1.2, { Size = Vector3.new(24 * s, 9 * s, 9 * s), Transparency = 1 })

	local orb = fxPart(Vector3.one * 5 * s, CFrame.new(center), bright, Enum.PartType.Ball, 0.35)
	orb.Parent = folder
	follow(orb)
	tween(orb, 0.7, { Size = Vector3.one * 16 * s, Transparency = 1 })

	Debris:AddItem(column, 1.4)
	Debris:AddItem(orb, 1.0)

	-- Mana motes rising off her while the waves expand.
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, -2.5, 0)
	att.Parent = root
	local motes = emitterSparks(color, 80, NumberRange.new(0.8, 1.3), NumberRange.new(6, 14), 1.4)
	motes.SpreadAngle = Vector2.new(30, 30)
	motes.Parent = att
	task.delay(1.2, function()
		motes.Enabled = false
	end)
	Debris:AddItem(att, 2.5)

	VFX.Burst(center - Vector3.new(0, 2.5, 0), color, 2.2 * s)
end

-- ============================================================================
-- ITADORI
--   Ability 1: blue-fire hand, enemies hit are marked with blue fire, Black Flash
--   Ability 2: blood sprayed through the cone
--   Ability 3: dust on grab + small black rectangles with white outlines (slashes)
--   Ultimate : blue fire over the whole body, one big black/white-outlined dismantle
--
-- Particle effects are cloned from ServerStorage.VFXTemplates, which are copies of the
-- reference effects on the map:
--     ItadoriBlueFlame  <- Workspace."Flame vfx"      (recolored from orange to blue)
--     ItadoriBlackFlash <- Workspace."Black Flash VFX"
--     ItadoriBlood      <- Workspace."Blood-01"
-- NOTE: ParticleEmitter:Emit() called from a server Script does not replicate to players,
-- so one-shot bursts below toggle Enabled for a short window instead.
-- ============================================================================

local rng = Random.new()

local ITA = {
	Blue = Color3.fromRGB(45, 150, 255),
	BlueCore = Color3.fromRGB(190, 235, 255),
	Red = Color3.fromRGB(225, 20, 35),
	Black = Color3.fromRGB(8, 8, 10),
	White = Color3.new(1, 1, 1),
	Dust = Color3.fromRGB(205, 205, 210),
}

local function getTemplate(name: string): Instance?
	local root = game:GetService("ServerStorage"):FindFirstChild("VFXTemplates")
	return root and root:FindFirstChild(name)
end

local function flatDirection(direction: Vector3): Vector3
	local d = Vector3.new(direction.X, 0, direction.Z)
	if d.Magnitude < 0.01 then
		return Vector3.new(0, 0, -1)
	end
	return d.Unit
end

-- ----------------------------------------------------------------------------
-- Emitter helpers
-- ----------------------------------------------------------------------------

local function scaleSequence(s: NumberSequence, k: number): NumberSequence
	local points = {}
	for _, p in ipairs(s.Keypoints) do
		table.insert(points, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
	end
	return NumberSequence.new(points)
end

-- Scales an emitter's particle size/speed/acceleration, and optionally its rate.
local function scaleEmitter(e: ParticleEmitter, size: number, rateMul: number?)
	e.Size = scaleSequence(e.Size, size)
	e.Speed = NumberRange.new(e.Speed.Min * size, e.Speed.Max * size)
	e.Acceleration = e.Acceleration * size
	e.Rate = e.Rate * (rateMul or 1)
end

-- Copies every emitter found in `template` onto `parent` (a part or attachment).
local function copyEmitters(template: Instance, parent: Instance, name: string, size: number, rateMul: number, objects)
	for _, e in ipairs(template:GetDescendants()) do
		if e:IsA("ParticleEmitter") then
			local c = e:Clone()
			c.Name = name
			scaleEmitter(c, size, rateMul)
			c.Parent = parent
			if objects then
				table.insert(objects, c)
			end
		end
	end
end

local function addBlueFlames(parent: Instance, objects, size: number, rateMul: number)
	local template = getTemplate("ItadoriBlueFlame")
	if template then
		copyEmitters(template, parent, "ItadoriFire", size, rateMul, objects)
	end
end

-- Turns an emitter on for a short window (replicates to clients, unlike :Emit()).
local function pulseEmitter(e: ParticleEmitter, rate: number, seconds: number)
	e.Rate = rate
	e.Enabled = true
	task.delay(seconds, function()
		if e.Parent then
			e.Enabled = false
		end
	end)
end

local function weldEffect(anchorPart: BasePart, effectPart: BasePart)
	effectPart.Parent = folder
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchorPart
	weld.Part1 = effectPart
	weld.Parent = effectPart
	effectPart.Anchored = false
end

local function stopEffects(objects)
	for _, obj in ipairs(objects) do
		if obj.Parent then
			if obj:IsA("ParticleEmitter") then
				obj.Enabled = false
				Debris:AddItem(obj, 1.2)
			elseif obj:IsA("Attachment") then
				for _, e in ipairs(obj:GetChildren()) do
					if e:IsA("ParticleEmitter") then
						e.Enabled = false
					end
				end
				Debris:AddItem(obj, 1.2)
			elseif obj:IsA("BasePart") then
				tween(obj, 0.25, { Transparency = 1 })
				Debris:AddItem(obj, 0.35)
			else
				obj:Destroy()
			end
		end
	end
end

local function clearOldFire(part: Instance)
	for _, child in ipairs(part:GetChildren()) do
		if child.Name == "ItadoriFire" or child.Name == "ItadoriArmGlow" then
			child:Destroy()
		end
	end
end

-- ----------------------------------------------------------------------------
-- Ability 1: Cursed Reinforcement
-- ----------------------------------------------------------------------------

-- Blue fire around the right arm, plus a jet of fire blowing out of the fist.
-- Stops when the empowered attack is used up (Itadori_CursedReinforcement attribute
-- cleared) or after `duration`.
function VFX.ItadoriArmFire(character: Model, duration: number?)
	if not character then
		return
	end

	local arm = character:FindFirstChild("Right Arm") or character:FindFirstChild("RightHand")
	if not arm or not arm:IsA("BasePart") then
		return
	end

	clearOldFire(arm)

	local objects = {}

	-- Fire licking the whole forearm.
	addBlueFlames(arm, objects, 0.5, 0.4)

	-- Fire blowing out of the fist (attachment points out of the hand end of the arm).
	local tip = Instance.new("Attachment")
	tip.Name = "ItadoriFire"
	tip.CFrame = CFrame.new(0, -arm.Size.Y / 2, 0) * CFrame.Angles(math.pi, 0, 0)
	tip.Parent = arm
	table.insert(objects, tip)
	addBlueFlames(tip, nil, 0.8, 0.3)

	-- Soft glowing shell + light so the hand visibly glows.
	local shell = fxPart(arm.Size + Vector3.new(0.4, 0.4, 0.4), arm.CFrame, ITA.Blue, nil, 0.7)
	weldEffect(arm, shell)
	table.insert(objects, shell)

	local light = Instance.new("PointLight")
	light.Name = "ItadoriArmGlow"
	light.Color = ITA.Blue
	light.Brightness = 3
	light.Range = 12
	light.Parent = arm
	table.insert(objects, light)

	local stopped = false
	local conn

	local function stop()
		if stopped then
			return
		end
		stopped = true
		if conn then
			conn:Disconnect()
		end
		stopEffects(objects)
	end

	conn = character:GetAttributeChangedSignal("Itadori_CursedReinforcement"):Connect(function()
		if not character:GetAttribute("Itadori_CursedReinforcement") then
			stop()
		end
	end)

	task.delay(duration or 2.5, stop)
end

-- Enemy marked by Cursed Reinforcement: blue fire burns on their body for `duration`.
function VFX.ItadoriBlueMark(target: Model, duration: number?)
	if not target then
		return
	end

	local part = target:FindFirstChild("Torso")
		or target:FindFirstChild("UpperTorso")
		or target:FindFirstChild("HumanoidRootPart")
		or target.PrimaryPart
	if not part or not part:IsA("BasePart") then
		return
	end

	local template = getTemplate("ItadoriBlueFlame")
	if not template then
		return
	end

	for _, child in ipairs(part:GetChildren()) do
		if child.Name == "ItadoriMarkFire" or child.Name == "ItadoriMarkLight" then
			child:Destroy()
		end
	end

	local objects = {}
	copyEmitters(template, part, "ItadoriMarkFire", 0.9, 0.35, objects)

	local light = Instance.new("PointLight")
	light.Name = "ItadoriMarkLight"
	light.Color = ITA.Blue
	light.Brightness = 2
	light.Range = 10
	light.Parent = part
	table.insert(objects, light)

	task.delay(duration or 3, function()
		stopEffects(objects)
	end)
end

-- Ultimate transformation: blue fire licking off the whole body.
function VFX.ItadoriZoneAura(character: Model, duration: number?)
	if not character then
		return
	end

	local objects = {}

	-- { part name, particle size, rate multiplier }
	local bodyParts = {
		{ "Torso", 0.9, 0.45 },
		{ "Head", 0.5, 0.2 },
		{ "Left Arm", 0.55, 0.25 },
		{ "Right Arm", 0.55, 0.25 },
		{ "Left Leg", 0.55, 0.25 },
		{ "Right Leg", 0.55, 0.25 },
	}

	for _, info in ipairs(bodyParts) do
		local part = character:FindFirstChild(info[1])
		if part and part:IsA("BasePart") then
			clearOldFire(part)
			addBlueFlames(part, objects, info[2], info[3])
		end
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		clearOldFire(root)

		local light = Instance.new("PointLight")
		light.Name = "ItadoriFire"
		light.Color = ITA.Blue
		light.Brightness = 3
		light.Range = 16
		light.Parent = root
		table.insert(objects, light)

		VFX.Burst(root.Position, ITA.Blue, 1.6)
		VFX.Circle(Vector3.new(root.Position.X, root.Position.Y - 2.5, root.Position.Z), 7, ITA.Blue, 0.6)
	end

	local stopped = false
	local conn

	local function stop()
		if stopped then
			return
		end
		stopped = true
		if conn then
			conn:Disconnect()
		end
		stopEffects(objects)
	end

	-- The character script clears this attribute when the transformation ends.
	conn = character:GetAttributeChangedSignal("Itadori_BlackFlashHealMultiplier"):Connect(function()
		if not character:GetAttribute("Itadori_BlackFlashHealMultiplier") then
			stop()
		end
	end)

	task.delay(duration or 15, stop)
end

-- Normal empowered hit: a quick blue flash on contact (the lingering blue fire is ItadoriBlueMark).
function VFX.ItadoriBlueSplash(position: Vector3)
	VFX.Burst(position, ITA.Blue, 0.9)
end

-- Black Flash: the reference "Black Flash VFX" (red-edged black lightning) at the hit point.
function VFX.ItadoriBlackFlash(position: Vector3)
	local template = getTemplate("ItadoriBlackFlash")
	if not template then
		VFX.Burst(position, ITA.Red, 1.1)
		return
	end

	local holder = template:Clone()
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.CFrame = CFrame.new(position)

	local emitters = {}
	for _, e in ipairs(holder:GetDescendants()) do
		if e:IsA("ParticleEmitter") then
			e.Enabled = false
			scaleEmitter(e, 1.35)
			table.insert(emitters, e)
		end
	end

	holder.Parent = folder

	-- Fire the lightning sprites for a moment, then cut them off.
	for _, e in ipairs(emitters) do
		pulseEmitter(e, 40, 0.28)
	end

	local light = holder:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = 6
		light.Range = 16
		tween(light, 0.5, { Brightness = 0 })
	end

	VFX.Burst(position, ITA.Red, 0.9)
	Debris:AddItem(holder, 1.5)
end

-- ----------------------------------------------------------------------------
-- Ability 2: Blood Spray (the reference "Blood-01" splatter, placed through the cone)
-- ----------------------------------------------------------------------------

local function spawnBlood(cf: CFrame, scale: number)
	local template = getTemplate("ItadoriBlood")
	if not template then
		return
	end

	local holder = template:Clone()
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.CFrame = cf

	local emitters = {}
	for _, e in ipairs(holder:GetDescendants()) do
		if e:IsA("ParticleEmitter") then
			e.Enabled = false
			scaleEmitter(e, scale)
			table.insert(emitters, e)
		end
	end

	holder.Parent = folder

	for _, e in ipairs(emitters) do
		if e:GetAttribute("EmitCount") then
			-- splatter sprites: a couple of them
			pulseEmitter(e, 14, 0.14)
		else
			-- the looping mist/droplet layer
			pulseEmitter(e, 24, 0.25)
		end
	end

	Debris:AddItem(holder, 2.2)
end

function VFX.ItadoriBloodSpray(origin: Vector3, direction: Vector3, range: number, angleDeg: number, count: number?)
	local dir = flatDirection(direction)
	local half = math.rad(math.clamp(angleDeg, 10, 170)) / 2
	local base = origin + Vector3.new(0, 0.5, 0)
	local pieces = math.clamp(math.floor((count or 14) / 3), 3, 6)

	for i = 1, pieces do
		local frac = i / pieces
		local dist = math.max(range * frac * rng:NextNumber(0.8, 1), 3)
		-- cone widens with distance so the spray reads as a cone
		local yaw = rng:NextNumber(-half, half) * frac
		local d = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(dir)
		local pos = base + d * dist + Vector3.new(0, rng:NextNumber(-1.5, 1.2), 0)

		-- stagger outward so the blood visibly shoots away from Itadori
		task.delay(frac * 0.16, function()
			spawnBlood(CFrame.lookAt(pos, pos + d), rng:NextNumber(0.9, 1.25))
		end)
	end
end

-- Blood on a target that got hit.
function VFX.ItadoriBloodHit(position: Vector3)
	local cf = CFrame.new(position + Vector3.new(0, 0.5, 0))
		* CFrame.Angles(rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, math.pi * 2), 0)
	spawnBlood(cf, 0.9)
end

-- ----------------------------------------------------------------------------
-- Ability 3 / Ultimate: Dismantle
-- ----------------------------------------------------------------------------

-- Dust clouds + an expanding air ring at the ground under `position` (a character root position).
function VFX.ItadoriDust(position: Vector3, scale: number?)
	local s = scale or 1
	local ground = Vector3.new(position.X, position.Y - 2.5, position.Z)

	for i = 1, 7 do
		local ang = ((i - 1) / 7) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local out = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local size = rng:NextNumber(1.6, 2.6) * s

		local puff = fxPart(
			Vector3.one * size,
			CFrame.new(ground + out * 0.8 * s + Vector3.new(0, size * 0.4, 0)),
			ITA.Dust,
			Enum.PartType.Ball,
			0.35
		)
		puff.Material = Enum.Material.SmoothPlastic
		puff.Parent = folder

		tween(puff, 0.6, {
			Size = Vector3.one * size * 2.4,
			Position = ground + out * rng:NextNumber(3, 5) * s + Vector3.new(0, rng:NextNumber(1, 2.2) * s, 0),
			Transparency = 1,
		})
		Debris:AddItem(puff, 0.7)
	end

	local ring = fxPart(
		Vector3.new(0.15, 2, 2),
		CFrame.new(ground + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		ITA.White,
		Enum.PartType.Cylinder,
		0.5
	)
	ring.Parent = folder
	tween(ring, 0.4, { Size = Vector3.new(0.15, 14 * s, 14 * s), Transparency = 1 })
	Debris:AddItem(ring, 0.5)
end

-- A black rectangle with a white outline (white rectangle sits behind a slightly smaller black one).
-- `cf` is the rectangle's center: its length runs along local X, width along local Y.
local function slashRect(cf: CFrame, length: number, width: number, grow: number, hold: number, fadeTime: number)
	local outline = math.max(0.12, width * 0.25)
	local thick = 0.1

	local white = fxPart(Vector3.new(length + outline * 2, width + outline * 2, thick), cf, ITA.White, nil, 0)
	local black = fxPart(Vector3.new(length, width, thick + 0.04), cf, ITA.Black, nil, 0)
	black.Material = Enum.Material.SmoothPlastic

	for _, p in ipairs({ white, black }) do
		local goal = p.Size
		p.Size = Vector3.new(goal.X * 0.08, goal.Y, goal.Z)
		p.Parent = folder
		tween(p, grow, { Size = goal }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Debris:AddItem(p, grow + hold + fadeTime + 0.3)

		task.delay(grow + hold, function()
			if p.Parent then
				tween(p, fadeTime, { Transparency = 1, Size = Vector3.new(goal.X, goal.Y * 0.15, goal.Z) })
			end
		end)
	end
end

-- Small dismantle cuts on a target (called once per hit of Ability 3): a few thin black
-- rectangles with white outlines flicker in at different angles. `facing` is the cast direction.
function VFX.ItadoriDismantleSlash(position: Vector3, scale: number?, facing: Vector3?)
	local s = scale or 1
	local face = facing and flatDirection(facing) or Vector3.new(0, 0, -1)

	for i = 1, 3 do
		task.delay((i - 1) * 0.035, function()
			local center = position
				+ Vector3.new(rng:NextNumber(-1.8, 1.8), rng:NextNumber(-1.5, 2), rng:NextNumber(-1.8, 1.8))

			-- plane faces back toward Itadori / the camera, rolled to a random diagonal
			local cf = CFrame.lookAt(center, center + face)
				* CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0)
				* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-70, 70)))

			slashRect(cf, rng:NextNumber(5, 8) * s, rng:NextNumber(0.28, 0.5) * s, 0.05, 0.06, 0.2)
		end)
	end

	VFX.Burst(position, ITA.White, 0.3)
end

-- The ultimate: one big black rectangle with a white outline that shoots out along the firing line,
-- standing upright and tilted so it reads as a huge slash.
function VFX.ItadoriMaxDismantle(origin: Vector3, direction: Vector3, range: number, width: number)
	local dir = flatDirection(direction)
	local height = math.max(width * 1.6, 8)
	local outline = math.max(0.6, height * 0.04)
	local thick = 0.4
	local tilt = math.rad(18)
	local len = math.max(range - 3, 1)
	local startPos = Vector3.new(origin.X, origin.Y + 1, origin.Z) + dir * 3

	-- Blade that has extended `dist` studs from the start point.
	local function frameAt(dist: number): CFrame
		local c = startPos + dir * (dist / 2)
		return CFrame.lookAt(c, c + dir) * CFrame.Angles(0, 0, tilt)
	end

	local startLen = 4
	local white = fxPart(Vector3.new(thick, height + outline * 2, startLen + outline * 2), frameAt(startLen), ITA.White, nil, 0)
	local black = fxPart(Vector3.new(thick + 0.3, height, startLen), frameAt(startLen), ITA.Black, nil, 0)
	black.Material = Enum.Material.SmoothPlastic

	local grow, hold, fadeTime = 0.22, 0.45, 0.6

	for _, p in ipairs({ white, black }) do
		local isWhite = p == white
		local goalSize = Vector3.new(p.Size.X, p.Size.Y, len + (isWhite and outline * 2 or 0))

		p.Parent = folder
		tween(p, grow, { Size = goalSize, CFrame = frameAt(len) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Debris:AddItem(p, grow + hold + fadeTime + 0.3)

		task.delay(grow + hold, function()
			if p.Parent then
				tween(p, fadeTime, {
					Transparency = 1,
					Size = Vector3.new(goalSize.X, goalSize.Y * 0.1, goalSize.Z),
				})
			end
		end)
	end

	VFX.Burst(startPos + dir * 2, ITA.White, 1.4)
end

-- ============================================================================
-- JOHNNY  (spinning nails)
-- ============================================================================

-- Character-specific basic-attack projectile visual. Signature matches the hook in
-- CombatService.launchBasicProjectile: (position, radius, color, direction, character).
-- Clones ServerStorage.JohnnyAssets.Spin (a Part with a spark emitter), points it along the
-- shot and spins it around its own axis. CombatService moves it by setting `Position`, which
-- keeps our rotation, so the spin only has to rewrite the rotation part of the CFrame.
local JOHNNY_NAIL_SPIN_SPEED = math.rad(1080) -- radians / second around the nail's axis

function VFX.JohnnySpinNail(position: Vector3, radius: number, color: Color3, direction: Vector3, character: Model?): BasePart
	local ServerStorage = game:GetService("ServerStorage")
	local assets = ServerStorage:FindFirstChild("JohnnyAssets")
	local template = assets and assets:FindFirstChild("Spin")

	if not template or not template:IsA("BasePart") then
		return VFX.Projectile(position, radius, color)
	end

	local dir = direction.Magnitude > 0.001 and direction.Unit or Vector3.new(0, 0, -1)

	local nail = template:Clone()
	nail.Name = "JohnnySpinNail"
	nail.Anchored = true
	nail.CanCollide = false
	nail.CanQuery = false
	nail.CanTouch = false
	nail.CastShadow = false
	nail.Color = color

	-- Point the nail's long (Y) axis down the shot direction.
	local aim = CFrame.lookAt(position, position + dir) * CFrame.Angles(-math.pi / 2, 0, 0)
	nail.CFrame = aim

	-- Discard() pops composite effects with a burst and fades everything, emitters included.
	nail:SetAttribute("BurstOnDiscard", true)
	nail:SetAttribute("BurstScale", 0.45)

	nail.Parent = folder

	local spin = 0
	local connection
	connection = RunService.Heartbeat:Connect(function(dt)
		if not nail.Parent or nail.Transparency >= 1 then
			connection:Disconnect()
			return
		end

		spin = (spin + JOHNNY_NAIL_SPIN_SPEED * dt) % (math.pi * 2)

		local here = nail.Position
		nail.CFrame = CFrame.lookAt(here, here + dir)
			* CFrame.Angles(-math.pi / 2, 0, 0)
			* CFrame.Angles(0, spin, 0)
	end)

	return nail
end

return VFX

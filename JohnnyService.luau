--[[
	JohnnyService - server-side logic for Johnny and his horse, Slow Dancer.

	What lives here (everything Johnny-specific that the shared character definition can't do):
	  * Mounting: on spawn Johnny is seated on a clone of ServerStorage.JohnnyAssets.SlowDancer.
	    The horse is welded under him and the rider's HipHeight is raised so the horse's hooves
	    stand on the ground.
	  * Damage soaking: Slow Dancer has its own health pool. While mounted it soaks ALL damage
	    (registered through DamageService.RegisterAbsorber, so it sees post-armor final damage).
	  * Break / remount: when the pool is empty the horse bolts, Johnny is on foot, and Slow Dancer
	    returns (at full health) after REMOUNT_DELAY seconds.
	  * Horse animation (Ride / Walk / Fall) and slow out-of-combat regeneration.

	Replicated character attributes (for HUD / ability gates):
	  Johnny_Mounted          boolean   true while Slow Dancer is under him
	  Johnny_MountHealth      number    current Slow Dancer health
	  Johnny_MountMaxHealth   number    current Slow Dancer max health
	  Johnny_RemountAt        number    server time Slow Dancer returns (0 = not waiting)

	GameServer loads this module defensively and calls Init() once.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local PlayerState = require(script.Parent.PlayerState)
local StatService = require(script.Parent.StatService)
local DamageService = require(script.Parent.DamageService)
local MatchService = require(script.Parent.MatchService)
local VFX = require(script.Parent.VFX)
local Remotes = require(script.Parent.Remotes)

local JohnnyService = {}

-- ============================================================================
-- TUNING
-- ============================================================================

local CHARACTER_ID = "Johnny"

local MOUNT_HEALTH_BASE = 150 -- Slow Dancer health at level 0
local MOUNT_HEALTH_PER_LEVEL = 45 -- added per champion level
local MOUNT_REGEN_DELAY = 6 -- seconds without being hit before the horse regenerates
local MOUNT_REGEN_PERCENT = 0.025 -- of max health per second once regenerating
local REMOUNT_DELAY = 20 -- seconds until a broken Slow Dancer returns
local MOUNT_MOVE_SPEED_BONUS = 3 -- flat MoveSpeed while mounted
local PASS_OVERFLOW_DAMAGE = false -- true: damage beyond the last horse HP hurts Johnny

-- Seating (measured from the SlowDancer rig: faces -Z, saddle top is ~0.1 above its root)
local SEAT_RISE = 1.2 -- rider HumanoidRootPart height above the horse's HumanoidRootPart
local HORSE_YAW = 0 -- extra yaw (radians) if the horse ever needs turning relative to Johnny
local R6_ROOT_HEIGHT = 3 -- R6: HumanoidRootPart centre above the floor at HipHeight 0

-- R6 sit pose for the rider (Roblox's default R6 "sit" animation). Set to "" to skip it.
local RIDER_SIT_ANIMATION = "rbxassetid://178130996"

local ANIMATOR_FALL_DELAY = 0.25 -- seconds airborne before the horse's Fall animation plays

-- ============================================================================
-- STATE
-- ============================================================================

type Mount = {
	Player: Player,
	Character: Model,
	Humanoid: Humanoid,
	Root: BasePart,
	Horse: Model,
	Health: number,
	MaxHealth: number,
	LastHit: number,
	OriginalHipHeight: number,
	Tracks: { [string]: AnimationTrack },
	Current: string?,
	RiderTrack: AnimationTrack?,
	AirborneFor: number,
	AttributeTimer: number,
}

-- Weak keys so a destroyed character never leaks its mount record.
local mounts: { [Model]: Mount } = setmetatable({}, { __mode = "k" })
local remountTokens: { [Model]: number } = setmetatable({}, { __mode = "k" })

local initialized = false

-- ============================================================================
-- HELPERS
-- ============================================================================

local function serverNow(): number
	return workspace:GetServerTimeNow()
end

local function computeMaxHealth(player: Player): number
	local state = PlayerState.Get(player)
	local level = state and state.Level or 0
	return MOUNT_HEALTH_BASE + MOUNT_HEALTH_PER_LEVEL * level
end

local function publishAttributes(mount: Mount)
	mount.Character:SetAttribute("Johnny_MountHealth", math.floor(mount.Health + 0.5))
	mount.Character:SetAttribute("Johnny_MountMaxHealth", math.floor(mount.MaxHealth + 0.5))
end

local function getTemplate(): Model?
	local assets = ServerStorage:FindFirstChild("JohnnyAssets")
	local template = assets and assets:FindFirstChild("SlowDancer")

	if template and template:IsA("Model") and template.PrimaryPart then
		return template
	end

	warn("[JohnnyService] ServerStorage.JohnnyAssets.SlowDancer is missing or has no PrimaryPart")
	return nil
end

-- Loads every Animation in the horse's Animations folder onto its Animator.
local function loadHorseTracks(horse: Model): { [string]: AnimationTrack }
	local tracks = {}

	local controller = horse:FindFirstChildOfClass("AnimationController")
	local animator = controller and controller:FindFirstChildOfClass("Animator")
	local folder = horse:FindFirstChild("Animations")

	if not animator or not folder then
		return tracks
	end

	for _, animation in ipairs(folder:GetChildren()) do
		if animation:IsA("Animation") then
			local ok, track = pcall(function()
				return animator:LoadAnimation(animation)
			end)

			if ok and track then
				track.Priority = Enum.AnimationPriority.Action
				track.Looped = (animation.Name == "Ride" or animation.Name == "Walk" or animation.Name == "Fall")
				tracks[animation.Name] = track
			else
				warn("[JohnnyService] could not load horse animation " .. animation.Name)
			end
		end
	end

	return tracks
end

local function playHorseState(mount: Mount, name: string, speed: number?)
	local track = mount.Tracks[name]

	if mount.Current ~= name then
		local previous = mount.Current and mount.Tracks[mount.Current]
		if previous then
			previous:Stop(0.15)
		end

		mount.Current = name

		if track then
			track:Play(0.15)
		end
	end

	if track and speed then
		track:AdjustSpeed(speed)
	end
end

-- Fades a horse out and removes it (used when it breaks and when it is cleaned up).
local function fadeOutHorse(horse: Model, duration: number)
	for _, descendant in ipairs(horse:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Transparency < 1 then
			TweenService:Create(descendant, TweenInfo.new(duration), { Transparency = 1 }):Play()
		end
	end

	Debris:AddItem(horse, duration + 0.1)
end

-- ============================================================================
-- MOUNT / DISMOUNT
-- ============================================================================

local function clearMountVisualsAndState(mount: Mount, fade: boolean)
	local character = mount.Character

	mounts[character] = nil

	if mount.RiderTrack then
		mount.RiderTrack:Stop(0.1)
		mount.RiderTrack = nil
	end

	for _, track in pairs(mount.Tracks) do
		track:Stop(0)
	end

	if mount.Horse and mount.Horse.Parent then
		-- Detach first so the dying horse can't drag the rider's physics around.
		local weld = mount.Root and mount.Root:FindFirstChild("SlowDancerWeld")
		if weld then
			weld:Destroy()
		end

		if fade then
			mount.Horse.Parent = workspace:FindFirstChild("Effects") or workspace
			fadeOutHorse(mount.Horse, 0.45)
		else
			mount.Horse:Destroy()
		end
	end

	if mount.Humanoid and mount.Humanoid.Parent then
		mount.Humanoid.HipHeight = mount.OriginalHipHeight
	end

	character:SetAttribute("Johnny_Mounted", false)
	character:SetAttribute("Johnny_MountHealth", 0)

	StatService.ClearModifier(mount.Player, "SlowDancer")
end

local function scheduleRemount(player: Player, character: Model)
	local token = (remountTokens[character] or 0) + 1
	remountTokens[character] = token

	character:SetAttribute("Johnny_RemountAt", serverNow() + REMOUNT_DELAY)

	task.delay(REMOUNT_DELAY, function()
		if remountTokens[character] ~= token then
			return
		end

		if not character.Parent or mounts[character] then
			return
		end

		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			return
		end

		JohnnyService.Mount(player, character)
	end)
end

local function breakMount(mount: Mount)
	local player, character, root = mount.Player, mount.Character, mount.Root

	if root and root.Parent then
		VFX.Burst(root.Position - Vector3.new(0, 2, 0), Color3.fromRGB(235, 200, 140), 1.3)
	end

	clearMountVisualsAndState(mount, true)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		scheduleRemount(player, character)
	end
end

function JohnnyService.IsMounted(character: Model?): boolean
	return character ~= nil and mounts[character] ~= nil
end

function JohnnyService.GetMountHealth(character: Model?): (number, number)
	local mount = character and mounts[character]
	if not mount then
		return 0, 0
	end

	return mount.Health, mount.MaxHealth
end

-- Seats Johnny on a fresh, full-health Slow Dancer. Returns true on success.
function JohnnyService.Mount(player: Player, character: Model): boolean
	if mounts[character] then
		return true
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or humanoid.Health <= 0 then
		return false
	end

	local template = getTemplate()
	if not template then
		return false
	end

	local horse = template:Clone()
	horse.Name = "SlowDancer"

	for _, descendant in ipairs(horse:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Massless = true
		end
	end

	local rootToFloor = horse:GetAttribute("RootToFloor") or 4.7
	local originalHip = humanoid.HipHeight

	-- Height the rider's root must have above the floor to sit on the saddle while the horse
	-- stands on the ground, and the HipHeight that produces it (R6 root height = 2 + half HRP).
	local targetRootHeight = rootToFloor + SEAT_RISE
	local baseRootHeight = (humanoid.RigType == Enum.HumanoidRigType.R6) and (R6_ROOT_HEIGHT - 1 + root.Size.Y / 2)
			or (root.Size.Y / 2)
	local newHip = targetRootHeight - baseRootHeight
	local lift = newHip - originalHip

	-- Raise the character by the same amount first so the legs don't clip the floor.
	character:PivotTo(character:GetPivot() + Vector3.new(0, lift, 0))
	humanoid.HipHeight = newHip

	horse:PivotTo(root.CFrame * CFrame.new(0, -SEAT_RISE, 0) * CFrame.Angles(0, HORSE_YAW, 0))

	local weld = Instance.new("WeldConstraint")
	weld.Name = "SlowDancerWeld"
	weld.Part0 = root
	weld.Part1 = horse.PrimaryPart
	weld.Parent = root

	horse.Parent = character

	local tracks = loadHorseTracks(horse)

	local mount: Mount = {
		Player = player,
		Character = character,
		Humanoid = humanoid,
		Root = root,
		Horse = horse,
		MaxHealth = computeMaxHealth(player),
		Health = 0,
		LastHit = -math.huge,
		OriginalHipHeight = originalHip,
		Tracks = tracks,
		Current = nil,
		RiderTrack = nil,
		AirborneFor = 0,
		AttributeTimer = 0,
	}
	mount.Health = mount.MaxHealth
	mounts[character] = mount

	-- Rider pose.
	if RIDER_SIT_ANIMATION ~= "" then
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid
		end

		local animation = Instance.new("Animation")
		animation.AnimationId = RIDER_SIT_ANIMATION

		local ok, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)

		if ok and track then
			track.Priority = Enum.AnimationPriority.Action
			track.Looped = true
			track:Play(0.1)
			mount.RiderTrack = track
		end
	end

	playHorseState(mount, "Ride")

	StatService.SetModifier(player, "SlowDancer", {
		MoveSpeed = { Flat = MOUNT_MOVE_SPEED_BONUS },
	})

	character:SetAttribute("Johnny_Mounted", true)
	character:SetAttribute("Johnny_RemountAt", 0)
	remountTokens[character] = (remountTokens[character] or 0) + 1 -- cancels any pending remount
	publishAttributes(mount)

	return true
end

-- Removes the horse without scheduling a return (death, match end, character change).
function JohnnyService.Dismount(character: Model, fade: boolean?)
	local mount = mounts[character]
	if mount then
		clearMountVisualsAndState(mount, fade == true)
	end

	remountTokens[character] = (remountTokens[character] or 0) + 1
	character:SetAttribute("Johnny_RemountAt", 0)
end

-- ============================================================================
-- CHARGE (used by the ultimate)
-- ============================================================================

-- Sends Johnny (and the horse welded under him) galloping toward `destination` using the same
-- client-side movement command the built-in Dash effect uses. Returns the distance travelled.
function JohnnyService.Charge(player: Player, character: Model, destination: Vector3, duration: number): number
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return 0
	end

	local offset = Vector3.new(destination.X - root.Position.X, 0, destination.Z - root.Position.Z)
	local distance = offset.Magnitude

	if distance < 0.5 then
		return 0
	end

	local direction = offset.Unit

	Remotes.MoveCommand:FireClient(player, {
		Mode = "Dash",
		Position = root.Position + direction * distance,
		Direction = direction,
		Distance = distance,
		Duration = duration,
	})

	return distance
end

-- ============================================================================
-- DAMAGE ABSORBER
-- ============================================================================

-- DamageService calls this with the final post-mitigation damage. Returning the amount that
-- should still reach Johnny's humanoid; while Slow Dancer is alive that is nothing.
local function absorbDamage(target: Model, amount: number, _packet, _attacker): number
	local mount = mounts[target]
	if not mount or amount <= 0 then
		return amount
	end

	mount.LastHit = os.clock()
	mount.Health -= amount

	if mount.Health <= 0 then
		local overflow = -mount.Health
		mount.Health = 0
		breakMount(mount)

		return PASS_OVERFLOW_DAMAGE and overflow or 0
	end

	publishAttributes(mount)
	return 0
end

-- ============================================================================
-- PER-FRAME: animation + regeneration
-- ============================================================================

local function stepMount(mount: Mount, dt: number)
	local humanoid, root = mount.Humanoid, mount.Root

	if not humanoid.Parent or not root.Parent then
		return
	end

	-- Keep the pool in step with champion level (level-ups grow the pool and grant that HP).
	local newMax = computeMaxHealth(mount.Player)
	if newMax ~= mount.MaxHealth then
		if newMax > mount.MaxHealth then
			mount.Health += newMax - mount.MaxHealth
		end

		mount.MaxHealth = newMax
		mount.Health = math.min(mount.Health, newMax)
	end

	-- Regeneration once the horse has been left alone for a while.
	if mount.Health < mount.MaxHealth and os.clock() - mount.LastHit >= MOUNT_REGEN_DELAY then
		mount.Health = math.min(mount.MaxHealth, mount.Health + mount.MaxHealth * MOUNT_REGEN_PERCENT * dt)
	end

	mount.AttributeTimer += dt
	if mount.AttributeTimer >= 0.2 then
		mount.AttributeTimer = 0
		publishAttributes(mount)
	end

	-- Animation: Fall when airborne, Walk while moving, Ride when standing still.
	local airborne = humanoid.FloorMaterial == Enum.Material.Air
	mount.AirborneFor = airborne and (mount.AirborneFor + dt) or 0

	local planarSpeed = Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude

	if mount.AirborneFor >= ANIMATOR_FALL_DELAY and mount.Tracks.Fall then
		playHorseState(mount, "Fall")
	elseif planarSpeed > 1 and mount.Tracks.Walk then
		playHorseState(mount, "Walk", math.clamp(planarSpeed / 14, 0.6, 1.8))
	else
		playHorseState(mount, "Ride")
	end
end

-- ============================================================================
-- SPAWN HOOK
-- ============================================================================

local function onCharacterSetup(player: Player, character: Model, def)
	if not def or def.Id ~= CHARACTER_ID then
		return
	end

	JohnnyService.Mount(player, character)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Once(function()
			JohnnyService.Dismount(character, true)
		end)
	end

	character.Destroying:Once(function()
		local mount = mounts[character]
		if mount then
			-- Character is going away; only the stat modifier needs undoing.
			mounts[character] = nil
			StatService.ClearModifier(player, "SlowDancer")
		end

		remountTokens[character] = nil
	end)
end

-- ============================================================================
-- INIT
-- ============================================================================

function JohnnyService.Init()
	if initialized then
		return
	end
	initialized = true

	MatchService.OnCharacterSetup(onCharacterSetup)
	DamageService.RegisterAbsorber(absorbDamage)

	RunService.Heartbeat:Connect(function(dt)
		for _, mount in pairs(mounts) do
			local ok, err = pcall(stepMount, mount, dt)
			if not ok then
				warn("[JohnnyService] mount step failed: " .. tostring(err))
			end
		end
	end)

	-- Leaving the match / switching characters must not leave a stale horse modifier behind.
	Players.PlayerRemoving:Connect(function(player)
		local character = player.Character
		if character then
			mounts[character] = nil
			remountTokens[character] = nil
		end
	end)
end

return JohnnyService

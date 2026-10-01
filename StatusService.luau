-- ServerScriptService.Server.StatusService
-- Drop-in replacement with Fear, Airborne, and Lockout support.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local StatService = require(script.Parent.StatService)

local StatusService = {}
local active = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

local function isValidStatus(name: string): boolean
	for _, statusName in ipairs(Config.Statuses) do
		if statusName == name then
			return true
		end
	end
	return false
end

function StatusService.Has(model: Model, name: string): boolean
	local set = active[model]
	local entry = set and set[name]
	return entry ~= nil and entry.Expire > now()
end

function StatusService.GetMagnitude(model: Model, name: string): number
	local set = active[model]
	local entry = set and set[name]
	if entry and entry.Expire > now() then
		return entry.Magnitude
	end
	return 0
end

function StatusService.RefreshMovement(model: Model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local player = Players:GetPlayerFromCharacter(model)
	if not player then
		return
	end

	local speed = StatService.Get(model, "MoveSpeed")

	if StatusService.Has(model, "Slow") then
		speed *= (1 - math.clamp(StatusService.GetMagnitude(model, "Slow"), 0, 0.9))
	end

	if model:GetAttribute("Blocking") then
		speed *= Config.Block.MoveSpeedMultiplier
	end

	if StatusService.Has(model, "Stun")
		or StatusService.Has(model, "Root")
		or StatusService.Has(model, "Fear")
		or StatusService.Has(model, "Airborne")
		or StatusService.Has(model, "Lockout")
	then
		speed = 0
	end

	humanoid.WalkSpeed = speed
end

function StatusService.Apply(model: Model, name: string, duration: number, magnitude: number?)
	if not isValidStatus(name) or duration <= 0 then
		return
	end

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	local set = active[model]
	if not set then
		set = {}
		active[model] = set
		model.Destroying:Once(function()
			active[model] = nil
		end)
	end

	local expire = now() + duration
	local existing = set[name]

	if existing and existing.Expire > now() then
		existing.Expire = math.max(existing.Expire, expire)
		existing.Magnitude = math.max(existing.Magnitude, magnitude or 0)
	else
		set[name] = {
			Expire = expire,
			Magnitude = magnitude or 0,
		}
	end

	model:SetAttribute("Status_" .. name, set[name].Expire)
	StatusService.RefreshMovement(model)
end

function StatusService.Clear(model: Model)
	local set = active[model]
	if set then
		for name in pairs(set) do
			model:SetAttribute("Status_" .. name, nil)
		end
	end
	active[model] = nil
	StatusService.RefreshMovement(model)
end

function StatusService.CanMove(model: Model): boolean
	return not (
		StatusService.Has(model, "Stun")
			or StatusService.Has(model, "Root")
			or StatusService.Has(model, "Fear")
			or StatusService.Has(model, "Airborne")
			or StatusService.Has(model, "Lockout")
	)
end

function StatusService.CanAct(model: Model): boolean
	return not (
		StatusService.Has(model, "Stun")
			or StatusService.Has(model, "Fear")
			or StatusService.Has(model, "Airborne")
			or StatusService.Has(model, "Lockout")
	)
end

function StatusService.CanCast(model: Model, ability): (boolean, string?)
	if StatusService.Has(model, "Lockout") then
		return false, "Locked out"
	end

	if StatusService.Has(model, "Airborne") then
		return false, "Airborne"
	end

	if StatusService.Has(model, "Stun") then
		return false, "Stunned"
	end

	if StatusService.Has(model, "Fear") then
		return false, "Feared"
	end

	if ability.Slot == "Summoner" then
		return true, nil
	end

	if StatusService.Has(model, "Silence") then
		return false, "Silenced"
	end

	local dt = ability.DamageType
	if (dt == Config.DamageType.Physical or dt == Config.DamageType.Hybrid)
		and StatusService.Has(model, "SuppressPhysical")
	then
		return false, "Physical abilities suppressed"
	end

	if (dt == Config.DamageType.Magical or dt == Config.DamageType.Hybrid)
		and StatusService.Has(model, "SuppressMagical")
	then
		return false, "Magical abilities suppressed"
	end

	return true, nil
end

function StatusService.Step()
	local t = now()

	for model, set in pairs(active) do
		local changed = false

		for name, entry in pairs(set) do
			if entry.Expire <= t then
				set[name] = nil
				model:SetAttribute("Status_" .. name, nil)
				changed = true
			end
		end

		if changed then
			StatusService.RefreshMovement(model)
		end
	end
end

StatService.OnRecomputed = function(player: Player)
	local character = player.Character
	if character then
		StatusService.RefreshMovement(character)
	end
end

return StatusService
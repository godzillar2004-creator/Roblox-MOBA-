--[[
	DummyService - stationary training targets standing in for minions / NPCs so the
	gold + XP flow can be tested. They are ordinary damageables: tagged "Damageable",
	with Stat_* attributes for armor and GoldValue / XpValue attributes for rewards.
	Dummy positions come from parts under Workspace.Map.DummySpawns.
]]

local Players = game:GetService("Players")

local DamageService = require(script.Parent.DamageService)
local Overhead = require(script.Parent.Overhead)

local DummyService = {}

local DUMMY = {
	MaxHealth = 900,
	PhysicalArmor = 20,
	MagicArmor = 20,
	Gold = 60,
	Xp = 70,
	RespawnDelay = 8,
}

local live: { [BasePart]: Model } = {}

local function spawnDummy(spawnPart: BasePart)
	local desc = Instance.new("HumanoidDescription")
	local rig = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R6)
	rig.Name = "Training Dummy"

	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	humanoid.MaxHealth = DUMMY.MaxHealth
	humanoid.Health = DUMMY.MaxHealth

	for _, child in ipairs(rig:GetChildren()) do
		if child:IsA("BasePart") and child.Name ~= "HumanoidRootPart" then
			child.Color = Color3.fromRGB(220, 180, 90)
		end
		if child:IsA("LocalScript") or child:IsA("Script") then
			child:Destroy() -- no animation script needed
		end
	end

	rig:SetAttribute("Stat_PhysicalArmor", DUMMY.PhysicalArmor)
	rig:SetAttribute("Stat_MagicArmor", DUMMY.MagicArmor)
	rig:SetAttribute("GoldValue", DUMMY.Gold)
	rig:SetAttribute("XpValue", DUMMY.Xp)

	rig.Parent = workspace
	rig:PivotTo(spawnPart.CFrame * CFrame.new(0, 3.1, 0))
	local root = rig:FindFirstChild("HumanoidRootPart")
	if root then
		root.Anchored = true
	end
	DamageService.TagDamageable(rig)
	Overhead.Attach(rig, "Training Dummy", Color3.fromRGB(230, 200, 80))

	live[spawnPart] = rig
	humanoid.Died:Once(function()
		task.delay(0.6, function()
			if rig.Parent then
				rig:Destroy()
			end
		end)
		task.delay(DUMMY.RespawnDelay, function()
			if spawnPart.Parent and live[spawnPart] == rig then
				spawnDummy(spawnPart)
			end
		end)
	end)
end

function DummyService.Init()
	local map = workspace:FindFirstChild("Map")
	local spawns = map and map:FindFirstChild("DummySpawns")
	if not spawns then
		warn("[DummyService] Workspace.Map.DummySpawns not found - no training dummies spawned")
		return
	end
	for _, part in ipairs(spawns:GetChildren()) do
		if part:IsA("BasePart") then
			spawnDummy(part)
		end
	end
end

-- Refill / respawn every dummy (used when a match is reset)
function DummyService.Reset()
	local snapshot = {}
	for spawnPart, rig in pairs(live) do
		table.insert(snapshot, { spawnPart, rig })
	end
	for _, entry in ipairs(snapshot) do
		local spawnPart, rig = entry[1], entry[2]
		live[spawnPart] = nil
		if rig.Parent then
			rig:Destroy()
		end
		if spawnPart.Parent then
			spawnDummy(spawnPart)
		end
	end
end

return DummyService

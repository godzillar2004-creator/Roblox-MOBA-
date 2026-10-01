-- Placeholder overhead name + health bar for every combatant (players and NPCs).
local Overhead = {}

function Overhead.Attach(model: Model, displayName: string, color: Color3, player: Player?)
	local head = model:FindFirstChild("Head")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not head or not humanoid then
		return
	end
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None

	local old = head:FindFirstChild("Overhead")
	if old then
		old:Destroy()
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Overhead"
	gui.Adornee = head
	gui.Size = UDim2.fromOffset(130, 36)
	gui.StudsOffset = Vector3.new(0, 2.7, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 250
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.Name = "NameLabel"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 14
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.Text = displayName
	label.Parent = gui

	local back = Instance.new("Frame")
	back.Name = "Back"
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	back.BorderSizePixel = 0
	back.Position = UDim2.new(0, 5, 0, 22)
	back.Size = UDim2.new(1, -10, 0, 9)
	back.Parent = gui

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = back

	gui.Parent = head

	local function updateBar()
		local ratio = humanoid.MaxHealth > 0 and math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1) or 0
		fill.Size = UDim2.fromScale(ratio, 1)
	end
	updateBar()
	humanoid.HealthChanged:Connect(updateBar)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(updateBar)

	if player then
		local function updateName()
			label.Text = string.format("[%d] %s", player:GetAttribute("Level") or 0, displayName)
		end
		updateName()
		player:GetAttributeChangedSignal("Level"):Connect(updateName)
	end
end

return Overhead

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local abilitySystem = ReplicatedStorage
	:WaitForChild("Shared")
	:WaitForChild("AbilitySystem")

print("========================================")
print("ABILITY TAGS DEEP DEBUG")
print("========================================")

for i, child in ipairs(abilitySystem:GetChildren()) do
	local bytes = {}

	for j = 1, #child.Name do
		table.insert(bytes, tostring(string.byte(child.Name, j)))
	end

	print(
		string.format(
			"Child #%d | Name=%q | Length=%d | Bytes=%s | Class=%s | ExactMatch=%s | Archivable=%s | FullName=%s",
			i,
			child.Name,
			#child.Name,
			table.concat(bytes, ","),
			child.ClassName,
			tostring(child.Name == "AbilityTags"),
			tostring(child.Archivable),
			child:GetFullName()
		)
	)
end

print("----------------------------------------")

local direct = abilitySystem:FindFirstChild("AbilityTags")

print("FindFirstChild('AbilityTags') =", direct)

if direct then
	print("FOUND DIRECTLY")
	print("Name:", direct.Name)
	print("Class:", direct.ClassName)
else
	print("NOT FOUND BY EXACT NAME")
end

print("----------------------------------------")

for _, child in ipairs(abilitySystem:GetChildren()) do
	if child:IsA("ModuleScript") then
		if string.find(child.Name, "AbilityTags", 1, true) then
			print("PARTIAL NAME MATCH FOUND:")
			print("Displayed Name:", child.Name)
			print("Length:", #child.Name)
			print("FullName:", child:GetFullName())
		end
	end
end

print("========================================")
-- Creates every RemoteEvent / RemoteFunction listed in Config and returns them by name.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local folder = ReplicatedStorage:FindFirstChild("Remotes")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "Remotes"
	folder.Parent = ReplicatedStorage
end

local Remotes = {}

for _, name in ipairs(Config.Remotes) do
	local remote = folder:FindFirstChild(name) or Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	Remotes[name] = remote
end

for _, name in ipairs(Config.RemoteFunctions) do
	local remote = folder:FindFirstChild(name) or Instance.new("RemoteFunction")
	remote.Name = name
	remote.Parent = folder
	Remotes[name] = remote
end

return Remotes

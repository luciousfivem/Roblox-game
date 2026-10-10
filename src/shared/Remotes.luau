--!strict
-- Creates (server) / waits for (client) every RemoteEvent and RemoteFunction.
-- The server must require this module before clients need it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local EVENTS = {
	"State",
	"Toast",
	"Mine",
	"Sell",
	"Forge",
	"Equip",
	"Buy",
	"Hatch",
	"PetEquip",
	"Rebirth",
	"Teleport",
	"Daily",
	"Admin",
}
local FUNCTIONS = { "GetState" }

local Remotes = {}

if RunService:IsServer() then
	local folder = Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = folder
	end
	for _, name in FUNCTIONS do
		local remote = Instance.new("RemoteFunction")
		remote.Name = name
		remote.Parent = folder
	end
	folder.Parent = ReplicatedStorage
end

function Remotes.Event(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name) :: RemoteEvent
end

function Remotes.Function(name: string): RemoteFunction
	local folder = ReplicatedStorage:WaitForChild("Remotes")
	return folder:WaitForChild(name) :: RemoteFunction
end

return Remotes

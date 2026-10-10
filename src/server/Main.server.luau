--!strict
-- Entry point: builds the world and starts every server system.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Must come first: creates the remotes clients wait on.
require(ReplicatedStorage.Shared.Remotes)

local Data = require(script.Parent.Data)
local Economy = require(script.Parent.Economy)
local Gear = require(script.Parent.Gear)
local Hazards = require(script.Parent.Hazards)
local Mining = require(script.Parent.Mining)
local World = require(script.Parent.World)

World.Build()
Data.Init()
Mining.Init()
Economy.Init()
Hazards.Init()

-- Re-apply gear on every respawn, and once data finishes loading.
local function watchCharacters(player: Player)
	player.CharacterAdded:Connect(function()
		task.wait() -- let the character finish assembling
		Gear.apply(player)
	end)
end

Players.PlayerAdded:Connect(watchCharacters)
for _, player in Players:GetPlayers() do
	watchCharacters(player)
end
Data.PlayerLoaded:Connect(Gear.apply)

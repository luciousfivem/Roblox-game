--!strict
-- Creates the Coins leaderboard stat for each player.
local Players = game:GetService("Players")

local function onPlayerAdded(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = stats

	stats.Parent = player
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

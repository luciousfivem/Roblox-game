--!strict
-- Spawns coins, awards points on touch, and keeps the coin count topped up.
local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local coinFolder = Instance.new("Folder")
coinFolder.Name = "Coins"
coinFolder.Parent = workspace

local coinCount = 0

local function randomPosition(): Vector3
	local half = Config.ArenaSize / 2 - 4
	return Vector3.new(math.random(-half, half), 3, math.random(-half, half))
end

local function spawnCoin()
	local golden = math.random() < Config.GoldenCoinChance
	local value = if golden then Config.GoldenCoinValue else Config.CoinValue

	local coin = Instance.new("Part")
	coin.Name = "Coin"
	coin.Shape = Enum.PartType.Cylinder
	coin.Size = Vector3.new(0.4, 3, 3)
	coin.Orientation = Vector3.new(0, 0, 90)
	coin.Position = randomPosition()
	coin.Anchored = true
	coin.CanCollide = false
	coin.Material = Enum.Material.Neon
	coin.Color = if golden then Color3.fromRGB(255, 200, 0) else Color3.fromRGB(255, 240, 120)
	coin:SetAttribute("Value", value)
	coin.Parent = coinFolder
	coinCount += 1

	local collected = false
	coin.Touched:Connect(function(hit)
		if collected then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		collected = true

		local stats = player:FindFirstChild("leaderstats")
		local coins = stats and stats:FindFirstChild("Coins")
		if coins and coins:IsA("IntValue") then
			coins.Value += value
		end
		coin:Destroy()
	end)

	coin.Destroying:Connect(function()
		coinCount -= 1
	end)
	Debris:AddItem(coin, Config.CoinLifetime)
end

task.spawn(function()
	while true do
		if coinCount < Config.MaxCoins then
			spawnCoin()
		end
		task.wait(Config.SpawnInterval)
	end
end)

-- Spin every coin; done with one loop rather than one per coin.
task.spawn(function()
	local RunService = game:GetService("RunService")
	while true do
		local dt = RunService.Heartbeat:Wait()
		for _, coin in coinFolder:GetChildren() do
			if coin:IsA("BasePart") then
				coin.CFrame *= CFrame.Angles(dt * 3, 0, 0)
			end
		end
	end
end)

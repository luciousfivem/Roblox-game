--!strict
-- Handles swing requests from clients: validates them, damages nodes, and pays out ore + XP.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameData = require(ReplicatedStorage.Shared.GameData)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Data = require(script.Parent.Data)
local Notify = require(script.Parent.Notify)
local World = require(script.Parent.World)

local Mining = {}

local lastSwing: { [Player]: number } = {}
local lastFullWarning: { [Player]: number } = {}

local function onMine(player: Player, node: unknown)
	if typeof(node) ~= "Instance" or not node:IsA("BasePart") or node.Parent ~= World.NodesFolder then
		return
	end
	local profile = Data.Get(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not root or not humanoid or humanoid.Health <= 0 then
		return
	end

	-- Rate limit (15% tolerance for network jitter).
	local now = os.clock()
	if now - (lastSwing[player] or 0) < GameData.cooldown(profile) * 0.85 then
		return
	end

	if (root.Position - node.Position).Magnitude > Config.MiningRange + node.Size.Magnitude / 2 then
		return
	end

	if GameData.usedCapacity(profile) >= GameData.capacity(profile) then
		if now - (lastFullWarning[player] or 0) > 2 then
			lastFullWarning[player] = now
			Notify.toast(player, "Backpack full! Sell your ores at the Sell Shop.", Color3.fromRGB(255, 110, 110))
		end
		return
	end
	lastSwing[player] = now

	local health = (node:GetAttribute("Health") :: number) - GameData.damage(profile)
	node:SetAttribute("Health", health)
	World.UpdateBar(node)
	if health > 0 then
		return
	end

	-- Node broken: pay out.
	local ore = GameData.Ores[node:GetAttribute("OreId") :: string]
	local zone = GameData.Zones[node:GetAttribute("ZoneId") :: number]
	node:Destroy()

	local yield = if math.random() < GameData.luck(profile) then 2 else 1
	yield = math.min(yield, GameData.capacity(profile) - GameData.usedCapacity(profile))
	profile.Ores[ore.Id] = (profile.Ores[ore.Id] or 0) + yield

	Data.AddXP(player, ore.XP)
	Notify.toast(player, `+{yield} {ore.Name}`, ore.Color)
	Data.Push(player)

	task.delay(Config.NodeRespawnTime, function()
		World.SpawnNode(zone)
	end)
end

function Mining.Init()
	Remotes.Event("Mine").OnServerEvent:Connect(onMine)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		lastFullWarning[player] = nil
	end)
end

return Mining

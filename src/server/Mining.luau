--!strict
-- Mining: validates player swings, and applies damage / payouts (shared with pets).
local Players = game:GetService("Players")
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

-- Damages a node on behalf of `player`. When it breaks, pays out ore + XP and queues a respawn.
-- The caller must already have checked that the backpack has room. Returns true if it broke.
function Mining.HitNode(player: Player, profile: GameData.Profile, node: BasePart, damage: number): boolean
	if node.Parent ~= World.NodesFolder then
		return false -- already broken by someone else this frame
	end

	local health = (node:GetAttribute("Health") :: number) - damage
	node:SetAttribute("Health", health)
	World.UpdateBar(node)
	if health > 0 then
		return false
	end

	local ore = GameData.Ores[node:GetAttribute("OreId") :: string]
	local zone = GameData.Zones[node:GetAttribute("ZoneId") :: number]
	local boss = node:GetAttribute("Boss") == true
	node:Destroy()

	local base = if boss then Config.BossYield else 1
	local yield = if math.random() < GameData.luck(profile) then base * 2 else base
	yield = math.min(yield, GameData.capacity(profile) - GameData.usedCapacity(profile))
	profile.Ores[ore.Id] = (profile.Ores[ore.Id] or 0) + yield

	Data.AddXP(player, ore.XP * (if boss then Config.BossXPMult else 1))
	Notify.toast(player, `+{yield} {ore.Name}`, ore.Color)
	Data.Push(player)

	task.delay(Config.NodeRespawnTime, function()
		World.SpawnNode(zone)
	end)
	return true
end

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

	Mining.HitNode(player, profile, node, GameData.damage(profile))
end

function Mining.Init()
	Remotes.Event("Mine").OnServerEvent:Connect(onMine)
	Players.PlayerRemoving:Connect(function(player)
		lastSwing[player] = nil
		lastFullWarning[player] = nil
	end)
end

return Mining

--!strict
-- Rebirth, the daily reward, and map teleports.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameData = require(ReplicatedStorage.Shared.GameData)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Data = require(script.Parent.Data)
local Gear = require(script.Parent.Gear)
local Notify = require(script.Parent.Notify)
local Pets = require(script.Parent.Pets)
local World = require(script.Parent.World)

local Progression = {}

local RED = Color3.fromRGB(255, 110, 110)
local GOLD = Color3.fromRGB(255, 220, 60)

local lastTeleport: { [Player]: number } = {}

-- Resets level, coins, ore and upgrades in exchange for permanent coin/XP multipliers.
-- Gear, pets and rebirth count are kept.
local function onRebirth(player: Player)
	local profile = Data.Get(player)
	if not profile or not World.NearStation(player, "Rebirth") then
		return
	end
	if not GameData.canRebirth(profile) then
		Notify.toast(player, `Reach level {GameData.rebirthRequirement(profile)} to rebirth.`, RED)
		return
	end

	profile.Rebirths += 1
	profile.Level = 1
	profile.XP = 0
	profile.Coins = 0
	table.clear(profile.Ores)
	table.clear(profile.Upgrades)

	Notify.toast(
		player,
		`Reborn! Rebirth {profile.Rebirths}: x{string.format("%.2f", GameData.sellMultiplier(profile))} coins`,
		Color3.fromRGB(190, 120, 255)
	)
	World.TryEnter(player, nil)
	Gear.apply(player) -- boots upgrade is gone, so walk speed resets
	Data.Push(player)
end

local function onDaily(player: Player)
	local profile = Data.Get(player)
	if not profile then
		return
	end
	local today = GameData.dailyDay(os.time())
	if profile.LastDaily >= today then
		Notify.toast(player, "You already claimed today's reward. Come back tomorrow!", RED)
		return
	end

	local streak = if profile.LastDaily == today - 1 then profile.Streak + 1 else 1
	profile.LastDaily = today
	profile.Streak = streak

	local coins = GameData.dailyReward(streak, profile.Level)
	profile.Coins += coins
	Notify.toast(player, `Daily reward (day {streak}): {coins} coins`, GOLD)
	if GameData.dailyBonusPet(streak) then
		Pets.Grant(player, profile, GameData.EggsById.DirtEgg)
	end
	Data.Push(player)
end

local function onTeleport(player: Player, zoneId: unknown)
	if type(zoneId) ~= "number" then
		return
	end
	local now = os.clock()
	if now - (lastTeleport[player] or 0) < Config.TeleportCooldown then
		return
	end
	local zone = if zoneId == 0 then nil else GameData.Zones[zoneId]
	if zoneId ~= 0 and not zone then
		return
	end
	if World.TryEnter(player, zone) then
		lastTeleport[player] = now
	end
end

function Progression.Init()
	Remotes.Event("Rebirth").OnServerEvent:Connect(onRebirth)
	Remotes.Event("Daily").OnServerEvent:Connect(onDaily)
	Remotes.Event("Teleport").OnServerEvent:Connect(onTeleport)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastTeleport[player] = nil
	end)
end

return Progression

--!strict
-- Selling ore, forging gear, equipping gear, and buying upgrades.
-- Every request is validated against the player's real profile and distance to the right station.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameData = require(ReplicatedStorage.Shared.GameData)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Data = require(script.Parent.Data)
local Gear = require(script.Parent.Gear)
local Notify = require(script.Parent.Notify)
local World = require(script.Parent.World)

local Economy = {}

local GOLD = Color3.fromRGB(255, 220, 60)
local RED = Color3.fromRGB(255, 110, 110)
local GREEN = Color3.fromRGB(120, 235, 120)

local function nearStation(player: Player, panel: string): boolean
	local station: BasePart? = World.Stations[panel]
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not station or not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - station.Position).Magnitude <= Config.StationRange
end

local function onSell(player: Player)
	local profile = Data.Get(player)
	if not profile or not nearStation(player, "Sell") then
		return
	end
	local value = GameData.sellValue(profile)
	if value <= 0 then
		Notify.toast(player, "You have nothing to sell.", RED)
		return
	end
	profile.Coins += value
	table.clear(profile.Ores)
	Notify.toast(player, `Sold ore for {value} coins`, GOLD)
	Data.Push(player)
end

local function onForge(player: Player, recipeId: unknown)
	local recipe = if type(recipeId) == "string" then GameData.RecipesById[recipeId] else nil
	local profile = Data.Get(player)
	if not recipe or not profile or not nearStation(player, "Forge") then
		return
	end
	if profile.Owned[recipe.Id] then
		return
	end
	if profile.Coins < recipe.Coins then
		Notify.toast(player, "Not enough coins.", RED)
		return
	end
	for oreId, amount in recipe.Ores do
		if (profile.Ores[oreId] or 0) < amount then
			Notify.toast(player, `Not enough {GameData.Ores[oreId].Name}.`, RED)
			return
		end
	end

	profile.Coins -= recipe.Coins
	for oreId, amount in recipe.Ores do
		local left = (profile.Ores[oreId] or 0) - amount
		if left > 0 then
			profile.Ores[oreId] = left
		else
			profile.Ores[oreId] = nil
		end
	end
	profile.Owned[recipe.Id] = true
	if recipe.Kind == "Weapon" then
		profile.Weapon = recipe.Id
	else
		profile.Armor = recipe.Id
	end

	Notify.toast(player, `Forged {recipe.Name}!`, GREEN)
	Gear.apply(player)
	Data.Push(player)
end

local function onEquip(player: Player, recipeId: unknown)
	local recipe = if type(recipeId) == "string" then GameData.RecipesById[recipeId] else nil
	local profile = Data.Get(player)
	if not recipe or not profile or not profile.Owned[recipe.Id] then
		return
	end
	if recipe.Kind == "Weapon" then
		profile.Weapon = recipe.Id
	else
		profile.Armor = recipe.Id
	end
	Gear.apply(player)
	Data.Push(player)
end

local function onBuy(player: Player, upgradeId: unknown)
	local upgrade = if type(upgradeId) == "string" then GameData.UpgradesById[upgradeId] else nil
	local profile = Data.Get(player)
	if not upgrade or not profile or not nearStation(player, "Upgrade") then
		return
	end
	local level = profile.Upgrades[upgrade.Id] or 0
	if level >= upgrade.MaxLevel then
		return
	end
	local cost = GameData.upgradeCost(upgrade.Id, level)
	if profile.Coins < cost then
		Notify.toast(player, "Not enough coins.", RED)
		return
	end

	profile.Coins -= cost
	profile.Upgrades[upgrade.Id] = level + 1
	Notify.toast(player, `{upgrade.Name} upgraded to level {level + 1}`, GREEN)
	Gear.apply(player) -- picks up the new walk speed
	Data.Push(player)
end

function Economy.Init()
	Remotes.Event("Sell").OnServerEvent:Connect(onSell)
	Remotes.Event("Forge").OnServerEvent:Connect(onForge)
	Remotes.Event("Equip").OnServerEvent:Connect(onEquip)
	Remotes.Event("Buy").OnServerEvent:Connect(onBuy)
end

return Economy

--!strict
-- Player profiles: loading, saving, XP/levels, and replicating state to the owning client.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local GameData = require(ReplicatedStorage.Shared.GameData)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Notify = require(script.Parent.Notify)

type Profile = GameData.Profile

local Data = {}

-- GetDataStore can throw in an unpublished place; the game must still run (just without saving).
local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(Config.DataStoreName)
	end)
	if ok then
		store = result
	else
		warn(`[Data] DataStore unavailable, progress will not be saved: {result}`)
	end
end
local profiles: { [Player]: Profile } = {}
local saveAllowed: { [Player]: boolean } = {} -- false when the load failed: never overwrite real data with defaults

local loadedEvent = Instance.new("BindableEvent")
Data.PlayerLoaded = loadedEvent.Event :: RBXScriptSignal

local function keyFor(player: Player): string
	return `Player_{player.UserId}`
end

-- Builds a clean profile from whatever was stored, discarding anything unexpected.
local function reconcile(saved: any): Profile
	local profile = GameData.newProfile()
	if type(saved) ~= "table" then
		return profile
	end

	if type(saved.Coins) == "number" then
		profile.Coins = math.max(0, math.floor(saved.Coins))
	end
	if type(saved.Level) == "number" then
		profile.Level = math.clamp(math.floor(saved.Level), 1, GameData.MaxLevel)
	end
	if type(saved.XP) == "number" then
		profile.XP = math.max(0, math.floor(saved.XP))
	end
	if type(saved.Ores) == "table" then
		for id, count in saved.Ores do
			if GameData.Ores[id] and type(count) == "number" and count > 0 then
				profile.Ores[id] = math.floor(count)
			end
		end
	end
	if type(saved.Upgrades) == "table" then
		for id, level in saved.Upgrades do
			local upgrade = GameData.UpgradesById[id]
			if upgrade and type(level) == "number" then
				profile.Upgrades[id] = math.clamp(math.floor(level), 0, upgrade.MaxLevel)
			end
		end
	end
	if type(saved.Owned) == "table" then
		for id, owned in saved.Owned do
			if GameData.RecipesById[id] and owned == true then
				profile.Owned[id] = true
			end
		end
	end
	if type(saved.Rebirths) == "number" then
		profile.Rebirths = math.clamp(math.floor(saved.Rebirths), 0, GameData.MaxRebirths)
	end
	if type(saved.LastDaily) == "number" then
		profile.LastDaily = math.max(0, math.floor(saved.LastDaily))
	end
	if type(saved.Streak) == "number" then
		profile.Streak = math.max(0, math.floor(saved.Streak))
	end
	if type(saved.Pets) == "table" then
		for id, count in saved.Pets do
			if GameData.PetsById[id] and type(count) == "number" and count > 0 then
				profile.Pets[id] = math.floor(count)
			end
		end
	end
	if type(saved.EquippedPets) == "table" then
		local used: { [string]: number } = {}
		for _, id in saved.EquippedPets do
			if
				type(id) == "string"
				and (profile.Pets[id] or 0) > (used[id] or 0)
				and #profile.EquippedPets < GameData.maxPets(profile)
			then
				used[id] = (used[id] or 0) + 1
				table.insert(profile.EquippedPets, id)
			end
		end
	end
	for _, field in { "Weapon", "Armor" } do
		local id = saved[field]
		local recipe = if type(id) == "string" then GameData.RecipesById[id] else nil
		if recipe and recipe.Kind == field and profile.Owned[id] then
			(profile :: any)[field] = id
		end
	end
	return profile
end

local function loadProfile(player: Player): (boolean, Profile)
	local activeStore = store
	if not activeStore then
		return false, GameData.newProfile()
	end
	local attempts = if RunService:IsStudio() then 1 else 3
	for attempt = 1, attempts do
		local ok, result = pcall(function()
			return activeStore:GetAsync(keyFor(player))
		end)
		if ok then
			return true, reconcile(result)
		end
		warn(`[Data] load failed for {player.Name} (attempt {attempt}): {result}`)
		if attempt < attempts then
			task.wait(attempt)
		end
	end
	return false, GameData.newProfile()
end

function Data.Save(player: Player)
	local profile = profiles[player]
	local activeStore = store
	if not profile or not activeStore or not saveAllowed[player] then
		return
	end
	local ok, err = pcall(function()
		activeStore:UpdateAsync(keyFor(player), function()
			return profile
		end)
	end)
	if not ok then
		warn(`[Data] save failed for {player.Name}: {err}`)
	end
end

function Data.Get(player: Player): Profile?
	return profiles[player]
end

-- The table sent to the client: raw profile plus every derived stat the UI shows.
function Data.Snapshot(profile: Profile): { [string]: any }
	local now = os.time()
	local today = GameData.dailyDay(now)
	local dailyReady = profile.LastDaily < today
	local nextStreak = if profile.LastDaily == today - 1 then profile.Streak + 1 else 1
	return {
		Coins = profile.Coins,
		XP = profile.XP,
		Level = profile.Level,
		XPNeeded = if profile.Level >= GameData.MaxLevel then 0 else GameData.xpForLevel(profile.Level),
		Ores = profile.Ores,
		Upgrades = profile.Upgrades,
		Owned = profile.Owned,
		Weapon = profile.Weapon,
		Armor = profile.Armor,
		Damage = GameData.damage(profile),
		Defense = GameData.defense(profile),
		Capacity = GameData.capacity(profile),
		Used = GameData.usedCapacity(profile),
		Cooldown = GameData.cooldown(profile),
		Luck = GameData.luck(profile),
		SellValue = GameData.sellValue(profile),
		SellMultiplier = GameData.sellMultiplier(profile),
		XPMultiplier = GameData.xpMultiplier(profile),
		Rebirths = profile.Rebirths,
		RebirthLevel = GameData.rebirthRequirement(profile),
		CanRebirth = GameData.canRebirth(profile),
		Pets = profile.Pets,
		EquippedPets = profile.EquippedPets,
		MaxPets = GameData.maxPets(profile),
		DailyReady = dailyReady,
		DailyStreak = profile.Streak,
		DailyNextStreak = nextStreak,
		DailyReward = GameData.dailyReward(nextStreak, profile.Level),
		DailyBonusPet = GameData.dailyBonusPet(nextStreak),
		DailyResetIn = (today + 1) * 86400 - now,
	}
end

-- Pushes the latest profile to its owner and refreshes the leaderboard.
function Data.Push(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	Remotes.Event("State"):FireClient(player, Data.Snapshot(profile))

	local stats = player:FindFirstChild("leaderstats")
	if stats then
		local level = stats:FindFirstChild("Level") :: IntValue?
		local coins = stats:FindFirstChild("Coins") :: IntValue?
		if level then
			level.Value = profile.Level
		end
		if coins then
			coins.Value = profile.Coins
		end
	end
end

-- Adds XP, handling multiple level-ups at once. Does not push; callers do.
function Data.AddXP(player: Player, amount: number)
	local profile = profiles[player]
	if not profile or profile.Level >= GameData.MaxLevel then
		return
	end

	profile.XP += math.floor(amount * GameData.xpMultiplier(profile))
	while profile.Level < GameData.MaxLevel and profile.XP >= GameData.xpForLevel(profile.Level) do
		profile.XP -= GameData.xpForLevel(profile.Level)
		profile.Level += 1
		Notify.toast(player, `Level up! You are now level {profile.Level}`, Color3.fromRGB(255, 220, 60))
		for _, zone in GameData.Zones do
			if zone.RequiredLevel == profile.Level then
				Notify.toast(player, `Zone unlocked: {zone.Name}`, zone.DifficultyColor)
			end
		end
	end
	if profile.Level >= GameData.MaxLevel then
		profile.XP = 0
	end
end

local function createLeaderstats(player: Player)
	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"

	local level = Instance.new("IntValue")
	level.Name = "Level"
	level.Value = 1
	level.Parent = stats

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = 0
	coins.Parent = stats

	stats.Parent = player
end

local function onPlayerAdded(player: Player)
	createLeaderstats(player)

	local ok, profile = loadProfile(player)
	if not player.Parent then
		return -- left while loading
	end
	profiles[player] = profile
	saveAllowed[player] = ok
	if not ok then
		Notify.toast(
			player,
			"Couldn't load your saved data. Progress this session won't be saved.",
			Color3.fromRGB(255, 90, 90)
		)
	end

	Data.Push(player)
	loadedEvent:Fire(player)
end

local function onPlayerRemoving(player: Player)
	Data.Save(player)
	profiles[player] = nil
	saveAllowed[player] = nil
end

function Data.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- The client asks for its state on startup, in case it missed the first push.
	Remotes.Function("GetState").OnServerInvoke = function(player: Player)
		local waited = 0
		while not profiles[player] and waited < 30 do
			waited += task.wait(0.25)
		end
		local profile = profiles[player]
		return if profile then Data.Snapshot(profile) else nil
	end

	task.spawn(function()
		while true do
			task.wait(Config.AutosaveInterval)
			for player in profiles do
				task.spawn(Data.Save, player)
			end
		end
	end)

	game:BindToClose(function()
		for player in profiles do
			task.spawn(Data.Save, player)
		end
		if not RunService:IsStudio() then
			task.wait(3)
		end
	end)
end

return Data

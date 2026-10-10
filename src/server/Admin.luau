--!strict
-- Admin tools: give items, spawn nodes, teleport, and so on.
-- Everything is authorised and validated here on the server. A client can fire the remote with
-- anything it likes; non-admins are ignored and every argument is type-checked and clamped.
-- Who counts as an admin: Studio sessions, the place owner (user-owned places), and the user ids
-- listed in Config.Admins.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local GameData = require(ReplicatedStorage.Shared.GameData)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Data = require(script.Parent.Data)
local Gear = require(script.Parent.Gear)
local Notify = require(script.Parent.Notify)
local Pets = require(script.Parent.Pets)
local World = require(script.Parent.World)

local Admin = {}

type Args = { [string]: any }
type Handler = (player: Player, profile: GameData.Profile, args: Args) -> (boolean, string)

local admins: { [Player]: boolean } = {}

local GREEN = Color3.fromRGB(120, 235, 120)
local RED = Color3.fromRGB(255, 110, 110)

local function checkAdmin(player: Player): boolean
	if RunService:IsStudio() then
		return true
	end
	if table.find(Config.Admins, player.UserId) then
		return true
	end
	-- User-owned places: the owner is an admin. For group-owned places, list admins in Config.Admins.
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

function Admin.IsAdmin(player: Player): boolean
	return admins[player] == true
end

-- A whole number within [min, max], or nil if the value isn't a usable number.
local function int(value: unknown, min: number, max: number): number?
	if type(value) ~= "number" or value ~= value then
		return nil
	end
	return math.clamp(math.floor(value), min, max)
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function trimPets(profile: GameData.Profile)
	while #profile.EquippedPets > GameData.maxPets(profile) do
		table.remove(profile.EquippedPets)
	end
end

local handlers: { [string]: Handler } = {}

handlers.coins = function(_, profile, args)
	local amount = int(args.amount, -1e12, 1e12)
	if not amount then
		return false, "Enter a valid amount."
	end
	profile.Coins = math.max(0, profile.Coins + amount)
	return true, `Coins {if amount >= 0 then "+" else ""}{amount}`
end

handlers.xp = function(player, _, args)
	local amount = int(args.amount, 0, 1e9)
	if not amount then
		return false, "Enter a valid amount."
	end
	Data.AddXP(player, amount)
	return true, `Gave {amount} XP`
end

handlers.level = function(_, profile, args)
	local level = int(args.amount, 1, GameData.MaxLevel)
	if not level then
		return false, "Enter a level."
	end
	profile.Level = level
	profile.XP = 0
	return true, `Level set to {level}`
end

handlers.rebirths = function(player, profile, args)
	local count = int(args.amount, 0, GameData.MaxRebirths)
	if not count then
		return false, "Enter a rebirth count."
	end
	profile.Rebirths = count
	trimPets(profile)
	Pets.Refresh(player)
	return true, `Rebirths set to {count}`
end

handlers.ore = function(_, profile, args)
	local id = args.id
	local amount = int(args.amount, 1, 1e6)
	if type(id) ~= "string" or not GameData.Ores[id] or not amount then
		return false, "Pick an ore and an amount."
	end
	profile.Ores[id] = (profile.Ores[id] or 0) + amount
	return true, `Gave {amount} {GameData.Ores[id].Name}`
end

handlers.gear = function(player, profile, args)
	local id = args.id
	local recipe = if type(id) == "string" then GameData.RecipesById[id] else nil
	if not recipe then
		return false, "Unknown gear."
	end
	profile.Owned[recipe.Id] = true
	if recipe.Kind == "Weapon" then
		profile.Weapon = recipe.Id
	else
		profile.Armor = recipe.Id
	end
	Gear.apply(player)
	return true, `Granted {recipe.Name}`
end

handlers.pet = function(player, profile, args)
	local id = args.id
	local pet = if type(id) == "string" then GameData.PetsById[id] else nil
	local amount = int(args.amount, 1, 99)
	if not pet or not amount then
		return false, "Unknown pet."
	end
	profile.Pets[pet.Id] = (profile.Pets[pet.Id] or 0) + amount
	for _ = 1, amount do
		if #profile.EquippedPets < GameData.maxPets(profile) then
			table.insert(profile.EquippedPets, pet.Id)
		end
	end
	Pets.Refresh(player)
	return true, `Granted {amount}x {pet.Name}`
end

handlers.maxupgrades = function(player, profile)
	for _, upgrade in GameData.Upgrades do
		profile.Upgrades[upgrade.Id] = upgrade.MaxLevel
	end
	Gear.apply(player)
	return true, "All upgrades maxed"
end

handlers.clearbag = function(_, profile)
	table.clear(profile.Ores)
	return true, "Backpack emptied"
end

handlers.reset = function(player, profile)
	for key in profile do
		(profile :: any)[key] = nil
	end
	for key, value in GameData.newProfile() do
		(profile :: any)[key] = value
	end
	player:SetAttribute("AdminSpeed", nil)
	Gear.apply(player)
	Pets.Refresh(player)
	return true, "Your data was reset"
end

handlers.heal = function(player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid then
		return false, "No character."
	end
	humanoid.Health = humanoid.MaxHealth
	return true, "Healed"
end

handlers.god = function(player)
	local enabled = player:GetAttribute("God") ~= true
	player:SetAttribute("God", if enabled then true else nil)
	Gear.apply(player)
	return true, `God mode {if enabled then "on" else "off"}`
end

handlers.speed = function(player, _, args)
	local speed = int(args.amount, 0, 200)
	if not speed then
		return false, "Enter a speed (0 resets)."
	end
	player:SetAttribute("AdminSpeed", if speed > 0 then speed else nil)
	Gear.apply(player)
	return true, if speed > 0 then `Walk speed {speed}` else "Walk speed reset"
end

handlers.tp = function(player, _, args)
	local zoneId = int(args.zoneId, 0, #GameData.Zones)
	if not zoneId then
		return false, "Unknown destination."
	end
	World.TeleportTo(player, if zoneId == 0 then nil else GameData.Zones[zoneId])
	return true, if zoneId == 0 then "Teleported to the hub" else `Teleported to {GameData.Zones[zoneId].Name}`
end

handlers.spawnnode = function(player, _, args)
	local id = args.oreId
	local root = rootOf(player)
	if type(id) ~= "string" or not GameData.Ores[id] or not root then
		return false, "Pick an ore (and be alive)."
	end
	local ahead = root.Position + root.CFrame.LookVector * 12
	local zone = World.ZoneAt(root.Position) or GameData.Zones[1]
	World.SpawnNode(zone, {
		OreId = id,
		Boss = args.boss == true,
		Position = Vector3.new(ahead.X, 0, ahead.Z),
		NoRespawn = true,
	})
	return true, `Spawned {if args.boss == true then "a Rich " else "a "}{GameData.Ores[id].Name} node`
end

local function onAdmin(player: Player, command: unknown, args: unknown)
	if not admins[player] or type(command) ~= "string" then
		return
	end
	local handler = handlers[command]
	local profile = Data.Get(player)
	if not handler or not profile then
		return
	end

	local arguments: Args = if type(args) == "table" then args :: any else {}
	local ok, message = handler(player, profile, arguments)
	Notify.toast(player, message, if ok then GREEN else RED)
	if ok then
		Data.Push(player)
	end
	print(`[Admin] {player.Name} ran {command}: {message}`)
end

local function register(player: Player)
	task.spawn(function()
		local isAdmin = checkAdmin(player)
		if player.Parent then
			admins[player] = isAdmin
			player:SetAttribute("IsAdmin", isAdmin) -- only controls whether the client shows the button
		end
	end)
end

function Admin.Init()
	Remotes.Event("Admin").OnServerEvent:Connect(onAdmin)
	Players.PlayerAdded:Connect(register)
	for _, player in Players:GetPlayers() do
		register(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		admins[player] = nil
	end)
end

return Admin

--!strict
-- All static game content (ores, zones, recipes, upgrades) and the formulas
-- derived from it. Shared so the client can preview exactly what the server computes.

export type Ore = {
	Id: string,
	Name: string,
	Value: number, -- coins when sold
	Health: number, -- damage needed to break the node
	XP: number,
	Color: Color3,
	Material: Enum.Material,
}

export type Zone = {
	Id: number,
	Name: string,
	Difficulty: string,
	DifficultyColor: Color3,
	RequiredLevel: number,
	Hazard: number, -- damage per second before armor reduction
	Floor: Color3,
	FloorMaterial: Enum.Material,
	Ores: { { Id: string, Weight: number } },
}

export type Recipe = {
	Id: string,
	Name: string,
	Kind: "Weapon" | "Armor",
	Stat: number, -- weapon: % mining damage bonus, armor: % hazard reduction
	Coins: number,
	Ores: { [string]: number },
	Color: Color3,
}

export type Pet = {
	Id: string,
	Name: string,
	Rarity: string,
	Power: number, -- damage dealt per attack
	Color: Color3,
}

export type Egg = {
	Id: string,
	Name: string,
	Cost: number,
	Color: Color3,
	Pets: { { Id: string, Weight: number } },
}

export type Upgrade = {
	Id: string,
	Name: string,
	Description: string,
	MaxLevel: number,
	BaseCost: number,
	CostGrowth: number,
}

local GameData = {}

GameData.MaxLevel = 60

-- Ores, ordered roughly by tier --------------------------------------------------------------

local oreList: { Ore } = {
	{
		Id = "Stone",
		Name = "Stone",
		Value = 2,
		Health = 15,
		XP = 2,
		Color = Color3.fromRGB(135, 135, 140),
		Material = Enum.Material.Slate,
	},
	{
		Id = "Coal",
		Name = "Coal",
		Value = 5,
		Health = 30,
		XP = 4,
		Color = Color3.fromRGB(40, 40, 45),
		Material = Enum.Material.Slate,
	},
	{
		Id = "Copper",
		Name = "Copper",
		Value = 12,
		Health = 60,
		XP = 8,
		Color = Color3.fromRGB(205, 125, 70),
		Material = Enum.Material.Metal,
	},
	{
		Id = "Iron",
		Name = "Iron",
		Value = 30,
		Health = 120,
		XP = 14,
		Color = Color3.fromRGB(180, 180, 190),
		Material = Enum.Material.Metal,
	},
	{
		Id = "Silver",
		Name = "Silver",
		Value = 70,
		Health = 250,
		XP = 26,
		Color = Color3.fromRGB(225, 232, 240),
		Material = Enum.Material.Metal,
	},
	{
		Id = "Gold",
		Name = "Gold",
		Value = 150,
		Health = 450,
		XP = 45,
		Color = Color3.fromRGB(255, 205, 40),
		Material = Enum.Material.Metal,
	},
	{
		Id = "Crystal",
		Name = "Crystal",
		Value = 320,
		Health = 900,
		XP = 80,
		Color = Color3.fromRGB(110, 210, 255),
		Material = Enum.Material.Glass,
	},
	{
		Id = "Obsidian",
		Name = "Obsidian",
		Value = 700,
		Health = 1800,
		XP = 140,
		Color = Color3.fromRGB(70, 30, 110),
		Material = Enum.Material.Glass,
	},
	{
		Id = "Mythril",
		Name = "Mythril",
		Value = 1500,
		Health = 3600,
		XP = 240,
		Color = Color3.fromRGB(80, 255, 190),
		Material = Enum.Material.Neon,
	},
	{
		Id = "Voidstone",
		Name = "Voidstone",
		Value = 3500,
		Health = 7500,
		XP = 400,
		Color = Color3.fromRGB(200, 40, 255),
		Material = Enum.Material.Neon,
	},
	{
		Id = "Starmetal",
		Name = "Starmetal",
		Value = 8000,
		Health = 15000,
		XP = 650,
		Color = Color3.fromRGB(190, 220, 255),
		Material = Enum.Material.Neon,
	},
	{
		Id = "Eclipsium",
		Name = "Eclipsium",
		Value = 18000,
		Health = 32000,
		XP = 1100,
		Color = Color3.fromRGB(255, 120, 20),
		Material = Enum.Material.Neon,
	},
}

GameData.OreOrder = oreList
GameData.Ores = {} :: { [string]: Ore }
for _, ore in oreList do
	GameData.Ores[ore.Id] = ore
end

-- Zones (normal -> extreme) ----------------------------------------------------------------------

local function zone(
	id: number,
	name: string,
	difficulty: string,
	difficultyColor: Color3,
	level: number,
	hazard: number,
	floorColor: Color3,
	floorMaterial: Enum.Material,
	ores: { { Id: string, Weight: number } }
): Zone
	return {
		Id = id,
		Name = name,
		Difficulty = difficulty,
		DifficultyColor = difficultyColor,
		RequiredLevel = level,
		Hazard = hazard,
		Floor = floorColor,
		FloorMaterial = floorMaterial,
		Ores = ores,
	}
end

GameData.Zones = {
	zone(
		1,
		"Sunny Quarry",
		"Normal",
		Color3.fromRGB(110, 220, 110),
		1,
		0,
		Color3.fromRGB(95, 150, 85),
		Enum.Material.Grass,
		{
			{ Id = "Stone", Weight = 60 },
			{ Id = "Coal", Weight = 30 },
			{ Id = "Copper", Weight = 10 },
		}
	),
	zone(
		2,
		"Iron Caverns",
		"Tough",
		Color3.fromRGB(230, 220, 90),
		5,
		0,
		Color3.fromRGB(95, 90, 90),
		Enum.Material.Slate,
		{
			{ Id = "Coal", Weight = 30 },
			{ Id = "Copper", Weight = 40 },
			{ Id = "Iron", Weight = 30 },
		}
	),
	zone(
		3,
		"Silver Ridge",
		"Hard",
		Color3.fromRGB(245, 170, 70),
		10,
		0,
		Color3.fromRGB(150, 150, 160),
		Enum.Material.Concrete,
		{
			{ Id = "Iron", Weight = 40 },
			{ Id = "Silver", Weight = 40 },
			{ Id = "Gold", Weight = 20 },
		}
	),
	zone(
		4,
		"Crystal Depths",
		"Brutal",
		Color3.fromRGB(245, 110, 70),
		16,
		3,
		Color3.fromRGB(60, 110, 150),
		Enum.Material.Ice,
		{
			{ Id = "Silver", Weight = 10 },
			{ Id = "Gold", Weight = 40 },
			{ Id = "Crystal", Weight = 50 },
		}
	),
	zone(
		5,
		"Magma Fields",
		"Extreme",
		Color3.fromRGB(235, 50, 50),
		24,
		8,
		Color3.fromRGB(110, 40, 25),
		Enum.Material.Basalt,
		{
			{ Id = "Gold", Weight = 10 },
			{ Id = "Crystal", Weight = 40 },
			{ Id = "Obsidian", Weight = 50 },
		}
	),
	zone(
		6,
		"Frozen Abyss",
		"Insane",
		Color3.fromRGB(190, 70, 220),
		34,
		15,
		Color3.fromRGB(170, 205, 235),
		Enum.Material.Snow,
		{
			{ Id = "Crystal", Weight = 10 },
			{ Id = "Obsidian", Weight = 40 },
			{ Id = "Mythril", Weight = 50 },
		}
	),
	zone(
		7,
		"Void Core",
		"Nightmare",
		Color3.fromRGB(150, 40, 255),
		45,
		25,
		Color3.fromRGB(20, 10, 35),
		Enum.Material.Slate,
		{
			{ Id = "Mythril", Weight = 45 },
			{ Id = "Voidstone", Weight = 55 },
		}
	),
	zone(
		8,
		"Sky Citadel",
		"Cataclysm",
		Color3.fromRGB(255, 80, 150),
		52,
		45,
		Color3.fromRGB(205, 215, 235),
		Enum.Material.Marble,
		{
			{ Id = "Voidstone", Weight = 30 },
			{ Id = "Starmetal", Weight = 70 },
		}
	),
	zone(
		9,
		"Eclipse Rift",
		"Impossible",
		Color3.fromRGB(255, 140, 20),
		60,
		70,
		Color3.fromRGB(25, 12, 8),
		Enum.Material.Basalt,
		{
			{ Id = "Starmetal", Weight = 40 },
			{ Id = "Eclipsium", Weight = 60 },
		}
	),
} :: { Zone }

-- Forge recipes ------------------------------------------------------------------------------------

local function recipe(
	id: string,
	name: string,
	kind: "Weapon" | "Armor",
	stat: number,
	coins: number,
	ores: { [string]: number },
	color: Color3
): Recipe
	return { Id = id, Name = name, Kind = kind, Stat = stat, Coins = coins, Ores = ores, Color = color }
end

GameData.Recipes = {
	-- Weapons: Stat = % bonus to mining damage.
	recipe("CopperSword", "Copper Sword", "Weapon", 25, 150, { Copper = 8, Stone = 12 }, Color3.fromRGB(205, 125, 70)),
	recipe("IronSword", "Iron Sword", "Weapon", 60, 600, { Iron = 10, Coal = 15 }, Color3.fromRGB(180, 180, 190)),
	recipe(
		"SilverBlade",
		"Silver Blade",
		"Weapon",
		110,
		2500,
		{ Silver = 10, Iron = 10 },
		Color3.fromRGB(225, 232, 240)
	),
	recipe(
		"GoldenCutlass",
		"Golden Cutlass",
		"Weapon",
		180,
		8000,
		{ Gold = 10, Silver = 8 },
		Color3.fromRGB(255, 205, 40)
	),
	recipe(
		"CrystalEdge",
		"Crystal Edge",
		"Weapon",
		300,
		25000,
		{ Crystal = 12, Gold = 8 },
		Color3.fromRGB(110, 210, 255)
	),
	recipe(
		"ObsidianCleaver",
		"Obsidian Cleaver",
		"Weapon",
		500,
		80000,
		{ Obsidian = 12, Crystal = 8 },
		Color3.fromRGB(70, 30, 110)
	),
	recipe(
		"MythrilGreatsword",
		"Mythril Greatsword",
		"Weapon",
		800,
		250000,
		{ Mythril = 15, Obsidian = 10 },
		Color3.fromRGB(80, 255, 190)
	),
	recipe(
		"Voidreaver",
		"Voidreaver",
		"Weapon",
		1300,
		800000,
		{ Voidstone = 20, Mythril = 12 },
		Color3.fromRGB(200, 40, 255)
	),
	recipe(
		"StarforgedBlade",
		"Starforged Blade",
		"Weapon",
		2000,
		2500000,
		{ Starmetal = 20, Voidstone = 15 },
		Color3.fromRGB(190, 220, 255)
	),
	recipe(
		"EclipseReaper",
		"Eclipse Reaper",
		"Weapon",
		3200,
		8000000,
		{ Eclipsium = 24, Starmetal = 15 },
		Color3.fromRGB(255, 120, 20)
	),
	-- Armor: Stat = % hazard damage reduction (capped at 95 when used).
	recipe("CopperArmor", "Copper Armor", "Armor", 10, 200, { Copper = 10, Stone = 15 }, Color3.fromRGB(205, 125, 70)),
	recipe("IronArmor", "Iron Armor", "Armor", 25, 800, { Iron = 12, Coal = 18 }, Color3.fromRGB(180, 180, 190)),
	recipe("SilverArmor", "Silver Armor", "Armor", 40, 3000, { Silver = 12, Iron = 12 }, Color3.fromRGB(225, 232, 240)),
	recipe("GoldenArmor", "Golden Armor", "Armor", 52, 10000, { Gold = 12, Silver = 10 }, Color3.fromRGB(255, 205, 40)),
	recipe(
		"CrystalArmor",
		"Crystal Armor",
		"Armor",
		64,
		30000,
		{ Crystal = 14, Gold = 10 },
		Color3.fromRGB(110, 210, 255)
	),
	recipe(
		"ObsidianArmor",
		"Obsidian Armor",
		"Armor",
		75,
		100000,
		{ Obsidian = 14, Crystal = 10 },
		Color3.fromRGB(70, 30, 110)
	),
	recipe(
		"MythrilArmor",
		"Mythril Armor",
		"Armor",
		84,
		300000,
		{ Mythril = 18, Obsidian = 12 },
		Color3.fromRGB(80, 255, 190)
	),
	recipe(
		"VoidPlate",
		"Void Plate",
		"Armor",
		90,
		900000,
		{ Voidstone = 24, Mythril = 14 },
		Color3.fromRGB(200, 40, 255)
	),
	recipe(
		"StarmetalPlate",
		"Starmetal Plate",
		"Armor",
		93,
		3000000,
		{ Starmetal = 24, Voidstone = 16 },
		Color3.fromRGB(190, 220, 255)
	),
	recipe(
		"EclipseAegis",
		"Eclipse Aegis",
		"Armor",
		95,
		9000000,
		{ Eclipsium = 28, Starmetal = 18 },
		Color3.fromRGB(255, 120, 20)
	),
} :: { Recipe }

GameData.RecipesById = {} :: { [string]: Recipe }
for _, r in GameData.Recipes do
	GameData.RecipesById[r.Id] = r
end

-- Pets & eggs ----------------------------------------------------------------------------------------------

GameData.RarityColors = {
	Common = Color3.fromRGB(190, 190, 190),
	Uncommon = Color3.fromRGB(110, 220, 110),
	Rare = Color3.fromRGB(80, 150, 255),
	Epic = Color3.fromRGB(180, 90, 255),
	Legendary = Color3.fromRGB(255, 170, 40),
	Mythic = Color3.fromRGB(255, 70, 120),
} :: { [string]: Color3 }

local function pet(id: string, name: string, rarity: string, power: number, color: Color3): Pet
	return { Id = id, Name = name, Rarity = rarity, Power = power, Color = color }
end

GameData.Pets = {
	pet("PebblePup", "Pebble Pup", "Common", 6, Color3.fromRGB(150, 150, 155)),
	pet("ClayMole", "Clay Mole", "Common", 9, Color3.fromRGB(170, 120, 90)),
	pet("CopperCat", "Copper Cat", "Uncommon", 18, Color3.fromRGB(205, 125, 70)),
	pet("IronFox", "Iron Fox", "Rare", 40, Color3.fromRGB(190, 190, 205)),
	pet("SilverWolf", "Silver Wolf", "Common", 150, Color3.fromRGB(225, 232, 240)),
	pet("GoldRam", "Gold Ram", "Uncommon", 270, Color3.fromRGB(255, 205, 40)),
	pet("CrystalStag", "Crystal Stag", "Rare", 550, Color3.fromRGB(110, 210, 255)),
	pet("PrismDragon", "Prism Dragon", "Epic", 1100, Color3.fromRGB(255, 150, 255)),
	pet("ObsidianBear", "Obsidian Bear", "Rare", 1500, Color3.fromRGB(90, 40, 140)),
	pet("MythrilGriffin", "Mythril Griffin", "Epic", 3000, Color3.fromRGB(80, 255, 190)),
	pet("VoidPhoenix", "Void Phoenix", "Legendary", 6500, Color3.fromRGB(200, 40, 255)),
	pet("StarbornWyrm", "Starborn Wyrm", "Mythic", 15000, Color3.fromRGB(190, 220, 255)),
} :: { Pet }

GameData.PetsById = {} :: { [string]: Pet }
for _, p in GameData.Pets do
	GameData.PetsById[p.Id] = p
end

local function egg(id: string, name: string, cost: number, color: Color3, pets: { { Id: string, Weight: number } }): Egg
	return { Id = id, Name = name, Cost = cost, Color = color, Pets = pets }
end

GameData.Eggs = {
	egg("DirtEgg", "Dirt Egg", 1000, Color3.fromRGB(150, 110, 80), {
		{ Id = "PebblePup", Weight = 50 },
		{ Id = "ClayMole", Weight = 30 },
		{ Id = "CopperCat", Weight = 15 },
		{ Id = "IronFox", Weight = 5 },
	}),
	egg("CrystalEgg", "Crystal Egg", 40000, Color3.fromRGB(110, 210, 255), {
		{ Id = "SilverWolf", Weight = 50 },
		{ Id = "GoldRam", Weight = 30 },
		{ Id = "CrystalStag", Weight = 15 },
		{ Id = "PrismDragon", Weight = 5 },
	}),
	egg("VoidEgg", "Void Egg", 1500000, Color3.fromRGB(200, 40, 255), {
		{ Id = "ObsidianBear", Weight = 50 },
		{ Id = "MythrilGriffin", Weight = 30 },
		{ Id = "VoidPhoenix", Weight = 15 },
		{ Id = "StarbornWyrm", Weight = 5 },
	}),
} :: { Egg }

GameData.EggsById = {} :: { [string]: Egg }
for _, e in GameData.Eggs do
	GameData.EggsById[e.Id] = e
end

-- Upgrades -------------------------------------------------------------------------------------------

GameData.Upgrades = {
	{
		Id = "Pickaxe",
		Name = "Pickaxe Power",
		Description = "+3 base mining damage",
		MaxLevel = 30,
		BaseCost = 30,
		CostGrowth = 1.35,
	},
	{
		Id = "Backpack",
		Name = "Backpack Size",
		Description = "+10 ore capacity",
		MaxLevel = 25,
		BaseCost = 40,
		CostGrowth = 1.3,
	},
	{
		Id = "Speed",
		Name = "Mining Speed",
		Description = "-0.04s between swings",
		MaxLevel = 12,
		BaseCost = 100,
		CostGrowth = 1.6,
	},
	{
		Id = "Luck",
		Name = "Lucky Strike",
		Description = "+3% chance for double ore",
		MaxLevel = 15,
		BaseCost = 250,
		CostGrowth = 1.5,
	},
	{
		Id = "Merchant",
		Name = "Merchant",
		Description = "+5% coins from selling",
		MaxLevel = 20,
		BaseCost = 200,
		CostGrowth = 1.5,
	},
	{
		Id = "Boots",
		Name = "Swift Boots",
		Description = "+1 walk speed",
		MaxLevel = 10,
		BaseCost = 150,
		CostGrowth = 1.45,
	},
} :: { Upgrade }

GameData.UpgradesById = {} :: { [string]: Upgrade }
for _, u in GameData.Upgrades do
	GameData.UpgradesById[u.Id] = u
end

-- Formulas --------------------------------------------------------------------------------------------

-- A plain data table; mirrors what the DataStore saves.
export type Profile = {
	Coins: number,
	XP: number,
	Level: number,
	Ores: { [string]: number },
	Upgrades: { [string]: number },
	Owned: { [string]: boolean },
	Weapon: string,
	Armor: string,
	Rebirths: number,
	Pets: { [string]: number }, -- pet id -> how many owned
	EquippedPets: { string }, -- pet ids (may repeat if owned more than once)
	LastDaily: number, -- day index (UTC) of the last claimed daily reward
	Streak: number,
}

GameData.MaxRebirths = 8
GameData.RebirthCoinBonus = 0.25 -- per rebirth
GameData.RebirthXPBonus = 0.2 -- per rebirth

function GameData.xpForLevel(level: number): number
	return math.floor(10 * level ^ 1.8)
end

function GameData.upgradeCost(id: string, currentLevel: number): number
	local u = GameData.UpgradesById[id]
	return math.floor(u.BaseCost * u.CostGrowth ^ currentLevel)
end

local function upgradeLevel(profile: Profile, id: string): number
	return profile.Upgrades[id] or 0
end

function GameData.weaponBonus(profile: Profile): number
	local r = GameData.RecipesById[profile.Weapon]
	return if r then r.Stat else 0
end

function GameData.defense(profile: Profile): number
	local r = GameData.RecipesById[profile.Armor]
	return if r then math.min(95, r.Stat) else 0
end

function GameData.damage(profile: Profile): number
	local base = 4 + 3 * upgradeLevel(profile, "Pickaxe")
	return base * (1 + GameData.weaponBonus(profile) / 100)
end

function GameData.capacity(profile: Profile): number
	return 20 + 10 * upgradeLevel(profile, "Backpack")
end

function GameData.cooldown(profile: Profile): number
	return 0.8 - 0.04 * upgradeLevel(profile, "Speed")
end

function GameData.luck(profile: Profile): number
	return 0.03 * upgradeLevel(profile, "Luck")
end

function GameData.sellMultiplier(profile: Profile): number
	return (1 + 0.05 * upgradeLevel(profile, "Merchant")) * (1 + GameData.RebirthCoinBonus * profile.Rebirths)
end

function GameData.xpMultiplier(profile: Profile): number
	return 1 + GameData.RebirthXPBonus * profile.Rebirths
end

function GameData.rebirthRequirement(profile: Profile): number
	return 20 + 5 * profile.Rebirths
end

function GameData.canRebirth(profile: Profile): boolean
	return profile.Rebirths < GameData.MaxRebirths and profile.Level >= GameData.rebirthRequirement(profile)
end

function GameData.maxPets(profile: Profile): number
	return 3 + math.min(profile.Rebirths, 3)
end

function GameData.dailyDay(now: number): number
	return math.floor(now / 86400)
end

function GameData.dailyReward(streak: number, level: number): number
	return math.floor(200 * math.min(streak, 7) * (1 + level / 4))
end

-- Every 7th day in a row also grants a free Dirt Egg pet.
function GameData.dailyBonusPet(streak: number): boolean
	return streak % 7 == 0
end

function GameData.walkSpeed(profile: Profile): number
	return 16 + upgradeLevel(profile, "Boots")
end

function GameData.usedCapacity(profile: Profile): number
	local total = 0
	for _, count in profile.Ores do
		total += count
	end
	return total
end

function GameData.sellValue(profile: Profile): number
	local total = 0
	for id, count in profile.Ores do
		local ore = GameData.Ores[id]
		if ore then
			total += ore.Value * count
		end
	end
	return math.floor(total * GameData.sellMultiplier(profile))
end

function GameData.newProfile(): Profile
	return {
		Coins = 0,
		XP = 0,
		Level = 1,
		Ores = {},
		Upgrades = {},
		Owned = {},
		Weapon = "",
		Armor = "",
		Rebirths = 0,
		Pets = {},
		EquippedPets = {},
		LastDaily = 0,
		Streak = 0,
	}
end

return GameData

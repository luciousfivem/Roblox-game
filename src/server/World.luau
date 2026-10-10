--!strict
-- Builds the hub, the stations, the zone platforms, portals, and ore nodes.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GameData = require(ReplicatedStorage.Shared.GameData)
local Data = require(script.Parent.Data)
local NodeModels = require(script.Parent.NodeModels)
local Notify = require(script.Parent.Notify)

type Zone = GameData.Zone

export type SpawnOptions = { OreId: string?, Boss: boolean?, Position: Vector3?, NoRespawn: boolean? }

local World = {}

World.NodesFolder = Instance.new("Folder")
World.NodesFolder.Name = "OreNodes"
World.Stations = {} :: { [string]: BasePart }
World.HubSpawn = Vector3.new(0, 5, 25)

local half = Config.ZoneSize / 2

local function make(className: string, props: { [string]: any }, parent: Instance?): any
	local inst = Instance.new(className)
	for key, value in props do
		(inst :: any)[key] = value
	end
	inst.Parent = parent
	return inst
end

local function label(parent: Instance, text: string, color: Color3, size: UDim2, order: number?): TextLabel
	return make("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Font = Enum.Font.GothamBold,
		TextScaled = true,
		TextColor3 = color,
		TextStrokeTransparency = 0.4,
		Text = text,
		LayoutOrder = order or 0,
	}, parent)
end

local function zoneCenter(zone: Zone): Vector3
	local count = #GameData.Zones
	return Vector3.new((zone.Id - (count + 1) / 2) * Config.ZoneSpacing, 0, Config.ZoneOffsetZ)
end

local function zoneSpawn(zone: Zone): Vector3
	return zoneCenter(zone) + Vector3.new(0, 5, half - 22)
end

-- Invisible boundary so nobody walks off a platform.
local function addWalls(center: Vector3, size: number, name: string)
	for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
		make("Part", {
			Name = name,
			Anchored = true,
			Transparency = 1,
			CanQuery = false,
			Size = if side[1] ~= 0 then Vector3.new(2, 60, size) else Vector3.new(size, 60, 2),
			Position = center + Vector3.new(side[1] * size / 2, 30, side[2] * size / 2),
		}, workspace)
	end
end

local function teleport(player: Player, position: Vector3)
	local character = player.Character
	if character then
		character:PivotTo(CFrame.new(position))
	end
end

-- Moves a player to a zone (nil = hub) with no checks.
function World.TeleportTo(player: Player, zone: Zone?)
	teleport(player, if zone then zoneSpawn(zone) else World.HubSpawn)
end

-- Moves a player to a zone (nil = hub) if their level allows it.
function World.TryEnter(player: Player, zone: Zone?): boolean
	local profile = Data.Get(player)
	if not profile then
		return false
	end
	if zone and profile.Level < zone.RequiredLevel then
		Notify.toast(player, `{zone.Name} requires level {zone.RequiredLevel}`, Color3.fromRGB(255, 110, 110))
		return false
	end
	World.TeleportTo(player, zone)
	return true
end

-- True when the player's character is close enough to use the given station.
function World.NearStation(player: Player, panel: string): boolean
	local station: BasePart? = World.Stations[panel]
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not station or not root or not root:IsA("BasePart") then
		return false
	end
	return (root.Position - station.Position).Magnitude <= Config.StationRange
end

-- Hub ---------------------------------------------------------------------------------------------------

local function buildStation(name: string, panel: string, position: Vector3, color: Color3)
	local part = make("Part", {
		Name = name,
		Anchored = true,
		Size = Vector3.new(12, 7, 6),
		Position = position + Vector3.new(0, 3.5, 0),
		Material = Enum.Material.Metal,
		Color = color,
	}, workspace)

	local gui = make("BillboardGui", {
		Size = UDim2.fromOffset(240, 60),
		StudsOffset = Vector3.new(0, 6, 0),
		AlwaysOnTop = true,
		MaxDistance = 120,
	}, part)
	label(gui, name, Color3.new(1, 1, 1), UDim2.fromScale(1, 1))

	local prompt = make("ProximityPrompt", {
		ActionText = "Open",
		ObjectText = name,
		HoldDuration = 0,
		MaxActivationDistance = 14,
		RequiresLineOfSight = false,
	}, part)
	prompt:SetAttribute("Panel", panel)

	World.Stations[panel] = part
end

local function buildHub()
	make("Part", {
		Name = "HubFloor",
		Anchored = true,
		Size = Vector3.new(Config.HubSize, 2, Config.HubSize),
		Position = Vector3.new(0, -1, 0),
		Material = Enum.Material.Cobblestone,
		Color = Color3.fromRGB(120, 115, 105),
	}, workspace)
	addWalls(Vector3.zero, Config.HubSize, "HubWall")

	make("SpawnLocation", {
		Name = "HubSpawn",
		Anchored = true,
		Size = Vector3.new(10, 1, 10),
		Position = Vector3.new(0, 0.5, 25),
		Neutral = true,
		Duration = 0,
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 190, 60),
	}, workspace)

	buildStation("Sell Shop", "Sell", Vector3.new(-56, 0, 45), Color3.fromRGB(70, 160, 80))
	buildStation("Upgrade Shop", "Upgrade", Vector3.new(-28, 0, 45), Color3.fromRGB(70, 110, 190))
	buildStation("The Forge", "Forge", Vector3.new(0, 0, 45), Color3.fromRGB(190, 85, 40))
	buildStation("Pet Hatchery", "Pets", Vector3.new(28, 0, 45), Color3.fromRGB(215, 120, 190))
	buildStation("Rebirth Altar", "Rebirth", Vector3.new(56, 0, 45), Color3.fromRGB(150, 70, 210))

	make("Part", {
		Name = "ForgeGlow",
		Anchored = true,
		CanCollide = false,
		Size = Vector3.new(3, 3, 3),
		Position = Vector3.new(0, 9, 45),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 140, 40),
		Shape = Enum.PartType.Ball,
	}, workspace)
end

-- Portals ---------------------------------------------------------------------------------------------

local function buildPortalGui(portal: Part, title: string, subtitle: string, color: Color3): TextLabel
	-- Sized in studs (scale) so neighbouring portals' labels never overlap.
	local gui = make("BillboardGui", {
		Size = UDim2.fromScale(16, 6.5),
		StudsOffset = Vector3.new(0, 11, 0),
		AlwaysOnTop = true,
		MaxDistance = 150,
	}, portal)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, gui)
	label(gui, title, Color3.new(1, 1, 1), UDim2.new(1, 0, 0.4, 0), 1)
	label(gui, subtitle, color, UDim2.new(1, 0, 0.3, 0), 2)
	return label(gui, "", Color3.new(1, 1, 1), UDim2.new(1, 0, 0.3, 0), 3)
end

-- Fires `onEnter` for a player touching `part`, at most once every 2 seconds each.
local function onTouchedByPlayer(part: BasePart, onEnter: (Player) -> ())
	local lastUse: { [Player]: number } = {}
	part.Touched:Connect(function(hit)
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		local now = os.clock()
		if now - (lastUse[player] or 0) < 2 then
			return
		end
		lastUse[player] = now
		onEnter(player)
	end)
end

local function buildPortalTo(zone: Zone)
	local count = #GameData.Zones
	local spacing = math.min(20, (Config.HubSize - 26) / (count - 1))
	local x = (zone.Id - (count + 1) / 2) * spacing
	local portal = make("Part", {
		Name = `Portal_{zone.Id}`,
		Anchored = true,
		CanCollide = false,
		Size = Vector3.new(12, 14, 1),
		Position = Vector3.new(x, 7, -58),
		Material = Enum.Material.Neon,
		Color = zone.DifficultyColor,
		Transparency = 0.25,
	}, workspace)
	portal:SetAttribute("ZoneId", zone.Id)
	portal:SetAttribute("RequiredLevel", zone.RequiredLevel)
	CollectionService:AddTag(portal, "Portal")

	local status = buildPortalGui(portal, zone.Name, zone.Difficulty, zone.DifficultyColor)
	status.Name = "Status"
	status.Text = `Level {zone.RequiredLevel}+`

	onTouchedByPlayer(portal, function(player)
		World.TryEnter(player, zone)
	end)
end

local function buildReturnPortal(zone: Zone)
	local center = zoneCenter(zone)
	local portal = make("Part", {
		Name = "ReturnPortal",
		Anchored = true,
		CanCollide = false,
		Size = Vector3.new(12, 14, 1),
		Position = center + Vector3.new(0, 7, half - 6),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0.25,
	}, workspace)
	local gui = make("BillboardGui", {
		Size = UDim2.fromOffset(240, 50),
		StudsOffset = Vector3.new(0, 10, 0),
		AlwaysOnTop = true,
		MaxDistance = 120,
	}, portal)
	label(gui, "Return to Hub", Color3.new(1, 1, 1), UDim2.fromScale(1, 1))

	onTouchedByPlayer(portal, function(player)
		World.TryEnter(player, nil)
	end)
end

-- Zones & ore nodes ---------------------------------------------------------------------------------------

local function pickOre(zone: Zone): GameData.Ore
	local total = 0
	for _, entry in zone.Ores do
		total += entry.Weight
	end
	local roll = math.random() * total
	for _, entry in zone.Ores do
		roll -= entry.Weight
		if roll <= 0 then
			return GameData.Ores[entry.Id]
		end
	end
	return GameData.Ores[zone.Ores[#zone.Ores].Id]
end

function World.UpdateBar(node: BasePart)
	local gui = node:FindFirstChildOfClass("BillboardGui")
	local fill = gui and gui:FindFirstChild("Fill", true) :: Frame?
	if fill then
		local fraction =
			math.clamp((node:GetAttribute("Health") :: number) / (node:GetAttribute("MaxHealth") :: number), 0, 1)
		fill.Size = UDim2.fromScale(fraction, 1)
	end
end

-- Spawns an ore node in `zone`. Options let admin tools pick the ore, force a rich node, choose the
-- exact ground position, or stop the node from respawning.
function World.SpawnNode(zone: Zone, options: SpawnOptions?)
	local opts: SpawnOptions = options or {}
	local center = zoneCenter(zone)
	local ore = if opts.OreId and GameData.Ores[opts.OreId] then GameData.Ores[opts.OreId] else pickOre(zone)
	local boss = if opts.Boss ~= nil then opts.Boss else math.random() < Config.BossChance

	local tier = table.find(GameData.OreOrder, ore) or 1
	local size = (3.2 + tier * 0.4) * (if boss then 1.7 else 1)
	local health = ore.Health * (if boss then Config.BossHealthMult else 1)

	-- Find a spot that isn't on top of another node (unless a position was requested).
	local position = opts.Position or center
	if not opts.Position then
		for _ = 1, 12 do
			local candidate = center + Vector3.new(math.random(-70, 70), 0, math.random(-72, 48))
			local free = true
			for _, other in World.NodesFolder:GetChildren() do
				if other:IsA("BasePart") and (other.Position - candidate).Magnitude < size + 6 then
					free = false
					break
				end
			end
			position = candidate
			if free then
				break
			end
		end
	end

	local node = make("Part", {
		Name = ore.Name,
		Anchored = true,
		Size = Vector3.new(size, size * 0.9, size),
		CFrame = CFrame.new(position + Vector3.new(0, size * 0.45, 0))
			* CFrame.Angles(0, math.rad(math.random(0, 359)), 0),
		Material = if boss then Enum.Material.Neon else ore.Material,
		Color = ore.Color,
	}, nil)
	node:SetAttribute("OreId", ore.Id)
	node:SetAttribute("ZoneId", zone.Id)
	node:SetAttribute("Health", health)
	node:SetAttribute("MaxHealth", health)
	node:SetAttribute("Boss", boss)
	node:SetAttribute("NoRespawn", opts.NoRespawn == true)

	local gui = make("BillboardGui", {
		Size = UDim2.fromOffset(150, 40),
		StudsOffset = Vector3.new(0, size * 0.45 + 2.5, 0),
		MaxDistance = 70,
	}, node)
	local title = if boss then `★ Rich {ore.Name} ★` else ore.Name
	label(gui, title, if boss then Color3.fromRGB(255, 225, 80) else ore.Color, UDim2.new(1, 0, 0.55, 0))
	local back = make("Frame", {
		BackgroundColor3 = Color3.fromRGB(25, 25, 25),
		BorderSizePixel = 0,
		Position = UDim2.fromScale(0, 0.62),
		Size = UDim2.fromScale(1, 0.3),
	}, gui)
	make("Frame", {
		Name = "Fill",
		BackgroundColor3 = if boss then Color3.fromRGB(255, 200, 40) else Color3.fromRGB(90, 220, 90),
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
	}, back)

	NodeModels.Decorate(node, ore, size, boss)

	if boss then
		make("ParticleEmitter", {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 235, 120)),
			Rate = 10,
			Lifetime = NumberRange.new(1, 2),
			Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(180, 180),
			Size = NumberSequence.new(0.8, 0),
			LightEmission = 1,
		}, node)
	end

	node.Parent = World.NodesFolder
end

local function buildZone(zone: Zone)
	local center = zoneCenter(zone)

	make("Part", {
		Name = `Zone_{zone.Id}_Floor`,
		Anchored = true,
		Size = Vector3.new(Config.ZoneSize, 2, Config.ZoneSize),
		Position = center + Vector3.new(0, -1, 0),
		Material = zone.FloorMaterial,
		Color = zone.Floor,
	}, workspace)
	addWalls(center, Config.ZoneSize, "ZoneWall")

	local sign = make("Part", {
		Name = `Zone_{zone.Id}_Sign`,
		Anchored = true,
		CanCollide = false,
		CanQuery = false,
		Transparency = 1,
		Size = Vector3.one,
		Position = center + Vector3.new(0, 30, -half + 8),
	}, workspace)
	local gui = make("BillboardGui", {
		Size = UDim2.fromOffset(420, 130),
		AlwaysOnTop = true,
		MaxDistance = 250,
	}, sign)
	make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, gui)
	label(gui, zone.Name, Color3.new(1, 1, 1), UDim2.new(1, 0, 0.5, 0), 1)
	local detail = if zone.Hazard > 0 then `{zone.Difficulty}  -  hazard: {zone.Hazard} dmg/s` else zone.Difficulty
	label(gui, detail, zone.DifficultyColor, UDim2.new(1, 0, 0.35, 0), 2)

	buildReturnPortal(zone)
	for _ = 1, Config.NodesPerZone do
		World.SpawnNode(zone)
	end
end

function World.ZoneAt(position: Vector3): Zone?
	for _, zone in GameData.Zones do
		local center = zoneCenter(zone)
		if math.abs(position.X - center.X) <= half and math.abs(position.Z - center.Z) <= half and position.Y > -10 then
			return zone
		end
	end
	return nil
end

function World.Build()
	-- Studio's Baseplate template would z-fight with our floors and has its own spawn pad.
	local template = workspace:FindFirstChild("Baseplate")
	if template then
		template:Destroy()
	end
	for _, child in workspace:GetChildren() do
		if child:IsA("SpawnLocation") then
			child:Destroy()
		end
	end

	World.NodesFolder.Parent = workspace
	buildHub()
	for _, zone in GameData.Zones do
		buildPortalTo(zone)
		buildZone(zone)
	end
end

return World

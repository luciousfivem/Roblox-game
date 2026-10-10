--!strict
-- Pets: animal models that follow their owner, auto-mine nearby ore, and are hatched from eggs.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local GameData = require(ReplicatedStorage.Shared.GameData)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Data = require(script.Parent.Data)
local Mining = require(script.Parent.Mining)
local Notify = require(script.Parent.Notify)
local World = require(script.Parent.World)

local Pets = {}

-- Visual spec ------------------------------------------------------------------------------------------

type Spec = {
	Scale: number?,
	Ears: string?, -- Pointy | Round
	Horns: string?, -- Ram | Antlers | Small
	Wings: boolean?,
	Tail: string?, -- Normal | Fluffy | Long | Serpent
	Beak: boolean?,
	Glow: Color3?,
}

local SPECS: { [string]: Spec } = {
	PebblePup = { Ears = "Round", Tail = "Normal" },
	ClayMole = { Tail = "Normal", Scale = 0.9 },
	CopperCat = { Ears = "Pointy", Tail = "Long" },
	IronFox = { Ears = "Pointy", Tail = "Fluffy" },
	SilverWolf = { Ears = "Pointy", Tail = "Fluffy", Scale = 1.15, Glow = Color3.fromRGB(200, 230, 255) },
	GoldRam = { Horns = "Ram", Tail = "Normal", Scale = 1.15 },
	CrystalStag = { Horns = "Antlers", Tail = "Normal", Scale = 1.2, Glow = Color3.fromRGB(150, 235, 255) },
	PrismDragon = { Horns = "Small", Wings = true, Tail = "Long", Scale = 1.2, Glow = Color3.fromRGB(255, 190, 255) },
	ObsidianBear = { Ears = "Round", Tail = "Normal", Scale = 1.45, Glow = Color3.fromRGB(190, 90, 255) },
	MythrilGriffin = { Wings = true, Beak = true, Tail = "Long", Scale = 1.3, Glow = Color3.fromRGB(100, 255, 200) },
	VoidPhoenix = { Wings = true, Beak = true, Tail = "Long", Scale = 1.35, Glow = Color3.fromRGB(230, 100, 255) },
	StarbornWyrm = {
		Horns = "Small",
		Wings = true,
		Tail = "Serpent",
		Scale = 1.5,
		Glow = Color3.fromRGB(190, 225, 255),
	},
}

type PetPart = { Part: Part, Rel: CFrame, Hinge: CFrame?, Side: number }

type PetState = {
	Model: Model,
	Parts: { PetPart },
	Power: number,
	Position: Vector3,
	Facing: Vector3,
	NextAttack: number,
	AttackUntil: number,
	AttackPos: Vector3,
}

local petsFolder = Instance.new("Folder")
petsFolder.Name = "Pets"
petsFolder.Parent = workspace

local active: { [Player]: { PetState } } = {}

local function buildModel(pet: GameData.Pet): (Model, { PetPart })
	local spec: Spec = SPECS[pet.Id] or {}
	local scale = spec.Scale or 1
	local model = Instance.new("Model")
	model.Name = pet.Name
	local parts: { PetPart } = {}

	local function add(
		rel: CFrame,
		size: Vector3,
		color: Color3,
		shape: Enum.PartType?,
		material: Enum.Material?,
		hinge: CFrame?,
		side: number?
	): Part
		local part = Instance.new("Part")
		part.Anchored = true
		part.CanCollide = false
		part.CanTouch = false
		part.CanQuery = false
		part.Massless = true
		part.Shape = shape or Enum.PartType.Block
		part.Size = size * scale
		part.Color = color
		part.Material = material or Enum.Material.SmoothPlastic
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		part.Parent = model
		local scaledHinge = if hinge then CFrame.new(hinge.Position * scale) * hinge.Rotation else nil
		table.insert(parts, {
			Part = part,
			Rel = CFrame.new(rel.Position * scale) * rel.Rotation,
			Hinge = scaledHinge,
			Side = side or 0,
		})
		return part
	end

	local function ball(d: number): Vector3
		return Vector3.new(d, d, d)
	end

	local base = pet.Color
	local light = base:Lerp(Color3.new(1, 1, 1), 0.35)
	local dark = base:Lerp(Color3.new(0, 0, 0), 0.45)
	local glow = spec.Glow
	local bodyMaterial = if glow then Enum.Material.Neon else Enum.Material.SmoothPlastic

	-- Body, head, face (the pet faces -Z).
	local body = add(CFrame.new(), ball(1.8), base, Enum.PartType.Ball, bodyMaterial)
	add(CFrame.new(0, 0.7, -1), ball(1.3), base, Enum.PartType.Ball, bodyMaterial)
	for _, side in { -1, 1 } do
		add(
			CFrame.new(side * 0.32, 0.85, -1.58),
			ball(0.26),
			if glow then glow else Color3.new(0, 0, 0),
			Enum.PartType.Ball,
			Enum.Material.Neon
		)
	end
	if not spec.Beak then
		add(CFrame.new(0, 0.55, -1.62), ball(0.5), light, Enum.PartType.Ball)
		add(CFrame.new(0, 0.62, -1.86), ball(0.18), dark, Enum.PartType.Ball)
	else
		add(CFrame.new(0, 0.55, -1.8), Vector3.new(0.35, 0.3, 0.65), Color3.fromRGB(255, 190, 60))
	end

	if spec.Ears == "Pointy" then
		for _, side in { -1, 1 } do
			add(
				CFrame.new(side * 0.42, 1.45, -0.95) * CFrame.Angles(0, 0, -side * math.rad(14)),
				Vector3.new(0.3, 0.7, 0.22),
				base
			)
		end
	elseif spec.Ears == "Round" then
		for _, side in { -1, 1 } do
			add(CFrame.new(side * 0.55, 1.3, -0.9), ball(0.5), base, Enum.PartType.Ball)
		end
	end

	if spec.Horns == "Ram" then
		for _, side in { -1, 1 } do
			add(
				CFrame.new(side * 0.62, 1.15, -0.9) * CFrame.Angles(0, side * math.rad(40), 0),
				Vector3.new(0.28, 0.28, 0.75),
				Color3.fromRGB(235, 225, 190)
			)
			add(
				CFrame.new(side * 0.95, 1.05, -0.62) * CFrame.Angles(0, side * math.rad(90), 0),
				Vector3.new(0.24, 0.24, 0.5),
				Color3.fromRGB(235, 225, 190)
			)
		end
	elseif spec.Horns == "Antlers" then
		for _, side in { -1, 1 } do
			local tint = light
			add(
				CFrame.new(side * 0.45, 1.75, -0.95) * CFrame.Angles(0, 0, -side * math.rad(18)),
				Vector3.new(0.13, 1.1, 0.13),
				tint,
				nil,
				Enum.Material.Glass
			)
			add(
				CFrame.new(side * 0.7, 1.95, -0.95) * CFrame.Angles(0, 0, -side * math.rad(50)),
				Vector3.new(0.1, 0.5, 0.1),
				tint,
				nil,
				Enum.Material.Glass
			)
			add(
				CFrame.new(side * 0.55, 2.3, -0.95) * CFrame.Angles(0, 0, -side * math.rad(10)),
				Vector3.new(0.1, 0.45, 0.1),
				tint,
				nil,
				Enum.Material.Glass
			)
		end
	elseif spec.Horns == "Small" then
		for _, side in { -1, 1 } do
			add(
				CFrame.new(side * 0.4, 1.5, -1.05) * CFrame.Angles(math.rad(-20), 0, -side * math.rad(15)),
				Vector3.new(0.18, 0.55, 0.18),
				light
			)
		end
	end

	-- Wings flap around a hinge at the shoulder (animated in the follow loop).
	if spec.Wings then
		for _, side in { -1, 1 } do
			add(
				CFrame.new(side * 1.05, 0, 0.1),
				Vector3.new(2.1, 0.1, 1.3),
				if glow then glow else light,
				nil,
				Enum.Material.Neon,
				CFrame.new(side * 0.55, 0.45, 0.2),
				side
			)
		end
	end

	local tail = spec.Tail
	if tail == "Normal" then
		add(CFrame.new(0, 0.3, 1.1), ball(0.5), base, Enum.PartType.Ball)
	elseif tail == "Fluffy" then
		add(CFrame.new(0, 0.5, 1.2), ball(0.95), base, Enum.PartType.Ball)
		add(CFrame.new(0, 0.62, 1.62), ball(0.45), Color3.new(1, 1, 1), Enum.PartType.Ball)
	elseif tail == "Long" then
		add(CFrame.new(0, 0.15, 1.1), ball(0.5), base, Enum.PartType.Ball)
		add(CFrame.new(0, 0.2, 1.6), ball(0.4), base, Enum.PartType.Ball)
		add(CFrame.new(0, 0.3, 2), ball(0.3), light, Enum.PartType.Ball, bodyMaterial)
	elseif tail == "Serpent" then
		for i = 1, 5 do
			add(
				CFrame.new(0, 0.1 + i * 0.05, 0.9 + i * 0.55),
				ball(0.85 - i * 0.12),
				if i % 2 == 0 then light else base,
				Enum.PartType.Ball,
				bodyMaterial
			)
		end
	end

	-- Name tag in the rarity colour.
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 24)
	gui.StudsOffset = Vector3.new(0, 2.8 * scale, 0)
	gui.MaxDistance = 45
	gui.Parent = body
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextStrokeTransparency = 0.4
	label.TextColor3 = GameData.RarityColors[pet.Rarity] or Color3.new(1, 1, 1)
	label.Text = pet.Name
	label.Parent = gui

	if pet.Rarity == "Epic" or pet.Rarity == "Legendary" or pet.Rarity == "Mythic" then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(glow or base)
		emitter.Rate = 6
		emitter.Lifetime = NumberRange.new(0.6, 1.2)
		emitter.Speed = NumberRange.new(0.5, 1.5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new(0.5, 0)
		emitter.LightEmission = 1
		emitter.Parent = body
	end

	return model, parts
end

-- Following / animating ---------------------------------------------------------------------------------

local function placePet(state: PetState, t: number)
	local origin = CFrame.lookAt(state.Position, state.Position + state.Facing)
	local flap = math.sin(t * 9) * 0.55
	for _, entry in state.Parts do
		if entry.Hinge then
			entry.Part.CFrame = origin * entry.Hinge * CFrame.Angles(0, 0, entry.Side * (0.25 + flap)) * entry.Rel
		else
			entry.Part.CFrame = origin * entry.Rel
		end
	end
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root else nil
end

local function clear(player: Player)
	local list = active[player]
	if list then
		for _, state in list do
			state.Model:Destroy()
		end
	end
	active[player] = nil
end

-- Rebuilds a player's pet models from their equipped list.
function Pets.Refresh(player: Player)
	clear(player)
	local profile = Data.Get(player)
	if not profile or not player.Parent then
		return
	end
	local root = rootOf(player)
	local list: { PetState } = {}
	for _, id in profile.EquippedPets do
		local pet = GameData.PetsById[id]
		if pet then
			local model, parts = buildModel(pet)
			local position = if root then root.Position + Vector3.new(0, 3, 4) else Vector3.new(0, 5, 0)
			local state: PetState = {
				Model = model,
				Parts = parts,
				Power = pet.Power,
				Position = position,
				Facing = Vector3.new(0, 0, -1),
				NextAttack = os.clock() + 1,
				AttackUntil = 0,
				AttackPos = position,
			}
			placePet(state, 0)
			model.Parent = petsFolder
			table.insert(list, state)
		end
	end
	active[player] = list
end

local function nearestNode(origin: Vector3): BasePart?
	local best: BasePart? = nil
	local bestDistance = Config.PetRange
	for _, node in World.NodesFolder:GetChildren() do
		if node:IsA("BasePart") then
			local distance = (node.Position - origin).Magnitude
			if distance < bestDistance then
				best = node
				bestDistance = distance
			end
		end
	end
	return best
end

local function stepFollow(dt: number)
	local t = os.clock()
	for player, list in active do
		local root = rootOf(player)
		if root then
			for index, state in list do
				local target: Vector3
				local lookAt: Vector3
				if t < state.AttackUntil then
					-- Lunge toward the ore being attacked.
					target = state.AttackPos + Vector3.new(0, 3.5, 0)
					lookAt = state.AttackPos
				else
					local offset = (index - (#list + 1) / 2) * 4
					local bob = math.sin(t * 3 + index) * 0.4
					target = (root.CFrame * CFrame.new(offset, 2.2 + bob, 4.5)).Position
					lookAt = state.Position + root.CFrame.LookVector * 5
				end
				state.Position = state.Position:Lerp(target, math.min(1, dt * 8))
				local flat = Vector3.new(lookAt.X - state.Position.X, 0, lookAt.Z - state.Position.Z)
				if flat.Magnitude > 0.1 then
					state.Facing = flat.Unit
				end
				placePet(state, t)
			end
		end
	end
end

local function stepAttacks()
	local t = os.clock()
	for player, list in active do
		local root = rootOf(player)
		local profile = Data.Get(player)
		if root and profile then
			for _, state in list do
				if t >= state.NextAttack then
					state.NextAttack = t + Config.PetInterval
					if GameData.usedCapacity(profile) < GameData.capacity(profile) then
						local node = nearestNode(root.Position)
						if node then
							state.AttackUntil = t + 0.4
							state.AttackPos = node.Position
							Mining.HitNode(player, profile, node, state.Power)
						end
					end
				end
			end
		end
	end
end

-- Hatching & equipping --------------------------------------------------------------------------------

local function equippedCount(profile: GameData.Profile, petId: string): number
	local n = 0
	for _, id in profile.EquippedPets do
		if id == petId then
			n += 1
		end
	end
	return n
end

local function roll(egg: GameData.Egg): GameData.Pet
	local total = 0
	for _, entry in egg.Pets do
		total += entry.Weight
	end
	local r = math.random() * total
	for _, entry in egg.Pets do
		r -= entry.Weight
		if r <= 0 then
			return GameData.PetsById[entry.Id]
		end
	end
	return GameData.PetsById[egg.Pets[#egg.Pets].Id]
end

-- Gives the player a random pet from `egg` (equipping it if there's a free slot). No cost check.
function Pets.Grant(player: Player, profile: GameData.Profile, egg: GameData.Egg): GameData.Pet
	local pet = roll(egg)
	profile.Pets[pet.Id] = (profile.Pets[pet.Id] or 0) + 1
	if #profile.EquippedPets < GameData.maxPets(profile) then
		table.insert(profile.EquippedPets, pet.Id)
	end
	Notify.toast(player, `Hatched {pet.Name}! ({pet.Rarity})`, GameData.RarityColors[pet.Rarity])
	Pets.Refresh(player)
	return pet
end

local function onHatch(player: Player, eggId: unknown)
	local egg = if type(eggId) == "string" then GameData.EggsById[eggId] else nil
	local profile = Data.Get(player)
	if not egg or not profile or not World.NearStation(player, "Pets") then
		return
	end
	if profile.Coins < egg.Cost then
		Notify.toast(player, "Not enough coins.", Color3.fromRGB(255, 110, 110))
		return
	end
	profile.Coins -= egg.Cost
	Pets.Grant(player, profile, egg)
	Data.Push(player)
end

local function onPetEquip(player: Player, petId: unknown, equip: unknown)
	local profile = Data.Get(player)
	if type(petId) ~= "string" or type(equip) ~= "boolean" or not profile or not GameData.PetsById[petId] then
		return
	end
	if not World.NearStation(player, "Pets") then
		return
	end

	if equip then
		if
			(profile.Pets[petId] or 0) <= equippedCount(profile, petId)
			or #profile.EquippedPets >= GameData.maxPets(profile)
		then
			return
		end
		table.insert(profile.EquippedPets, petId)
	else
		local index = table.find(profile.EquippedPets, petId)
		if not index then
			return
		end
		table.remove(profile.EquippedPets, index)
	end
	Pets.Refresh(player)
	Data.Push(player)
end

function Pets.Init()
	Remotes.Event("Hatch").OnServerEvent:Connect(onHatch)
	Remotes.Event("PetEquip").OnServerEvent:Connect(onPetEquip)
	RunService.Heartbeat:Connect(stepFollow)
	task.spawn(function()
		while true do
			task.wait(0.25)
			stepAttacks()
		end
	end)
	Players.PlayerRemoving:Connect(clear)
end

return Pets

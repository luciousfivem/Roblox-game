--!strict
-- Gives each ore node its look: extra decoration parts around the clickable core part.
-- Decoration parts carry an "Anim" attribute; the client animates them (see client/Effects).
--
-- To use your own mesh instead, put a Model named after the ore id (e.g. "Copper") in
-- ReplicatedStorage/Models/Ores. It replaces the procedural decoration. Give any part an
-- attribute Anim = "Spin", "Bob", "Pulse" or "Orbit" (comma-separate to combine) to animate it.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = require(ReplicatedStorage.Shared.GameData)

local NodeModels = {}

type Props = {
	Offset: CFrame,
	Size: Vector3,
	Color: Color3,
	Material: Enum.Material?,
	Shape: Enum.PartType?,
	Anim: string?,
	Speed: number?,
	Amp: number?,
	Phase: number?,
	Transparency: number?,
}

local function decor(node: Part, p: Props): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Shape = p.Shape or Enum.PartType.Block
	part.Size = p.Size
	part.Color = p.Color
	part.Material = p.Material or Enum.Material.Slate
	part.Transparency = p.Transparency or 0
	part.CFrame = node.CFrame * p.Offset
	if p.Anim then
		part:SetAttribute("Anim", p.Anim)
		part:SetAttribute("Speed", p.Speed or 2)
		part:SetAttribute("Amp", p.Amp or 0.4)
		part:SetAttribute("Phase", p.Phase or math.random() * math.pi * 2)
	end
	part.Parent = node
	return part
end

local function ball(d: number): Vector3
	return Vector3.new(d, d, d)
end

local function rotated(): CFrame
	return CFrame.Angles(math.rad(math.random(-25, 25)), math.rad(math.random(0, 359)), math.rad(math.random(-25, 25)))
end

-- Small rocks scattered at the base.
local function pebbles(node: Part, s: number, color: Color3, count: number)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random() * 0.6
		local r = s * (0.62 + math.random() * 0.2)
		local d = s * (0.22 + math.random() * 0.18)
		decor(node, {
			Offset = CFrame.new(math.cos(angle) * r, -s * 0.3, math.sin(angle) * r) * rotated(),
			Size = Vector3.new(d, d * 0.8, d),
			Color = color:Lerp(Color3.new(0.5, 0.5, 0.5), 0.2),
			Material = node.Material,
		})
	end
end

-- Pointed spikes (crystals / shards) growing out of the core.
local function spikes(node: Part, s: number, color: Color3, material: Enum.Material, count: number, glow: Color3?)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2
		local r = s * 0.28
		local h = s * (0.9 + math.random() * 0.8)
		local spike = decor(node, {
			Offset = CFrame.new(math.cos(angle) * r, s * 0.4 + h * 0.3, math.sin(angle) * r)
				* CFrame.Angles(math.sin(angle) * 0.4, angle, -math.cos(angle) * 0.4),
			Size = Vector3.new(s * 0.22, h, s * 0.22),
			Color = color,
			Material = material,
			Transparency = 0.1,
		})
		if glow and i % 2 == 0 then
			spike.Color = glow
			spike.Material = Enum.Material.Neon
			spike:SetAttribute("Anim", "Pulse")
			spike:SetAttribute("Speed", 2 + i * 0.3)
			spike:SetAttribute("Amp", 0.3)
			spike:SetAttribute("Phase", i)
		end
	end
end

local function ring(
	node: Part,
	s: number,
	color: Color3,
	count: number,
	radius: number,
	y: number,
	tilt: number,
	speed: number
)
	for i = 1, count do
		decor(node, {
			Offset = CFrame.Angles(tilt, 0, 0)
				* CFrame.new(0, y, 0)
				* CFrame.Angles(0, (i / count) * math.pi * 2, 0)
				* CFrame.new(0, 0, radius),
			Size = Vector3.new(s * 0.18, s * 0.18, s * 0.34),
			Color = color,
			Material = Enum.Material.Neon,
			Anim = "Orbit",
			Speed = speed,
			Phase = 0,
		})
	end
end

-- One builder per visual style; `s` is the node's base size in studs.
local styles: { [string]: (Part, number, GameData.Ore, boolean) -> () } = {
	Rock = function(node, s, ore)
		pebbles(node, s, ore.Color, 3)
	end,

	Ember = function(node, s, ore)
		pebbles(node, s, ore.Color, 3)
		for i = 1, 4 do
			local angle = i * 1.7
			decor(node, {
				Offset = CFrame.new(math.cos(angle) * s * 0.3, s * 0.42 + (i % 2) * 0.05, math.sin(angle) * s * 0.3),
				Size = ball(s * 0.16),
				Color = Color3.fromRGB(255, 120, 30),
				Material = Enum.Material.Neon,
				Shape = Enum.PartType.Ball,
				Anim = "Pulse",
				Speed = 3 + i,
				Phase = i,
			})
		end
	end,

	Nuggets = function(node, s, ore)
		pebbles(node, s, ore.Color:Lerp(Color3.fromRGB(110, 110, 115), 0.6), 3)
		local count = 5
		for i = 1, count do
			local angle = (i / count) * math.pi * 2
			local d = s * (0.22 + math.random() * 0.1)
			decor(node, {
				Offset = CFrame.new(
					math.cos(angle) * s * 0.34,
					s * 0.3 + (i % 2) * s * 0.12,
					math.sin(angle) * s * 0.34
				) * rotated(),
				Size = Vector3.new(d, d * 0.9, d),
				Color = ore.Color,
				Material = Enum.Material.Metal,
				Anim = if i % 2 == 0 then "Pulse" else nil,
				Speed = 2,
				Amp = 0.2,
			})
		end
	end,

	Crystal = function(node, s, ore)
		spikes(node, s, ore.Color, Enum.Material.Glass, 6, ore.Color:Lerp(Color3.new(1, 1, 1), 0.4))
		decor(node, {
			Offset = CFrame.new(s * 0.7, s * 1.5, 0),
			Size = ball(s * 0.22),
			Color = ore.Color,
			Material = Enum.Material.Neon,
			Anim = "Bob,Spin",
			Speed = 2,
			Amp = 0.4,
		})
	end,

	Shards = function(node, s, ore)
		spikes(node, s, Color3.fromRGB(35, 20, 55), Enum.Material.Glass, 6, ore.Color)
	end,

	Rune = function(node, s, ore)
		node.Shape = Enum.PartType.Ball
		ring(node, s, ore.Color, 6, s * 0.95, s * 0.1, 0, 1.4)
		decor(node, {
			Offset = CFrame.new(0, s * 1.2, 0) * CFrame.Angles(math.rad(45), math.rad(45), 0),
			Size = Vector3.new(s * 0.3, s * 0.3, s * 0.3),
			Color = ore.Color,
			Material = Enum.Material.Neon,
			Anim = "Spin,Bob",
			Speed = 2.5,
			Amp = 0.3,
		})
	end,

	Orb = function(node, s, ore)
		node.Shape = Enum.PartType.Ball
		for i = 1, 3 do
			decor(node, {
				Offset = CFrame.Angles(0, 0, math.rad(i * 40 - 60))
					* CFrame.Angles(0, (i / 3) * math.pi * 2, 0)
					* CFrame.new(0, 0, s * 0.95),
				Size = Vector3.new(s * 0.22, s * 0.5, s * 0.22),
				Color = ore.Color,
				Material = Enum.Material.Neon,
				Anim = "Orbit",
				Speed = 1.2 + i * 0.4,
				Phase = 0,
			})
		end
		decor(node, {
			Offset = CFrame.identity,
			Size = ball(s * 1.35),
			Color = ore.Color,
			Material = Enum.Material.ForceField,
			Shape = Enum.PartType.Ball,
			Anim = "Pulse",
			Speed = 2,
			Amp = 0.35,
			Transparency = 0.4,
		})
	end,

	Star = function(node, s, ore)
		node.Shape = Enum.PartType.Ball
		node.Size = ball(s * 0.7)
		for i = 0, 2 do
			decor(node, {
				Offset = CFrame.Angles(0, 0, math.rad(i * 60)),
				Size = Vector3.new(s * 0.14, s * 1.5, s * 0.14),
				Color = ore.Color,
				Material = Enum.Material.Neon,
				Anim = "Spin,Bob",
				Speed = 1.6,
				Amp = 0.25,
				Phase = 0,
			})
		end
	end,

	Eclipse = function(node, s, ore)
		node.Shape = Enum.PartType.Ball
		node.Color = Color3.fromRGB(15, 10, 10)
		node.Material = Enum.Material.Metal
		ring(node, s, ore.Color, 12, s * 0.85, 0, math.rad(20), 1.8)
		ring(node, s, ore.Color:Lerp(Color3.new(1, 1, 1), 0.4), 8, s * 1.15, 0, math.rad(-35), -1.2)
	end,
}

local STYLE_BY_ORE: { [string]: string } = {
	Stone = "Rock",
	Coal = "Ember",
	Copper = "Nuggets",
	Iron = "Nuggets",
	Silver = "Nuggets",
	Gold = "Nuggets",
	Crystal = "Crystal",
	Obsidian = "Shards",
	Mythril = "Rune",
	Voidstone = "Orb",
	Starmetal = "Star",
	Eclipsium = "Eclipse",
}

-- Replaces the procedural look with a user-supplied Model template, if one exists.
local function applyTemplate(node: Part, ore: GameData.Ore, s: number): boolean
	local models = ReplicatedStorage:FindFirstChild("Models")
	local folder = models and models:FindFirstChild("Ores")
	local template = folder and folder:FindFirstChild(ore.Id)
	if not template or not template:IsA("Model") then
		return false
	end

	local clone = template:Clone()
	clone:ScaleTo(s / 4) -- templates are authored at roughly 4 studs
	clone:PivotTo(node.CFrame)
	node.Transparency = 1 -- the core stays as an invisible hitbox
	for _, descendant in clone:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.Parent = node
		end
	end
	clone:Destroy()
	return true
end

function NodeModels.Decorate(node: Part, ore: GameData.Ore, size: number, boss: boolean)
	if not applyTemplate(node, ore, size) then
		local style = styles[STYLE_BY_ORE[ore.Id] or "Rock"]
		style(node, size, ore, boss)
	end

	if boss then
		-- A halo of gold motes marks rich nodes from a distance.
		for i = 1, 5 do
			decor(node, {
				Offset = CFrame.Angles(0, (i / 5) * math.pi * 2, 0) * CFrame.new(0, size * 0.9, size * 0.9),
				Size = ball(size * 0.14),
				Color = Color3.fromRGB(255, 225, 80),
				Material = Enum.Material.Neon,
				Shape = Enum.PartType.Ball,
				Anim = "Orbit,Bob",
				Speed = 1.5,
				Amp = 0.3,
				Phase = 0,
			})
		end
	end
end

return NodeModels

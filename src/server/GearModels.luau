--!strict
-- Builds weapon Tools and armor attachments out of parts, one distinct look per recipe.
--
-- To use your own mesh, put a Tool named after the recipe id (e.g. "IronSword") in
-- ReplicatedStorage/Models/Weapons. It must contain a part called "Handle". For armor, put a
-- Model named after the recipe id in ReplicatedStorage/Models/Armor with parts named
-- "Chest", "Head", "LeftArm", "RightArm" - each is welded to the matching body part.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = require(ReplicatedStorage.Shared.GameData)

local GearModels = {}

-- Weapons ---------------------------------------------------------------------------------------------

type WeaponSpec = {
	Length: number,
	Width: number,
	Thick: number?,
	Segments: number?,
	Curve: number?, -- degrees of bend per segment
	Taper: number?, -- 0 = constant width, 1 = fully pointed
	Plane: string?, -- "YZ" swords, "XZ" scythes
	Hilt: number?,
	Guard: string?, -- Cross | Wings | Star | Cup | None
	GuardWidth: number?,
	Material: Enum.Material?,
	Color: Color3?,
	Glow: Color3?,
	Particles: boolean?,
	Trail: Color3?,
}

local SPECS: { [string]: WeaponSpec } = {
	CopperSword = { Length = 4, Width = 0.8, Segments = 3, Taper = 0.4, Guard = "Cross", GuardWidth = 2 },
	IronSword = {
		Length = 4.6,
		Width = 0.9,
		Segments = 3,
		Taper = 0.45,
		Guard = "Cross",
		GuardWidth = 2.4,
		Trail = Color3.fromRGB(220, 220, 230),
	},
	SilverBlade = {
		Length = 5,
		Width = 1,
		Segments = 4,
		Taper = 0.5,
		Guard = "Cross",
		GuardWidth = 2.6,
		Glow = Color3.fromRGB(200, 225, 255),
		Trail = Color3.fromRGB(210, 230, 255),
	},
	GoldenCutlass = {
		Length = 4.6,
		Width = 1.1,
		Segments = 5,
		Curve = 7,
		Taper = 0.35,
		Guard = "Cup",
		GuardWidth = 1.6,
		Trail = Color3.fromRGB(255, 220, 90),
	},
	CrystalEdge = {
		Length = 5.4,
		Width = 1.2,
		Segments = 4,
		Taper = 0.55,
		Guard = "Cross",
		GuardWidth = 2.6,
		Material = Enum.Material.Glass,
		Glow = Color3.fromRGB(120, 230, 255),
		Particles = true,
		Trail = Color3.fromRGB(120, 230, 255),
	},
	ObsidianCleaver = {
		Length = 4.4,
		Width = 2.2,
		Thick = 0.22,
		Segments = 3,
		Taper = 0.1,
		Guard = "Cross",
		GuardWidth = 3,
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(40, 20, 70),
		Glow = Color3.fromRGB(190, 90, 255),
		Trail = Color3.fromRGB(170, 80, 255),
	},
	MythrilGreatsword = {
		Length = 6.4,
		Width = 1.5,
		Thick = 0.16,
		Segments = 5,
		Taper = 0.5,
		Guard = "Wings",
		GuardWidth = 3.6,
		Glow = Color3.fromRGB(100, 255, 200),
		Particles = true,
		Trail = Color3.fromRGB(100, 255, 200),
	},
	Voidreaver = {
		Length = 4,
		Width = 1.2,
		Segments = 6,
		Curve = 14,
		Taper = 0.6,
		Plane = "XZ",
		Hilt = 5.5,
		Guard = "None",
		Color = Color3.fromRGB(35, 15, 50),
		Glow = Color3.fromRGB(205, 70, 255),
		Particles = true,
		Trail = Color3.fromRGB(205, 70, 255),
	},
	StarforgedBlade = {
		Length = 6.8,
		Width = 1.4,
		Thick = 0.16,
		Segments = 5,
		Taper = 0.55,
		Guard = "Star",
		GuardWidth = 3.8,
		Glow = Color3.fromRGB(180, 220, 255),
		Particles = true,
		Trail = Color3.fromRGB(190, 225, 255),
	},
	EclipseReaper = {
		Length = 5,
		Width = 1.5,
		Segments = 7,
		Curve = 14,
		Taper = 0.6,
		Plane = "XZ",
		Hilt = 6.5,
		Guard = "None",
		Color = Color3.fromRGB(30, 18, 14),
		Glow = Color3.fromRGB(255, 130, 30),
		Particles = true,
		Trail = Color3.fromRGB(255, 140, 40),
	},
}

local DEFAULT_SPEC: WeaponSpec = { Length = 4, Width = 0.9, Segments = 3, Taper = 0.4, Guard = "Cross", GuardWidth = 2 }

local function toolPart(
	tool: Tool,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Shape = shape or Enum.PartType.Block
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = tool
	return part
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function addGuard(tool: Tool, handle: Part, spec: WeaponSpec, z: number, metal: Color3, accent: Color3)
	local kind = spec.Guard or "Cross"
	local width = spec.GuardWidth or 2
	local function attach(part: Part, offset: CFrame)
		part.CFrame = handle.CFrame * offset
		weld(handle, part)
	end

	if kind == "Cross" then
		attach(toolPart(tool, "Guard", Vector3.new(0.3, width, 0.35), metal, Enum.Material.Metal), CFrame.new(0, 0, z))
	elseif kind == "Wings" then
		for _, side in { 1, -1 } do
			attach(
				toolPart(tool, "GuardWing", Vector3.new(0.3, width * 0.55, 0.4), metal, Enum.Material.Metal),
				CFrame.new(0, side * width * 0.28, z) * CFrame.Angles(side * math.rad(28), 0, 0)
			)
		end
		attach(
			toolPart(tool, "GuardGem", Vector3.new(0.45, 0.45, 0.45), accent, Enum.Material.Neon, Enum.PartType.Ball),
			CFrame.new(0, 0, z + 0.05)
		)
	elseif kind == "Star" then
		for i = 0, 1 do
			attach(
				toolPart(tool, "GuardStar", Vector3.new(0.3, width, 0.3), accent, Enum.Material.Neon),
				CFrame.new(0, 0, z + 0.1) * CFrame.Angles(math.rad(45 + i * 90), 0, 0)
			)
		end
	elseif kind == "Cup" then
		attach(
			toolPart(tool, "GuardCup", Vector3.one * (width * 0.55), metal, Enum.Material.Metal, Enum.PartType.Ball),
			CFrame.new(0, 0, z + 0.2)
		)
	end
end

local function buildProcedural(recipe: GameData.Recipe): Tool
	local spec = SPECS[recipe.Id] or DEFAULT_SPEC
	local bladeColor = spec.Color or recipe.Color
	local material = spec.Material or Enum.Material.Metal
	local accent = spec.Glow or recipe.Color:Lerp(Color3.new(1, 1, 1), 0.3)
	local hilt = spec.Hilt or 1.3
	local thick = spec.Thick or 0.12
	local segments = spec.Segments or 3
	local curve = math.rad(spec.Curve or 0)
	local taper = spec.Taper or 0.4
	local flatXZ = spec.Plane == "XZ"

	local tool = Instance.new("Tool")
	tool.Name = recipe.Name
	tool.ToolTip = `+{recipe.Stat}% mining damage`
	tool.CanBeDropped = false
	tool.GripPos = Vector3.zero
	tool.GripForward = Vector3.new(-1, 0, 0)
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(0, 0, 1)
	tool:SetAttribute("Forged", true)

	-- The hilt (or scythe shaft) is the Handle; everything else welds to it.
	local leather = Color3.fromRGB(70, 45, 30)
	local handle = toolPart(
		tool,
		"Handle",
		Vector3.new(0.35, 0.35, hilt),
		if spec.Hilt then Color3.fromRGB(60, 40, 30) else leather,
		Enum.Material.Wood
	)
	local halfHilt = hilt / 2

	local pommel =
		toolPart(tool, "Pommel", Vector3.new(0.55, 0.55, 0.55), accent, Enum.Material.Metal, Enum.PartType.Ball)
	pommel.CFrame = handle.CFrame * CFrame.new(0, 0, -halfHilt - 0.1)
	weld(handle, pommel)

	local metal = recipe.Color:Lerp(Color3.fromRGB(90, 90, 95), 0.35)
	addGuard(tool, handle, spec, halfHilt + 0.15, metal, accent)

	-- Blade: a chain of segments, optionally bending, each a little narrower than the last.
	local start = if spec.Guard == "None" then halfHilt else halfHilt + 0.4
	local cf = handle.CFrame * CFrame.new(0, 0, start)
	local segLen = spec.Length / segments
	local firstBlade: Part? = nil
	local lastBlade: Part? = nil
	local bend = if flatXZ then CFrame.Angles(0, -curve, 0) else CFrame.Angles(curve, 0, 0)

	for i = 1, segments do
		local width = spec.Width * (1 - taper * (i - 1) / segments)
		local size = if flatXZ
			then Vector3.new(width, thick, segLen * 1.04)
			else Vector3.new(thick, width, segLen * 1.04)
		local segCF = cf * bend * CFrame.new(0, 0, segLen / 2)
		local blade = toolPart(tool, "Blade", size, bladeColor, material)
		blade.CFrame = segCF
		weld(handle, blade)

		if spec.Glow then
			local glowSize = if flatXZ
				then Vector3.new(width * 0.2, thick * 1.5, segLen)
				else Vector3.new(thick * 1.5, width * 0.2, segLen)
			local glow = toolPart(tool, "BladeGlow", glowSize, spec.Glow, Enum.Material.Neon)
			glow.CFrame = segCF
			weld(handle, glow)
		end

		firstBlade = firstBlade or blade
		lastBlade = blade
		cf = cf * bend * CFrame.new(0, 0, segLen)
	end

	-- Pointed tip: a square rotated 45 degrees reads as a point from either side.
	local tipWidth = spec.Width * (1 - taper) * 0.9
	local tip = toolPart(tool, "Tip", Vector3.new(thick * 0.9, tipWidth, tipWidth), bladeColor, material)
	tip.CFrame = cf * (if flatXZ then CFrame.Angles(0, math.rad(45), 0) else CFrame.Angles(math.rad(45), 0, 0))
	if flatXZ then
		tip.Size = Vector3.new(tipWidth, thick * 0.9, tipWidth)
	end
	weld(handle, tip)

	if spec.Trail and firstBlade then
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0, start)
		a0.Parent = handle
		local a1 = Instance.new("Attachment")
		a1.Parent = tip
		local trail = Instance.new("Trail")
		trail.Attachment0 = a0
		trail.Attachment1 = a1
		trail.Color = ColorSequence.new(spec.Trail)
		trail.Transparency = NumberSequence.new(0.35, 1)
		trail.Lifetime = 0.25
		trail.LightEmission = 0.6
		trail.FaceCamera = true
		trail.Parent = handle
	end

	if spec.Particles and firstBlade then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(spec.Glow or recipe.Color)
		emitter.Rate = 14
		emitter.Lifetime = NumberRange.new(0.5, 1)
		emitter.Speed = NumberRange.new(0.5, 2)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new(0.5, 0)
		emitter.LightEmission = 1
		emitter.Parent = lastBlade
	end

	return tool
end

function GearModels.Weapon(recipe: GameData.Recipe): Tool
	local models = ReplicatedStorage:FindFirstChild("Models")
	local folder = models and models:FindFirstChild("Weapons")
	local template = folder and folder:FindFirstChild(recipe.Id)
	if template and template:IsA("Tool") and template:FindFirstChild("Handle") then
		local tool = template:Clone()
		tool.CanBeDropped = false
		tool:SetAttribute("Forged", true)
		return tool
	end
	return buildProcedural(recipe)
end

-- Armor -----------------------------------------------------------------------------------------------

local function armorPart(
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material,
	shape: Enum.PartType?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material
	part.Shape = shape or Enum.PartType.Block
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = model
	return part
end

local function findBodyPart(character: Model, r15: string, r6: string): BasePart?
	local part = character:FindFirstChild(r15) or character:FindFirstChild(r6)
	return if part and part:IsA("BasePart") then part else nil
end

local function attachTo(body: BasePart, part: Part, offset: CFrame)
	part.CFrame = body.CFrame * offset
	weld(body, part)
end

local function applyArmorTemplate(character: Model, recipe: GameData.Recipe): boolean
	local models = ReplicatedStorage:FindFirstChild("Models")
	local folder = models and models:FindFirstChild("Armor")
	local template = folder and folder:FindFirstChild(recipe.Id)
	if not template or not template:IsA("Model") then
		return false
	end
	local clone = template:Clone()
	clone.Name = "ForgedArmor"
	local mapping: { [string]: BasePart } = {}
	local function map(name: string, body: BasePart?)
		if body then
			mapping[name] = body
		end
	end
	map("Chest", findBodyPart(character, "UpperTorso", "Torso"))
	map("Head", findBodyPart(character, "Head", "Head"))
	map("LeftArm", findBodyPart(character, "LeftUpperArm", "Left Arm"))
	map("RightArm", findBodyPart(character, "RightUpperArm", "Right Arm"))
	for name, body in mapping do
		local part = clone:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.Massless = true
			part.CFrame = body.CFrame
			weld(body, part)
		end
	end
	clone.Parent = character
	return true
end

-- Replaces whatever armor visuals the character wears with the model for `recipe` (nil = none).
function GearModels.ApplyArmor(character: Model, recipe: GameData.Recipe?)
	local old = character:FindFirstChild("ForgedArmor")
	if old then
		old:Destroy()
	end
	if not recipe then
		return
	end
	if applyArmorTemplate(character, recipe) then
		return
	end

	local torso = findBodyPart(character, "UpperTorso", "Torso")
	local head = findBodyPart(character, "Head", "Head")
	local leftArm = findBodyPart(character, "LeftUpperArm", "Left Arm")
	local rightArm = findBodyPart(character, "RightUpperArm", "Right Arm")
	if not torso then
		return
	end

	local model = Instance.new("Model")
	model.Name = "ForgedArmor"

	local tier = recipe.Stat
	local plate = recipe.Color:Lerp(Color3.fromRGB(80, 80, 85), 0.2)
	local material = if tier >= 64 then Enum.Material.Glass else Enum.Material.Metal
	local trim = if tier >= 64
		then recipe.Color:Lerp(Color3.new(1, 1, 1), 0.5)
		else recipe.Color:Lerp(Color3.fromRGB(40, 40, 45), 0.5)
	local trimMaterial = if tier >= 64 then Enum.Material.Neon else Enum.Material.Metal

	-- Chest plate with a trim band.
	local chest = armorPart(model, "Chest", torso.Size + Vector3.new(0.2, -0.25, 0.25), plate, material)
	attachTo(torso, chest, CFrame.new(0, 0.05, 0))
	local band = armorPart(model, "Band", Vector3.new(torso.Size.X + 0.24, 0.2, torso.Size.Z + 0.3), trim, trimMaterial)
	attachTo(torso, band, CFrame.new(0, -torso.Size.Y * 0.25, 0))

	-- Shoulder pauldrons.
	for _, arm in { leftArm, rightArm } do
		if arm then
			local pauldron =
				armorPart(model, "Pauldron", Vector3.new(arm.Size.X + 0.45, 0.6, arm.Size.Z + 0.45), plate, material)
			attachTo(arm, pauldron, CFrame.new(0, arm.Size.Y / 2 - 0.1, 0))
			if tier >= 40 then
				local spike = armorPart(model, "PauldronSpike", Vector3.new(0.2, 0.55, 0.2), trim, trimMaterial)
				attachTo(arm, spike, CFrame.new(0, arm.Size.Y / 2 + 0.45, 0))
			end
		end
	end

	-- Helmet from iron tier up.
	if head and tier >= 25 then
		local helmet = armorPart(
			model,
			"Helmet",
			Vector3.new(head.Size.X + 0.3, head.Size.Y * 0.55, head.Size.Z + 0.3),
			plate,
			material
		)
		attachTo(head, helmet, CFrame.new(0, head.Size.Y * 0.25, 0))
		local cap =
			armorPart(model, "HelmetCap", Vector3.new(head.Size.X * 0.85, 0.3, head.Size.Z + 0.2), plate, material)
		attachTo(head, cap, CFrame.new(0, head.Size.Y * 0.6, 0))
		local visor = armorPart(model, "Visor", Vector3.new(head.Size.X * 0.8, 0.14, 0.12), trim, trimMaterial)
		attachTo(head, visor, CFrame.new(0, head.Size.Y * 0.05, -(head.Size.Z / 2 + 0.2)))
		if tier >= 52 then
			local crest = armorPart(model, "Crest", Vector3.new(0.18, 0.7, head.Size.Z * 0.9), trim, trimMaterial)
			attachTo(head, crest, CFrame.new(0, head.Size.Y * 0.62, 0))
		end
	end

	model.Parent = character
end

return GearModels

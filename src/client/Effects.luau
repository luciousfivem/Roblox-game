--!strict
-- Everything you see and hear around ore nodes, all driven by replicated state:
--   * idle animation of decoration parts (spin / bob / pulse / orbit)
--   * shake, sparks, damage numbers and a sound when a node is hit
--   * a burst of particles and flying chunks when a node breaks
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Sounds = require(script.Parent.Sounds)
local UI = require(script.Parent.UI)

local Effects = {}

local player = Players.LocalPlayer

local VIEW_DISTANCE = 90 -- only animate / react to nodes this close to the player

type Decor = {
	Part: BasePart,
	Rel: CFrame,
	Spin: boolean,
	Bob: boolean,
	Pulse: boolean,
	Orbit: boolean,
	Speed: number,
	Amp: number,
	Phase: number,
	BaseTransparency: number,
}

type Tracked = {
	Node: BasePart,
	Base: CFrame,
	Decor: { Decor },
	Shake: number,
	LastHealth: number,
	Color: Color3,
	Material: Enum.Material,
	Boss: boolean,
	Size: number,
}

local tracked: { [BasePart]: Tracked } = {}

local function rootPosition(): Vector3?
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function isNear(position: Vector3, distance: number): boolean
	local origin = rootPosition()
	return origin ~= nil and (origin - position).Magnitude <= distance
end

local function burst(position: Vector3, color: Color3, count: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position
	anchor.Parent = workspace

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Speed = NumberRange.new(10, 24)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Size = NumberSequence.new(0.9, 0)
	emitter.LightEmission = 0.6
	emitter.Acceleration = Vector3.new(0, -35, 0)
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(count)
	Debris:AddItem(anchor, 1.5)
end

local function chunks(position: Vector3, color: Color3, material: Enum.Material, count: number, size: number)
	for _ = 1, count do
		local chunk = Instance.new("Part")
		chunk.Size = Vector3.one * size * (0.6 + math.random() * 0.8)
		chunk.Color = color
		chunk.Material = material
		chunk.CanTouch = false
		chunk.CanQuery = false
		chunk.Massless = true
		chunk.CFrame = CFrame.new(position) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
		chunk.AssemblyLinearVelocity = Vector3.new(math.random(-20, 20), math.random(20, 36), math.random(-20, 20))
		chunk.AssemblyAngularVelocity = Vector3.new(math.random(-12, 12), math.random(-12, 12), math.random(-12, 12))
		chunk.Parent = workspace
		Debris:AddItem(chunk, 1.6)
		TweenService:Create(
			chunk,
			TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 1),
			{ Transparency = 1 }
		):Play()
	end
end

local function floatText(position: Vector3, text: string, color: Color3, scale: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	anchor.Position = position + Vector3.new(math.random(-10, 10) / 10, 0, math.random(-10, 10) / 10)
	anchor.Parent = workspace

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(7 * scale, 2.6 * scale)
	gui.AlwaysOnTop = true
	gui.Parent = anchor

	local label = UI.new("TextLabel", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Font = Enum.Font.GothamBlack,
		TextScaled = true,
		TextColor3 = color,
		TextStrokeTransparency = 0.2,
		Text = text,
	}, gui)

	TweenService:Create(
		anchor,
		TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Position = anchor.Position + Vector3.new(0, 4, 0) }
	):Play()
	TweenService:Create(
		label,
		TweenInfo.new(0.5, Enum.EasingStyle.Linear, Enum.EasingDirection.In, 0, false, 0.4),
		{ TextTransparency = 1, TextStrokeTransparency = 1 }
	):Play()
	Debris:AddItem(anchor, 1.2)
end

-- Collects the animated decoration parts of a node (they replicate with it).
local function collect(node: BasePart, base: CFrame): { Decor }
	local list: { Decor } = {}
	for _, child in node:GetChildren() do
		local anim = child:GetAttribute("Anim")
		if child:IsA("BasePart") and type(anim) == "string" then
			table.insert(list, {
				Part = child,
				Rel = base:ToObjectSpace(child.CFrame),
				Spin = string.find(anim, "Spin", 1, true) ~= nil,
				Bob = string.find(anim, "Bob", 1, true) ~= nil,
				Pulse = string.find(anim, "Pulse", 1, true) ~= nil,
				Orbit = string.find(anim, "Orbit", 1, true) ~= nil,
				Speed = (child:GetAttribute("Speed") :: number?) or 2,
				Amp = (child:GetAttribute("Amp") :: number?) or 0.4,
				Phase = (child:GetAttribute("Phase") :: number?) or 0,
				BaseTransparency = child.Transparency,
			})
		end
	end
	return list
end

local function track(node: Instance)
	if not node:IsA("BasePart") then
		return
	end
	-- Wait a frame so the node's decoration children have arrived with it.
	task.defer(function()
		if not node.Parent then
			return
		end
		local entry: Tracked = {
			Node = node,
			Base = node.CFrame,
			Decor = collect(node, node.CFrame),
			Shake = 0,
			LastHealth = (node:GetAttribute("Health") :: number?) or 0,
			Color = node.Color,
			Material = node.Material,
			Boss = node:GetAttribute("Boss") == true,
			Size = node.Size.Magnitude / 1.7,
		}
		tracked[node] = entry

		node:GetAttributeChangedSignal("Health"):Connect(function()
			local health = (node:GetAttribute("Health") :: number?) or 0
			local dealt = entry.LastHealth - health
			entry.LastHealth = health
			if dealt <= 0 or not isNear(node.Position, VIEW_DISTANCE) then
				return
			end
			entry.Shake = 0.25
			burst(node.Position + Vector3.new(0, node.Size.Y / 2, 0), entry.Color, 5)
			floatText(
				node.Position + Vector3.new(0, node.Size.Y / 2 + 1, 0),
				UI.number(dealt),
				entry.Boss and Color3.fromRGB(255, 225, 80) or Color3.new(1, 1, 1),
				1
			)
			Sounds.play("Hit", 0.4, 0.85 + math.random() * 0.3)
		end)
	end)
end

local function onRemoved(node: Instance)
	local entry = tracked[node :: BasePart]
	tracked[node :: BasePart] = nil
	if not entry or not isNear(entry.Base.Position, VIEW_DISTANCE) then
		return
	end
	burst(entry.Base.Position, entry.Color, if entry.Boss then 70 else 30)
	chunks(entry.Base.Position, entry.Color, entry.Material, if entry.Boss then 10 else 6, entry.Size * 0.25)
	Sounds.play("Break", 0.6, 0.9 + math.random() * 0.2)
end

local function animate(t: number, dt: number)
	local origin = rootPosition()
	if not origin then
		return
	end
	for _, entry in tracked do
		if (entry.Base.Position - origin).Magnitude <= VIEW_DISTANCE then
			local node = entry.Node
			local current = entry.Base
			if entry.Shake > 0 then
				entry.Shake = math.max(0, entry.Shake - dt)
				local k = entry.Shake * 2.2
				current = entry.Base * CFrame.new((math.random() - 0.5) * k, 0, (math.random() - 0.5) * k)
				node.CFrame = current
			end

			for _, decor in entry.Decor do
				local part = decor.Part
				if part.Parent then
					local phase = t * decor.Speed + decor.Phase
					if decor.Orbit then
						part.CFrame = current * CFrame.Angles(0, phase, 0) * decor.Rel
					elseif decor.Spin and decor.Bob then
						part.CFrame = current
							* CFrame.new(0, math.sin(phase) * decor.Amp, 0)
							* decor.Rel
							* CFrame.Angles(0, phase, 0)
					elseif decor.Spin then
						part.CFrame = current * decor.Rel * CFrame.Angles(0, phase, 0)
					elseif decor.Bob then
						part.CFrame = current * CFrame.new(0, math.sin(phase) * decor.Amp, 0) * decor.Rel
					elseif entry.Shake > 0 then
						part.CFrame = current * decor.Rel
					end
					if decor.Pulse then
						part.Transparency =
							math.clamp(decor.BaseTransparency + (0.5 + 0.5 * math.sin(phase)) * decor.Amp, 0, 0.95)
					end
				end
			end
		end
	end
end

function Effects.Init()
	local nodes = workspace:WaitForChild("OreNodes")
	nodes.ChildAdded:Connect(track)
	nodes.ChildRemoved:Connect(onRemoved)
	for _, node in nodes:GetChildren() do
		track(node)
	end
	RunService.Heartbeat:Connect(function(dt)
		animate(os.clock(), dt)
	end)
end

return Effects

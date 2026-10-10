--!strict
-- Hold the mouse button (or a finger) on an ore node to mine it.
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)

local Mining = {}

local player = Players.LocalPlayer

function Mining.Init()
	local mineRemote = Remotes.Event("Mine")
	local nodes = workspace:WaitForChild("OreNodes")

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { nodes }

	local highlight = Instance.new("Highlight")
	highlight.FillTransparency = 1
	highlight.OutlineColor = Color3.new(1, 1, 1)
	highlight.Parent = workspace

	local holding = false
	local usingTouch = false
	local touchPosition = Vector2.zero
	local lastSwing = 0

	local function pointer(): Vector2
		return if usingTouch then touchPosition else UserInputService:GetMouseLocation()
	end

	local function nodeAt(position: Vector2): BasePart?
		local camera = workspace.CurrentCamera
		if not camera then
			return nil
		end
		local ray = camera:ViewportPointToRay(position.X, position.Y)
		local result = workspace:Raycast(ray.Origin, ray.Direction * 500, params)
		local hit = result and result.Instance
		if hit and hit:IsA("BasePart") then
			return hit
		end
		return nil
	end

	local function inRange(node: BasePart): boolean
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		return root ~= nil and (root.Position - node.Position).Magnitude <= Config.MiningRange + node.Size.Magnitude / 2
	end

	local function isPointerInput(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not isPointerInput(input) then
			return
		end
		holding = true
		usingTouch = input.UserInputType == Enum.UserInputType.Touch
		if usingTouch then
			touchPosition = Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if usingTouch and input.UserInputType == Enum.UserInputType.Touch then
			touchPosition = Vector2.new(input.Position.X, input.Position.Y) + GuiService:GetGuiInset()
		end
	end)

	UserInputService.InputEnded:Connect(function(input)
		if isPointerInput(input) then
			holding = false
		end
	end)

	RunService.Heartbeat:Connect(function()
		local node = nodeAt(pointer())
		local target = if node and inRange(node) then node else nil

		-- Hover outline (only meaningful with a mouse).
		highlight.Adornee = if UserInputService.MouseEnabled then target else nil

		if holding and target then
			local cooldown = if State.Data then State.Data.Cooldown else 0.8
			local now = os.clock()
			if now - lastSwing >= cooldown then
				lastSwing = now
				mineRemote:FireServer(target)
			end
		end
	end)
end

return Mining

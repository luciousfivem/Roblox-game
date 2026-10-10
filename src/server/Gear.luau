--!strict
-- Applies a player's equipped gear and upgrades to their character:
-- walk speed, a visual weapon tool, and armor colouring.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = require(ReplicatedStorage.Shared.GameData)
local Data = require(script.Parent.Data)

local Gear = {}

local function makeWeaponTool(recipe: GameData.Recipe): Tool
	local tool = Instance.new("Tool")
	tool.Name = recipe.Name
	tool.ToolTip = `+{recipe.Stat}% mining damage`
	tool.CanBeDropped = false
	tool.GripPos = Vector3.new(0, 0, -1.5)
	tool.GripForward = Vector3.new(-1, 0, 0)
	tool.GripRight = Vector3.new(0, 1, 0)
	tool.GripUp = Vector3.new(0, 0, 1)
	tool:SetAttribute("Forged", true)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 0.8, 4)
	handle.Color = recipe.Color
	handle.Material = if recipe.Stat >= 300 then Enum.Material.Neon else Enum.Material.Metal
	handle.CanCollide = false
	handle.Parent = tool
	return tool
end

local function clearForgedTools(player: Player)
	local containers: { Instance } = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		table.insert(containers, backpack)
	end
	if player.Character then
		table.insert(containers, player.Character)
	end
	for _, container in containers do
		for _, child in container:GetChildren() do
			if child:IsA("Tool") and child:GetAttribute("Forged") then
				child:Destroy()
			end
		end
	end
end

-- Safe to call at any time (new character, new purchase, data finished loading).
function Gear.apply(player: Player)
	local profile = Data.Get(player)
	local character = player.Character
	if not profile or not character then
		return
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = GameData.walkSpeed(profile)
	end

	clearForgedTools(player)
	local weapon = GameData.RecipesById[profile.Weapon]
	local backpack = player:FindFirstChildOfClass("Backpack")
	if weapon and backpack then
		makeWeaponTool(weapon).Parent = backpack
	end

	local armor = GameData.RecipesById[profile.Armor]
	local bodyColors = character:FindFirstChildOfClass("BodyColors")
	if armor and bodyColors then
		bodyColors.TorsoColor3 = armor.Color
		bodyColors.LeftArmColor3 = armor.Color
		bodyColors.RightArmColor3 = armor.Color
	end
end

return Gear

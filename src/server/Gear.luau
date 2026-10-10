--!strict
-- Applies a player's equipped gear and upgrades to their character:
-- walk speed, a forged weapon tool, and armor pieces.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = require(ReplicatedStorage.Shared.GameData)
local Data = require(script.Parent.Data)
local GearModels = require(script.Parent.GearModels)

local Gear = {}

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
		humanoid.WalkSpeed = (player:GetAttribute("AdminSpeed") :: number?) or GameData.walkSpeed(profile)
	end

	clearForgedTools(player)
	local weapon = GameData.RecipesById[profile.Weapon]
	local backpack = player:FindFirstChildOfClass("Backpack")
	if weapon and backpack then
		local tool = GearModels.Weapon(weapon)
		tool.Parent = backpack
		if humanoid and humanoid.Health > 0 then
			humanoid:EquipTool(tool) -- hold it right away
		end
	end

	GearModels.ApplyArmor(character, GameData.RecipesById[profile.Armor])

	-- Admin god mode survives respawns because Gear.apply runs on every new character.
	local god = character:FindFirstChild("AdminGod")
	if player:GetAttribute("God") == true then
		if not god then
			local forceField = Instance.new("ForceField")
			forceField.Name = "AdminGod"
			forceField.Visible = false
			forceField.Parent = character
		end
	elseif god then
		god:Destroy()
	end
end

return Gear

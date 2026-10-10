--!strict
-- Tracks which zone each player is in and applies environmental damage, reduced by armor.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = require(ReplicatedStorage.Shared.GameData)
local Data = require(script.Parent.Data)
local World = require(script.Parent.World)

local Hazards = {}

function Hazards.Init()
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				local profile = Data.Get(player)
				if root and humanoid and profile then
					local zone = World.ZoneAt(root.Position)
					player:SetAttribute("ZoneId", if zone then zone.Id else 0)
					if zone and zone.Hazard > 0 and humanoid.Health > 0 then
						humanoid:TakeDamage(zone.Hazard * (1 - GameData.defense(profile) / 100))
					end
				end
			end
		end
	end)
end

return Hazards

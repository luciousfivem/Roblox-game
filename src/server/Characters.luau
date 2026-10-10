--!strict
-- Spawns every player as an R6 character. Roblox only offers R6 as a place-wide setting, so we build
-- the rig ourselves and attach our own R6 animation script (see src/templates/Animate.client.luau).
-- If anything about that fails we fall back to the engine's default character.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local World = require(script.Parent.World)

local Characters = {}

local RESPAWN_TIME = 4
local descriptions: { [Player]: HumanoidDescription } = {}

-- The player's avatar look (clothes, colours). Falls back to a plain rig when it can't be fetched.
local function descriptionFor(player: Player): HumanoidDescription
	local cached = descriptions[player]
	if cached then
		return cached
	end
	local description: HumanoidDescription? = nil
	if player.UserId > 0 then
		local ok, result = pcall(function()
			return Players:GetHumanoidDescriptionFromUserId(player.UserId)
		end)
		if ok then
			description = result
		end
	end
	local final = description or Instance.new("HumanoidDescription")
	descriptions[player] = final
	return final
end

local function useDefaultCharacter(player: Player, reason: string)
	warn(`[Characters] using the default character: {reason}`)
	player:LoadCharacterAsync()
end

local function spawnCharacter(player: Player)
	if not player.Parent then
		return
	end

	local description = descriptionFor(player)
	local ok, result = pcall(function()
		return Players:CreateHumanoidModelFromDescription(description, Enum.HumanoidRigType.R6)
	end)
	if not ok then
		useDefaultCharacter(player, tostring(result))
		return
	end
	local model: Model = result
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		model:Destroy()
		useDefaultCharacter(player, "rig has no Humanoid")
		return
	end

	model.Name = player.Name
	-- The Animator must exist on the server so everyone sees the animations.
	if not humanoid:FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end

	local templates = ServerStorage:FindFirstChild("Templates")
	local animate = templates and templates:FindFirstChild("Animate")
	if animate then
		animate:Clone().Parent = model
	else
		warn("[Characters] ServerStorage/Templates/Animate is missing, so there will be no animations")
	end

	model:PivotTo(CFrame.new(World.HubSpawn + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4))))
	local previous = player.Character
	model.Parent = workspace
	player.Character = model
	if previous and previous ~= model then
		previous:Destroy()
	end

	humanoid.Died:Connect(function()
		task.wait(RESPAWN_TIME)
		if player.Parent and player.Character == model then
			spawnCharacter(player)
		end
	end)
end

function Characters.Init()
	Players.CharacterAutoLoads = false

	local function onPlayer(player: Player)
		task.spawn(spawnCharacter, player)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		onPlayer(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		descriptions[player] = nil
	end)
end

return Characters

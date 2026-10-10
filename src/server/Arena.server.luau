--!strict
-- Builds a simple arena so the place works without any hand-made map.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)

local size = Config.ArenaSize

local floor = Instance.new("Part")
floor.Name = "ArenaFloor"
floor.Anchored = true
floor.Size = Vector3.new(size, 2, size)
floor.Position = Vector3.new(0, -1, 0)
floor.Material = Enum.Material.Grass
floor.Color = Color3.fromRGB(80, 160, 90)
floor.TopSurface = Enum.SurfaceType.Smooth
floor.Parent = workspace

local spawn = Instance.new("SpawnLocation")
spawn.Anchored = true
spawn.Size = Vector3.new(8, 1, 8)
spawn.Position = Vector3.new(0, 0.5, 0)
spawn.Neutral = true
spawn.Parent = workspace

-- Invisible walls keep players inside the arena.
for _, side in { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } } do
	local wall = Instance.new("Part")
	wall.Name = "ArenaWall"
	wall.Anchored = true
	wall.Transparency = 1
	wall.Size = if side[1] ~= 0 then Vector3.new(1, 40, size) else Vector3.new(size, 40, 1)
	wall.Position = Vector3.new(side[1] * size / 2, 20, side[2] * size / 2)
	wall.Parent = workspace
end

--!strict
-- Always-visible UI: coins, level/XP bar, backpack, combat stats, current zone, portal lock labels.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameData = require(ReplicatedStorage.Shared.GameData)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Hud = {}

local player = Players.LocalPlayer

local function bar(parent: Instance, position: UDim2, size: UDim2, color: Color3): (Frame, Frame)
	local back = UI.new("Frame", {
		BackgroundColor3 = Color3.fromRGB(20, 20, 25),
		BorderSizePixel = 0,
		Position = position,
		Size = size,
	}, parent)
	UI.corner(back, 6)
	local fill = UI.new("Frame", { BackgroundColor3 = color, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1) }, back)
	UI.corner(fill, 6)
	return back, fill
end

local function updatePortals(level: number)
	for _, portal in CollectionService:GetTagged("Portal") do
		local status = portal:FindFirstChild("Status", true) :: TextLabel?
		local required = portal:GetAttribute("RequiredLevel") :: number
		if status then
			if level >= required then
				status.Text = "Unlocked"
				status.TextColor3 = UI.Colors.Good
			else
				status.Text = `Locked - Level {required}`
				status.TextColor3 = UI.Colors.Bad
			end
		end
	end
end

function Hud.Init()
	local gui = UI.new("ScreenGui", { Name = "Hud", ResetOnSpawn = false }, player:WaitForChild("PlayerGui"))

	-- Top-center: level + XP + zone.
	local top = UI.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.fromOffset(340, 74),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, gui)
	UI.corner(top, 10)
	local levelLabel = UI.text(top, {
		Position = UDim2.fromOffset(12, 4),
		Size = UDim2.new(1, -24, 0, 24),
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		Text = "Level 1",
	})
	local _, xpFill = bar(top, UDim2.fromOffset(12, 30), UDim2.new(1, -24, 0, 14), Color3.fromRGB(110, 190, 255))
	local zoneLabel = UI.text(top, {
		Position = UDim2.fromOffset(12, 48),
		Size = UDim2.new(1, -24, 0, 22),
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center,
		RichText = true,
		Text = "",
	})

	-- Left: coins, backpack, stats.
	local side = UI.new("Frame", {
		Position = UDim2.fromOffset(12, 100),
		Size = UDim2.fromOffset(220, 138),
		BackgroundColor3 = UI.Colors.Panel,
		BackgroundTransparency = 0.2,
		BorderSizePixel = 0,
	}, gui)
	UI.corner(side, 10)
	local coinsLabel = UI.text(side, {
		Position = UDim2.fromOffset(12, 6),
		Size = UDim2.new(1, -24, 0, 26),
		Font = Enum.Font.GothamBold,
		TextSize = 22,
		TextColor3 = UI.Colors.Gold,
		Text = "0 coins",
	})
	local backpackLabel = UI.text(side, {
		Position = UDim2.fromOffset(12, 36),
		Size = UDim2.new(1, -24, 0, 20),
		TextSize = 14,
		Text = "Backpack 0/20",
	})
	local _, backpackFill = bar(side, UDim2.fromOffset(12, 58), UDim2.new(1, -24, 0, 10), Color3.fromRGB(240, 170, 60))
	local damageLabel = UI.text(
		side,
		{ Position = UDim2.fromOffset(12, 76), Size = UDim2.new(1, -24, 0, 20), TextSize = 14, Text = "" }
	)
	local defenseLabel = UI.text(
		side,
		{ Position = UDim2.fromOffset(12, 96), Size = UDim2.new(1, -24, 0, 20), TextSize = 14, Text = "" }
	)
	UI.text(side, {
		Position = UDim2.fromOffset(12, 116),
		Size = UDim2.new(1, -24, 0, 18),
		TextSize = 12,
		TextColor3 = UI.Colors.Muted,
		Text = "Hold click on ore to mine",
	})

	local function refreshZone()
		local snapshot = State.Data
		local zone = GameData.Zones[player:GetAttribute("ZoneId") :: number]
		if not zone then
			zoneLabel.Text = `<font color="#{UI.Colors.Muted:ToHex()}">Hub</font>`
			return
		end
		local text = `<font color="#{zone.DifficultyColor:ToHex()}">{zone.Name} ({zone.Difficulty})</font>`
		if zone.Hazard > 0 then
			local defense = if snapshot then snapshot.Defense else 0
			local taken = zone.Hazard * (1 - defense / 100)
			text ..= `  <font color="#{UI.Colors.Bad:ToHex()}">-{string.format("%.1f", taken)} HP/s</font>`
		end
		zoneLabel.Text = text
	end
	player:GetAttributeChangedSignal("ZoneId"):Connect(refreshZone)

	local function refresh(s: { [string]: any })
		levelLabel.Text = if s.XPNeeded > 0
			then `Level {s.Level}   {UI.number(s.XP)} / {UI.number(s.XPNeeded)} XP`
			else `Level {s.Level} (MAX)`
		xpFill.Size = UDim2.fromScale(if s.XPNeeded > 0 then math.clamp(s.XP / s.XPNeeded, 0, 1) else 1, 1)
		coinsLabel.Text = `{UI.number(s.Coins)} coins`
		backpackLabel.Text = `Backpack {s.Used}/{s.Capacity}`
		backpackFill.Size = UDim2.fromScale(math.clamp(s.Used / s.Capacity, 0, 1), 1)
		backpackFill.BackgroundColor3 = if s.Used >= s.Capacity then UI.Colors.Bad else Color3.fromRGB(240, 170, 60)
		damageLabel.Text = `Damage per hit: {string.format("%.0f", s.Damage)}`
		defenseLabel.Text = `Hazard resistance: {s.Defense}%`
		refreshZone()
		updatePortals(s.Level)
	end

	State.Changed:Connect(refresh)
	if State.Data then
		refresh(State.Data)
	end
	CollectionService:GetInstanceAddedSignal("Portal"):Connect(function()
		if State.Data then
			updatePortals(State.Data.Level)
		end
	end)
end

return Hud

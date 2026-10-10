--!strict
-- Windows: Sell, Forge, Upgrade, Pets, Rebirth (opened at hub stations) and Map, Daily (HUD buttons).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local GameData = require(ReplicatedStorage.Shared.GameData)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local State = require(script.Parent.State)
local UI = require(script.Parent.UI)

local Panels = {}

local player = Players.LocalPlayer

type Window = {
	Frame: Frame,
	Tabs: Frame,
	Body: ScrollingFrame,
}

type Snapshot = { [string]: any }

local gui: ScreenGui
local windows: { [string]: Window } = {}
local openPanel: string? = nil
local openStation: BasePart? = nil
local forgeTab: "Weapon" | "Armor" = "Weapon"
local rebirthConfirm = false

local function createWindow(title: string, hasTabs: boolean): Window
	local frame = UI.new("Frame", {
		Visible = false,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.92, 0.8),
		BackgroundColor3 = UI.Colors.Panel,
		BorderSizePixel = 0,
	}, gui)
	UI.corner(frame, 12)
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(560, 480) }, frame)

	UI.text(frame, {
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -80, 0, 36),
		Font = Enum.Font.GothamBold,
		TextSize = 24,
		Text = title,
	})
	local close = UI.button(frame, "X", UI.Colors.Bad, true, function()
		Panels.Close()
	end)
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -12, 0, 10)
	close.Size = UDim2.fromOffset(34, 34)

	local tabs = UI.new("Frame", {
		Position = UDim2.fromOffset(12, 50),
		Size = UDim2.new(1, -24, 0, 34),
		BackgroundTransparency = 1,
		Visible = hasTabs,
	}, frame)
	UI.new("UIListLayout", { FillDirection = Enum.FillDirection.Horizontal, Padding = UDim.new(0, 8) }, tabs)

	local top = if hasTabs then 92 else 54
	local body = UI.new("ScrollingFrame", {
		Position = UDim2.fromOffset(12, top),
		Size = UDim2.new(1, -24, 1, -top - 12),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, frame)
	UI.new("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder }, body)

	return { Frame = frame, Tabs = tabs, Body = body }
end

local function clear(container: Instance)
	for _, child in container:GetChildren() do
		if not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
end

local function newRow(body: Instance, height: number, order: number): Frame
	local row = UI.new("Frame", {
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, height),
		BackgroundColor3 = UI.Colors.Row,
		BorderSizePixel = 0,
	}, body)
	UI.corner(row, 8)
	return row
end

-- Right-aligned button; `slot` 0 is the rightmost, 1 sits to its left, and so on.
local function rightButton(
	row: Frame,
	text: string,
	color: Color3,
	enabled: boolean,
	onClick: () -> (),
	slot: number?,
	width: number?
): TextButton
	local w = width or 110
	local button = UI.button(row, text, color, enabled, onClick)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -12 - (slot or 0) * (w + 8), 0.5, 0)
	button.Size = UDim2.fromOffset(w, 40)
	return button
end

local function rowText(row: Frame, y: number, height: number, props: { [string]: any })
	local merged: { [string]: any } = {
		Position = UDim2.fromOffset(12, y),
		Size = UDim2.new(1, -150, 0, height),
	}
	for key, value in props do
		merged[key] = value
	end
	return UI.text(row, merged)
end

local function infoRow(body: Instance, order: number, height: number, text: string, color: Color3?, size: number?)
	local row = newRow(body, height, order)
	UI.text(row, {
		Position = UDim2.fromOffset(12, 0),
		Size = UDim2.new(1, -24, 1, 0),
		TextWrapped = true,
		RichText = true,
		TextSize = size or 15,
		TextColor3 = color or UI.Colors.Text,
		Text = text,
	})
	return row
end

-- Sell ----------------------------------------------------------------------------------------------------

local function renderSell(s: Snapshot)
	local body = windows.Sell.Body
	local scroll = body.CanvasPosition
	clear(body)

	local top = newRow(body, 60, 0)
	rowText(top, 8, 22, {
		Font = Enum.Font.GothamBold,
		Text = `Total value: {UI.number(s.SellValue)} coins`,
		TextColor3 = UI.Colors.Gold,
	})
	rowText(top, 32, 20, {
		TextSize = 13,
		TextColor3 = UI.Colors.Muted,
		Text = `Bonus multiplier: x{string.format("%.2f", s.SellMultiplier)}`,
	})
	rightButton(top, "Sell All", UI.Colors.Good, s.SellValue > 0, function()
		Remotes.Event("Sell"):FireServer()
	end)

	local order = 1
	for _, ore in GameData.OreOrder do
		local count = s.Ores[ore.Id]
		if count and count > 0 then
			local row = newRow(body, 40, order)
			order += 1
			local swatch = UI.new("Frame", {
				Position = UDim2.fromOffset(12, 10),
				Size = UDim2.fromOffset(20, 20),
				BackgroundColor3 = ore.Color,
				BorderSizePixel = 0,
			}, row)
			UI.corner(swatch, 4)
			UI.text(
				row,
				{ Position = UDim2.fromOffset(44, 0), Size = UDim2.new(0.5, -44, 1, 0), Text = `{ore.Name}  x{count}` }
			)
			UI.text(row, {
				Position = UDim2.new(0.5, 0, 0, 0),
				Size = UDim2.new(0.5, -12, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = UI.Colors.Gold,
				Text = `{UI.number(ore.Value * count)} coins`,
			})
		end
	end
	if order == 1 then
		UI.text(body, {
			LayoutOrder = 1,
			Size = UDim2.new(1, 0, 0, 60),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextColor3 = UI.Colors.Muted,
			Text = "Your backpack is empty. Go mine some ore!",
		})
	end
	body.CanvasPosition = scroll
end

-- Forge ---------------------------------------------------------------------------------------------------

local function requirementText(recipe: GameData.Recipe, s: Snapshot): string
	local parts = {}
	for _, ore in GameData.OreOrder do
		local need = recipe.Ores[ore.Id]
		if need then
			local have = s.Ores[ore.Id] or 0
			local color = if have >= need then UI.Colors.Good else UI.Colors.Bad
			table.insert(parts, `<font color="#{color:ToHex()}">{ore.Name} {have}/{need}</font>`)
		end
	end
	local coinColor = if s.Coins >= recipe.Coins then UI.Colors.Good else UI.Colors.Bad
	table.insert(parts, `<font color="#{coinColor:ToHex()}">{UI.number(recipe.Coins)} coins</font>`)
	return table.concat(parts, "   ")
end

local function renderForge(s: Snapshot)
	local window = windows.Forge
	clear(window.Tabs)
	for _, kind in { "Weapon", "Armor" } do
		local button = UI.button(
			window.Tabs,
			if kind == "Weapon" then "Weapons" else "Armor",
			UI.Colors.Button,
			forgeTab ~= kind,
			function()
				forgeTab = kind :: any
				Panels.Refresh()
			end
		)
		button.Size = UDim2.fromOffset(120, 34)
	end

	local body = window.Body
	local scroll = body.CanvasPosition
	clear(body)

	for order, recipe in GameData.Recipes do
		if recipe.Kind == forgeTab then
			local row = newRow(body, 96, order)
			rowText(row, 6, 24, {
				Font = Enum.Font.GothamBold,
				TextSize = 18,
				TextColor3 = UI.readable(recipe.Color),
				Text = recipe.Name,
			})
			rowText(row, 30, 20, {
				TextSize = 14,
				TextColor3 = UI.Colors.Muted,
				Text = if recipe.Kind == "Weapon"
					then `+{recipe.Stat}% mining damage`
					else `{math.min(95, recipe.Stat)}% less hazard damage`,
			})
			rowText(row, 52, 40, {
				TextSize = 13,
				TextWrapped = true,
				TextYAlignment = Enum.TextYAlignment.Top,
				RichText = true,
				Text = requirementText(recipe, s),
			})

			local owned = s.Owned[recipe.Id]
			local equipped = s.Weapon == recipe.Id or s.Armor == recipe.Id
			if equipped then
				rightButton(row, "Equipped", UI.Colors.Disabled, false, function() end)
			elseif owned then
				rightButton(row, "Equip", UI.Colors.Button, true, function()
					Remotes.Event("Equip"):FireServer(recipe.Id)
				end)
			else
				local canAfford = s.Coins >= recipe.Coins
				for oreId, need in recipe.Ores do
					if (s.Ores[oreId] or 0) < need then
						canAfford = false
					end
				end
				rightButton(row, "Forge", UI.Colors.Good, canAfford, function()
					Remotes.Event("Forge"):FireServer(recipe.Id)
				end)
			end
		end
	end
	body.CanvasPosition = scroll
end

-- Upgrades ------------------------------------------------------------------------------------------------

local function renderUpgrade(s: Snapshot)
	local body = windows.Upgrade.Body
	local scroll = body.CanvasPosition
	clear(body)

	for order, upgrade in GameData.Upgrades do
		local level = s.Upgrades[upgrade.Id] or 0
		local row = newRow(body, 76, order)
		rowText(
			row,
			6,
			24,
			{ Font = Enum.Font.GothamBold, TextSize = 18, Text = `{upgrade.Name}  (Lv {level}/{upgrade.MaxLevel})` }
		)
		rowText(row, 32, 20, { TextSize = 14, TextColor3 = UI.Colors.Muted, Text = upgrade.Description })
		if level >= upgrade.MaxLevel then
			rowText(row, 52, 20, { TextSize = 14, TextColor3 = UI.Colors.Good, Text = "Maxed out" })
			rightButton(row, "MAX", UI.Colors.Disabled, false, function() end)
		else
			local cost = GameData.upgradeCost(upgrade.Id, level)
			local canAfford = s.Coins >= cost
			rowText(row, 52, 20, {
				TextSize = 14,
				TextColor3 = if canAfford then UI.Colors.Gold else UI.Colors.Bad,
				Text = `Cost: {UI.number(cost)} coins`,
			})
			rightButton(row, "Buy", UI.Colors.Good, canAfford, function()
				Remotes.Event("Buy"):FireServer(upgrade.Id)
			end)
		end
	end
	body.CanvasPosition = scroll
end

-- Pets ---------------------------------------------------------------------------------------------------

local function renderPets(s: Snapshot)
	local body = windows.Pets.Body
	local scroll = body.CanvasPosition
	clear(body)

	local equipped: { [string]: number } = {}
	for _, id in s.EquippedPets do
		equipped[id] = (equipped[id] or 0) + 1
	end
	local slotsFull = #s.EquippedPets >= s.MaxPets

	infoRow(
		body,
		0,
		44,
		`Equipped pets: <b>{#s.EquippedPets} / {s.MaxPets}</b>. Pets follow you and mine nearby ore automatically (more slots with rebirths).`,
		UI.Colors.Muted,
		13
	)

	local order = 1
	for _, egg in GameData.Eggs do
		local total = 0
		for _, entry in egg.Pets do
			total += entry.Weight
		end
		local odds = {}
		for _, entry in egg.Pets do
			local pet = GameData.PetsById[entry.Id]
			local color = GameData.RarityColors[pet.Rarity]
			table.insert(
				odds,
				`<font color="#{color:ToHex()}">{pet.Name} {math.floor(entry.Weight / total * 100)}%</font>`
			)
		end
		local row = newRow(body, 96, order)
		order += 1
		rowText(
			row,
			6,
			24,
			{ Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = UI.readable(egg.Color), Text = egg.Name }
		)
		rowText(row, 30, 20, {
			TextSize = 14,
			TextColor3 = if s.Coins >= egg.Cost then UI.Colors.Gold else UI.Colors.Bad,
			Text = `{UI.number(egg.Cost)} coins`,
		})
		rowText(row, 52, 40, {
			TextSize = 12,
			TextWrapped = true,
			TextYAlignment = Enum.TextYAlignment.Top,
			RichText = true,
			Text = table.concat(odds, "   "),
		})
		rightButton(row, "Hatch", UI.Colors.Good, s.Coins >= egg.Cost, function()
			Remotes.Event("Hatch"):FireServer(egg.Id)
		end)
	end

	for _, pet in GameData.Pets do
		local owned = s.Pets[pet.Id]
		if owned and owned > 0 then
			local row = newRow(body, 64, order)
			order += 1
			local color = GameData.RarityColors[pet.Rarity]
			rowText(
				row,
				6,
				24,
				{ Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = color, Text = `{pet.Name}  ({pet.Rarity})` }
			)
			rowText(row, 32, 24, {
				Size = UDim2.new(1, -220, 0, 24),
				TextSize = 13,
				TextColor3 = UI.Colors.Muted,
				Text = `Power {UI.number(pet.Power)}  |  Owned {owned}  |  Equipped {equipped[pet.Id] or 0}`,
			})
			local canEquip = (equipped[pet.Id] or 0) < owned and not slotsFull
			rightButton(row, "Equip", UI.Colors.Button, canEquip, function()
				Remotes.Event("PetEquip"):FireServer(pet.Id, true)
			end, 0, 80)
			rightButton(row, "Remove", UI.Colors.Bad, (equipped[pet.Id] or 0) > 0, function()
				Remotes.Event("PetEquip"):FireServer(pet.Id, false)
			end, 1, 80)
		end
	end
	body.CanvasPosition = scroll
end

-- Rebirth ---------------------------------------------------------------------------------------------------

local function renderRebirth(s: Snapshot)
	local body = windows.Rebirth.Body
	local scroll = body.CanvasPosition
	clear(body)

	local maxed = s.Rebirths >= GameData.MaxRebirths
	local levelColor = if s.Level >= s.RebirthLevel then UI.Colors.Good else UI.Colors.Bad
	local nextCoins = 1 + GameData.RebirthCoinBonus * (s.Rebirths + 1)
	local nextXP = 1 + GameData.RebirthXPBonus * (s.Rebirths + 1)

	infoRow(
		body,
		1,
		50,
		`Rebirths: <b>{s.Rebirths} / {GameData.MaxRebirths}</b>\nPermanent bonus: coins x{string.format(
			"%.2f",
			1 + GameData.RebirthCoinBonus * s.Rebirths
		)}, XP x{string.format("%.2f", s.XPMultiplier)}`,
		UI.Colors.Text
	)
	if maxed then
		infoRow(body, 2, 44, "You have reached the maximum rebirth. Congratulations!", UI.Colors.Gold)
	else
		infoRow(
			body,
			2,
			36,
			`Requirement: <font color="#{levelColor:ToHex()}">level {s.RebirthLevel}</font> (you are level {s.Level})`
		)
		infoRow(
			body,
			3,
			36,
			`Next rebirth: coins x{string.format("%.2f", nextCoins)}, XP x{string.format("%.2f", nextXP)}`,
			UI.Colors.Good
		)
	end
	infoRow(
		body,
		4,
		48,
		`<font color="#{UI.Colors.Bad:ToHex()}">Resets:</font> level, XP, coins, backpack ore and upgrades.`,
		UI.Colors.Muted,
		14
	)
	infoRow(
		body,
		5,
		48,
		`<font color="#{UI.Colors.Good:ToHex()}">Keeps:</font> forged weapons and armor, pets, rebirth bonuses, and 1 extra pet slot per rebirth (up to 3).`,
		UI.Colors.Muted,
		14
	)

	local row = newRow(body, 64, 6)
	local canRebirth = s.CanRebirth
	rightButton(
		row,
		if rebirthConfirm then "Confirm!" else "Rebirth",
		if rebirthConfirm then UI.Colors.Bad else Color3.fromRGB(160, 90, 230),
		canRebirth,
		function()
			if rebirthConfirm then
				rebirthConfirm = false
				Remotes.Event("Rebirth"):FireServer()
				Panels.Close()
			else
				rebirthConfirm = true
				Panels.Refresh()
				task.delay(4, function()
					if rebirthConfirm then
						rebirthConfirm = false
						Panels.Refresh()
					end
				end)
			end
		end,
		0,
		150
	)
	rowText(row, 0, 64, {
		Size = UDim2.new(1, -190, 1, 0),
		TextSize = 14,
		TextWrapped = true,
		TextColor3 = UI.Colors.Muted,
		Text = if maxed
			then "Maximum reached."
			elseif canRebirth then "Click Rebirth, then Confirm."
			else "Reach the required level first.",
	})
	body.CanvasPosition = scroll
end

-- Map -----------------------------------------------------------------------------------------------------------

local function renderMap(s: Snapshot)
	local body = windows.Map.Body
	local scroll = body.CanvasPosition
	clear(body)

	local hub = newRow(body, 56, 0)
	rowText(hub, 0, 56, { Font = Enum.Font.GothamBold, TextSize = 18, Text = "Hub", Size = UDim2.new(1, -150, 1, 0) })
	rightButton(hub, "Teleport", UI.Colors.Button, true, function()
		Remotes.Event("Teleport"):FireServer(0)
		Panels.Close()
	end)

	for _, zone in GameData.Zones do
		local unlocked = s.Level >= zone.RequiredLevel
		local row = newRow(body, 76, zone.Id)
		rowText(
			row,
			6,
			24,
			{ Font = Enum.Font.GothamBold, TextSize = 18, TextColor3 = zone.DifficultyColor, Text = zone.Name }
		)
		rowText(row, 32, 20, {
			TextSize = 14,
			TextColor3 = if unlocked then UI.Colors.Muted else UI.Colors.Bad,
			Text = `{zone.Difficulty}  -  Level {zone.RequiredLevel}{if unlocked then "" else "  (locked)"}`,
		})
		local hazard = if zone.Hazard > 0
			then `Hazard: {string.format("%.1f", zone.Hazard * (1 - s.Defense / 100))} HP/s with your armor`
			else "No hazard"
		rowText(
			row,
			52,
			20,
			{ TextSize = 13, TextColor3 = if zone.Hazard > 0 then UI.Colors.Bad else UI.Colors.Good, Text = hazard }
		)
		rightButton(row, if unlocked then "Teleport" else "Locked", UI.Colors.Button, unlocked, function()
			Remotes.Event("Teleport"):FireServer(zone.Id)
			Panels.Close()
		end)
	end
	body.CanvasPosition = scroll
end

-- Daily ---------------------------------------------------------------------------------------------------------

local function renderDaily(s: Snapshot)
	local body = windows.Daily.Body
	local scroll = body.CanvasPosition
	clear(body)

	infoRow(
		body,
		1,
		44,
		`Current streak: <b>{s.DailyStreak}</b> day(s). Log in every day to keep it going.`,
		UI.Colors.Text
	)
	infoRow(
		body,
		2,
		44,
		`Today's reward (day {s.DailyNextStreak}): <b>{UI.number(s.DailyReward)} coins</b>`,
		UI.Colors.Gold,
		17
	)
	if s.DailyBonusPet then
		infoRow(body, 3, 36, "Bonus: a free Dirt Egg pet on this day!", Color3.fromRGB(255, 160, 220))
	else
		local untilBonus = 7 - (s.DailyNextStreak % 7)
		infoRow(body, 3, 36, `A free pet arrives in {untilBonus} more day(s) of streak.`, UI.Colors.Muted, 14)
	end

	local row = newRow(body, 64, 4)
	if s.DailyReady then
		rightButton(row, "Claim", UI.Colors.Good, true, function()
			Remotes.Event("Daily"):FireServer()
		end, 0, 150)
		rowText(
			row,
			0,
			64,
			{ Size = UDim2.new(1, -190, 1, 0), TextColor3 = UI.Colors.Good, Text = "Your reward is ready!" }
		)
	else
		local hours = math.floor(s.DailyResetIn / 3600)
		local minutes = math.floor(s.DailyResetIn % 3600 / 60)
		rightButton(row, "Claimed", UI.Colors.Disabled, false, function() end, 0, 150)
		rowText(row, 0, 64, {
			Size = UDim2.new(1, -190, 1, 0),
			TextColor3 = UI.Colors.Muted,
			Text = `Next reward in {hours}h {minutes}m`,
		})
	end
	body.CanvasPosition = scroll
end

local renderers: { [string]: (Snapshot) -> () } = {
	Sell = renderSell,
	Forge = renderForge,
	Upgrade = renderUpgrade,
	Pets = renderPets,
	Rebirth = renderRebirth,
	Map = renderMap,
	Daily = renderDaily,
}

-- Public --------------------------------------------------------------------------------------------------------

function Panels.Refresh()
	if openPanel and State.Data then
		renderers[openPanel](State.Data)
	end
end

function Panels.Close()
	if openPanel then
		windows[openPanel].Frame.Visible = false
	end
	openPanel = nil
	openStation = nil
	rebirthConfirm = false
end

-- `station` is the hub station the window belongs to; the window closes when you walk away from it.
function Panels.Open(name: string, station: BasePart?)
	if not windows[name] then
		return
	end
	Panels.Close()
	openPanel = name
	openStation = station
	windows[name].Frame.Visible = true
	Panels.Refresh()
end

function Panels.Toggle(name: string)
	if openPanel == name then
		Panels.Close()
	else
		Panels.Open(name, nil)
	end
end

function Panels.Init()
	gui = UI.new(
		"ScreenGui",
		{ Name = "Panels", ResetOnSpawn = false, DisplayOrder = 10 },
		player:WaitForChild("PlayerGui")
	)
	windows.Sell = createWindow("Sell Shop", false)
	windows.Forge = createWindow("The Forge", true)
	windows.Upgrade = createWindow("Upgrade Shop", false)
	windows.Pets = createWindow("Pet Hatchery", false)
	windows.Rebirth = createWindow("Rebirth Altar", false)
	windows.Map = createWindow("World Map", false)
	windows.Daily = createWindow("Daily Reward", false)

	State.Changed:Connect(Panels.Refresh)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		local name = prompt:GetAttribute("Panel")
		local station = prompt.Parent
		if who == player and type(name) == "string" and station and station:IsA("BasePart") then
			Panels.Open(name, station)
		end
	end)

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.M then
			Panels.Toggle("Map")
		end
	end)

	-- Close automatically when the player walks away from the station.
	task.spawn(function()
		while true do
			task.wait(0.4)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if
				openStation and (not root or (root.Position - openStation.Position).Magnitude > Config.StationRange + 4)
			then
				Panels.Close()
			end
		end
	end)
end

return Panels

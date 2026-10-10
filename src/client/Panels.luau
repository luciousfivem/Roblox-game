--!strict
-- Sell / Forge / Upgrade windows, opened from the stations in the hub.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

local gui: ScreenGui
local windows: { [string]: Window } = {}
local openPanel: string? = nil
local openStation: BasePart? = nil
local forgeTab: "Weapon" | "Armor" = "Weapon"

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
	UI.new("UISizeConstraint", { MaxSize = Vector2.new(540, 470) }, frame)

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

local function rightButton(row: Frame, text: string, color: Color3, enabled: boolean, onClick: () -> ()): TextButton
	local button = UI.button(row, text, color, enabled, onClick)
	button.AnchorPoint = Vector2.new(1, 0.5)
	button.Position = UDim2.new(1, -12, 0.5, 0)
	button.Size = UDim2.fromOffset(110, 40)
	return button
end

-- Sell ----------------------------------------------------------------------------------------------------

local function renderSell(s: { [string]: any })
	local body = windows.Sell.Body
	local scroll = body.CanvasPosition
	clear(body)

	local top = newRow(body, 60, 0)
	UI.text(top, {
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -150, 0, 22),
		Font = Enum.Font.GothamBold,
		Text = `Total value: {UI.number(s.SellValue)} coins`,
		TextColor3 = UI.Colors.Gold,
	})
	UI.text(top, {
		Position = UDim2.fromOffset(12, 32),
		Size = UDim2.new(1, -150, 0, 20),
		TextSize = 13,
		TextColor3 = UI.Colors.Muted,
		Text = `Merchant bonus: x{string.format("%.2f", s.SellMultiplier)}`,
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

local function requirementText(recipe: GameData.Recipe, s: { [string]: any }): string
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

local function renderForge(s: { [string]: any })
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
			UI.text(row, {
				Position = UDim2.fromOffset(12, 6),
				Size = UDim2.new(1, -150, 0, 24),
				Font = Enum.Font.GothamBold,
				TextSize = 18,
				TextColor3 = UI.readable(recipe.Color),
				Text = recipe.Name,
			})
			UI.text(row, {
				Position = UDim2.fromOffset(12, 30),
				Size = UDim2.new(1, -150, 0, 20),
				TextSize = 14,
				TextColor3 = UI.Colors.Muted,
				Text = if recipe.Kind == "Weapon"
					then `+{recipe.Stat}% mining damage`
					else `{recipe.Stat}% less hazard damage`,
			})
			UI.text(row, {
				Position = UDim2.fromOffset(12, 52),
				Size = UDim2.new(1, -150, 0, 40),
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

local function renderUpgrade(s: { [string]: any })
	local body = windows.Upgrade.Body
	local scroll = body.CanvasPosition
	clear(body)

	for order, upgrade in GameData.Upgrades do
		local level = s.Upgrades[upgrade.Id] or 0
		local row = newRow(body, 76, order)
		UI.text(row, {
			Position = UDim2.fromOffset(12, 6),
			Size = UDim2.new(1, -150, 0, 24),
			Font = Enum.Font.GothamBold,
			TextSize = 18,
			Text = `{upgrade.Name}  (Lv {level}/{upgrade.MaxLevel})`,
		})
		UI.text(row, {
			Position = UDim2.fromOffset(12, 32),
			Size = UDim2.new(1, -150, 0, 20),
			TextSize = 14,
			TextColor3 = UI.Colors.Muted,
			Text = upgrade.Description,
		})
		if level >= upgrade.MaxLevel then
			UI.text(row, {
				Position = UDim2.fromOffset(12, 52),
				Size = UDim2.new(1, -150, 0, 20),
				TextSize = 14,
				TextColor3 = UI.Colors.Good,
				Text = "Maxed out",
			})
			rightButton(row, "MAX", UI.Colors.Disabled, false, function() end)
		else
			local cost = GameData.upgradeCost(upgrade.Id, level)
			local canAfford = s.Coins >= cost
			UI.text(row, {
				Position = UDim2.fromOffset(12, 52),
				Size = UDim2.new(1, -150, 0, 20),
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

local renderers: { [string]: ({ [string]: any }) -> () } = {
	Sell = renderSell,
	Forge = renderForge,
	Upgrade = renderUpgrade,
}

-- Public --------------------------------------------------------------------------------------------------

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
end

function Panels.Open(name: string, station: BasePart)
	if not windows[name] then
		return
	end
	Panels.Close()
	openPanel = name
	openStation = station
	windows[name].Frame.Visible = true
	Panels.Refresh()
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

	State.Changed:Connect(Panels.Refresh)

	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		local name = prompt:GetAttribute("Panel")
		local station = prompt.Parent
		if who == player and type(name) == "string" and station and station:IsA("BasePart") then
			Panels.Open(name, station)
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

--!strict
-- Short-lived messages stacked on the right side of the screen.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local UI = require(script.Parent.UI)

local Toasts = {}

local MAX_TOASTS = 6
local LIFETIME = 2.6

function Toasts.Init()
	local gui = UI.new(
		"ScreenGui",
		{ Name = "Toasts", ResetOnSpawn = false, DisplayOrder = 20 },
		Players.LocalPlayer:WaitForChild("PlayerGui")
	)
	local holder = UI.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -16, 0.5, 0),
		Size = UDim2.fromOffset(300, 300),
		BackgroundTransparency = 1,
	}, gui)
	UI.new("UIListLayout", {
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, holder)

	local order = 0
	Remotes.Event("Toast").OnClientEvent:Connect(function(text: string, color: Color3)
		order += 1
		local label = UI.text(holder, {
			LayoutOrder = order,
			Size = UDim2.fromOffset(300, 28),
			Text = text,
			TextColor3 = color,
			TextSize = 18,
			Font = Enum.Font.GothamBold,
			TextXAlignment = Enum.TextXAlignment.Right,
			TextStrokeTransparency = 0.3,
		})

		local children = holder:GetChildren()
		local count = 0
		for _, child in children do
			if child:IsA("TextLabel") then
				count += 1
			end
		end
		if count > MAX_TOASTS then
			for _, child in children do
				if child:IsA("TextLabel") then
					child:Destroy()
					break
				end
			end
		end

		task.delay(LIFETIME, function()
			if label.Parent then
				local tween =
					TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1, TextStrokeTransparency = 1 })
				tween:Play()
				tween.Completed:Wait()
				label:Destroy()
			end
		end)
	end)
end

return Toasts

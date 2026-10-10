--!strict
-- Shows the player's coin count and pops a "+N" when it increases.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local stats = player:WaitForChild("leaderstats")
local coins = stats:WaitForChild("Coins") :: IntValue

local gui = Instance.new("ScreenGui")
gui.Name = "CoinHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.fromScale(0.5, 0.03)
label.Size = UDim2.fromOffset(220, 50)
label.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
label.BackgroundTransparency = 0.3
label.TextColor3 = Color3.fromRGB(255, 220, 60)
label.Font = Enum.Font.GothamBold
label.TextSize = 28
label.Text = "Coins: 0"
label.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = label

local scale = Instance.new("UIScale")
scale.Parent = label

local last = coins.Value
coins:GetPropertyChangedSignal("Value"):Connect(function()
	local gained = coins.Value - last
	last = coins.Value
	label.Text = `Coins: {coins.Value}`

	if gained > 0 then
		scale.Scale = 1.25
		TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	end
end)

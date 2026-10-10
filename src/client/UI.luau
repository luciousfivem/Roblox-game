--!strict
-- Tiny helpers so the UI code stays readable.
local Sounds = require(script.Parent.Sounds)

local UI = {}

UI.Colors = {
	Panel = Color3.fromRGB(28, 30, 38),
	Row = Color3.fromRGB(42, 45, 57),
	Text = Color3.fromRGB(240, 240, 245),
	Muted = Color3.fromRGB(165, 170, 185),
	Gold = Color3.fromRGB(255, 215, 70),
	Good = Color3.fromRGB(120, 235, 120),
	Bad = Color3.fromRGB(255, 110, 110),
	Button = Color3.fromRGB(70, 150, 235),
	Disabled = Color3.fromRGB(80, 82, 92),
}

function UI.new(className: string, props: { [string]: any }?, parent: Instance?): any
	local inst = Instance.new(className)
	if props then
		for key, value in props do
			(inst :: any)[key] = value
		end
	end
	inst.Parent = parent
	return inst
end

function UI.corner(parent: Instance, radius: number?): UICorner
	return UI.new("UICorner", { CornerRadius = UDim.new(0, radius or 8) }, parent)
end

function UI.text(parent: Instance, props: { [string]: any }): TextLabel
	local merged: { [string]: any } = {
		BackgroundTransparency = 1,
		Font = Enum.Font.GothamMedium,
		TextColor3 = UI.Colors.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
	}
	for key, value in props do
		merged[key] = value
	end
	return UI.new("TextLabel", merged, parent)
end

function UI.button(parent: Instance, text: string, color: Color3, enabled: boolean, onClick: () -> ()): TextButton
	local button = UI.new("TextButton", {
		BackgroundColor3 = if enabled then color else UI.Colors.Disabled,
		AutoButtonColor = enabled,
		Active = enabled,
		Font = Enum.Font.GothamBold,
		Text = text,
		TextColor3 = if enabled then Color3.new(1, 1, 1) else UI.Colors.Muted,
		TextSize = 16,
		BorderSizePixel = 0,
	}, parent)
	UI.corner(button, 8)
	if enabled then
		button.Activated:Connect(function()
			Sounds.play("Click", 0.4)
			onClick()
		end)
	end
	return button
end

-- 1234 -> "1,234"; 1250000 -> "1.25M"
function UI.number(n: number): string
	n = math.floor(n)
	if n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	end
	local s = tostring(n)
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- Lightens a colour so dark ores stay readable on a dark UI.
function UI.readable(color: Color3): Color3
	return color:Lerp(Color3.new(1, 1, 1), 0.35)
end

return UI

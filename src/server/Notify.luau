--!strict
-- Sends small on-screen messages to a player.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local Notify = {}

function Notify.toast(player: Player, text: string, color: Color3?)
	Remotes.Event("Toast"):FireClient(player, text, color or Color3.new(1, 1, 1))
end

return Notify

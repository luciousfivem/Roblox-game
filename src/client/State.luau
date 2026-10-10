--!strict
-- Holds the latest state snapshot sent by the server and announces changes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

local State = {}

State.Data = nil :: { [string]: any }?

local changed = Instance.new("BindableEvent")
State.Changed = changed.Event :: RBXScriptSignal

local function set(snapshot: { [string]: any })
	State.Data = snapshot
	changed:Fire(snapshot)
end

function State.Init()
	Remotes.Event("State").OnClientEvent:Connect(set)
	task.spawn(function()
		local snapshot = Remotes.Function("GetState"):InvokeServer()
		if snapshot and not State.Data then
			set(snapshot)
		end
	end)
end

return State

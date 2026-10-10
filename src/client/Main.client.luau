--!strict
-- Entry point for all client-side UI and input.
local Hud = require(script.Parent.Hud)
local Mining = require(script.Parent.Mining)
local Panels = require(script.Parent.Panels)
local State = require(script.Parent.State)
local Toasts = require(script.Parent.Toasts)

State.Init()
Toasts.Init()
Hud.Init()
Panels.Init()
Mining.Init()

--!strict
-- Entry point for all client-side UI, effects and input.
local Effects = require(script.Parent.Effects)
local Hud = require(script.Parent.Hud)
local Mining = require(script.Parent.Mining)
local Panels = require(script.Parent.Panels)
local State = require(script.Parent.State)
local Toasts = require(script.Parent.Toasts)

State.Init()
Toasts.Init()
Panels.Init()
Hud.Init()
Effects.Init()
Mining.Init()

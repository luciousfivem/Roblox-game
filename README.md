# Coin Rush

A small Roblox game: run around an arena and grab coins. Gold coins are worth 5.

## Setup

1. Install tools: `rokit install` (Rojo, Selene, StyLua).
2. `rojo build -o CoinRush.rbxl` then open the file in Roblox Studio, or
   run `rojo serve` and connect with the Rojo Studio plugin.

## Layout

- `src/shared/Config.luau` – tunable settings
- `src/server/` – arena, coin spawning, leaderstats
- `src/client/Hud.client.luau` – coin counter UI

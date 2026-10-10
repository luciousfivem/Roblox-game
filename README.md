# Forge Miners

A Roblox mining simulator. Mine ore across zones from **Normal** to **Nightmare**, sell it for coins,
forge weapons and armor, and level up to unlock harder, richer zones.

## Gameplay loop

1. **Mine** – hold click (or touch) on an ore node near you. Each hit deals damage; break the node to
   collect ore and XP. Your backpack has limited space.
2. **Sell** – at the *Sell Shop* in the hub, turn ore into coins.
3. **Upgrade** – at the *Upgrade Shop*, spend coins on pickaxe power, backpack size, mining speed,
   lucky double-drops, sell bonus and walk speed.
4. **Forge** – at *The Forge*, combine ore + coins into weapons (+% mining damage) and armor
   (-% hazard damage). Equipped gear applies automatically.
5. **Level up** – XP from mining raises your level, unlocking portals to tougher zones.

| Zone | Difficulty | Level | Hazard | Main ores |
| --- | --- | --- | --- | --- |
| Sunny Quarry | Normal | 1 | – | Stone, Coal, Copper |
| Iron Caverns | Tough | 5 | – | Coal, Copper, Iron |
| Silver Ridge | Hard | 10 | – | Iron, Silver, Gold |
| Crystal Depths | Brutal | 16 | 3 dmg/s | Gold, Crystal |
| Magma Fields | Extreme | 24 | 8 dmg/s | Crystal, Obsidian |
| Frozen Abyss | Insane | 34 | 15 dmg/s | Obsidian, Mythril |
| Void Core | Nightmare | 45 | 25 dmg/s | Mythril, Voidstone |

Hazard damage is reduced by your armor's resistance, so deep zones need forged armor.

## Setup

1. `rokit install` (Rojo, Selene, StyLua).
2. `rojo build -o ForgeMiners.rbxl`, open it in Roblox Studio, or `rojo serve` + the Rojo plugin.
3. To test saving in Studio, enable *Game Settings -> Security -> Enable Studio Access to API Services*.
   Without it the game still plays; progress just isn't saved.

## Layout

```
src/shared/GameData.luau   ores, zones, recipes, upgrades + all formulas (edit this to rebalance)
src/shared/Config.luau     world layout and timing constants
src/shared/Remotes.luau    RemoteEvent / RemoteFunction registry
src/server/                Data (save/load, XP), World (hub, zones, nodes), Mining, Economy,
                           Gear, Hazards, Main
src/client/                State, Hud, Panels (sell/forge/upgrade UI), Mining (input), Toasts, Main
```

The server is authoritative: mining range, swing rate, backpack space, recipe costs, upgrade costs
and station distance are all validated server-side. The client only sends intents.

## Balancing

Add content by editing `GameData.luau`: a new ore, zone, recipe or upgrade appears in the world
and UI automatically. XP per level is `10 * level^1.8` (`xpForLevel`).

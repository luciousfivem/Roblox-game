Custom models. Anything placed here (or in ReplicatedStorage/Models inside Studio) overrides the
procedural look. Names must match the ids in src/shared/GameData.luau.

Ores/     Model named after the ore id (Stone, Coal, Copper, ... Eclipsium). Author it at roughly
          4 studs wide; it is scaled to each node. Give any part an attribute Anim = Spin, Bob,
          Pulse or Orbit (comma-separate to combine) and optional Speed / Amp numbers to animate it.
Weapons/  Tool named after the recipe id (CopperSword, IronSword, ... EclipseReaper) with a Handle.
Armor/    Model named after the recipe id (CopperArmor, ... EclipseAegis) with parts named Chest,
          Head, LeftArm, RightArm. Each is welded to the matching body part.

Export from Studio with right-click > Save to File... as .rbxm and drop the file into the folder.

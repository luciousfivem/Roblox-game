--!strict
-- World / tuning constants shared by server and client.
return {
	MiningRange = 20, -- studs between player and ore node
	StationRange = 18, -- studs to use a shop / forge / sell station
	NodesPerZone = 22,
	NodeRespawnTime = 8, -- seconds
	ZoneSize = 180, -- studs, square platform
	ZoneSpacing = 280, -- studs between zone centres
	ZoneOffsetZ = -320, -- zones sit north of the hub
	HubSize = 160,
	AutosaveInterval = 60,
	DataStoreName = "ForgeMinersV1",
	TeleportCooldown = 3, -- seconds between map teleports

	-- "Rich" boss nodes: rare, tougher, and pay out much more.
	BossChance = 0.04,
	BossHealthMult = 6,
	BossYield = 5,
	BossXPMult = 4,

	-- Pets
	PetRange = 30, -- studs from the owner a pet will pick a target
	PetInterval = 2, -- seconds between pet attacks

	-- Client sounds. These are sounds that ship with the Roblox client; swap any of them for an
	-- "rbxassetid://..." audio id you own or that Roblox has made public.
	SoundsEnabled = true,
	SoundIds = {
		Hit = "rbxasset://sounds/clickfast.wav",
		Break = "rbxasset://sounds/snap.mp3",
		Ping = "rbxasset://sounds/electronicpingshort.wav",
		LevelUp = "rbxasset://sounds/victory.wav",
		Click = "rbxasset://sounds/button.wav",
	},
}

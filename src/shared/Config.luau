--!strict
-- Tunable game settings shared by server and client.
return {
	ArenaSize = 120, -- studs, square arena centred on the origin
	MaxCoins = 40,
	SpawnInterval = 0.5, -- seconds between coin spawns while below MaxCoins
	CoinValue = 1,
	GoldenCoinChance = 0.1,
	GoldenCoinValue = 5,
	CoinLifetime = 30, -- seconds before an uncollected coin despawns
}

--!nonstrict
-- Shared numbers for the dark-wood maze. The server builds the place from
-- these values; nothing here depends on Roblox services, so tests can read it.
local MazeConfig = {}

-- Corridor grid. A cell is 12 studs wide: 10 studs of walking room and a
-- 2 stud wall skin on each side.
MazeConfig.CellSize = 12
MazeConfig.WallThickness = 2
MazeConfig.WallHeight = 10.5
MazeConfig.GridWidth = 25
MazeConfig.GridDepth = 25

-- The maze floor sits 13.5 studs above the safe room floor, so the staircase
-- climbs one storey.
MazeConfig.MazeFloorY = 13.5

-- Chair rail height: the wainscot field runs from the baseboard up to here.
MazeConfig.PanelHeight = 4.4

MazeConfig.SafeRoomWidth = 44
MazeConfig.SafeRoomDepth = 44

-- Generation.
MazeConfig.BraidChance = 0.3
MazeConfig.RoomCount = 6
MazeConfig.RoomMinSize = 2
MazeConfig.RoomMaxSize = 3
MazeConfig.FoyerWidth = 3
MazeConfig.FoyerDepth = 2

-- Staircase rises 13.5 studs in 15 steps of 0.9 studs.
MazeConfig.StairSteps = 15
MazeConfig.StairRise = 0.9
MazeConfig.StairDepth = 1.0
MazeConfig.StairWidth = 8

-- Lights.
MazeConfig.SconceChance = 0.13
MazeConfig.MaxSconces = 60
MazeConfig.SconceSpacing = 24
MazeConfig.SconceHeight = 6.4

MazeConfig.Assets = {
	Chandelier = "Chandelier",
	WallCandle = "WallCandle",
}

-- Set this to an image id that the game's owner uploaded and every wall picks up
-- real grain, no other change needed. A Creator Store decal id will not work: the
-- image behind a decal belongs to its author and other games cannot reference it.
MazeConfig.WoodTexture = nil
MazeConfig.WoodStudsPerTile = 8

-- Until then the wood is material, colour and geometry.
-- Brown, not orange. Saturated wood reads as a toy game; real mahogany is a
-- desaturated dark brown that only picks up warmth where the light hits it.
MazeConfig.Palette = {
	Wood = Color3.fromRGB(54, 36, 27),
	WoodField = Color3.fromRGB(39, 26, 20),
	WoodTrim = Color3.fromRGB(20, 14, 11),
	Wall = Color3.fromRGB(28, 24, 21),
	Ceiling = Color3.fromRGB(27, 21, 18),
	Floor = Color3.fromRGB(45, 31, 23),
	Candle = Color3.fromRGB(148, 132, 112),
	CandleLight = Color3.fromRGB(255, 198, 152),
}

return MazeConfig

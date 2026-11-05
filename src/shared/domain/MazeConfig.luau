--!nonstrict
-- Shared numbers for the dark-wood maze. The server builds the place from
-- these values; nothing here depends on Roblox services, so tests can read it.
local MazeConfig = {}

-- Corridor grid. A cell is 12 studs wide: 10 studs of walking room and a
-- 2 stud wall skin on each side.
MazeConfig.CellSize = 12
MazeConfig.WallThickness = 2
MazeConfig.WallHeight = 14
MazeConfig.GridWidth = 25
MazeConfig.GridDepth = 25

-- The maze floor sits 18 studs above the safe room floor, so the staircase
-- climbs one storey.
MazeConfig.MazeFloorY = 18

-- Vertical break in the wall: wood panel up to here, dark wall above.
MazeConfig.PanelHeight = 6

MazeConfig.SafeRoomWidth = 44
MazeConfig.SafeRoomDepth = 44

-- Generation.
MazeConfig.BraidChance = 0.3
MazeConfig.RoomCount = 6
MazeConfig.RoomMinSize = 2
MazeConfig.RoomMaxSize = 3
MazeConfig.FoyerWidth = 3
MazeConfig.FoyerDepth = 2

-- Staircase rises 18 studs in 20 steps of 0.9 studs.
MazeConfig.StairSteps = 20
MazeConfig.StairRise = 0.9
MazeConfig.StairDepth = 1.0
MazeConfig.StairWidth = 8

-- Lights.
MazeConfig.SconceChance = 0.13
MazeConfig.MaxSconces = 60
MazeConfig.SconceSpacing = 24
MazeConfig.SconceHeight = 9

MazeConfig.Assets = {
	Chandelier = "Chandelier",
	WallCandle = "WallCandle",
}

MazeConfig.WoodTexture = "rbxassetid://5332619725"

MazeConfig.Palette = {
	Wood = Color3.fromRGB(46, 26, 16),
	WoodTrim = Color3.fromRGB(60, 36, 22),
	Wall = Color3.fromRGB(42, 36, 32),
	Ceiling = Color3.fromRGB(30, 25, 22),
	Floor = Color3.fromRGB(38, 25, 18),
	Candle = Color3.fromRGB(148, 132, 112),
	CandleLight = Color3.fromRGB(255, 182, 108),
}

return MazeConfig

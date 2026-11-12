--!strict
-- Tunable settings shared by the server and the client.

local Config = {
	-- Map seed. Change it for a different map.
	Seed = 20261112,

	-- Build grid. One cell is one terrain voxel column, so CellSize must stay 4.
	CellSize = 4,
	MapCells = 256,

	-- Terrain is written in square chunks of this many cells per side.
	ChunkCells = 32,

	-- World heights in studs. All three must be multiples of 4.
	SeaLevel = 0,
	TerrainBottom = -32,
	TerrainTop = 64,

	-- Height difference to a neighbouring cell, in studs.
	Slope = {
		ModerateAbove = 1.0, -- costs more to build on
		SteepAbove = 2.5, -- needs leveling first
	},

	Lakes = {
		Count = 3,
		MinRadius = 7, -- cells
		MaxRadius = 14,
	},

	Camera = {
		MinZoom = 30,
		MaxZoom = 700,
		StartZoom = 260,
		MinPitchDeg = 40, -- zoomed in
		MaxPitchDeg = 72, -- zoomed out
		PanSpeed = 1.2, -- studs per second, per stud of zoom
		FastMultiplier = 2.5,
		RotateSpeed = 1.6, -- radians per second (Q/E)
		DragRotate = 0.006, -- radians per pixel (right-drag)
		ZoomStep = 0.85,
		FieldOfView = 50,
	},

	-- Camera focus updates sent to the server for streaming.
	Focus = {
		SendInterval = 0.25, -- seconds between client sends
		SendDistance = 16, -- studs moved before sending
		MinInterval = 0.1, -- server ignores updates faster than this
	},

	-- Cells shown on each side of the pointer when the grid is on.
	GridRadius = 6,
}

return table.freeze(Config)

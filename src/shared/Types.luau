--!strict
-- Shared types and the numeric codes stored in the map buffers.

local Types = {}

-- Everything known about the land, one entry per cell, indexed by Grid.index.
export type MapData = {
	seed: number,
	size: number, -- cells per side
	height: buffer, -- f32: ground height in studs (world Y)
	water: buffer, -- u8: 1 if the cell is under water
	slope: buffer, -- u8: a Types.Slope code
	resource: buffer, -- u8: a Types.Resource code
}

export type MapStats = {
	cells: number,
	water: number,
	moderate: number,
	steep: number,
	fertile: number,
	ore: number,
	forest: number,
	minHeight: number,
	maxHeight: number,
}

Types.Slope = table.freeze({
	Flat = 0,
	Moderate = 1,
	Steep = 2,
})

Types.Resource = table.freeze({
	None = 0,
	Fertile = 1,
	Ore = 2,
	Forest = 3,
})

Types.SlopeNames = table.freeze({ [0] = "Flat", [1] = "Moderate", [2] = "Steep" })
Types.ResourceNames = table.freeze({ [0] = "None", [1] = "Fertile soil", [2] = "Ore", [3] = "Forest" })

return Types

--!strict
-- Grid maths. Cells are numbered from 0 to MapCells - 1 on each axis, and the
-- map is centred on the world origin. Functions return plain numbers so that
-- callers in hot loops create no garbage.

local Config = require(script.Parent.Config)

local CELL = Config.CellSize
local SIZE = Config.MapCells
local HALF = SIZE * CELL / 2

local Grid = {}

Grid.CellSize = CELL
Grid.Size = SIZE
-- World X and Z of the map's lowest corner.
Grid.OriginX = -HALF
Grid.OriginZ = -HALF
-- World distance from the centre to each edge.
Grid.HalfExtent = HALF

function Grid.inBounds(x: number, z: number): boolean
	return x >= 0 and z >= 0 and x < SIZE and z < SIZE
end

-- Position of a cell in the map buffers (0-based).
function Grid.index(x: number, z: number): number
	return z * SIZE + x
end

function Grid.fromIndex(index: number): (number, number)
	return index % SIZE, index // SIZE
end

-- World X and Z of the centre of a cell.
function Grid.cellToWorld(x: number, z: number): (number, number)
	return -HALF + (x + 0.5) * CELL, -HALF + (z + 0.5) * CELL
end

-- The cell containing a world position. May be out of bounds; check with inBounds.
function Grid.worldToCell(worldX: number, worldZ: number): (number, number)
	return math.floor((worldX + HALF) / CELL), math.floor((worldZ + HALF) / CELL)
end

-- Keeps a world coordinate inside the map.
function Grid.clampWorld(value: number): number
	return math.clamp(value, -HALF, HALF)
end

return Grid

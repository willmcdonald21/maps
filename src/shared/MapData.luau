--!strict
-- Read access to a Types.MapData. The grid state lives in these buffers and is
-- never read back from parts or terrain.

local Config = require(script.Parent.Config)
local Grid = require(script.Parent.Grid)
local Types = require(script.Parent.Types)

type MapData = Types.MapData

local MapData = {}

function MapData.height(data: MapData, x: number, z: number): number
	return buffer.readf32(data.height, Grid.index(x, z) * 4)
end

function MapData.isWater(data: MapData, x: number, z: number): boolean
	return buffer.readu8(data.water, Grid.index(x, z)) == 1
end

function MapData.slope(data: MapData, x: number, z: number): number
	return buffer.readu8(data.slope, Grid.index(x, z))
end

function MapData.resource(data: MapData, x: number, z: number): number
	return buffer.readu8(data.resource, Grid.index(x, z))
end

-- Height of whatever is on top at this cell: the ground, or the water surface.
function MapData.surface(data: MapData, x: number, z: number): number
	return math.max(MapData.height(data, x, z), Config.SeaLevel)
end

-- Whether the land itself allows building here. Later phases add checks for
-- roads, buildings and cost on top of this.
function MapData.isBuildable(data: MapData, x: number, z: number): boolean
	if not Grid.inBounds(x, z) then
		return false
	end
	local index = Grid.index(x, z)
	return buffer.readu8(data.water, index) == 0 and buffer.readu8(data.slope, index) ~= Types.Slope.Steep
end

function MapData.stats(data: MapData): Types.MapStats
	local stats: Types.MapStats = {
		cells = data.size * data.size,
		water = 0,
		moderate = 0,
		steep = 0,
		fertile = 0,
		ore = 0,
		forest = 0,
		minHeight = math.huge,
		maxHeight = -math.huge,
	}
	for index = 0, stats.cells - 1 do
		local height = buffer.readf32(data.height, index * 4)
		stats.minHeight = math.min(stats.minHeight, height)
		stats.maxHeight = math.max(stats.maxHeight, height)
		stats.water += buffer.readu8(data.water, index)
		local slope = buffer.readu8(data.slope, index)
		if slope == Types.Slope.Moderate then
			stats.moderate += 1
		elseif slope == Types.Slope.Steep then
			stats.steep += 1
		end
		local resource = buffer.readu8(data.resource, index)
		if resource == Types.Resource.Fertile then
			stats.fertile += 1
		elseif resource == Types.Resource.Ore then
			stats.ore += 1
		elseif resource == Types.Resource.Forest then
			stats.forest += 1
		end
	end
	return stats
end

return MapData

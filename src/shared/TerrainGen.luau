--!strict
-- Builds the map from a seed. Pure and deterministic: the same seed always
-- gives the same map, so the client can rebuild the server's map from the seed.
--
-- All water sits at Config.SeaLevel. Rivers and lakes are carved down below it.

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

type MapData = Types.MapData

local TerrainGen = {}

local LOWLAND_HEIGHT = 5
local LOWLAND_ROLL = 5
local HILL_HEIGHT = 40
local HILL_ROLL = 25
local RIVER_BED = -6
local RIVER_BANK = 10 -- cells from the water's edge to untouched land
local LAKE_BED = -5
local SEA_BED = -12
local BEACH_HEIGHT = 1.5

local function smoothstep(low: number, high: number, value: number): number
	local t = math.clamp((value - low) / (high - low), 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Three layers of noise, roughly -1 to 1.
local function layered(x: number, z: number): number
	return math.noise(x, z, 0.5) * 0.57 + math.noise(x * 2, z * 2, 1.5) * 0.29 + math.noise(x * 4, z * 4, 2.5) * 0.14
end

type Lake = { x: number, z: number, radius: number }

function TerrainGen.generate(seed: number): MapData
	local size = Config.MapCells
	local count = size * size
	local rng = Random.new(seed)

	local function offset(): number
		return rng:NextNumber(-4096, 4096)
	end

	local hillX, hillZ = offset(), offset()
	local detailX, detailZ = offset(), offset()
	local riverA, riverB = offset(), offset()
	local coastA = offset()
	local lakeX, lakeZ = offset(), offset()
	local oreX, oreZ = offset(), offset()
	local forestX, forestZ = offset(), offset()
	local fertileX, fertileZ = offset(), offset()
	local riverBase = rng:NextNumber(0.3, 0.7) * size

	-- 0 on the plains, 1 in the middle of hill country.
	local function hills(x: number, z: number): number
		return smoothstep(0.05, 0.5, math.noise(x / 110 + hillX, z / 110 + hillZ, 0.5))
	end

	-- Column the river runs down at a given row.
	local function riverCentre(z: number): number
		return riverBase
			+ math.noise(z / 45 + riverA, riverB, 0.5) * size * 0.10
			+ math.noise(z / 15 + riverA, riverB, 3.5) * size * 0.02
	end

	-- Row where the sea starts at a given column.
	local function coastRow(x: number): number
		return size * 0.84 + math.noise(x / 50 + coastA, 0.5, 0.5) * size * 0.04
	end

	-- Pick lakes on the plains, clear of the river, the coast and each other.
	local lakes: { Lake } = {}
	for _ = 1, 60 do
		if #lakes >= Config.Lakes.Count then
			break
		end
		local x = rng:NextInteger(24, size - 24)
		local z = rng:NextInteger(24, math.floor(size * 0.68))
		local radius = rng:NextNumber(Config.Lakes.MinRadius, Config.Lakes.MaxRadius)
		local ok = hills(x, z) < 0.25 and math.abs(x - riverCentre(z)) > radius + 24
		if ok then
			for _, other in lakes do
				local dx, dz = x - other.x, z - other.z
				if math.sqrt(dx * dx + dz * dz) < radius + other.radius + 20 then
					ok = false
					break
				end
			end
		end
		if ok then
			table.insert(lakes, { x = x, z = z, radius = radius })
		end
	end

	local height = buffer.create(count * 4)
	local water = buffer.create(count)
	local slope = buffer.create(count)
	local resource = buffer.create(count)

	-- Pass 1: heights and water.
	for z = 0, size - 1 do
		local centre = riverCentre(z)
		local riverHalfWidth = 2.5 + 2.5 * smoothstep(0.5, 0.9, z / size)
		for x = 0, size - 1 do
			local detail = layered(x / 40 + detailX, z / 40 + detailZ)
			local h = LOWLAND_HEIGHT + detail * LOWLAND_ROLL + hills(x, z) * (HILL_HEIGHT + detail * HILL_ROLL)

			-- River valley.
			local fromRiver = math.abs(x - centre)
			if fromRiver < riverHalfWidth + RIVER_BANK then
				h = lerp(h, RIVER_BED, 1 - smoothstep(riverHalfWidth, riverHalfWidth + RIVER_BANK, fromRiver))
			end

			-- Lakes, with wobbly edges.
			for _, lake in lakes do
				local dx, dz = x - lake.x, z - lake.z
				local reach = lake.radius * 1.6
				if math.abs(dx) < reach and math.abs(dz) < reach then
					local wobble = 1 + 0.3 * math.noise(x / 9 + lakeX, z / 9 + lakeZ, 0.5)
					local distance = math.sqrt(dx * dx + dz * dz) / (lake.radius * wobble)
					h = lerp(h, LAKE_BED, 1 - smoothstep(0.7, 1.3, distance))
				end
			end

			-- Coastline along the high-z edge.
			local pastCoast = z - coastRow(x)
			if pastCoast > -14 then
				h = lerp(h, SEA_BED, smoothstep(-14, 6, pastCoast))
			end

			local index = z * size + x
			buffer.writef32(height, index * 4, h)
			buffer.writeu8(water, index, if h < Config.SeaLevel then 1 else 0)
		end
	end

	-- Pass 2: slope, from the biggest height step to a neighbour.
	for z = 0, size - 1 do
		for x = 0, size - 1 do
			local index = z * size + x
			local h = buffer.readf32(height, index * 4)
			local step = 0
			if x > 0 then
				step = math.max(step, math.abs(h - buffer.readf32(height, (index - 1) * 4)))
			end
			if x < size - 1 then
				step = math.max(step, math.abs(h - buffer.readf32(height, (index + 1) * 4)))
			end
			if z > 0 then
				step = math.max(step, math.abs(h - buffer.readf32(height, (index - size) * 4)))
			end
			if z < size - 1 then
				step = math.max(step, math.abs(h - buffer.readf32(height, (index + size) * 4)))
			end
			local code = Types.Slope.Flat
			if step > Config.Slope.SteepAbove then
				code = Types.Slope.Steep
			elseif step > Config.Slope.ModerateAbove then
				code = Types.Slope.Moderate
			end
			buffer.writeu8(slope, index, code)
		end
	end

	-- Pass 3: natural resources, on dry land only.
	for z = 0, size - 1 do
		for x = 0, size - 1 do
			local index = z * size + x
			local code = Types.Resource.None
			if buffer.readu8(water, index) == 0 then
				local h = buffer.readf32(height, index * 4)
				local cellSlope = buffer.readu8(slope, index)
				if hills(x, z) > 0.3 and math.noise(x / 18 + oreX, z / 18 + oreZ, 0.5) > 0.35 then
					code = Types.Resource.Ore
				elseif
					h > BEACH_HEIGHT
					and h < 10
					and cellSlope == Types.Slope.Flat
					and math.noise(x / 35 + fertileX, z / 35 + fertileZ, 0.5) > 0.15
				then
					code = Types.Resource.Fertile
				elseif
					h > BEACH_HEIGHT
					and cellSlope ~= Types.Slope.Steep
					and layered(x / 60 + forestX, z / 60 + forestZ) > 0.12
				then
					code = Types.Resource.Forest
				end
			end
			buffer.writeu8(resource, index, code)
		end
	end

	return {
		seed = seed,
		size = size,
		height = height,
		water = water,
		slope = slope,
		resource = resource,
	}
end

TerrainGen.BeachHeight = BEACH_HEIGHT

return TerrainGen

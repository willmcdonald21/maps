--!strict
-- Owns the authoritative map. Everything that needs to know about the land on
-- the server asks here.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))
local MapData = require(Shared:WaitForChild("MapData"))
local TerrainGen = require(Shared:WaitForChild("TerrainGen"))
local Types = require(Shared:WaitForChild("Types"))

local TerrainWriter = require(script.Parent:WaitForChild("TerrainWriter"))

local MapService = {}

local data: Types.MapData? = nil

local function current(): Types.MapData
	assert(data, "MapService has not started")
	return data
end

-- Generates the map and writes the terrain. Yields until the terrain is done.
function MapService.start()
	local seed = Config.Seed
	local generateStart = os.clock()
	local map = TerrainGen.generate(seed)
	data = map
	local generateTime = os.clock() - generateStart

	-- Clients rebuild the same map from the seed.
	Workspace:SetAttribute("MapSeed", seed)

	local writeStart = os.clock()
	TerrainWriter.write(map)
	local writeTime = os.clock() - writeStart
	Workspace:SetAttribute("MapReady", true)

	local stats = MapData.stats(map)
	print(
		string.format(
			"[MapService] seed %d: generated in %.2fs, terrain written in %.2fs. "
				.. "Water %.1f%%, moderate slope %.1f%%, steep %.1f%%, fertile %d, ore %d, forest %d, height %.1f to %.1f",
			seed,
			generateTime,
			writeTime,
			stats.water / stats.cells * 100,
			stats.moderate / stats.cells * 100,
			stats.steep / stats.cells * 100,
			stats.fertile,
			stats.ore,
			stats.forest,
			stats.minHeight,
			stats.maxHeight
		)
	)
end

function MapService.getSeed(): number
	return current().seed
end

function MapService.getData(): Types.MapData
	return current()
end

function MapService.heightAt(x: number, z: number): number?
	if not Grid.inBounds(x, z) then
		return nil
	end
	return MapData.height(current(), x, z)
end

function MapService.isWater(x: number, z: number): boolean
	return Grid.inBounds(x, z) and MapData.isWater(current(), x, z)
end

function MapService.isBuildable(x: number, z: number): boolean
	return MapData.isBuildable(current(), x, z)
end

return MapService

--!strict
-- Turns map data into Roblox terrain. One cell is one voxel column. The work is
-- done a chunk at a time, yielding between chunks so the server never stalls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))
local TerrainGen = require(Shared:WaitForChild("TerrainGen"))
local Types = require(Shared:WaitForChild("Types"))

local VOXEL = 4
local CHUNK = Config.ChunkCells
local BOTTOM = Config.TerrainBottom
local TOP = Config.TerrainTop
local SEA = Config.SeaLevel
local LAYERS = (TOP - BOTTOM) // VOXEL

local AIR = Enum.Material.Air

local TerrainWriter = {}

local function groundMaterial(data: Types.MapData, index: number): Enum.Material
	local height = buffer.readf32(data.height, index * 4)
	if height < TerrainGen.BeachHeight then
		return Enum.Material.Sand
	end
	if buffer.readu8(data.slope, index) == Types.Slope.Steep then
		return Enum.Material.Rock
	end
	local resource = buffer.readu8(data.resource, index)
	if resource == Types.Resource.Ore then
		return Enum.Material.Basalt
	elseif resource == Types.Resource.Forest then
		return Enum.Material.LeafyGrass
	elseif resource == Types.Resource.Fertile then
		return Enum.Material.Ground
	end
	return Enum.Material.Grass
end

local function grid3<T>(sizeX: number, sizeY: number, sizeZ: number, value: T): { { { T } } }
	local grid = table.create(sizeX)
	for x = 1, sizeX do
		local plane = table.create(sizeY)
		for y = 1, sizeY do
			plane[y] = table.create(sizeZ, value)
		end
		grid[x] = plane
	end
	return grid
end

function TerrainWriter.write(data: Types.MapData)
	assert(Config.CellSize == VOXEL, "CellSize must match the terrain voxel size (4)")
	assert(data.size % CHUNK == 0, "MapCells must be a multiple of ChunkCells")

	local terrain = Workspace.Terrain
	local size = data.size

	-- Reused for every chunk; every entry is overwritten each time.
	local materials = grid3(CHUNK, LAYERS, CHUNK, AIR)
	local solid = grid3(CHUNK, LAYERS, CHUNK, 0)
	local liquid = grid3(CHUNK, LAYERS, CHUNK, 0)
	local channels = {
		SolidMaterial = materials,
		SolidOccupancy = solid,
		LiquidOccupancy = liquid,
	}

	for chunkZ = 0, size - 1, CHUNK do
		for chunkX = 0, size - 1, CHUNK do
			for localX = 1, CHUNK do
				local materialPlane = materials[localX]
				local solidPlane = solid[localX]
				local liquidPlane = liquid[localX]
				for localZ = 1, CHUNK do
					local index = Grid.index(chunkX + localX - 1, chunkZ + localZ - 1)
					local height = buffer.readf32(data.height, index * 4)
					local material = groundMaterial(data, index)
					for layer = 1, LAYERS do
						local voxelBottom = BOTTOM + (layer - 1) * VOXEL
						local fill = math.clamp((height - voxelBottom) / VOXEL, 0, 1)
						local waterFill = 0
						if fill < 1 and voxelBottom < SEA then
							waterFill = math.clamp((SEA - voxelBottom) / VOXEL, 0, 1)
						end
						materialPlane[layer][localZ] = if fill > 0 then material else AIR
						solidPlane[layer][localZ] = fill
						liquidPlane[layer][localZ] = waterFill
					end
				end
			end

			local minX = Grid.OriginX + chunkX * VOXEL
			local minZ = Grid.OriginZ + chunkZ * VOXEL
			local region = Region3.new(
				Vector3.new(minX, BOTTOM, minZ),
				Vector3.new(minX + CHUNK * VOXEL, TOP, minZ + CHUNK * VOXEL)
			)
			terrain:WriteVoxelChannels(region, VOXEL, channels)
			task.wait()
		end
	end
end

return TerrainWriter

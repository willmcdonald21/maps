--!strict
-- Finds the grid cell under the pointer, highlights it, and (with G) shows the
-- build grid around it coloured by how buildable the land is. Parts are made
-- once and moved, never created per frame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))
local MapData = require(Shared:WaitForChild("MapData"))
local Types = require(Shared:WaitForChild("Types"))

local DebugHud = require(script.Parent:WaitForChild("DebugHud"))

local CELL = Config.CellSize
local RADIUS = Config.GridRadius
local SIDE = RADIUS * 2 + 1
local RAY_LENGTH = 5000
local HIDDEN = CFrame.new(0, -5000, 0)

local COLOR_GOOD = Color3.fromRGB(120, 230, 140)
local COLOR_COSTLY = Color3.fromRGB(245, 205, 90)
local COLOR_BLOCKED = Color3.fromRGB(235, 90, 90)

local GridCursor = {}

local map: Types.MapData
local folder: Folder
local cursor: Part
local rayParams: RaycastParams

local hoverX: number? = nil
local hoverZ: number? = nil

local gridOn = false
local tiles: { BasePart } = {}
local tileCFrames: { CFrame } = {}
local tileStates: { number } = {} -- 0 hidden, 1 good, 2 costly, 3 blocked

local function makePart(name: string, size: Vector3, transparency: number): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.Size = size
	part.Transparency = transparency
	part.CFrame = HIDDEN
	part.Parent = folder
	return part
end

-- 1 good, 2 costly, 3 blocked.
local function cellState(x: number, z: number): number
	if not MapData.isBuildable(map, x, z) then
		return 3
	end
	return if MapData.slope(map, x, z) == Types.Slope.Moderate then 2 else 1
end

local function stateColor(state: number): Color3
	if state == 1 then
		return COLOR_GOOD
	elseif state == 2 then
		return COLOR_COSTLY
	end
	return COLOR_BLOCKED
end

local function cellCFrame(x: number, z: number, lift: number): CFrame
	local worldX, worldZ = Grid.cellToWorld(x, z)
	return CFrame.new(worldX, MapData.surface(map, x, z) + lift, worldZ)
end

local function ensureTiles()
	if #tiles > 0 then
		return
	end
	local size = Vector3.new(CELL - 0.3, 0.1, CELL - 0.3)
	for i = 1, SIDE * SIDE do
		tiles[i] = makePart("GridTile", size, 0.55)
		tileCFrames[i] = HIDDEN
		tileStates[i] = 0
	end
end

local function hideTiles()
	if #tiles == 0 then
		return
	end
	for i = 1, #tiles do
		tileCFrames[i] = HIDDEN
		tileStates[i] = 0
	end
	Workspace:BulkMoveTo(tiles, tileCFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

local function layoutTiles(centreX: number, centreZ: number)
	ensureTiles()
	local i = 0
	for dz = -RADIUS, RADIUS do
		for dx = -RADIUS, RADIUS do
			i += 1
			local x, z = centreX + dx, centreZ + dz
			if Grid.inBounds(x, z) then
				local state = cellState(x, z)
				if tileStates[i] ~= state then
					tileStates[i] = state
					tiles[i].Color = stateColor(state)
				end
				tileCFrames[i] = cellCFrame(x, z, 0.35)
			else
				tileStates[i] = 0
				tileCFrames[i] = HIDDEN
			end
		end
	end
	Workspace:BulkMoveTo(tiles, tileCFrames, Enum.BulkMoveMode.FireCFrameChanged)
end

local function setHover(x: number?, z: number?)
	if x == hoverX and z == hoverZ then
		return
	end
	hoverX, hoverZ = x, z
	if x and z then
		cursor.CFrame = cellCFrame(x, z, 0.5)
		cursor.Color = stateColor(cellState(x, z))
		DebugHud.showCell(
			x,
			z,
			MapData.height(map, x, z),
			MapData.isWater(map, x, z),
			MapData.slope(map, x, z),
			MapData.resource(map, x, z),
			MapData.isBuildable(map, x, z)
		)
		if gridOn then
			layoutTiles(x, z)
		end
	else
		cursor.CFrame = HIDDEN
		DebugHud.clearCell()
		hideTiles()
	end
end

local function step()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local origin, direction = ray.Origin, ray.Direction

	local hitX: number? = nil
	local hitZ: number? = nil
	local result = Workspace:Raycast(origin, direction * RAY_LENGTH, rayParams)
	if result then
		-- Nudge along the ray so a hit on a cell's edge lands inside that cell.
		hitX = result.Position.X + direction.X * 0.05
		hitZ = result.Position.Z + direction.Z * 0.05
	elseif direction.Y < -0.001 then
		-- Terrain not loaded here yet: fall back to the sea-level plane.
		local distance = (Config.SeaLevel - origin.Y) / direction.Y
		hitX = origin.X + direction.X * distance
		hitZ = origin.Z + direction.Z * distance
	end

	if hitX and hitZ then
		local x, z = Grid.worldToCell(hitX, hitZ)
		if Grid.inBounds(x, z) then
			setHover(x, z)
			return
		end
	end
	setHover(nil, nil)
end

local function onInputBegan(input: InputObject, processed: boolean)
	if processed or input.KeyCode ~= Enum.KeyCode.G then
		return
	end
	gridOn = not gridOn
	if gridOn and hoverX and hoverZ then
		layoutTiles(hoverX, hoverZ)
	else
		hideTiles()
	end
end

function GridCursor.start(mapData: Types.MapData)
	map = mapData

	folder = Instance.new("Folder")
	folder.Name = "GridCursor"
	folder.Parent = Workspace

	cursor = makePart("Cursor", Vector3.new(CELL, 0.2, CELL), 0.2)
	cursor.Material = Enum.Material.Neon

	rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Include
	rayParams.FilterDescendantsInstances = { Workspace.Terrain }
	rayParams.IgnoreWater = false

	UserInputService.InputBegan:Connect(onInputBegan)
	RunService:BindToRenderStep("GridCursor", Enum.RenderPriority.Camera.Value + 1, step)
end

-- The cell under the pointer, or nil when it is off the map.
function GridCursor.getHoveredCell(): (number?, number?)
	return hoverX, hoverZ
end

return GridCursor

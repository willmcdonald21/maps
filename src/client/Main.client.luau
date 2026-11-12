--!strict
-- Client entry point. Rebuilds the map from the server's seed, then starts the
-- camera, the grid cursor and the debug panel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TerrainGen = require(Shared:WaitForChild("TerrainGen"))

local Controllers = script.Parent:WaitForChild("Controllers")
local CameraController = require(Controllers:WaitForChild("CameraController"))
local DebugHud = require(Controllers:WaitForChild("DebugHud"))
local GridCursor = require(Controllers:WaitForChild("GridCursor"))

local seed = Workspace:GetAttribute("MapSeed")
while typeof(seed) ~= "number" do
	Workspace:GetAttributeChangedSignal("MapSeed"):Wait()
	seed = Workspace:GetAttribute("MapSeed")
end

local map = TerrainGen.generate(seed)

DebugHud.start(map)
CameraController.start(map)
GridCursor.start(map)

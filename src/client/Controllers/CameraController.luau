--!strict
-- Free city-builder camera: it orbits a focus point on the ground.
--   W A S D / arrows  move (Shift = faster)
--   Q / E, right-drag rotate
--   scroll            zoom (tilts flatter as it zooms in)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))
local MapData = require(Shared:WaitForChild("MapData"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Types = require(Shared:WaitForChild("Types"))

local SETTINGS = Config.Camera
local MIN_PITCH = math.rad(SETTINGS.MinPitchDeg)
local MAX_PITCH = math.rad(SETTINGS.MaxPitchDeg)
local CAMERA_CLEARANCE = 6 -- studs kept between the camera and the ground under it

local CameraController = {}

local map: Types.MapData
local camera: Camera

local focusX, focusZ = 0, 0
local groundY = 0
local yaw = 0
local zoom = SETTINGS.StartZoom
local targetZoom = SETTINGS.StartZoom
local rotating = false

local focusEvent: RemoteEvent
local sentX, sentZ = 0, 0
local sinceSend = 0

local function key(code: Enum.KeyCode): number
	return if UserInputService:IsKeyDown(code) then 1 else 0
end

local function surfaceAt(worldX: number, worldZ: number): number
	local x, z = Grid.worldToCell(worldX, worldZ)
	x = math.clamp(x, 0, Grid.Size - 1)
	z = math.clamp(z, 0, Grid.Size - 1)
	return MapData.surface(map, x, z)
end

local function step(dt: number)
	dt = math.min(dt, 0.1)

	if UserInputService:GetFocusedTextBox() == nil then
		local forward = math.max(key(Enum.KeyCode.W), key(Enum.KeyCode.Up))
			- math.max(key(Enum.KeyCode.S), key(Enum.KeyCode.Down))
		local right = math.max(key(Enum.KeyCode.D), key(Enum.KeyCode.Right))
			- math.max(key(Enum.KeyCode.A), key(Enum.KeyCode.Left))
		local turn = key(Enum.KeyCode.E) - key(Enum.KeyCode.Q)

		yaw += turn * SETTINGS.RotateSpeed * dt

		if forward ~= 0 or right ~= 0 then
			local speed = zoom * SETTINGS.PanSpeed * dt
			if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
				speed *= SETTINGS.FastMultiplier
			end
			if forward ~= 0 and right ~= 0 then
				speed *= 0.7071
			end
			local sin, cos = math.sin(yaw), math.cos(yaw)
			focusX = Grid.clampWorld(focusX + (-sin * forward + cos * right) * speed)
			focusZ = Grid.clampWorld(focusZ + (-cos * forward - sin * right) * speed)
		end
	end

	local blend = math.min(1, dt * 10)
	zoom += (targetZoom - zoom) * blend
	groundY += (surfaceAt(focusX, focusZ) - groundY) * blend

	local zoomAlpha = (zoom - SETTINGS.MinZoom) / (SETTINGS.MaxZoom - SETTINGS.MinZoom)
	local pitch = MIN_PITCH + (MAX_PITCH - MIN_PITCH) * zoomAlpha
	local flat = math.cos(pitch) * zoom
	local cameraX = focusX + math.sin(yaw) * flat
	local cameraZ = focusZ + math.cos(yaw) * flat
	local cameraY = math.max(groundY + math.sin(pitch) * zoom, surfaceAt(cameraX, cameraZ) + CAMERA_CLEARANCE)

	local focus = Vector3.new(focusX, groundY, focusZ)
	camera.CFrame = CFrame.lookAt(Vector3.new(cameraX, cameraY, cameraZ), focus)
	camera.Focus = CFrame.new(focus)

	-- Tell the server where we are looking, so it streams the right area.
	sinceSend += dt
	if sinceSend >= Config.Focus.SendInterval then
		local dx, dz = focusX - sentX, focusZ - sentZ
		if dx * dx + dz * dz >= Config.Focus.SendDistance * Config.Focus.SendDistance then
			sinceSend = 0
			sentX, sentZ = focusX, focusZ
			focusEvent:FireServer(focusX, focusZ)
		end
	end
end

local function onInputChanged(input: InputObject, processed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if not processed then
			targetZoom =
				math.clamp(targetZoom * SETTINGS.ZoomStep ^ input.Position.Z, SETTINGS.MinZoom, SETTINGS.MaxZoom)
		end
	elseif input.UserInputType == Enum.UserInputType.MouseMovement and rotating then
		yaw -= input.Delta.X * SETTINGS.DragRotate
	end
end

local function onInputBegan(input: InputObject, processed: boolean)
	if input.UserInputType == Enum.UserInputType.MouseButton2 and not processed then
		rotating = true
		UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
	end
end

local function onInputEnded(input: InputObject)
	if input.UserInputType == Enum.UserInputType.MouseButton2 and rotating then
		rotating = false
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end
end

function CameraController.start(mapData: Types.MapData)
	map = mapData
	focusEvent = Remotes.event("CameraFocus")

	local current = Workspace.CurrentCamera
	assert(current, "No camera")
	camera = current
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = SETTINGS.FieldOfView
	groundY = surfaceAt(focusX, focusZ)

	-- The default scripts may try to take the camera back; keep it ours.
	camera:GetPropertyChangedSignal("CameraType"):Connect(function()
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
	end)

	UserInputService.InputChanged:Connect(onInputChanged)
	UserInputService.InputBegan:Connect(onInputBegan)
	UserInputService.InputEnded:Connect(onInputEnded)
	RunService:BindToRenderStep("CityCamera", Enum.RenderPriority.Camera.Value, step)
end

-- World X and Z the camera is looking at.
function CameraController.getFocus(): (number, number)
	return focusX, focusZ
end

return CameraController

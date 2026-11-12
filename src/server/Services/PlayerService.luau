--!strict
-- Players have no avatar; they are a camera. With StreamingEnabled the server
-- needs to know where each camera is looking, so each player gets an invisible
-- focus part that follows their camera.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Grid = require(Shared:WaitForChild("Grid"))
local Remotes = require(Shared:WaitForChild("Remotes"))

local PlayerService = {}

local focusFolder: Folder
local focusParts: { [Player]: Part } = {}
local lastUpdate: { [Player]: number } = {}

local function addPlayer(player: Player)
	if focusParts[player] then
		return
	end
	local part = Instance.new("Part")
	part.Name = tostring(player.UserId)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	part.Position = Vector3.new(0, Config.SeaLevel, 0)
	part.Parent = focusFolder
	focusParts[player] = part
	lastUpdate[player] = 0
	player.ReplicationFocus = part
end

local function removePlayer(player: Player)
	local part = focusParts[player]
	if part then
		part:Destroy()
	end
	focusParts[player] = nil
	lastUpdate[player] = nil
end

-- Never trust the client: check types, reject NaN, clamp to the map, and limit
-- how often a player can move their focus.
local function onCameraFocus(player: Player, x: unknown, z: unknown)
	local part = focusParts[player]
	if not part then
		return
	end
	if typeof(x) ~= "number" or typeof(z) ~= "number" then
		return
	end
	if x ~= x or z ~= z then
		return
	end
	local now = os.clock()
	if now - (lastUpdate[player] or 0) < Config.Focus.MinInterval then
		return
	end
	lastUpdate[player] = now
	part.Position = Vector3.new(Grid.clampWorld(x), Config.SeaLevel, Grid.clampWorld(z))
end

function PlayerService.start()
	focusFolder = Instance.new("Folder")
	focusFolder.Name = "PlayerFocus"
	focusFolder.Parent = Workspace

	Remotes.event("CameraFocus").OnServerEvent:Connect(onCameraFocus)
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
end

-- Where a player's camera is looking, for later phases (and tests).
function PlayerService.getFocus(player: Player): Vector3?
	local part = focusParts[player]
	return if part then part.Position else nil
end

return PlayerService

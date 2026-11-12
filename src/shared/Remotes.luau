--!strict
-- One place that names every remote. The server creates them; the client waits
-- for them.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER_NAME = "Remotes"

local EVENTS = {
	-- client -> server: (x: number, z: number) world position the camera looks at
	"CameraFocus",
}

local Remotes = {}

-- Server only. Creates every remote. Safe to call more than once.
function Remotes.init()
	assert(RunService:IsServer(), "Remotes.init is server only")
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local event = Instance.new("RemoteEvent")
			event.Name = name
			event.Parent = folder
		end
	end
end

function Remotes.event(name: string): RemoteEvent
	local folder = ReplicatedStorage:WaitForChild(FOLDER_NAME)
	local event = folder:WaitForChild(name)
	assert(event:IsA("RemoteEvent"), name .. " is not a RemoteEvent")
	return event
end

return Remotes

--!strict
-- Server entry point. Starts each service in order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared:WaitForChild("Remotes"))

local Services = script.Parent:WaitForChild("Services")
local MapService = require(Services:WaitForChild("MapService"))
local PlayerService = require(Services:WaitForChild("PlayerService"))

Remotes.init()
PlayerService.start()
MapService.start()

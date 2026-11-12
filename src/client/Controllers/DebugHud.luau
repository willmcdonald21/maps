--!strict
-- Small text panel showing what the pointer is over. Temporary: the real HUD
-- arrives in a later phase.

local Players = game:GetService("Players")

local Types = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Types"))

local DebugHud = {}

local infoLabel: TextLabel
local seed = 0

local function makeLabel(parent: Instance, text: string): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(20, 24, 30)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.TextColor3 = Color3.fromRGB(240, 240, 240)
	label.Font = Enum.Font.RobotoMono
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextYAlignment = Enum.TextYAlignment.Top
	label.Text = text
	label.AutomaticSize = Enum.AutomaticSize.XY
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 8)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = label
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = label
	label.Parent = parent
	return label
end

function DebugHud.start(map: Types.MapData)
	seed = map.seed

	local gui = Instance.new("ScreenGui")
	gui.Name = "DebugHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false

	infoLabel = makeLabel(gui, "")
	infoLabel.Position = UDim2.fromOffset(12, 12)

	local help = makeLabel(gui, "WASD / arrows: move   Shift: faster   Q / E or right-drag: rotate   Scroll: zoom   G: grid")
	help.AnchorPoint = Vector2.new(0.5, 1)
	help.Position = UDim2.new(0.5, 0, 1, -12)

	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	DebugHud.clearCell()
end

-- Called only when the hovered cell changes, never every frame.
function DebugHud.showCell(
	x: number,
	z: number,
	height: number,
	water: boolean,
	slope: number,
	resource: number,
	buildable: boolean
)
	infoLabel.Text = string.format(
		"Seed       %d\nCell       %d, %d\nHeight     %.1f\nWater      %s\nSlope      %s\nResource   %s\nBuildable  %s",
		seed,
		x,
		z,
		height,
		if water then "yes" else "no",
		Types.SlopeNames[slope],
		Types.ResourceNames[resource],
		if buildable then "yes" else "no"
	)
end

function DebugHud.clearCell()
	infoLabel.Text = string.format("Seed       %d\nCell       (off the map)", seed)
end

return DebugHud

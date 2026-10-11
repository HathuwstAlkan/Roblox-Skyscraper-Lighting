--!strict
--[[
	SkyscraperClientFX.client.luau
	Client-side visual effects and performance LOD optimizer for high-rise buildings.
	Synchronizes rooftop aviation beacons and manages light rendering distance.
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local TAG_BEACON = "AviationBeacon"
local MAX_LIGHT_RENDER_DISTANCE = 450 -- studs beyond which PointLight is culled (Neon remains visible)

local activeBeacons: { [BasePart]: PointLight? } = {}
local camera = Workspace.CurrentCamera or Workspace:WaitForChild("Camera") :: Camera

local function onBeaconAdded(part: Instance)
	if not part:IsA("BasePart") then return end
	local light = part:FindFirstChildOfClass("PointLight")
	activeBeacons[part] = light
end

local function onBeaconRemoved(part: Instance)
	if part:IsA("BasePart") then
		activeBeacons[part] = nil
	end
end

for _, part in ipairs(CollectionService:GetTagged(TAG_BEACON)) do
	onBeaconAdded(part)
end

CollectionService:GetInstanceAddedSignal(TAG_BEACON):Connect(onBeaconAdded)
CollectionService:GetInstanceRemovedSignal(TAG_BEACON):Connect(onBeaconRemoved)

-- Synchronized optical pulse loop
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local camPos = camera.CFrame.Position

	-- 40 flashes per minute -> 1.5 seconds per cycle
	local cycle = (now % 1.5) / 1.5
	local intensity: number

	if cycle < 0.15 then
		intensity = cycle / 0.15
	elseif cycle < 0.70 then
		local decayAlpha = (cycle - 0.15) / 0.55
		intensity = math.exp(-3.5 * decayAlpha)
	else
		intensity = 0.0
	end

	local clockTime = Lighting.ClockTime
	local isDaytime = clockTime > 7.5 and clockTime < 16.5
	local maxBrightness = isDaytime and 1.2 or 3.5

	local beaconColor = Color3.fromRGB(
		math.floor(255 * (0.2 + (0.8 * intensity))),
		math.floor(25 * intensity),
		math.floor(25 * intensity)
	)

	for beaconPart, light in pairs(activeBeacons) do
		if beaconPart and beaconPart.Parent then
			beaconPart.Color = beaconColor
			if light then
				local dist = (beaconPart.Position - camPos).Magnitude
				if dist <= MAX_LIGHT_RENDER_DISTANCE and intensity > 0.05 then
					light.Enabled = true
					light.Brightness = maxBrightness * intensity
				else
					light.Enabled = false
				end
			end
		end
	end
end)

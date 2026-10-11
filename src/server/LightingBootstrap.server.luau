--!strict
--[[
	LightingBootstrap.server.luau
	Server-side bootstrap for Photorealistic World Lighting & Skyscraper Dynamic Lighting.
	Executes upon server start, sets up Future Lighting, initializes skyscraper engines,
	and automatically registers existing buildings.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LightingFolder = Shared:WaitForChild("Lighting")

local PhotorealLighting = require(LightingFolder:WaitForChild("PhotorealLighting") :: ModuleScript)
local SkyscraperLighting = require(LightingFolder:WaitForChild("SkyscraperLighting") :: ModuleScript)

-- 1. Initialize Photorealistic Lighting & Apply the iconic Blue Hour preset
PhotorealLighting.InitializeFutureEngine()
PhotorealLighting.ApplyPreset("BlueHour")

-- 2. Automatically scan Workspace for skyscraper models and tag windows
for _, child in ipairs(Workspace:GetChildren()) do
	if child:IsA("Model") then
		local lowerName = string.lower(child.Name)
		if string.find(lowerName, "building") or string.find(lowerName, "skyscraper") or string.find(lowerName, "tower") then
			local count = SkyscraperLighting.TagModelAsSkyscraper(child)
			if count > 0 then
				print(string.format("[LightingBootstrap] Registered %d windows in '%s'", count, child.Name))
			end
		end
	end
end

-- 3. Start dynamic skyscraper lighting engine (occupancy curve, beacon pulse, facade lights)
SkyscraperLighting.Start()

-- 4. (Optional) Run a 24-minute real-time day/night cycle (1 in-game minute = 1 real second)
-- Set to false if you want a fixed time-of-day for screenshots or development
local ENABLE_DAY_NIGHT_CYCLE = false
if ENABLE_DAY_NIGHT_CYCLE then
	PhotorealLighting.StartDayNightCycle(24)
end

print("[LightingBootstrap] Photorealistic Lighting & Skyscraper Engine active.")

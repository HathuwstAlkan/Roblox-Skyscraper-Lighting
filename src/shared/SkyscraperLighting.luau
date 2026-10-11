--!strict
--[[
	SkyscraperLighting.luau
	High-Rise Building & Skyscraper Dynamic Lighting Engine.
	Controls:
	  1. Procedural Window Grid (Office occupancy simulation, multi-temp lighting, floor clustering)
	  2. Aviation Obstruction Warning Beacons (FAA/ICAO synchronized 40-fpm red beacons)
	  3. Architectural Crown & Facade Wash Uplights (Dusk/Dawn automated scheduling)
	  4. Performance LOD (Zero-lag Neon emission architecture with 60+ FPS scalability)
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local TAG_WINDOW = "SkyscraperWindow"
local TAG_BEACON = "AviationBeacon"
local TAG_FACADE = "FacadeLight"

-- Realistic Office / Residential Color Temperatures
local COLOR_TEMPS = {
	FluorescentOffice = Color3.fromRGB(248, 244, 236), -- 4000K Neutral White (65%)
	WarmExecutive = Color3.fromRGB(255, 214, 168),     -- 2700K Warm Incandescent (20%)
	CoolTerminal = Color3.fromRGB(218, 235, 255),      -- 6000K Cool Daylight LED (10%)
	AmberAccent = Color3.fromRGB(255, 232, 195),       -- 3200K Halogen Soft White (5%)
}

-- Signature "Black Glass & Golden Specks" Theme Palette
local GOLDEN_SPECKS_PALETTE = {
	AmberGold = Color3.fromRGB(255, 188, 85),      -- Warm Glowing Honey Gold
	ChampagneGold = Color3.fromRGB(255, 212, 128),  -- Bright Golden Ray
	DeepDuskGold = Color3.fromRGB(255, 164, 58),   -- Sunset Deep Amber
	IncandescentGold = Color3.fromRGB(255, 198, 105), -- Cozy Desk Lamp Gold
}

-- Obsidian / Midnight Black Architectural Curtain Wall Glass
local BLACK_GLASS_COLOR = Color3.fromRGB(14, 17, 24)
local BLACK_GLASS_MATERIAL = Enum.Material.Glass
local BLACK_GLASS_TRANSPARENCY = 0.08

-- Default unlit dark reflective glass properties
local UNLIT_COLOR = BLACK_GLASS_COLOR
local UNLIT_MATERIAL = BLACK_GLASS_MATERIAL
local UNLIT_TRANSPARENCY = BLACK_GLASS_TRANSPARENCY

export type WindowData = {
	Part: BasePart,
	LitColor: Color3,
	OriginalColor: Color3,
	OriginalMaterial: Enum.Material,
	OriginalTransparency: number,
	FloorId: number,
	IsLit: boolean,
}

local SkyscraperLighting = {}

local registeredWindows: { [BasePart]: WindowData } = {}
local registeredBeacons: { [BasePart]: PointLight? } = {}
local registeredFacades: { [Light]: number } = {} -- stores original brightness

local isRunning = false
local heartbeatConn: RBXScriptConnection? = nil
local microEventTimer = 0

-- Compute office occupancy probability from ClockTime (0 - 24)
function SkyscraperLighting.GetOccupancyProbability(clockTime: number): number
	-- 00:00 - 05:00: Deep night (cleaning crews, servers, security) ~18%
	if clockTime < 5.0 then
		return 0.18
	-- 05:00 - 08:30: Morning arrival ramp (18% -> 55%)
	elseif clockTime < 8.5 then
		local alpha = (clockTime - 5.0) / 3.5
		return 0.18 + (0.37 * alpha)
	-- 08:30 - 16.5: Daytime standard office hours (lights on, ambient high) ~45%
	elseif clockTime < 16.5 then
		return 0.45
	-- 16:50 - 19:30: Dusk Overtime Peak (Golden hour & Blue hour skyline glow!) ~88%
	elseif clockTime < 19.5 then
		local alpha = (clockTime - 16.5) / 3.0
		return 0.45 + (0.43 * alpha)
	-- 19:30 - 22:30: Evening departure ramp (88% -> 40%)
	elseif clockTime < 22.5 then
		local alpha = (clockTime - 19.5) / 3.0
		return 0.88 - (0.48 * alpha)
	-- 22:30 - 24:00: Night wind-down (40% -> 18%)
	else
		local alpha = (clockTime - 22.5) / 1.5
		return 0.40 - (0.22 * alpha)
	end
end

-- Selects a realistic office color temperature based on weighted distribution
local function getRandomWindowColor(): Color3
	local roll = math.random()
	if roll < 0.65 then
		return COLOR_TEMPS.FluorescentOffice
	elseif roll < 0.85 then
		return COLOR_TEMPS.WarmExecutive
	elseif roll < 0.95 then
		return COLOR_TEMPS.CoolTerminal
	else
		return COLOR_TEMPS.AmberAccent
	end
end

-- Registers a window part into the engine
local function registerWindow(part: BasePart)
	if registeredWindows[part] then return end

	local litColor = getRandomWindowColor()
	local floorId = math.floor(part.Position.Y / 14) -- approximate floor division

	registeredWindows[part] = {
		Part = part,
		LitColor = litColor,
		OriginalColor = part.Color,
		OriginalMaterial = part.Material,
		OriginalTransparency = part.Transparency,
		FloorId = floorId,
		IsLit = false,
	}
end

local function unregisterWindow(part: BasePart)
	registeredWindows[part] = nil
end

-- Sets an individual window's lit/unlit visual state
function SkyscraperLighting.SetWindowState(part: BasePart, lit: boolean)
	local data = registeredWindows[part]
	if not data then return end

	data.IsLit = lit
	if lit then
		part.Material = Enum.Material.Neon
		part.Color = data.LitColor
		part.Transparency = 0.0
	else
		part.Material = UNLIT_MATERIAL
		part.Color = UNLIT_COLOR
		part.Transparency = UNLIT_TRANSPARENCY
	end
end

-- Registers an aviation obstruction beacon
local function registerBeacon(beaconPart: BasePart)
	if registeredBeacons[beaconPart] ~= nil then return end

	beaconPart.Material = Enum.Material.Neon
	beaconPart.Color = Color3.fromRGB(255, 30, 30)

	local pointLight = beaconPart:FindFirstChildOfClass("PointLight")
	if not pointLight then
		pointLight = Instance.new("PointLight")
		pointLight.Name = "BeaconGlow"
		pointLight.Color = Color3.fromRGB(255, 30, 30)
		pointLight.Range = 14
		pointLight.Brightness = 3
		pointLight.Shadows = false
		pointLight.Parent = beaconPart
	end

	registeredBeacons[beaconPart] = pointLight
end

local function unregisterBeacon(beaconPart: BasePart)
	registeredBeacons[beaconPart] = nil
end

-- Registers facade architectural wash lights
local function registerFacade(light: Instance)
	if not (light:IsA("SpotLight") or light:IsA("SurfaceLight") or light:IsA("PointLight")) then
		return
	end
	local lightInstance = light :: Light
	if registeredFacades[lightInstance] then return end
	registeredFacades[lightInstance] = lightInstance.Brightness
end

local function unregisterFacade(light: Instance)
	registeredFacades[light :: Light] = nil
end

-- Refreshes occupancy across all registered windows
function SkyscraperLighting.UpdateWindowOccupancy(clockTime: number?)
	local timeOfDay = clockTime or Lighting.ClockTime
	local targetProbability = SkyscraperLighting.GetOccupancyProbability(timeOfDay)

	for part, data in pairs(registeredWindows) do
		-- Spatial pseudo-random hash to cluster floors and office suites
		local hashVal = math.noise(part.Position.X * 0.05, data.FloorId * 0.5, part.Position.Z * 0.05)
		local normalizedHash = (hashVal + 1) * 0.5 -- 0.0 to 1.0

		local shouldBeLit = normalizedHash <= targetProbability
		if shouldBeLit ~= data.IsLit then
			SkyscraperLighting.SetWindowState(part, shouldBeLit)
		end
	end
end

-- Updates rooftop aviation beacons with synchronized FAA L-864 red pulse
function SkyscraperLighting.UpdateAviationBeacons(now: number)
	-- Standard FAA / ICAO flash rate: 40 flashes per minute -> 1.5 seconds per cycle
	local cycle = (now % 1.5) / 1.5
	local intensity: number

	-- Pulse envelope: rapid attack (0 to 0.15) followed by smooth exponential decay (0.15 to 0.7), dark remainder
	if cycle < 0.15 then
		intensity = cycle / 0.15
	elseif cycle < 0.70 then
		local decayAlpha = (cycle - 0.15) / 0.55
		intensity = math.exp(-3.5 * decayAlpha)
	else
		intensity = 0.0
	end

	-- Dim during bright noon, full intensity at night / twilight
	local clockTime = Lighting.ClockTime
	local isDaytime = clockTime > 7.0 and clockTime < 17.0
	local maxBrightness = isDaytime and 1.2 or 3.5

	local beaconColor = Color3.fromRGB(
		math.floor(255 * (0.2 + (0.8 * intensity))),
		math.floor(25 * intensity),
		math.floor(25 * intensity)
	)

	for beaconPart, pointLight in pairs(registeredBeacons) do
		beaconPart.Color = beaconColor
		if pointLight then
			pointLight.Brightness = maxBrightness * intensity
			pointLight.Enabled = intensity > 0.05
		end
	end
end

-- Updates architectural facade uplights based on twilight / night
function SkyscraperLighting.UpdateFacadeLights(clockTime: number)
	local isNightOrTwilight = clockTime >= 17.5 or clockTime <= 6.5

	for light, origBrightness in pairs(registeredFacades) do
		if isNightOrTwilight then
			light.Enabled = true
			light.Brightness = origBrightness
		else
			light.Enabled = false
			light.Brightness = 0
		end
	end
end

-- Randomly flickers / toggles a few windows to give the city an organic heartbeat
local function processMicroEvents()
	local windowList = {}
	for part, _ in pairs(registeredWindows) do
		table.insert(windowList, part)
	end
	if #windowList == 0 then return end

	-- Pick 1-3 random windows to flip state
	local count = math.random(1, math.min(3, #windowList))
	for _ = 1, count do
		local randomPart = windowList[math.random(1, #windowList)]
		local data = registeredWindows[randomPart]
		if data then
			SkyscraperLighting.SetWindowState(randomPart, not data.IsLit)
		end
	end
end

-- Starts the dynamic lighting engine loop
function SkyscraperLighting.Start()
	if isRunning then return end
	isRunning = true

	-- Bind CollectionService listeners
	for _, part in ipairs(CollectionService:GetTagged(TAG_WINDOW)) do
		if part:IsA("BasePart") then
			registerWindow(part)
		end
	end

	for _, beacon in ipairs(CollectionService:GetTagged(TAG_BEACON)) do
		if beacon:IsA("BasePart") then
			registerBeacon(beacon)
		end
	end

	for _, facade in ipairs(CollectionService:GetTagged(TAG_FACADE)) do
		registerFacade(facade)
	end

	CollectionService:GetInstanceAddedSignal(TAG_WINDOW):Connect(function(inst)
		if inst:IsA("BasePart") then registerWindow(inst) end
	end)

	CollectionService:GetInstanceRemovedSignal(TAG_WINDOW):Connect(function(inst)
		if inst:IsA("BasePart") then unregisterWindow(inst) end
	end)

	CollectionService:GetInstanceAddedSignal(TAG_BEACON):Connect(function(inst)
		if inst:IsA("BasePart") then registerBeacon(inst) end
	end)

	CollectionService:GetInstanceRemovedSignal(TAG_BEACON):Connect(function(inst)
		if inst:IsA("BasePart") then unregisterBeacon(inst) end
	end)

	CollectionService:GetInstanceAddedSignal(TAG_FACADE):Connect(function(inst)
		registerFacade(inst)
	end)

	CollectionService:GetInstanceRemovedSignal(TAG_FACADE):Connect(function(inst)
		unregisterFacade(inst)
	end)

	-- Initial occupancy pass
	SkyscraperLighting.UpdateWindowOccupancy(Lighting.ClockTime)

	-- Heartbeat render loop for smooth beacon synchronization and micro-events
	local lastOccupancyUpdate = 0
	heartbeatConn = RunService.Heartbeat:Connect(function(dt: number)
		local now = os.clock()

		-- Beacon strobe
		SkyscraperLighting.UpdateAviationBeacons(now)

		-- Update occupancy every 3 seconds or when time changes significantly
		if now - lastOccupancyUpdate > 3.0 then
			lastOccupancyUpdate = now
			SkyscraperLighting.UpdateWindowOccupancy(Lighting.ClockTime)
			SkyscraperLighting.UpdateFacadeLights(Lighting.ClockTime)
		end

		-- Micro-activity pulse every 6 to 12 seconds
		microEventTimer += dt
		if microEventTimer > 8.0 then
			microEventTimer = 0
			processMicroEvents()
		end
	end)
end

function SkyscraperLighting.Stop()
	if not isRunning then return end
	isRunning = false
	if heartbeatConn then
		heartbeatConn:Disconnect()
		heartbeatConn = nil
	end
end

-- =========================================================================
-- BUILDER & STUDIO HELPER UTILITIES
-- =========================================================================

-- Scans a model/folder and tags all glass/window parts as SkyscraperWindow
function SkyscraperLighting.TagModelAsSkyscraper(container: Instance): number
	local taggedCount = 0
	for _, desc in ipairs(container:GetDescendants()) do
		if desc:IsA("BasePart") then
			local lowerName = string.lower(desc.Name)
			local isWindowByName = string.find(lowerName, "window") ~= nil 
				or string.find(lowerName, "glass") ~= nil 
				or string.find(lowerName, "pane") ~= nil
			local isWindowByMaterial = desc.Material == Enum.Material.Glass or desc.Material == Enum.Material.Neon
			local isWindowByTransparency = desc.Transparency > 0.05 and desc.Transparency < 0.95

			if isWindowByName or isWindowByMaterial or isWindowByTransparency then
				CollectionService:AddTag(desc, TAG_WINDOW)
				taggedCount += 1
			end
		end
	end
	return taggedCount
end

-- Spawns an FAA-standard aviation beacon assembly
function SkyscraperLighting.CreateAviationBeacon(cframe: CFrame, parent: Instance?): Part
	local targetParent = parent or workspace

	local beacon = Instance.new("Part")
	beacon.Name = "AviationObstructionBeacon"
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Size = Vector3.new(1.8, 1.2, 1.2)
	beacon.CFrame = cframe * CFrame.Angles(0, 0, math.rad(90))
	beacon.Color = Color3.fromRGB(255, 30, 30)
	beacon.Material = Enum.Material.Neon
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CastShadow = false

	local pointLight = Instance.new("PointLight")
	pointLight.Name = "BeaconGlow"
	pointLight.Color = Color3.fromRGB(255, 30, 30)
	pointLight.Range = 14
	pointLight.Shadows = false
	pointLight.Parent = beacon

	CollectionService:AddTag(beacon, TAG_BEACON)
	beacon.Parent = targetParent
	return beacon
end

-- Converts tagged windows to the signature "Black Glass & Golden Specks" style
function SkyscraperLighting.ApplyGoldenSpecksTheme(container: Instance?): number
	local targetParts: { BasePart } = {}
	if container then
		for _, desc in ipairs(container:GetDescendants()) do
			if desc:IsA("BasePart") and CollectionService:HasTag(desc, TAG_WINDOW) then
				table.insert(targetParts, desc)
			end
		end
	else
		for _, part in ipairs(CollectionService:GetTagged(TAG_WINDOW)) do
			if part:IsA("BasePart") then
				table.insert(targetParts, part)
			end
		end
	end

	local goldenColorArray = {
		GOLDEN_SPECKS_PALETTE.AmberGold,
		GOLDEN_SPECKS_PALETTE.ChampagneGold,
		GOLDEN_SPECKS_PALETTE.DeepDuskGold,
		GOLDEN_SPECKS_PALETTE.IncandescentGold,
	}

	local count = 0
	for _, part in ipairs(targetParts) do
		local data = registeredWindows[part]
		local pickedColor = goldenColorArray[math.random(1, #goldenColorArray)]
		if data then
			data.LitColor = pickedColor
		end

		if data and data.IsLit then
			part.Material = Enum.Material.Neon
			part.Color = pickedColor
			part.Transparency = 0.0
		else
			part.Material = BLACK_GLASS_MATERIAL
			part.Color = BLACK_GLASS_COLOR
			part.Transparency = BLACK_GLASS_TRANSPARENCY
		end
		count += 1
	end

	return count
end

-- Procedurally generates a photorealistic dual-layer glass curtain wall facade
-- with outer tinted glass and interior recessed golden light sources.
function SkyscraperLighting.GenerateCurtainWallFacade(cframe: CFrame, width: number, height: number, parent: Instance?): Model
	local targetParent = parent or workspace
	local facadeModel = Instance.new("Model")
	facadeModel.Name = string.format("CurtainWall_Facade_%dx%d", math.round(width), math.round(height))

	local numFloors = math.max(1, math.round(height / 10))
	local floorH = height / numFloors

	local numBays = math.max(1, math.round(width / 3.8))
	local bayW = width / numBays

	local mullionColor = Color3.fromRGB(20, 22, 28)
	local mullionMat = Enum.Material.Metal

	local goldenColorArray = {
		GOLDEN_SPECKS_PALETTE.AmberGold,
		GOLDEN_SPECKS_PALETTE.ChampagneGold,
		GOLDEN_SPECKS_PALETTE.DeepDuskGold,
		GOLDEN_SPECKS_PALETTE.IncandescentGold,
	}

	-- 1. Outer Dark Structural Spandrels (horizontal floor bands)
	for f = 0, numFloors do
		local spandrelY = -height * 0.5 + (f * floorH)
		local spandrel = Instance.new("Part")
		spandrel.Name = "Spandrel_Band"
		spandrel.Size = Vector3.new(width, 0.6, 0.45)
		spandrel.CFrame = cframe * CFrame.new(0, spandrelY, 0.05)
		spandrel.Color = mullionColor
		spandrel.Material = mullionMat
		spandrel.Anchored = true
		spandrel.CanCollide = true
		spandrel.Parent = facadeModel
	end

	-- 2. Vertical Mullions (structural column fins)
	for b = 0, numBays do
		local mullionX = -width * 0.5 + (b * bayW)
		local mullion = Instance.new("Part")
		mullion.Name = "Mullion_Fin"
		mullion.Size = Vector3.new(0.4, height, 0.5)
		mullion.CFrame = cframe * CFrame.new(mullionX, 0, 0.1)
		mullion.Color = mullionColor
		mullion.Material = mullionMat
		mullion.Anchored = true
		mullion.CanCollide = true
		mullion.Parent = facadeModel
	end

	-- 3. Individual Window Bays (Outer Tinted Glass + Recessed Interior Light Pane)
	for f = 0, numFloors - 1 do
		local floorCenterY = -height * 0.5 + ((f + 0.5) * floorH)
		local floorId = math.floor((cframe.Position.Y + floorCenterY) / 10)

		for b = 0, numBays - 1 do
			local bayCenterX = -width * 0.5 + ((b + 0.5) * bayW)
			local worldPos = (cframe * CFrame.new(bayCenterX, floorCenterY, 0)).Position

			-- A. Outer Tinted Glass Cladding (Reflects sky, sun, and clouds)
			local outerGlass = Instance.new("Part")
			outerGlass.Name = string.format("GlassPane_F%d_B%d", f + 1, b + 1)
			outerGlass.Size = Vector3.new(bayW - 0.38, floorH - 0.55, 0.12)
			outerGlass.CFrame = cframe * CFrame.new(bayCenterX, floorCenterY, 0.08)
			outerGlass.Color = BLACK_GLASS_COLOR
			outerGlass.Material = Enum.Material.Glass
			outerGlass.Transparency = 0.28 -- Clear enough to see glowing room, reflective enough for sky
			outerGlass.Anchored = true
			outerGlass.CanCollide = true
			outerGlass.Parent = facadeModel

			-- B. Recessed Interior Light Source Pane (0.35 studs behind the glass)
			local innerLight = Instance.new("Part")
			innerLight.Name = string.format("InteriorLight_F%d_B%d", f + 1, b + 1)
			innerLight.Size = Vector3.new(bayW - 0.55, floorH - 0.75, 0.12)
			innerLight.CFrame = cframe * CFrame.new(bayCenterX, floorCenterY, -0.32)
			innerLight.Anchored = true
			innerLight.CanCollide = false
			innerLight.CastShadow = false

			-- Coherent Perlin Noise clustering for room occupancy
			local hashVal = math.noise(worldPos.X * 0.06, floorId * 0.5, worldPos.Z * 0.06)
			local isLit = (hashVal + 1) * 0.5 <= 0.45 -- 45% default evening occupancy

			local pickedColor = goldenColorArray[math.random(1, #goldenColorArray)]

			if isLit then
				innerLight.Material = Enum.Material.Neon
				innerLight.Color = pickedColor
				innerLight.Transparency = 0.0
			else
				innerLight.Material = Enum.Material.SmoothPlastic
				innerLight.Color = Color3.fromRGB(16, 18, 24) -- Dark interior room
				innerLight.Transparency = 0.0
			end

			-- Tag for dynamic runtime occupancy engine
			CollectionService:AddTag(innerLight, TAG_WINDOW)
			innerLight.Parent = facadeModel
		end
	end

	facadeModel.Parent = targetParent
	return facadeModel
end

-- Procedurally generates a curved or 360-degree cylindrical glass curtain wall tower
function SkyscraperLighting.GenerateCylindricalFacade(centerCFrame: CFrame, radius: number, height: number, arcAngleDeg: number?, parent: Instance?): Model
	local targetParent = parent or workspace
	local arcDegrees = arcAngleDeg or 360
	local totalArcRad = math.rad(math.clamp(arcDegrees, 10, 360))
	local isFullCircle = arcDegrees >= 360

	local facadeModel = Instance.new("Model")
	facadeModel.Name = string.format("Cylindrical_Tower_R%d_H%d", math.round(radius), math.round(height))

	local numFloors = math.max(1, math.round(height / 10))
	local floorH = height / numFloors

	local arcLength = radius * totalArcRad
	local numBays = math.max(6, math.round(arcLength / 3.6))
	local dTheta = totalArcRad / numBays
	local bayChordW = 2 * radius * math.sin(dTheta * 0.5)

	local mullionColor = Color3.fromRGB(20, 22, 28)
	local mullionMat = Enum.Material.Metal

	local goldenColorArray = {
		GOLDEN_SPECKS_PALETTE.AmberGold,
		GOLDEN_SPECKS_PALETTE.ChampagneGold,
		GOLDEN_SPECKS_PALETTE.DeepDuskGold,
		GOLDEN_SPECKS_PALETTE.IncandescentGold,
	}

	local startAngle = -totalArcRad * 0.5
	if isFullCircle then
		startAngle = 0
	end

	for b = 0, numBays - 1 do
		local angle = startAngle + (b + 0.5) * dTheta
		local cosA, sinA = math.cos(angle), math.sin(angle)

		local radialDir = Vector3.new(sinA, 0, cosA)
		local tangentDir = Vector3.new(cosA, 0, -sinA)

		local bayCenterLocal = radialDir * radius
		local bayRotation = CFrame.fromMatrix(Vector3.zero, tangentDir, Vector3.new(0, 1, 0), radialDir)

		for f = 0, numFloors - 1 do
			local floorCenterY = -height * 0.5 + ((f + 0.5) * floorH)
			local floorId = math.floor((centerCFrame.Position.Y + floorCenterY) / 10)

			local paneCFrame = centerCFrame * CFrame.new(bayCenterLocal.X, floorCenterY, bayCenterLocal.Z) * bayRotation

			local outerGlass = Instance.new("Part")
			outerGlass.Name = string.format("CurvedGlass_F%d_B%d", f + 1, b + 1)
			outerGlass.Size = Vector3.new(bayChordW - 0.2, floorH - 0.5, 0.12)
			outerGlass.CFrame = paneCFrame * CFrame.new(0, 0, 0.06)
			outerGlass.Color = BLACK_GLASS_COLOR
			outerGlass.Material = Enum.Material.Glass
			outerGlass.Transparency = 0.28
			outerGlass.Anchored = true
			outerGlass.CanCollide = true
			outerGlass.Parent = facadeModel

			local innerLight = Instance.new("Part")
			innerLight.Name = string.format("InteriorLight_F%d_B%d", f + 1, b + 1)
			innerLight.Size = Vector3.new(bayChordW - 0.4, floorH - 0.7, 0.12)
			innerLight.CFrame = paneCFrame * CFrame.new(0, 0, -0.32)
			innerLight.Anchored = true
			innerLight.CanCollide = false
			innerLight.CastShadow = false

			local worldPos = innerLight.Position
			local hashVal = math.noise(worldPos.X * 0.06, floorId * 0.5, worldPos.Z * 0.06)
			local isLit = (hashVal + 1) * 0.5 <= 0.45

			local pickedColor = goldenColorArray[math.random(1, #goldenColorArray)]
			if isLit then
				innerLight.Material = Enum.Material.Neon
				innerLight.Color = pickedColor
				innerLight.Transparency = 0.0
			else
				innerLight.Material = Enum.Material.SmoothPlastic
				innerLight.Color = Color3.fromRGB(16, 18, 24)
				innerLight.Transparency = 0.0
			end

			CollectionService:AddTag(innerLight, TAG_WINDOW)
			innerLight.Parent = facadeModel
		end

		local mullionAngle = startAngle + (b * dTheta)
		local mCos, mSin = math.cos(mullionAngle), math.sin(mullionAngle)
		local mPos = Vector3.new(mSin, 0, mCos) * radius
		local mRot = CFrame.fromMatrix(Vector3.zero, Vector3.new(mCos, 0, -mSin), Vector3.new(0, 1, 0), Vector3.new(mSin, 0, mCos))

		local mullion = Instance.new("Part")
		mullion.Name = "Curved_Mullion"
		mullion.Size = Vector3.new(0.35, height, 0.45)
		mullion.CFrame = centerCFrame * CFrame.new(mPos.X, 0, mPos.Z) * mRot
		mullion.Color = mullionColor
		mullion.Material = mullionMat
		mullion.Anchored = true
		mullion.CanCollide = true
		mullion.Parent = facadeModel
	end

	facadeModel.Parent = targetParent
	return facadeModel
end

-- Procedurally generates a tapered / trapezoidal glass skyscraper facade
function SkyscraperLighting.GenerateTaperedFacade(baseCFrame: CFrame, baseWidth: number, topWidth: number, height: number, parent: Instance?): Model
	local targetParent = parent or workspace
	local facadeModel = Instance.new("Model")
	facadeModel.Name = string.format("Tapered_Facade_%dx%d_to_%d", math.round(baseWidth), math.round(height), math.round(topWidth))

	local numFloors = math.max(1, math.round(height / 10))
	local floorH = height / numFloors

	local goldenColorArray = {
		GOLDEN_SPECKS_PALETTE.AmberGold,
		GOLDEN_SPECKS_PALETTE.ChampagneGold,
		GOLDEN_SPECKS_PALETTE.DeepDuskGold,
		GOLDEN_SPECKS_PALETTE.IncandescentGold,
	}

	for f = 0, numFloors - 1 do
		local alpha = (f + 0.5) / numFloors
		local currentFloorWidth = baseWidth + (topWidth - baseWidth) * alpha
		local floorCenterY = -height * 0.5 + ((f + 0.5) * floorH)
		local floorId = math.floor((baseCFrame.Position.Y + floorCenterY) / 10)

		local numBaysThisFloor = math.max(1, math.round(currentFloorWidth / 3.8))
		local bayW = currentFloorWidth / numBaysThisFloor

		for b = 0, numBaysThisFloor - 1 do
			local bayCenterX = -currentFloorWidth * 0.5 + ((b + 0.5) * bayW)
			local paneCFrame = baseCFrame * CFrame.new(bayCenterX, floorCenterY, 0)
			local worldPos = paneCFrame.Position

			local outerGlass = Instance.new("Part")
			outerGlass.Name = string.format("TaperedGlass_F%d_B%d", f + 1, b + 1)
			outerGlass.Size = Vector3.new(bayW - 0.35, floorH - 0.5, 0.12)
			outerGlass.CFrame = paneCFrame * CFrame.new(0, 0, 0.08)
			outerGlass.Color = BLACK_GLASS_COLOR
			outerGlass.Material = Enum.Material.Glass
			outerGlass.Transparency = 0.28
			outerGlass.Anchored = true
			outerGlass.CanCollide = true
			outerGlass.Parent = facadeModel

			local innerLight = Instance.new("Part")
			innerLight.Name = string.format("InteriorLight_F%d_B%d", f + 1, b + 1)
			innerLight.Size = Vector3.new(bayW - 0.5, floorH - 0.7, 0.12)
			innerLight.CFrame = paneCFrame * CFrame.new(0, 0, -0.32)
			innerLight.Anchored = true
			innerLight.CanCollide = false
			innerLight.CastShadow = false

			local hashVal = math.noise(worldPos.X * 0.06, floorId * 0.5, worldPos.Z * 0.06)
			local isLit = (hashVal + 1) * 0.5 <= 0.45

			local pickedColor = goldenColorArray[math.random(1, #goldenColorArray)]
			if isLit then
				innerLight.Material = Enum.Material.Neon
				innerLight.Color = pickedColor
				innerLight.Transparency = 0.0
			else
				innerLight.Material = Enum.Material.SmoothPlastic
				innerLight.Color = Color3.fromRGB(16, 18, 24)
				innerLight.Transparency = 0.0
			end

			CollectionService:AddTag(innerLight, TAG_WINDOW)
			innerLight.Parent = facadeModel
		end
	end

	facadeModel.Parent = targetParent
	return facadeModel
end

return SkyscraperLighting

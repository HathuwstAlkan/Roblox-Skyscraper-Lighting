--!strict
--[[
	SkyscraperLightingPlugin (init.server.luau)
	Roblox Studio Plugin for Photorealistic Lighting & Skyscraper Systems.
	Features:
	  - One-click Photoreal Future Lighting setup with calibrated physical Atmosphere, Bloom, ColorCorrection, SunRays.
	  - Architectural photography presets: Blue Hour, Golden Hour, Noon, Metropolis Night, Moody Overcast.
	  - Dual-layer window architecture: Exterior tinted obsidian glass + recessed interior golden office lights.
	  - Modular non-stretching curtain wall generator & 360-degree round glass tower generator.
	  - Rooftop FAA/ICAO synchronized aviation warning beacons.
	  - Floating non-docking palette & direct Studio ribbon buttons to prevent Qt cursor capture.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Selection = game:GetService("Selection")
local Workspace = game:GetService("Workspace")

local TAG_WINDOW = "SkyscraperWindow"
local TAG_INTERIOR = "SkyscraperInteriorLight"
local TAG_BEACON = "AviationBeacon"
local TAG_FACADE = "FacadeLight"

-- Architectural tinted glass specification
local GLASS_TINT_COLOR = Color3.fromRGB(16, 20, 26) -- Dark obsidian tint
local GLASS_TRANSPARENCY = 0.45 -- 45% tint balances sky reflections with interior illumination

-- Golden specks interior lighting palette
local GOLDEN_COLORS = {
	Color3.fromRGB(245, 185, 95),  -- Warm Glowing Honey Gold (2700K)
	Color3.fromRGB(252, 205, 125), -- Soft Champagne Amber (3000K)
	Color3.fromRGB(235, 160, 65),  -- Deep Sunset Amber (2400K)
	Color3.fromRGB(255, 222, 155), -- Cozy Desk Lamp Glow (3200K)
}
local UNLIT_ROOM_COLOR = Color3.fromRGB(16, 18, 22) -- Dark unlit office interior

-- Photoreal calibrated shader presets
local PRESETS = {
	BlueHour = {
		Name = "Blue Hour (Skyscraper Dusk)",
		ClockTime = 18.25,
		GeographicLatitude = 40.7,
		Brightness = 0.9, -- Calibrated non-blinding dusk illumination
		ExposureCompensation = -0.05,
		EnvironmentDiffuseScale = 0.85,
		EnvironmentSpecularScale = 1.0,
		ShadowSoftness = 0.15,
		OutdoorAmbient = Color3.fromRGB(35, 45, 65),
		Ambient = Color3.fromRGB(18, 22, 32),
		ColorShift_Top = Color3.fromRGB(245, 180, 130),
		ColorShift_Bottom = Color3.fromRGB(30, 40, 65),
		Atmosphere = {
			Density = 0.32,
			Offset = 0.22,
			Glare = 0.15,
			Haze = 1.1,
			Color = Color3.fromRGB(140, 165, 210),
			Decay = Color3.fromRGB(45, 60, 95),
		},
		Bloom = {
			Threshold = 2.2, -- Pinpoint threshold: only true light sources bloom, preventing washed-out glare
			Size = 14, -- Tight optical glare around window frames
			Intensity = 0.22, -- Subtle, photorealistic glow
		},
		ColorCorrection = {
			Brightness = 0.0,
			Contrast = 0.12,
			Saturation = 0.04,
			TintColor = Color3.fromRGB(252, 250, 255),
		},
		SunRays = {
			Intensity = 0.08,
			Spread = 0.72,
		},
		Clouds = {
			Cover = 0.55,
			Density = 0.35,
		},
	},
	GoldenHour = {
		Name = "Golden Hour (Dramatic Sunset)",
		ClockTime = 17.4,
		GeographicLatitude = 40.7,
		Brightness = 1.4,
		ExposureCompensation = 0.0,
		EnvironmentDiffuseScale = 1.0,
		EnvironmentSpecularScale = 1.0,
		ShadowSoftness = 0.25,
		OutdoorAmbient = Color3.fromRGB(75, 62, 52),
		Ambient = Color3.fromRGB(38, 30, 25),
		ColorShift_Top = Color3.fromRGB(255, 175, 95),
		ColorShift_Bottom = Color3.fromRGB(80, 52, 35),
		Atmosphere = {
			Density = 0.30,
			Offset = 0.24,
			Glare = 0.45,
			Haze = 1.4,
			Color = Color3.fromRGB(255, 185, 130),
			Decay = Color3.fromRGB(180, 75, 45),
		},
		Bloom = {
			Threshold = 2.2,
			Size = 16,
			Intensity = 0.25,
		},
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.12,
			Saturation = 0.08,
			TintColor = Color3.fromRGB(255, 246, 236),
		},
		SunRays = {
			Intensity = 0.14,
			Spread = 0.75,
		},
		Clouds = {
			Cover = 0.5,
			Density = 0.4,
		},
	},
	HighNoon = {
		Name = "Photoreal Noon (Crisp Daylight)",
		ClockTime = 12.0,
		GeographicLatitude = 40.7,
		Brightness = 1.8,
		ExposureCompensation = 0.0,
		EnvironmentDiffuseScale = 1.0,
		EnvironmentSpecularScale = 1.0,
		ShadowSoftness = 0.18,
		OutdoorAmbient = Color3.fromRGB(105, 112, 122),
		Ambient = Color3.fromRGB(45, 48, 52),
		ColorShift_Top = Color3.fromRGB(255, 252, 246),
		ColorShift_Bottom = Color3.fromRGB(115, 120, 128),
		Atmosphere = {
			Density = 0.26,
			Offset = 0.20,
			Glare = 0.20,
			Haze = 0.8,
			Color = Color3.fromRGB(195, 215, 242),
			Decay = Color3.fromRGB(95, 125, 160),
		},
		Bloom = {
			Threshold = 2.4,
			Size = 12,
			Intensity = 0.15,
		},
		ColorCorrection = {
			Brightness = 0.0,
			Contrast = 0.10,
			Saturation = 0.04,
			TintColor = Color3.fromRGB(255, 255, 255),
		},
		SunRays = {
			Intensity = 0.04,
			Spread = 0.60,
		},
		Clouds = {
			Cover = 0.4,
			Density = 0.32,
		},
	},
	NightMetropolis = {
		Name = "Metropolis Night (Glowing Skyline)",
		ClockTime = 22.8,
		GeographicLatitude = 40.7,
		Brightness = 0.22,
		ExposureCompensation = 0.05,
		EnvironmentDiffuseScale = 0.85,
		EnvironmentSpecularScale = 1.0,
		ShadowSoftness = 0.3,
		OutdoorAmbient = Color3.fromRGB(14, 18, 28),
		Ambient = Color3.fromRGB(10, 12, 18),
		ColorShift_Top = Color3.fromRGB(75, 95, 140),
		ColorShift_Bottom = Color3.fromRGB(14, 18, 28),
		Atmosphere = {
			Density = 0.38,
			Offset = 0.28,
			Glare = 0.10,
			Haze = 1.6,
			Color = Color3.fromRGB(24, 32, 55),
			Decay = Color3.fromRGB(8, 12, 28),
		},
		Bloom = {
			Threshold = 2.1,
			Size = 14,
			Intensity = 0.26,
		},
		ColorCorrection = {
			Brightness = 0.0,
			Contrast = 0.14,
			Saturation = 0.06,
			TintColor = Color3.fromRGB(240, 245, 255),
		},
		SunRays = {
			Intensity = 0.0,
			Spread = 0.5,
		},
		Clouds = {
			Cover = 0.45,
			Density = 0.3,
		},
	},
	OvercastMoody = {
		Name = "Moody Overcast (Soft Fog)",
		ClockTime = 14.5,
		GeographicLatitude = 40.7,
		Brightness = 0.85,
		ExposureCompensation = 0.0,
		EnvironmentDiffuseScale = 1.0,
		EnvironmentSpecularScale = 1.0,
		ShadowSoftness = 0.4,
		OutdoorAmbient = Color3.fromRGB(80, 85, 95),
		Ambient = Color3.fromRGB(40, 42, 48),
		ColorShift_Top = Color3.fromRGB(165, 175, 185),
		ColorShift_Bottom = Color3.fromRGB(72, 76, 84),
		Atmosphere = {
			Density = 0.50,
			Offset = 0.34,
			Glare = 0.10,
			Haze = 2.2,
			Color = Color3.fromRGB(165, 175, 185),
			Decay = Color3.fromRGB(100, 110, 120),
		},
		Bloom = {
			Threshold = 2.4,
			Size = 12,
			Intensity = 0.14,
		},
		ColorCorrection = {
			Brightness = -0.01,
			Contrast = 0.08,
			Saturation = -0.05,
			TintColor = Color3.fromRGB(235, 240, 245),
		},
		SunRays = {
			Intensity = 0.02,
			Spread = 0.85,
		},
		Clouds = {
			Cover = 0.75,
			Density = 0.55,
		},
	},
}

local function getOrCreate<T>(className: string, name: string, parent: Instance): T
	local found = parent:FindFirstChild(name)
	if not found or not found:IsA(className) then
		if found then found:Destroy() end
		local created = Instance.new(className)
		created.Name = name
		created.Parent = parent
		return created :: any
	end
	return found :: any
end

local function applyLightingPreset(key: string)
	local p = PRESETS[key]
	if not p then return end

	Lighting.Technology = Enum.Technology.Future
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = p.EnvironmentDiffuseScale
	Lighting.EnvironmentSpecularScale = p.EnvironmentSpecularScale
	Lighting.ShadowSoftness = p.ShadowSoftness
	Lighting.GeographicLatitude = p.GeographicLatitude
	Lighting.ClockTime = p.ClockTime
	Lighting.Brightness = p.Brightness
	Lighting.ExposureCompensation = p.ExposureCompensation
	Lighting.OutdoorAmbient = p.OutdoorAmbient
	Lighting.Ambient = p.Ambient
	Lighting.ColorShift_Top = p.ColorShift_Top
	Lighting.ColorShift_Bottom = p.ColorShift_Bottom

	local atmo = getOrCreate("Atmosphere", "PhotorealAtmosphere", Lighting) :: Atmosphere
	atmo.Density = p.Atmosphere.Density
	atmo.Offset = p.Atmosphere.Offset
	atmo.Color = p.Atmosphere.Color
	atmo.Decay = p.Atmosphere.Decay
	atmo.Glare = p.Atmosphere.Glare
	atmo.Haze = p.Atmosphere.Haze

	local bloom = getOrCreate("BloomEffect", "PhotorealBloom", Lighting) :: BloomEffect
	bloom.Threshold = p.Bloom.Threshold
	bloom.Size = p.Bloom.Size
	bloom.Intensity = p.Bloom.Intensity

	local cc = getOrCreate("ColorCorrectionEffect", "PhotorealColorCorrection", Lighting) :: ColorCorrectionEffect
	cc.Brightness = p.ColorCorrection.Brightness
	cc.Contrast = p.ColorCorrection.Contrast
	cc.Saturation = p.ColorCorrection.Saturation
	cc.TintColor = p.ColorCorrection.TintColor

	local sunRays = getOrCreate("SunRaysEffect", "PhotorealSunRays", Lighting) :: SunRaysEffect
	sunRays.Intensity = p.SunRays.Intensity
	sunRays.Spread = p.SunRays.Spread

	local terrain = Workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Name = "AtmosphericClouds"
		clouds.Parent = terrain
	end
	clouds.Cover = p.Clouds.Cover
	clouds.Density = p.Clouds.Density

	ChangeHistoryService:SetWaypoint("Applied " .. p.Name)
	print("[SkyscraperPlugin] Applied photoreal lighting preset:", p.Name)
end

-- Calculates inward CFrame offset and size for a recessed interior light behind an exterior window pane
local function computeInteriorLightGeometry(part: BasePart, modelCenter: Vector3): (CFrame, Vector3)
	local cf = part.CFrame
	local sx, sy, sz = part.Size.X, part.Size.Y, part.Size.Z
	local toCenter = modelCenter - part.Position

	-- Identify the thinnest axis (window normal)
	if sz <= sx and sz <= sy then
		-- Normal is along Z axis (LookVector)
		local sign = (cf.LookVector:Dot(toCenter) >= 0) and 1 or -1
		local offsetDist = (sz * 0.5) + 0.20
		local lightCF = cf * CFrame.new(0, 0, sign * offsetDist)
		local lightSize = Vector3.new(math.max(0.3, sx * 0.94), math.max(0.3, sy * 0.94), 0.12)
		return lightCF, lightSize
	elseif sx <= sy and sx <= sz then
		-- Normal is along X axis (RightVector)
		local sign = (cf.RightVector:Dot(toCenter) >= 0) and 1 or -1
		local offsetDist = (sx * 0.5) + 0.20
		local lightCF = cf * CFrame.new(sign * offsetDist, 0, 0)
		local lightSize = Vector3.new(0.12, math.max(0.3, sy * 0.94), math.max(0.3, sz * 0.94))
		return lightCF, lightSize
	else
		-- Normal is along Y axis (UpVector)
		local sign = (cf.UpVector:Dot(toCenter) >= 0) and 1 or -1
		local offsetDist = (sy * 0.5) + 0.20
		local lightCF = cf * CFrame.new(0, sign * offsetDist, 0)
		local lightSize = Vector3.new(math.max(0.3, sx * 0.94), 0.12, math.max(0.3, sz * 0.94))
		return lightCF, lightSize
	end
end

-- Ensures a window part has dark tinted glass on the outside and a recessed light part behind it
local function setupDualLayerWindow(part: BasePart, modelCenter: Vector3, isLit: boolean): BasePart
	-- 1. Outer window pane ALWAYS remains dark tinted glass
	part.Material = Enum.Material.Glass
	part.Color = GLASS_TINT_COLOR
	part.Transparency = GLASS_TRANSPARENCY
	part.Reflectance = 0
	part.CastShadow = false
	CollectionService:AddTag(part, TAG_WINDOW)

	-- 2. Locate or create recessed interior light part behind the glass
	local parentModel = part.Parent or workspace
	local interiorName = part.Name .. "_InteriorLight"
	local interior = parentModel:FindFirstChild(interiorName) :: BasePart?

	if not interior or not interior:IsA("BasePart") then
		local lightCF, lightSize = computeInteriorLightGeometry(part, modelCenter)
		local created = Instance.new("Part")
		created.Name = interiorName
		created.Size = lightSize
		created.CFrame = lightCF
		created.Anchored = true
		created.CanCollide = false
		created.CastShadow = false
		created.Parent = parentModel
		interior = created
	end

	CollectionService:AddTag(interior, TAG_INTERIOR)

	-- 3. Set interior light state
	if isLit then
		interior.Material = Enum.Material.Neon
		interior.Color = GOLDEN_COLORS[math.random(1, #GOLDEN_COLORS)]
		interior.Transparency = 0.0
	else
		interior.Material = Enum.Material.SmoothPlastic
		interior.Color = UNLIT_ROOM_COLOR
		interior.Transparency = 0.0
	end

	return interior
end

-- Checks if a part is a window candidate (excluding existing interior lights)
local function isWindowCandidate(part: BasePart): boolean
	if string.find(part.Name, "_InteriorLight") or CollectionService:HasTag(part, TAG_INTERIOR) then
		return false
	end
	if CollectionService:HasTag(part, TAG_WINDOW) then
		return true
	end
	local lowerName = string.lower(part.Name)
	if string.find(lowerName, "window") or string.find(lowerName, "glass") or string.find(lowerName, "pane") or string.find(lowerName, "glazing") or string.find(lowerName, "curtain") then
		return true
	end
	if part.Material == Enum.Material.Glass or part.Material == Enum.Material.Neon then
		return true
	end
	if part.Transparency > 0.05 and part.Transparency < 0.95 then
		return true
	end
	return false
end

-- Convert selected building model windows to dual-layer tinted glass & warm interior lights
local function convertSelectedBuildingWindows(): number
	local selected = Selection:Get()
	if #selected == 0 then
		warn("[SkyscraperPlugin] Select a building model or parts in the Explorer first!")
		return 0
	end

	local convertedCount = 0

	for _, root in ipairs(selected) do
		local partsToConvert: { BasePart } = {}
		local modelCenter = Vector3.zero

		if root:IsA("Model") then
			local cf = root:GetBoundingBox()
			modelCenter = cf.Position
			for _, desc in ipairs(root:GetDescendants()) do
				if desc:IsA("BasePart") and isWindowCandidate(desc) then
					table.insert(partsToConvert, desc)
				end
			end
		elseif root:IsA("BasePart") then
			modelCenter = root.Position - (root.CFrame.LookVector * 10)
			if isWindowCandidate(root) then
				table.insert(partsToConvert, root)
			end
		end

		for _, part in ipairs(partsToConvert) do
			-- 45% active golden specks ratio for luxury skyscraper aesthetic
			local isLit = math.random() < 0.45
			setupDualLayerWindow(part, modelCenter, isLit)
			convertedCount += 1
		end
	end

	ChangeHistoryService:SetWaypoint("Converted " .. convertedCount .. " Dual-Layer Windows")
	print(string.format("[SkyscraperPlugin] Successfully converted %d windows to tinted glass with recessed golden lights.", convertedCount))
	return convertedCount
end

-- Randomize lit state of all tagged skyscraper windows
local function randomizeTaggedWindows(litProbability: number?): number
	local prob = litProbability or 0.45
	local count = 0

	for _, part in ipairs(CollectionService:GetTagged(TAG_WINDOW)) do
		if part:IsA("BasePart") and not CollectionService:HasTag(part, TAG_INTERIOR) then
			-- Ensure outer glass stays dark obsidian tinted glass
			part.Material = Enum.Material.Glass
			part.Color = GLASS_TINT_COLOR
			part.Transparency = GLASS_TRANSPARENCY

			-- Locate interior light
			local parent = part.Parent or workspace
			local interior = parent:FindFirstChild(part.Name .. "_InteriorLight") :: BasePart?

			if interior and interior:IsA("BasePart") then
				local isLit = math.random() < prob
				if isLit then
					interior.Material = Enum.Material.Neon
					interior.Color = GOLDEN_COLORS[math.random(1, #GOLDEN_COLORS)]
					interior.Transparency = 0.0
				else
					interior.Material = Enum.Material.SmoothPlastic
					interior.Color = UNLIT_ROOM_COLOR
					interior.Transparency = 0.0
				end
				count += 1
			end
		end
	end

	ChangeHistoryService:SetWaypoint("Randomized " .. count .. " Window Lights")
	print(string.format("[SkyscraperPlugin] Randomized %d interior lights.", count))
	return count
end

-- Generates or fits a dual-layer glass curtain wall facade
local function spawnOrFitCurtainWall(): Model
	local selected = Selection:Get()
	local cframe: CFrame
	local width: number
	local height: number
	local parent: Instance = workspace

	if #selected > 0 and selected[1]:IsA("BasePart") then
		local basePart = selected[1] :: BasePart
		parent = basePart.Parent or workspace
		cframe = basePart.CFrame

		local sx, sy, sz = basePart.Size.X, basePart.Size.Y, basePart.Size.Z
		if sz <= sx and sz <= sy then
			width = sx
			height = sy
		elseif sx <= sy and sx <= sz then
			width = sz
			height = sy
			cframe = cframe * CFrame.Angles(0, math.rad(90), 0)
		else
			width = sx
			height = sz
			cframe = cframe * CFrame.Angles(math.rad(90), 0, 0)
		end
	else
		local cam = workspace.CurrentCamera
		cframe = cam and (cam.CFrame * CFrame.new(0, 0, -35)) or CFrame.new(0, 30, 0)
		cframe = CFrame.new(cframe.Position)
		width = 36
		height = 60
	end

	local facadeModel = Instance.new("Model")
	facadeModel.Name = string.format("CurtainWall_Facade_%dx%d", math.round(width), math.round(height))

	local numFloors = math.max(1, math.round(height / 10))
	local floorH = height / numFloors
	local numBays = math.max(1, math.round(width / 3.8))
	local bayW = width / numBays

	local mullionColor = Color3.fromRGB(20, 22, 28)
	local mullionMat = Enum.Material.Metal

	-- Horizontal Spandrels
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

	-- Vertical Mullions
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

	-- Dual-Layer Window Grid
	for f = 0, numFloors - 1 do
		local floorCenterY = -height * 0.5 + ((f + 0.5) * floorH)
		local floorId = math.floor((cframe.Position.Y + floorCenterY) / 10)

		for b = 0, numBays - 1 do
			local bayCenterX = -width * 0.5 + ((b + 0.5) * bayW)
			local worldPos = (cframe * CFrame.new(bayCenterX, floorCenterY, 0)).Position

			-- 1. Outer Glass (Dark obsidian tinted glass, PBR reflections)
			local outerGlass = Instance.new("Part")
			outerGlass.Name = string.format("GlassPane_F%d_B%d", f + 1, b + 1)
			outerGlass.Size = Vector3.new(bayW - 0.38, floorH - 0.55, 0.12)
			outerGlass.CFrame = cframe * CFrame.new(bayCenterX, floorCenterY, 0.08)
			outerGlass.Color = GLASS_TINT_COLOR
			outerGlass.Material = Enum.Material.Glass
			outerGlass.Transparency = GLASS_TRANSPARENCY
			outerGlass.CastShadow = false
			outerGlass.Anchored = true
			outerGlass.CanCollide = true
			outerGlass.Parent = facadeModel
			CollectionService:AddTag(outerGlass, TAG_WINDOW)

			-- 2. Recessed Interior Light (0.4 studs behind glass into building)
			local innerLight = Instance.new("Part")
			innerLight.Name = string.format("GlassPane_F%d_B%d_InteriorLight", f + 1, b + 1)
			innerLight.Size = Vector3.new(bayW - 0.55, floorH - 0.75, 0.12)
			innerLight.CFrame = cframe * CFrame.new(bayCenterX, floorCenterY, -0.32)
			innerLight.Anchored = true
			innerLight.CanCollide = false
			innerLight.CastShadow = false

			local hashVal = math.noise(worldPos.X * 0.06, floorId * 0.5, worldPos.Z * 0.06)
			local isLit = (hashVal + 1) * 0.5 <= 0.45

			if isLit then
				innerLight.Material = Enum.Material.Neon
				innerLight.Color = GOLDEN_COLORS[math.random(1, #GOLDEN_COLORS)]
				innerLight.Transparency = 0.0
			else
				innerLight.Material = Enum.Material.SmoothPlastic
				innerLight.Color = UNLIT_ROOM_COLOR
				innerLight.Transparency = 0.0
			end

			CollectionService:AddTag(innerLight, TAG_INTERIOR)
			innerLight.Parent = facadeModel
		end
	end

	facadeModel.Parent = parent
	Selection:Set({ facadeModel })
	ChangeHistoryService:SetWaypoint("Generated Curtain Wall Facade")
	return facadeModel
end

-- Spawns a 360-degree round glass skyscraper tower
local function spawnCylindricalTower(): Model
	local cam = workspace.CurrentCamera
	local cframe = cam and (cam.CFrame * CFrame.new(0, 0, -45)) or CFrame.new(0, 40, 0)
	cframe = CFrame.new(cframe.Position)

	local radius = 22
	local height = 80
	local numFloors = math.max(1, math.round(height / 10))
	local floorH = height / numFloors
	local totalArcRad = math.rad(360)
	local numBays = math.max(6, math.round((radius * totalArcRad) / 3.6))
	local dTheta = totalArcRad / numBays
	local bayChordW = 2 * radius * math.sin(dTheta * 0.5)

	local facadeModel = Instance.new("Model")
	facadeModel.Name = string.format("Cylindrical_Glass_Tower_R%d_H%d", math.round(radius), math.round(height))

	for b = 0, numBays - 1 do
		local angle = (b + 0.5) * dTheta
		local cosA, sinA = math.cos(angle), math.sin(angle)
		local radialDir = Vector3.new(sinA, 0, cosA)
		local tangentDir = Vector3.new(cosA, 0, -sinA)
		local bayCenterLocal = radialDir * radius
		local bayRotation = CFrame.fromMatrix(Vector3.zero, tangentDir, Vector3.new(0, 1, 0), radialDir)

		for f = 0, numFloors - 1 do
			local floorCenterY = -height * 0.5 + ((f + 0.5) * floorH)
			local floorId = math.floor((cframe.Position.Y + floorCenterY) / 10)
			local paneCFrame = cframe * CFrame.new(bayCenterLocal.X, floorCenterY, bayCenterLocal.Z) * bayRotation

			-- 1. Outer Curved Glass Pane
			local outerGlass = Instance.new("Part")
			outerGlass.Name = string.format("CurvedGlass_F%d_B%d", f + 1, b + 1)
			outerGlass.Size = Vector3.new(bayChordW - 0.2, floorH - 0.5, 0.12)
			outerGlass.CFrame = paneCFrame * CFrame.new(0, 0, 0.06)
			outerGlass.Color = GLASS_TINT_COLOR
			outerGlass.Material = Enum.Material.Glass
			outerGlass.Transparency = GLASS_TRANSPARENCY
			outerGlass.CastShadow = false
			outerGlass.Anchored = true
			outerGlass.CanCollide = true
			outerGlass.Parent = facadeModel
			CollectionService:AddTag(outerGlass, TAG_WINDOW)

			-- 2. Recessed Interior Light (0.38 studs behind glass towards tower center)
			local innerLight = Instance.new("Part")
			innerLight.Name = string.format("CurvedGlass_F%d_B%d_InteriorLight", f + 1, b + 1)
			innerLight.Size = Vector3.new(bayChordW - 0.4, floorH - 0.7, 0.12)
			innerLight.CFrame = paneCFrame * CFrame.new(0, 0, -0.32)
			innerLight.Anchored = true
			innerLight.CanCollide = false
			innerLight.CastShadow = false

			local worldPos = innerLight.Position
			local hashVal = math.noise(worldPos.X * 0.06, floorId * 0.5, worldPos.Z * 0.06)
			local isLit = (hashVal + 1) * 0.5 <= 0.45

			if isLit then
				innerLight.Material = Enum.Material.Neon
				innerLight.Color = GOLDEN_COLORS[math.random(1, #GOLDEN_COLORS)]
				innerLight.Transparency = 0.0
			else
				innerLight.Material = Enum.Material.SmoothPlastic
				innerLight.Color = UNLIT_ROOM_COLOR
				innerLight.Transparency = 0.0
			end

			CollectionService:AddTag(innerLight, TAG_INTERIOR)
			innerLight.Parent = facadeModel
		end

		-- Vertical Architectural Mullion
		local mullionAngle = b * dTheta
		local mCos, mSin = math.cos(mullionAngle), math.sin(mullionAngle)
		local mPos = Vector3.new(mSin, 0, mCos) * radius
		local mRot = CFrame.fromMatrix(Vector3.zero, Vector3.new(mCos, 0, -mSin), Vector3.new(0, 1, 0), Vector3.new(mSin, 0, mCos))

		local mullion = Instance.new("Part")
		mullion.Name = "Curved_Mullion"
		mullion.Size = Vector3.new(0.35, height, 0.45)
		mullion.CFrame = cframe * CFrame.new(mPos.X, 0, mPos.Z) * mRot
		mullion.Color = Color3.fromRGB(20, 22, 28)
		mullion.Material = Enum.Material.Metal
		mullion.Anchored = true
		mullion.CanCollide = true
		mullion.Parent = facadeModel
	end

	facadeModel.Parent = workspace
	Selection:Set({ facadeModel })
	ChangeHistoryService:SetWaypoint("Generated Cylindrical Tower")
	return facadeModel
end

-- Add Aviation Beacon on summit of selected building
local function addAviationBeaconToSelection(): Part?
	local selected = Selection:Get()
	if #selected == 0 then
		warn("[SkyscraperPlugin] Select a building model or rooftop part first!")
		return nil
	end

	local highestY = -math.huge
	local highestPos = Vector3.zero
	local targetParent = selected[1]

	for _, root in ipairs(selected) do
		if root:IsA("BasePart") then
			local topY = root.Position.Y + (root.Size.Y * 0.5)
			if topY > highestY then
				highestY = topY
				highestPos = Vector3.new(root.Position.X, topY, root.Position.Z)
			end
		else
			for _, desc in ipairs(root:GetDescendants()) do
				if desc:IsA("BasePart") then
					local topY = desc.Position.Y + (desc.Size.Y * 0.5)
					if topY > highestY then
						highestY = topY
						highestPos = Vector3.new(desc.Position.X, topY, desc.Position.Z)
					end
				end
			end
		end
	end

	if highestY == -math.huge then return nil end

	local beacon = Instance.new("Part")
	beacon.Name = "AviationObstructionBeacon"
	beacon.Shape = Enum.PartType.Cylinder
	beacon.Size = Vector3.new(1.6, 1.2, 1.2)
	beacon.CFrame = CFrame.new(highestPos + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beacon.Color = Color3.fromRGB(255, 30, 30)
	beacon.Material = Enum.Material.Neon
	beacon.Anchored = true
	beacon.CanCollide = false
	beacon.CastShadow = false

	local light = Instance.new("PointLight")
	light.Name = "BeaconGlow"
	light.Color = Color3.fromRGB(255, 30, 30)
	light.Range = 14
	light.Brightness = 3.0
	light.Shadows = false
	light.Parent = beacon

	CollectionService:AddTag(beacon, TAG_BEACON)
	beacon.Parent = targetParent

	ChangeHistoryService:SetWaypoint("Created Rooftop Aviation Beacon")
	Selection:Set({ beacon })
	return beacon
end

-- =========================================================================
-- STUDIO RIBBON TOOLBAR (Direct 1-Click Actions Without Docking)
-- =========================================================================

local toolbar = plugin:CreateToolbar("Skyscraper Lighting")

local btnApplyLighting = toolbar:CreateButton(
	"Blue Hour Dusk",
	"One-click photoreal Blue Hour dusk lighting, atmosphere, and bloom",
	"rbxassetid://6031075931"
)

local btnConvert = toolbar:CreateButton(
	"Convert Windows",
	"Convert selected building to dual-layer tinted glass & warm interior lights",
	"rbxassetid://6031265976"
)

local btnCurtainWall = toolbar:CreateButton(
	"Fit Facade",
	"Fit modular non-stretching glass curtain wall to selected part",
	"rbxassetid://6034287594"
)

local btnCylinder = toolbar:CreateButton(
	"Round Tower",
	"Spawn 360-degree cylindrical glass skyscraper tower",
	"rbxassetid://6031075929"
)

local btnRandomize = toolbar:CreateButton(
	"Randomize",
	"Randomize office lights across all tagged buildings",
	"rbxassetid://6031280883"
)

local btnTogglePanel = toolbar:CreateButton(
	"Control Panel",
	"Open floating control panel for presets and tools",
	"rbxassetid://6031280882"
)

-- Direct toolbar button handlers
btnApplyLighting.Click:Connect(function()
	applyLightingPreset("BlueHour")
end)

btnConvert.Click:Connect(function()
	convertSelectedBuildingWindows()
end)

btnCurtainWall.Click:Connect(function()
	spawnOrFitCurtainWall()
end)

btnCylinder.Click:Connect(function()
	spawnCylindricalTower()
end)

btnRandomize.Click:Connect(function()
	randomizeTaggedWindows()
end)

-- =========================================================================
-- FLOATING CONTROL PANEL (InitialDockState.Float avoids Qt dock cursor bug)
-- =========================================================================

local widgetInfo = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float,
	false, -- initially enabled = false
	false, -- override previous state = false
	320,   -- default width
	540,   -- default height
	280,   -- min width
	380    -- min height
)

local widget = plugin:CreateDockWidgetPluginGui("SkyscraperFloatingPalette", widgetInfo)
widget.Title = "Skyscraper & Photoreal Lighting"
widget.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local bg = Instance.new("ScrollingFrame")
bg.Name = "MainFrame"
bg.Size = UDim2.new(1, 0, 1, 0)
bg.BackgroundColor3 = Color3.fromRGB(24, 26, 32)
bg.BorderSizePixel = 0
bg.ScrollBarThickness = 5
bg.ScrollBarImageColor3 = Color3.fromRGB(70, 75, 90)
bg.CanvasSize = UDim2.new(0, 0, 0, 800)
bg.Active = false -- IMPORTANT: false prevents mouse capture in Studio
bg.Parent = widget

local padding = Instance.new("UIPadding")
padding.PaddingLeft = UDim.new(0, 12)
padding.PaddingRight = UDim.new(0, 12)
padding.PaddingTop = UDim.new(0, 12)
padding.PaddingBottom = UDim.new(0, 12)
padding.Parent = bg

local layout = Instance.new("UIListLayout")
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 8)
layout.Parent = bg

local function createHeader(text: string, order: number)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, 24)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(220, 225, 235)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.LayoutOrder = order
	label.Active = false
	label.Parent = bg
	return label
end

local function createButton(text: string, order: number, color: Color3?, onClick: () -> ())
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, 34)
	btn.BackgroundColor3 = color or Color3.fromRGB(42, 48, 60)
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 12
	btn.TextColor3 = Color3.fromRGB(255, 255, 255)
	btn.Text = text
	btn.AutoButtonColor = true
	btn.LayoutOrder = order
	btn.Parent = bg

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 5)
	corner.Parent = btn

	btn.MouseButton1Click:Connect(onClick)
	return btn
end

-- Section 1: Presets
createHeader("PHOTOREAL SHADER PRESETS", 1)

createButton("🌆 Blue Hour (Skyscraper Dusk)", 2, Color3.fromRGB(35, 65, 115), function()
	applyLightingPreset("BlueHour")
end)

createButton("🌅 Golden Hour (Dramatic Sunset)", 3, Color3.fromRGB(135, 70, 25), function()
	applyLightingPreset("GoldenHour")
end)

createButton("☀️ Photoreal High Noon", 4, Color3.fromRGB(60, 88, 118), function()
	applyLightingPreset("HighNoon")
end)

createButton("🌃 Metropolis Night", 5, Color3.fromRGB(26, 32, 54), function()
	applyLightingPreset("NightMetropolis")
end)

createButton("☁️ Moody Overcast", 6, Color3.fromRGB(58, 66, 76), function()
	applyLightingPreset("OvercastMoody")
end)

-- Section 2: Building Tools
createHeader("DUAL-LAYER SKYSCRAPER TOOLS", 7)

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 0, 20)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 11
statusLabel.TextColor3 = Color3.fromRGB(130, 205, 140)
statusLabel.Text = "Ready. Select a model in Explorer."
statusLabel.LayoutOrder = 8
statusLabel.Active = false
statusLabel.Parent = bg

createButton("🏢 Convert Selection (Tinted Glass + Inner Light)", 9, Color3.fromRGB(36, 100, 72), function()
	local count = convertSelectedBuildingWindows()
	if count > 0 then
		statusLabel.Text = string.format("✓ Converted %d windows with dual-layer lighting!", count)
	else
		statusLabel.Text = "Select a building model first."
	end
end)

createButton("🪟 Fit Curtain Wall to Selected Part", 10, Color3.fromRGB(30, 85, 120), function()
	local facade = spawnOrFitCurtainWall()
	if facade then
		statusLabel.Text = "✓ Generated Glass & Golden Light Facade!"
	end
end)

createButton("🔵 Spawn 360° Cylindrical Tower", 11, Color3.fromRGB(40, 72, 130), function()
	local tower = spawnCylindricalTower()
	if tower then
		statusLabel.Text = "✓ Generated 360° Round Glass Tower!"
	end
end)

createButton("🚨 Add Rooftop Aviation Beacon", 12, Color3.fromRGB(130, 36, 36), function()
	local beacon = addAviationBeaconToSelection()
	if beacon then
		statusLabel.Text = "✓ Added rooftop obstruction beacon!"
	else
		statusLabel.Text = "Select a building model or rooftop first."
	end
end)

createButton("🎲 Randomize Office Lights", 13, Color3.fromRGB(52, 58, 72), function()
	local count = randomizeTaggedWindows()
	statusLabel.Text = string.format("✓ Randomized %d windows!", count)
end)

-- Section 3: Time Shortcuts
createHeader("TIME OF DAY QUICK JUMP", 14)

local timeContainer = Instance.new("Frame")
timeContainer.Size = UDim2.new(1, 0, 0, 32)
timeContainer.BackgroundTransparency = 1
timeContainer.LayoutOrder = 15
timeContainer.Active = false
timeContainer.Parent = bg

local timeGrid = Instance.new("UIGridLayout")
timeGrid.CellSize = UDim2.new(0.23, 0, 1, 0)
timeGrid.CellPadding = UDim2.new(0.026, 0, 0, 0)
timeGrid.Parent = timeContainer

local function addTimeBtn(text: string, time: number)
	local b = Instance.new("TextButton")
	b.Text = text
	b.Font = Enum.Font.GothamMedium
	b.TextSize = 10
	b.TextColor3 = Color3.fromRGB(235, 235, 235)
	b.BackgroundColor3 = Color3.fromRGB(38, 42, 52)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 4)
	c.Parent = b
	b.MouseButton1Click:Connect(function()
		Lighting.ClockTime = time
		ChangeHistoryService:SetWaypoint("Set Time to " .. text)
	end)
	b.Parent = timeContainer
end

addTimeBtn("06:00", 6.0)
addTimeBtn("12:00", 12.0)
addTimeBtn("18:15", 18.25)
addTimeBtn("23:00", 23.0)

btnTogglePanel.Click:Connect(function()
	widget.Enabled = not widget.Enabled
end)

print("[SkyscraperLightingPlugin] Plugin loaded successfully with ribbon controls and floating palette.")

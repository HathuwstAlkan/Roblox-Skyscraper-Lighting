--!strict
--[[
	PhotorealLighting.luau
	Advanced Photorealistic Lighting & Post-Processing Engine for Roblox.
	Provides physically-calibrated atmospheric scattering, ACES tone curve emulation,
	Future Technology lighting setup, and cinematic cityscape presets.
]]

local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

export type AtmospherePreset = {
	Density: number,
	Offset: number,
	Color: Color3,
	Decay: Color3,
	Glare: number,
	Haze: number,
}

export type BloomPreset = {
	Threshold: number,
	Size: number,
	Intensity: number,
}

export type ColorCorrectionPreset = {
	Brightness: number,
	Contrast: number,
	Saturation: number,
	TintColor: Color3,
}

export type SunRaysPreset = {
	Intensity: number,
	Spread: number,
}

export type CloudsPreset = {
	Cover: number,
	Density: number,
	Color: Color3,
}

export type LightingPreset = {
	Name: string,
	ClockTime: number,
	GeographicLatitude: number,
	Brightness: number,
	ExposureCompensation: number,
	EnvironmentDiffuseScale: number,
	EnvironmentSpecularScale: number,
	ShadowSoftness: number,
	OutdoorAmbient: Color3,
	Ambient: Color3,
	ColorShift_Top: Color3,
	ColorShift_Bottom: Color3,
	Atmosphere: AtmospherePreset,
	Bloom: BloomPreset,
	ColorCorrection: ColorCorrectionPreset,
	SunRays: SunRaysPreset,
	Clouds: CloudsPreset?,
}

local PhotorealLighting = {}

local PRESETS: { [string]: LightingPreset } = {
	["BlueHour"] = {
		Name = "Blue Hour (Skyscraper Twilight)",
		ClockTime = 18.25,
		GeographicLatitude = 40.7,
		Brightness = 1.8,
		ExposureCompensation = 0.05,
		EnvironmentDiffuseScale = 1.0,
		EnvironmentSpecularScale = 1.0,
		ShadowSoftness = 0.2,
		OutdoorAmbient = Color3.fromRGB(45, 60, 95),
		Ambient = Color3.fromRGB(22, 28, 42),
		ColorShift_Top = Color3.fromRGB(255, 195, 145),
		ColorShift_Bottom = Color3.fromRGB(38, 50, 78),
		Atmosphere = {
			Density = 0.38,
			Offset = 0.28,
			Color = Color3.fromRGB(155, 185, 235),
			Decay = Color3.fromRGB(55, 78, 130),
			Glare = 0.38,
			Haze = 1.35,
		},
		Bloom = {
			Threshold = 1.75,
			Size = 24,
			Intensity = 0.45,
		},
		ColorCorrection = {
			Brightness = 0.02,
			Contrast = 0.14,
			Saturation = 0.06,
			TintColor = Color3.fromRGB(250, 248, 255),
		},
		SunRays = {
			Intensity = 0.08,
			Spread = 0.72,
		},
		Clouds = {
			Cover = 0.45,
			Density = 0.35,
			Color = Color3.fromRGB(215, 210, 235),
		},
	},

	["GoldenHour"] = {
		Name = "Golden Hour (Dramatic Sunset)",
		ClockTime = 17.4,
		GeographicLatitude = 40.7,
		Brightness = 2.4,
		ExposureCompensation = 0.0,
		EnvironmentDiffuseScale = 1.0,
		EnvironmentSpecularScale = 1.0,
		ShadowSoftness = 0.25,
		OutdoorAmbient = Color3.fromRGB(80, 68, 58),
		Ambient = Color3.fromRGB(42, 34, 28),
		ColorShift_Top = Color3.fromRGB(255, 175, 95),
		ColorShift_Bottom = Color3.fromRGB(85, 55, 38),
		Atmosphere = {
			Density = 0.32,
			Offset = 0.25,
			Color = Color3.fromRGB(255, 185, 130),
			Decay = Color3.fromRGB(180, 75, 45),
			Glare = 0.65,
			Haze = 1.6,
		},
		Bloom = {
			Threshold = 1.6,
			Size = 26,
			Intensity = 0.42,
		},
		ColorCorrection = {
			Brightness = 0.03,
			Contrast = 0.12,
			Saturation = 0.10,
			TintColor = Color3.fromRGB(255, 246, 236),
		},
		SunRays = {
			Intensity = 0.15,
			Spread = 0.78,
		},
		Clouds = {
			Cover = 0.5,
			Density = 0.4,
			Color = Color3.fromRGB(255, 205, 160),
		},
	},

	["HighNoon"] = {
		Name = "Photoreal Noon (Crisp Daylight)",
		ClockTime = 12.0,
		GeographicLatitude = 40.7,
		Brightness = 2.7,
		ExposureCompensation = 0.0,
		EnvironmentDiffuseScale = 1.0,
		EnvironmentSpecularScale = 1.0,
		ShadowSoftness = 0.18,
		OutdoorAmbient = Color3.fromRGB(110, 118, 128),
		Ambient = Color3.fromRGB(48, 50, 55),
		ColorShift_Top = Color3.fromRGB(255, 252, 246),
		ColorShift_Bottom = Color3.fromRGB(120, 125, 132),
		Atmosphere = {
			Density = 0.28,
			Offset = 0.22,
			Color = Color3.fromRGB(195, 215, 242),
			Decay = Color3.fromRGB(95, 125, 160),
			Glare = 0.25,
			Haze = 0.85,
		},
		Bloom = {
			Threshold = 2.0,
			Size = 22,
			Intensity = 0.32,
		},
		ColorCorrection = {
			Brightness = 0.01,
			Contrast = 0.10,
			Saturation = 0.05,
			TintColor = Color3.fromRGB(255, 255, 255),
		},
		SunRays = {
			Intensity = 0.05,
			Spread = 0.6,
		},
		Clouds = {
			Cover = 0.4,
			Density = 0.32,
			Color = Color3.fromRGB(255, 255, 255),
		},
	},

	["NightMetropolis"] = {
		Name = "Metropolis Night (Luminescent Skyline)",
		ClockTime = 22.8,
		GeographicLatitude = 40.7,
		Brightness = 0.35,
		ExposureCompensation = 0.1,
		EnvironmentDiffuseScale = 0.9,
		EnvironmentSpecularScale = 1.0,
		ShadowSoftness = 0.3,
		OutdoorAmbient = Color3.fromRGB(16, 20, 32),
		Ambient = Color3.fromRGB(12, 14, 22),
		ColorShift_Top = Color3.fromRGB(85, 105, 150),
		ColorShift_Bottom = Color3.fromRGB(15, 20, 32),
		Atmosphere = {
			Density = 0.42,
			Offset = 0.30,
			Color = Color3.fromRGB(26, 36, 62),
			Decay = Color3.fromRGB(10, 15, 32),
			Glare = 0.12,
			Haze = 1.85,
		},
		Bloom = {
			Threshold = 1.45,
			Size = 28,
			Intensity = 0.58,
		},
		ColorCorrection = {
			Brightness = 0.01,
			Contrast = 0.16,
			Saturation = 0.08,
			TintColor = Color3.fromRGB(240, 245, 255),
		},
		SunRays = {
			Intensity = 0.0,
			Spread = 0.5,
		},
		Clouds = {
			Cover = 0.55,
			Density = 0.48,
			Color = Color3.fromRGB(38, 44, 66),
		},
	},

	["OvercastMoody"] = {
		Name = "Moody Overcast (Atmospheric Fog)",
		ClockTime = 14.5,
		GeographicLatitude = 40.7,
		Brightness = 1.35,
		ExposureCompensation = 0.0,
		EnvironmentDiffuseScale = 1.0,
		EnvironmentSpecularScale = 1.0,
		ShadowSoftness = 0.4,
		OutdoorAmbient = Color3.fromRGB(88, 92, 102),
		Ambient = Color3.fromRGB(44, 46, 52),
		ColorShift_Top = Color3.fromRGB(175, 185, 195),
		ColorShift_Bottom = Color3.fromRGB(78, 82, 90),
		Atmosphere = {
			Density = 0.54,
			Offset = 0.36,
			Color = Color3.fromRGB(170, 180, 190),
			Decay = Color3.fromRGB(105, 115, 125),
			Glare = 0.12,
			Haze = 2.4,
		},
		Bloom = {
			Threshold = 1.9,
			Size = 20,
			Intensity = 0.25,
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
			Cover = 0.85,
			Density = 0.78,
			Color = Color3.fromRGB(175, 180, 190),
		},
	},
}

-- Ensure instances exist and are named consistently
local function getOrCreateInstance<T>(className: string, name: string, parent: Instance): T
	local found = parent:FindFirstChild(name)
	if not found or not found:IsA(className) then
		if found then
			found:Destroy()
		end
		local created = Instance.new(className)
		created.Name = name
		created.Parent = parent
		return created :: any
	end
	return found :: any
end

local function getTerrainClouds(): Clouds
	local terrain = Workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Name = "AtmosphericClouds"
		clouds.Parent = terrain
	end
	return clouds
end

-- Sets up the Lighting engine for photorealism
function PhotorealLighting.InitializeFutureEngine()
	Lighting.Technology = Enum.Technology.Future
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 1.0
	Lighting.EnvironmentSpecularScale = 1.0
	Lighting.ShadowSoftness = 0.2
	Lighting.GeographicLatitude = 40.7
	Lighting.ExposureCompensation = 0.0

	-- Ensure core post effects
	getOrCreateInstance("Atmosphere", "PhotorealAtmosphere", Lighting)
	getOrCreateInstance("BloomEffect", "PhotorealBloom", Lighting)
	getOrCreateInstance("ColorCorrectionEffect", "PhotorealColorCorrection", Lighting)
	getOrCreateInstance("SunRaysEffect", "PhotorealSunRays", Lighting)
	getTerrainClouds()
end

-- Applies a preset instantly or with smooth tweening
function PhotorealLighting.ApplyPreset(presetKey: string, transitionDuration: number?)
	local preset = PRESETS[presetKey]
	if not preset then
		warn(string.format("[PhotorealLighting] Unknown preset key '%s'. Available: BlueHour, GoldenHour, HighNoon, NightMetropolis, OvercastMoody", tostring(presetKey)))
		return
	end

	PhotorealLighting.InitializeFutureEngine()

	local atmosphere = getOrCreateInstance("Atmosphere", "PhotorealAtmosphere", Lighting) :: Atmosphere
	local bloom = getOrCreateInstance("BloomEffect", "PhotorealBloom", Lighting) :: BloomEffect
	local cc = getOrCreateInstance("ColorCorrectionEffect", "PhotorealColorCorrection", Lighting) :: ColorCorrectionEffect
	local sunRays = getOrCreateInstance("SunRaysEffect", "PhotorealSunRays", Lighting) :: SunRaysEffect
	local clouds = getTerrainClouds()

	local duration = transitionDuration or 0

	if duration <= 0 then
		-- Instant apply
		Lighting.ClockTime = preset.ClockTime
		Lighting.Brightness = preset.Brightness
		Lighting.ExposureCompensation = preset.ExposureCompensation
		Lighting.EnvironmentDiffuseScale = preset.EnvironmentDiffuseScale
		Lighting.EnvironmentSpecularScale = preset.EnvironmentSpecularScale
		Lighting.ShadowSoftness = preset.ShadowSoftness
		Lighting.OutdoorAmbient = preset.OutdoorAmbient
		Lighting.Ambient = preset.Ambient
		Lighting.ColorShift_Top = preset.ColorShift_Top
		Lighting.ColorShift_Bottom = preset.ColorShift_Bottom

		atmosphere.Density = preset.Atmosphere.Density
		atmosphere.Offset = preset.Atmosphere.Offset
		atmosphere.Color = preset.Atmosphere.Color
		atmosphere.Decay = preset.Atmosphere.Decay
		atmosphere.Glare = preset.Atmosphere.Glare
		atmosphere.Haze = preset.Atmosphere.Haze

		bloom.Threshold = preset.Bloom.Threshold
		bloom.Size = preset.Bloom.Size
		bloom.Intensity = preset.Bloom.Intensity

		cc.Brightness = preset.ColorCorrection.Brightness
		cc.Contrast = preset.ColorCorrection.Contrast
		cc.Saturation = preset.ColorCorrection.Saturation
		cc.TintColor = preset.ColorCorrection.TintColor

		sunRays.Intensity = preset.SunRays.Intensity
		sunRays.Spread = preset.SunRays.Spread

		if preset.Clouds then
			clouds.Cover = preset.Clouds.Cover
			clouds.Density = preset.Clouds.Density
			clouds.Color = preset.Clouds.Color
		end
	else
		-- Smooth tween transition
		local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.Out)

		TweenService:Create(Lighting, tweenInfo, {
			ClockTime = preset.ClockTime,
			Brightness = preset.Brightness,
			ExposureCompensation = preset.ExposureCompensation,
			EnvironmentDiffuseScale = preset.EnvironmentDiffuseScale,
			EnvironmentSpecularScale = preset.EnvironmentSpecularScale,
			ShadowSoftness = preset.ShadowSoftness,
			OutdoorAmbient = preset.OutdoorAmbient,
			Ambient = preset.Ambient,
			ColorShift_Top = preset.ColorShift_Top,
			ColorShift_Bottom = preset.ColorShift_Bottom,
		}):Play()

		TweenService:Create(atmosphere, tweenInfo, {
			Density = preset.Atmosphere.Density,
			Offset = preset.Atmosphere.Offset,
			Color = preset.Atmosphere.Color,
			Decay = preset.Atmosphere.Decay,
			Glare = preset.Atmosphere.Glare,
			Haze = preset.Atmosphere.Haze,
		}):Play()

		TweenService:Create(bloom, tweenInfo, {
			Threshold = preset.Bloom.Threshold,
			Size = preset.Bloom.Size,
			Intensity = preset.Bloom.Intensity,
		}):Play()

		TweenService:Create(cc, tweenInfo, {
			Brightness = preset.ColorCorrection.Brightness,
			Contrast = preset.ColorCorrection.Contrast,
			Saturation = preset.ColorCorrection.Saturation,
			TintColor = preset.ColorCorrection.TintColor,
		}):Play()

		TweenService:Create(sunRays, tweenInfo, {
			Intensity = preset.SunRays.Intensity,
			Spread = preset.SunRays.Spread,
		}):Play()

		if preset.Clouds then
			TweenService:Create(clouds, tweenInfo, {
				Cover = preset.Clouds.Cover,
				Density = preset.Clouds.Density,
				Color = preset.Clouds.Color,
			}):Play()
		end
	end
end

-- Get all available presets for UI / plugins
function PhotorealLighting.GetPresetList(): { [string]: string }
	local list: { [string]: string } = {}
	for key, preset in pairs(PRESETS) do
		list[key] = preset.Name
	end
	return list
end

-- Returns preset data
function PhotorealLighting.GetPreset(key: string): LightingPreset?
	return PRESETS[key]
end

local activeCycleConnection: RBXScriptConnection? = nil

-- Starts a realistic day-night time progression
function PhotorealLighting.StartDayNightCycle(minutesPerDay: number, dynamicAtmosphere: boolean?)
	if activeCycleConnection then
		activeCycleConnection:Disconnect()
		activeCycleConnection = nil
	end

	PhotorealLighting.InitializeFutureEngine()
	local RunService = game:GetService("RunService")
	local hoursPerSecond = 24 / (minutesPerDay * 60)

	activeCycleConnection = RunService.Heartbeat:Connect(function(dt: number)
		Lighting.ClockTime = (Lighting.ClockTime + (hoursPerSecond * dt)) % 24
	end)
end

function PhotorealLighting.StopDayNightCycle()
	if activeCycleConnection then
		activeCycleConnection:Disconnect()
		activeCycleConnection = nil
	end
end

return PhotorealLighting

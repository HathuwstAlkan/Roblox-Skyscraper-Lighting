# Roblox Photoreal Skyscraper & Lighting System

[![Roblox Engine](https://img.shields.io/badge/Roblox-Studio-red?logo=roblox)](https://roblox.com)
[![Language](https://img.shields.io/badge/Language-Luau-00A2FF?logo=lua)](https://luau-lang.org)
[![Technology](https://img.shields.io/badge/Lighting-Future%20Technology-purple)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

An advanced procedural architectural lighting engine and Roblox Studio plugin. Delivers **photorealistic world lighting ("shaders")**, dynamic **high-rise office occupancy simulation**, and procedural **dual-layer glass curtain walls** with glowing golden interior lights.

---

## Key Features

### 1. Photorealistic Lighting & Atmospheric Post-Processing
* **Future Technology**: Per-pixel contact shadows, dynamic specular highlights, and full PBR sky reflection (`EnvironmentSpecularScale = 1.0`).
* **Physical Rayleigh & Mie Atmosphere**: Calibrated atmospheric scattering, horizon glare, and distance haze.
* **Calibrated Lens Bloom**: Sets threshold to `1.75 - 1.85` so only true light sources bloom, preventing blurry smears and creating crisp pinpoints of light.
* **ACES Film Tonemapping**: Digital camera sensor emulation via `ColorCorrectionEffect`.
* **5 Curated Presets**:
  * **Blue Hour (Skyscraper Dusk)**: Deep royal blue twilight with glowing office windows and wet specular reflections.
  * **Golden Hour (Dramatic Sunset)**: Low warm amber directional sun with long cinematic shadows.
  * **Photoreal High Noon**: High dynamic range daylight with balanced camera exposure.
  * **Metropolis Night**: Deep midnight sky with an electric glowing skyline.
  * **Moody Overcast**: Diffused cloud scattering with soft fog.

### 2. Signature "Black Glass & Golden Specks" Aesthetic
* **Dual-Layer Curtain Wall**:
  * **Outer Skin**: Obsidian tinted reflective glass (`Material = Glass`, `Transparency = 0.28`, `Color = (14, 17, 24)`) that mirrors the sky and clouds.
  * **Inner Skin**: Warm golden interior lighting recessed 0.35 studs behind the glass (`Material = Neon`, Amber/Champagne Gold). Light shines through the glass for true 3D parallax depth.
* **Tight Bloom & Contrast**: Keeps every window pane looking like a razor-sharp, sparkling diamond of gold across dark monolithic facades.

### 3. Additive Procedural Facade Generation
* **Zero Texture Distortion**: Scaling a wall does not stretch window decals. It additively tiles new geometric window bays while locking floor height (10 studs) and bay width (3.8 studs).
* **Flat Curtain Walls**: Fits any rectangular wall or massing block in your workspace.
* **Round Cylindrical Towers**: Generates 360-degree round glass skyscrapers using polar coordinates (such as circular hotel spires).
* **Tapered / Trapezoidal Facades**: Procedurally narrows bay counts as floors climb.

### 4. Procedural 3D Perlin Noise Occupancy
* **Room & Floor Coherence**: Instead of chaotic random noise, window states are computed using 3D continuous Perlin noise:
  $$\text{hash} = \text{math.noise}(X \times 0.06, \text{FloorId} \times 0.5, Z \times 0.06)$$
  Adjacent offices on the same floor remain lit together in natural office suites.
* **Dynamic Time-of-Day Curve**:
  * **18:15 (Dusk Rush)**: Peak occupancy (~88% of windows lit).
  * **22:00 (Evening)**: Floors wind down progressively.
  * **02:30 (Late Night)**: Drops to ~18% (cleaning crews & security).
* **Organic Micro-Events**: Subtle periodic window toggles simulate real occupants moving inside.

### 5. FAA/ICAO Rooftop Aviation Obstruction Beacons
* Synchronized 40-fpm red obstruction warning strobes across the entire city skyline using standard GPS-synchronization math.
* Smooth exponential decay pulse envelope.
* Client-side distance LOD for 60+ FPS scalability.

---

## Installation

### Option A: Roblox Studio Plugin (Recommended)
1. Download **`SkyscraperLightingPlugin.rbxmx`** from the [`dist/`](dist/SkyscraperLightingPlugin.rbxmx) folder.
2. Drop it into your local Roblox plugins directory:
   * **Windows**: `%LOCALAPPDATA%\Roblox\Plugins\`
   * **macOS**: `~/Library/Application Support/Roblox/Plugins/`
3. Restart or open Roblox Studio. The plugin panel will appear in the Studio toolbar.

### Option B: Rojo / Luau Project
1. Clone this repository or copy `src/` into your Rojo project:
   ```bash
   git clone https://github.com/HathuwstAlkan/Roblox-Skyscraper-Lighting.git
   ```
2. Build the project or plugin using Rojo:
   ```bash
   rojo build -o SkyscraperLighting.rbxl
   rojo build plugin.project.json -o dist/SkyscraperLightingPlugin.rbxmx
   ```

---

## API Reference & Code Usage

### Core Lighting Engine (`PhotorealLighting.luau`)
```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PhotorealLighting = require(ReplicatedStorage.Shared.Lighting.PhotorealLighting)

-- 1. Initialize Future Lighting Engine
PhotorealLighting.InitializeFutureEngine()

-- 2. Apply a preset ("BlueHour", "GoldenHour", "HighNoon", "NightMetropolis", "OvercastMoody")
PhotorealLighting.ApplyPreset("BlueHour", 2.0) -- optional transition duration in seconds

-- 3. Start a continuous day/night cycle (e.g. 24 real minutes per full day)
PhotorealLighting.StartDayNightCycle(24)
```

### Skyscraper Dynamic Engine (`SkyscraperLighting.luau`)
```lua
local SkyscraperLighting = require(ReplicatedStorage.Shared.Lighting.SkyscraperLighting)

-- Start the dynamic occupancy loop & synchronized beacon pulses
SkyscraperLighting.Start()

-- Procedurally generate a flat glass curtain wall facade (Width: 40, Height: 80)
local flatFacade = SkyscraperLighting.GenerateCurtainWallFacade(wallPart.CFrame, 40, 80, workspace)

-- Procedurally generate a 360-degree round glass tower (Radius: 24, Height: 80)
local roundTower = SkyscraperLighting.GenerateCylindricalFacade(CFrame.new(0, 40, 0), 24, 80, 360, workspace)

-- Style all windows in a building to Black Glass & Golden Specks
SkyscraperLighting.ApplyGoldenSpecksTheme(workspace.MyBuilding)
```

---

## Studio Plugin Toolbar Overview

| Action | Description |
| :--- | :--- |
| **Fit Curtain Wall to Selected Part** | Select any part in Studio to generate a dual-layer glass curtain wall fitted to its face, or spawn a 36x60 stud sample. |
| **Spawn Round Cylindrical Tower** | Spawns a complete 360-degree round glass skyscraper tower with dark glass and golden specks. |
| **Style: Black Glass & Golden Specks** | Converts tagged windows into dark obsidian reflective glass and glowing golden neon with tight optical bloom. |
| **Auto-Convert Selected Windows** | Scans selected model, identifies window parts by name/material/transparency, and tags them. |
| **Add Rooftop Aviation Beacon** | Detects the summit of selected building and places an FAA-standard blinking red obstruction light. |
| **Randomize Office Lights** | Re-rolls window lit/unlit patterns for instant skyline screenshots. |
| **Shader Presets** | One-click buttons for Blue Hour, Golden Hour, High Noon, Metropolis Night, and Overcast. |

---

## License
This project is licensed under the [MIT License](LICENSE).

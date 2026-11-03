class_name LightingPreset
extends Resource
## One lighting keyframe. EnvironmentController blends these by time of day
## (and blends in the overcast preset by weather amount).

@export var label := ""
@export var hour := 12.0
@export var sun_color := Color(1.0, 0.96, 0.9)
@export var sun_energy := 1.4
@export var moon_energy := 0.0
@export var moon_color := Color(0.6, 0.7, 0.95)
@export var sky_zenith := Color(0.24, 0.45, 0.78)
@export var sky_horizon := Color(0.68, 0.8, 0.9)
@export var sky_ground := Color(0.25, 0.27, 0.25)
@export var sun_halo := Color(1.0, 0.9, 0.75)
@export var ambient_energy := 1.0
@export var fog_color := Color(0.7, 0.8, 0.88)
@export var fog_density := 0.0012
@export var fog_height_density := 0.0
@export var exposure := 1.0
@export var glow_intensity := 0.5
@export var stars := 0.0
@export var saturation := 1.05
@export var contrast := 1.03
@export var warmth := 0.0
@export var wind := 0.5
@export var heat_haze := 0.0
@export var lamps := 0.0
@export var cloud_cover := 0.25

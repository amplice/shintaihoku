extends Node3D

## Day/night cycle that modulates environment lighting over time.
## Full cycle = 600 seconds (10 minutes real time).

@export var cycle_duration: float = 600.0  # seconds for full 24h cycle
@export var time_of_day: float = 22.0  # start at night (0.0 - 24.0)

var sun: DirectionalLight3D
var environment: Environment
var world_env: WorldEnvironment

# Color presets for each period
var night_bg := Color(0.03, 0.02, 0.06)
var night_ambient := Color(0.18, 0.12, 0.25)
var night_sun_color := Color(0.2, 0.15, 0.3)
var night_fog := Color(0.06, 0.03, 0.1)

var dawn_bg := Color(0.15, 0.08, 0.12)
var dawn_ambient := Color(0.4, 0.25, 0.3)
var dawn_sun_color := Color(1.0, 0.6, 0.3)
var dawn_fog := Color(0.15, 0.08, 0.1)

var day_bg := Color(0.35, 0.4, 0.5)
var day_ambient := Color(0.6, 0.6, 0.65)
var day_sun_color := Color(1.0, 0.95, 0.85)
var day_fog := Color(0.3, 0.3, 0.35)

var dusk_bg := Color(0.12, 0.05, 0.08)
var dusk_ambient := Color(0.35, 0.15, 0.2)
var dusk_sun_color := Color(1.0, 0.4, 0.15)
var dusk_fog := Color(0.12, 0.05, 0.08)

func _ready() -> void:
	# Find references in the scene
	var parent := get_parent()
	if parent:
		sun = parent.get_node_or_null("DirectionalLight3D")
		world_env = parent.get_node_or_null("WorldEnvironment")
		if world_env:
			environment = world_env.environment

func _process(delta: float) -> void:
	if not environment or not sun:
		return

	# Advance time (24h over cycle_duration seconds)
	time_of_day += (24.0 / cycle_duration) * delta
	if time_of_day >= 24.0:
		time_of_day -= 24.0

	# Determine blend between periods
	var bg_color: Color
	var ambient_color: Color
	var sun_color: Color
	var fog_color: Color
	var sun_energy: float
	var ambient_energy: float
	var vol_fog_density: float

	if time_of_day >= 21.0 or time_of_day < 5.0:
		# Night (21:00 - 5:00)
		bg_color = night_bg
		ambient_color = night_ambient
		sun_color = night_sun_color
		fog_color = night_fog
		sun_energy = 0.15
		ambient_energy = 6.0
		vol_fog_density = 0.015
	elif time_of_day < 7.0:
		# Dawn (5:00 - 7:00) -- blend from night to dawn to day
		var t := (time_of_day - 5.0) / 2.0  # 0.0 to 1.0
		bg_color = night_bg.lerp(dawn_bg, t)
		ambient_color = night_ambient.lerp(dawn_ambient, t)
		sun_color = night_sun_color.lerp(dawn_sun_color, t)
		fog_color = night_fog.lerp(dawn_fog, t)
		sun_energy = lerpf(0.15, 0.6, t)
		ambient_energy = lerpf(6.0, 4.0, t)
		vol_fog_density = lerpf(0.015, 0.008, t)
	elif time_of_day < 17.0:
		# Day (7:00 - 17:00)
		var t: float
		if time_of_day < 9.0:
			# Transition from dawn to full day (7-9)
			t = (time_of_day - 7.0) / 2.0
			bg_color = dawn_bg.lerp(day_bg, t)
			ambient_color = dawn_ambient.lerp(day_ambient, t)
			sun_color = dawn_sun_color.lerp(day_sun_color, t)
			fog_color = dawn_fog.lerp(day_fog, t)
			sun_energy = lerpf(0.6, 1.0, t)
			ambient_energy = lerpf(4.0, 3.0, t)
			vol_fog_density = lerpf(0.008, 0.005, t)
		elif time_of_day < 15.0:
			# Full day (9-15)
			bg_color = day_bg
			ambient_color = day_ambient
			sun_color = day_sun_color
			fog_color = day_fog
			sun_energy = 1.0
			ambient_energy = 3.0
			vol_fog_density = 0.005
		else:
			# Transition from day to dusk (15-17)
			t = (time_of_day - 15.0) / 2.0
			bg_color = day_bg.lerp(dusk_bg, t)
			ambient_color = day_ambient.lerp(dusk_ambient, t)
			sun_color = day_sun_color.lerp(dusk_sun_color, t)
			fog_color = day_fog.lerp(dusk_fog, t)
			sun_energy = lerpf(1.0, 0.5, t)
			ambient_energy = lerpf(3.0, 4.0, t)
			vol_fog_density = lerpf(0.005, 0.01, t)
	else:
		# Dusk (17:00 - 21:00) -- blend from dusk to night
		var t := (time_of_day - 17.0) / 4.0  # 0.0 to 1.0
		bg_color = dusk_bg.lerp(night_bg, t)
		ambient_color = dusk_ambient.lerp(night_ambient, t)
		sun_color = dusk_sun_color.lerp(night_sun_color, t)
		fog_color = dusk_fog.lerp(night_fog, t)
		sun_energy = lerpf(0.5, 0.15, t)
		ambient_energy = lerpf(4.0, 6.0, t)
		vol_fog_density = lerpf(0.01, 0.015, t)

	# Apply to environment
	environment.background_color = bg_color
	environment.ambient_light_color = ambient_color
	environment.ambient_light_energy = ambient_energy
	environment.fog_light_color = bg_color  # match fog to sky so no visible seam
	environment.fog_light_energy = 0.0

	# Apply to sun
	sun.light_color = sun_color
	sun.light_energy = sun_energy

	# Rotate sun based on time of day (arc across sky)
	# At noon (12:00) sun is highest, at midnight it's lowest
	var sun_angle := (time_of_day / 24.0) * TAU - PI * 0.5  # full rotation
	sun.rotation.x = sun_angle

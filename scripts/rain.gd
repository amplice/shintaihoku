extends GPUParticles3D

## Rain system that follows the camera with ground-level splashes.

var splash_particles: GPUParticles3D
var rain_time: float = 0.0
var base_amount: int = 0
var base_splash_amount: int = 0
var wind_gust_timer: float = 8.0
var wind_x: float = 0.0
var wind_target_x: float = 0.0

func _ready() -> void:
	_setup_splash_particles()
	base_amount = amount
	base_splash_amount = 40

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = cam.global_position + Vector3(0, 15, 0)
		if splash_particles:
			splash_particles.global_position = Vector3(cam.global_position.x, 0.05, cam.global_position.z)

	# Rain intensity variation (~60s cycle)
	rain_time += delta
	var intensity := 0.5 + 0.5 * sin(rain_time * 0.1)  # 0.0 to 1.0
	amount = int(base_amount * (0.4 + 0.6 * intensity))
	if splash_particles:
		splash_particles.amount = int(base_splash_amount * (0.3 + 0.7 * intensity))

	# Wind gusts — shift rain gravity sideways periodically
	wind_gust_timer -= delta
	if wind_gust_timer <= 0.0:
		wind_gust_timer = randf_range(6.0, 15.0)
		wind_target_x = randf_range(-4.0, 4.0)
	wind_x = lerpf(wind_x, wind_target_x, 1.5 * delta)
	# Decay wind back toward calm
	wind_target_x = lerpf(wind_target_x, 0.0, 0.3 * delta)
	var rain_mat := process_material as ParticleProcessMaterial
	if rain_mat:
		rain_mat.gravity = Vector3(wind_x, -25.0, wind_x * 0.3)

func _setup_splash_particles() -> void:
	splash_particles = GPUParticles3D.new()
	splash_particles.amount = 40
	splash_particles.lifetime = 0.4
	splash_particles.visibility_aabb = AABB(Vector3(-20, -1, -20), Vector3(40, 3, 40))

	var mat := ParticleProcessMaterial.new()
	mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mat.emission_box_extents = Vector3(15, 0, 15)
	mat.direction = Vector3(0, 1, 0)
	mat.spread = 30.0
	mat.initial_velocity_min = 1.5
	mat.initial_velocity_max = 3.0
	mat.gravity = Vector3(0, -8.0, 0)
	mat.scale_min = 0.1
	mat.scale_max = 0.25
	mat.color = Color(0.5, 0.55, 0.7, 0.2)
	splash_particles.process_material = mat

	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	splash_particles.draw_pass_1 = mesh

	get_parent().call_deferred("add_child", splash_particles)

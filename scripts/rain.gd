extends GPUParticles3D

## Rain system that follows the camera with ground-level splashes.

var splash_particles: GPUParticles3D

func _ready() -> void:
	_setup_splash_particles()

func _process(_delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam:
		global_position = cam.global_position + Vector3(0, 15, 0)
		if splash_particles:
			splash_particles.global_position = Vector3(cam.global_position.x, 0.05, cam.global_position.z)

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

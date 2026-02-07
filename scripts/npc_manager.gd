extends Node3D

## Spawns NPC pedestrians that walk along streets.

@export var num_npcs: int = 20
@export var grid_size: int = 6
@export var block_size: float = 20.0
@export var street_width: float = 8.0

var ps1_shader: Shader
var npcs: Array[Dictionary] = []
var cell_stride: float
var grid_extent: float
var stop_rng := RandomNumberGenerator.new()

# NPC outfit color palettes
var jacket_colors: Array[Color] = [
	Color(0.12, 0.12, 0.15),  # dark charcoal
	Color(0.15, 0.08, 0.2),   # dark purple
	Color(0.2, 0.1, 0.1),     # dark red
	Color(0.08, 0.12, 0.18),  # dark navy
	Color(0.18, 0.15, 0.08),  # dark olive
	Color(0.1, 0.1, 0.1),     # black
]

var accent_colors: Array[Color] = [
	Color(1.0, 0.05, 0.4),   # hot magenta
	Color(0.0, 0.9, 1.0),    # cyan
	Color(0.6, 0.0, 1.0),    # purple
	Color(1.0, 0.4, 0.0),    # orange
	Color(0.0, 1.0, 0.5),    # green
	Color(1.0, 1.0, 0.0),    # yellow
]

var skin_colors: Array[Color] = [
	Color(0.85, 0.72, 0.6),
	Color(0.72, 0.55, 0.42),
	Color(0.55, 0.38, 0.28),
	Color(0.92, 0.8, 0.7),
]

func _ready() -> void:
	ps1_shader = load("res://shaders/ps1.gdshader")
	cell_stride = block_size + street_width
	grid_extent = grid_size * cell_stride

	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	stop_rng.seed = 9999

	for i in range(num_npcs):
		_spawn_npc(rng, i)

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var cam_pos := cam.global_position if cam else Vector3.ZERO
	for npc_data in npcs:
		var node: Node3D = npc_data["node"]
		var speed: float = npc_data["speed"]
		var axis: String = npc_data["axis"]
		var direction: float = npc_data["direction"]
		var anim: HumanoidAnimation = npc_data["anim"]

		# Stop-and-look behavior
		var is_stopped: bool = npc_data["is_stopped"]
		if is_stopped:
			npc_data["stop_duration"] -= delta
			if npc_data["stop_duration"] <= 0.0:
				npc_data["is_stopped"] = false
				npc_data["stop_timer"] = stop_rng.randf_range(10.0, 30.0)
		else:
			npc_data["stop_timer"] -= delta
			if npc_data["stop_timer"] <= 0.0:
				npc_data["is_stopped"] = true
				npc_data["stop_duration"] = stop_rng.randf_range(2.0, 5.0)

		var current_speed := 0.0 if is_stopped else speed

		# Always move (even if culled, to keep positions consistent)
		if not is_stopped:
			if axis == "x":
				node.position.x += speed * direction * delta
				if node.position.x > grid_extent:
					node.position.x = -grid_extent
				elif node.position.x < -grid_extent:
					node.position.x = grid_extent
			else:
				node.position.z += speed * direction * delta
				if node.position.z > grid_extent:
					node.position.z = -grid_extent
				elif node.position.z < -grid_extent:
					node.position.z = grid_extent

		# Distance-based culling
		var dist := node.global_position.distance_to(cam_pos)
		if dist > 80.0:
			node.visible = false
			continue
		else:
			node.visible = true

		# Update walk animation (only for visible NPCs)
		anim.update(delta, current_speed)

		# Toggle cigarette smoke
		var smoke: GPUParticles3D = npc_data["smoke"]
		if smoke:
			smoke.emitting = is_stopped

func _spawn_npc(rng: RandomNumberGenerator, _index: int) -> void:
	var npc := Node3D.new()

	# Pick a street to walk on
	var axis := "x" if rng.randf() < 0.5 else "z"
	var lane_index := rng.randi_range(-grid_size, grid_size - 1)
	var lane_pos := lane_index * cell_stride + block_size * 0.5 + street_width * 0.3
	# Offset to sidewalk side
	var sidewalk_offset := rng.randf_range(-1.5, 1.5)
	var along_pos := rng.randf_range(-grid_extent, grid_extent)
	var direction := 1.0 if rng.randf() < 0.5 else -1.0
	var speed := rng.randf_range(1.5, 3.5)

	if axis == "x":
		npc.position = Vector3(along_pos, 0, lane_pos + sidewalk_offset)
		npc.rotation.y = 0.0 if direction > 0 else PI
	else:
		npc.position = Vector3(lane_pos + sidewalk_offset, 0, along_pos)
		npc.rotation.y = PI * 0.5 if direction > 0 else -PI * 0.5

	# Build humanoid model with height/build variety
	var model := Node3D.new()
	model.name = "Model"
	var height_scale := rng.randf_range(0.85, 1.15)
	model.scale = Vector3(height_scale, height_scale, height_scale)
	npc.add_child(model)

	var skin_color := skin_colors[rng.randi_range(0, skin_colors.size() - 1)]
	var jacket_color := jacket_colors[rng.randi_range(0, jacket_colors.size() - 1)]
	var pants_color := Color(jacket_color.r * 0.8, jacket_color.g * 0.8, jacket_color.b * 0.8)
	var accent := accent_colors[rng.randi_range(0, accent_colors.size() - 1)]

	# Head
	_add_body_part(model, "Head", SphereMesh.new(), Vector3(0, 1.55, 0), skin_color)
	(model.get_node("Head").mesh as SphereMesh).radius = 0.18
	(model.get_node("Head").mesh as SphereMesh).height = 0.36

	# Torso
	_add_body_part(model, "Torso", BoxMesh.new(), Vector3(0, 1.1, 0), jacket_color,
		Vector3(0.5, 0.55, 0.28))

	# Accent stripe
	_add_body_part(model, "AccentStripe", BoxMesh.new(), Vector3(0, 1.05, 0.141), accent,
		Vector3(0.3, 0.06, 0.01), true, accent, 2.0)

	# Hips
	_add_body_part(model, "Hips", BoxMesh.new(), Vector3(0, 0.75, 0), pants_color,
		Vector3(0.45, 0.2, 0.25))

	# Left arm (pivot-based)
	var left_shoulder := _add_pivot(model, "LeftShoulder", Vector3(-0.32, 1.3, 0))
	_add_body_part(left_shoulder, "LeftUpperArm", BoxMesh.new(), Vector3(0, -0.15, 0),
		jacket_color, Vector3(0.13, 0.3, 0.13))
	var left_elbow := _add_pivot(left_shoulder, "LeftElbow", Vector3(0, -0.3, 0))
	_add_body_part(left_elbow, "LeftLowerArm", BoxMesh.new(), Vector3(0, -0.15, 0),
		skin_color, Vector3(0.12, 0.3, 0.12))

	# Right arm
	var right_shoulder := _add_pivot(model, "RightShoulder", Vector3(0.32, 1.3, 0))
	_add_body_part(right_shoulder, "RightUpperArm", BoxMesh.new(), Vector3(0, -0.15, 0),
		jacket_color, Vector3(0.13, 0.3, 0.13))
	var right_elbow := _add_pivot(right_shoulder, "RightElbow", Vector3(0, -0.3, 0))
	_add_body_part(right_elbow, "RightLowerArm", BoxMesh.new(), Vector3(0, -0.15, 0),
		skin_color, Vector3(0.12, 0.3, 0.12))

	# Left leg
	var left_hip := _add_pivot(model, "LeftHip", Vector3(-0.12, 0.65, 0))
	_add_body_part(left_hip, "LeftUpperLeg", BoxMesh.new(), Vector3(0, -0.17, 0),
		pants_color, Vector3(0.15, 0.33, 0.15))
	var left_knee := _add_pivot(left_hip, "LeftKnee", Vector3(0, -0.33, 0))
	_add_body_part(left_knee, "LeftLowerLeg", BoxMesh.new(), Vector3(0, -0.17, 0),
		pants_color, Vector3(0.14, 0.33, 0.14))

	# Right leg
	var right_hip := _add_pivot(model, "RightHip", Vector3(0.12, 0.65, 0))
	_add_body_part(right_hip, "RightUpperLeg", BoxMesh.new(), Vector3(0, -0.17, 0),
		pants_color, Vector3(0.15, 0.33, 0.15))
	var right_knee := _add_pivot(right_hip, "RightKnee", Vector3(0, -0.33, 0))
	_add_body_part(right_knee, "RightLowerLeg", BoxMesh.new(), Vector3(0, -0.17, 0),
		pants_color, Vector3(0.14, 0.33, 0.14))

	# Setup animation
	var anim := HumanoidAnimation.new()
	anim.setup(model)

	# Cigarette smoke (30% of NPCs are smokers)
	var smoke_particles: GPUParticles3D = null
	if rng.randf() < 0.30:
		smoke_particles = GPUParticles3D.new()
		smoke_particles.position = Vector3(0.1, 1.6, 0.15)
		smoke_particles.amount = 8
		smoke_particles.lifetime = 2.0
		smoke_particles.emitting = false
		smoke_particles.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 3, 2))
		var smoke_mat := ParticleProcessMaterial.new()
		smoke_mat.direction = Vector3(0.2, 1, 0)
		smoke_mat.spread = 15.0
		smoke_mat.initial_velocity_min = 0.3
		smoke_mat.initial_velocity_max = 0.6
		smoke_mat.gravity = Vector3(0, 0.2, 0)
		smoke_mat.damping_min = 0.5
		smoke_mat.damping_max = 1.0
		smoke_mat.scale_min = 0.02
		smoke_mat.scale_max = 0.08
		smoke_mat.color = Color(0.6, 0.6, 0.7, 0.15)
		smoke_particles.process_material = smoke_mat
		var smoke_mesh := SphereMesh.new()
		smoke_mesh.radius = 0.04
		smoke_mesh.height = 0.08
		smoke_particles.draw_pass_1 = smoke_mesh
		model.add_child(smoke_particles)

	add_child(npc)

	npcs.append({
		"node": npc,
		"speed": speed,
		"base_speed": speed,
		"axis": axis,
		"direction": direction,
		"anim": anim,
		"stop_timer": rng.randf_range(8.0, 25.0),
		"stop_duration": 0.0,
		"is_stopped": false,
		"smoke": smoke_particles,
	})

func _add_pivot(parent: Node3D, pivot_name: String, pos: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = pivot_name
	pivot.position = pos
	parent.add_child(pivot)
	return pivot

func _add_body_part(parent: Node3D, part_name: String, mesh: Mesh, pos: Vector3,
		color: Color, box_size: Vector3 = Vector3.ZERO, is_emissive: bool = false,
		emit_color: Color = Color.BLACK, emit_strength: float = 0.0) -> void:
	var mi := MeshInstance3D.new()
	mi.name = part_name
	mi.mesh = mesh
	mi.position = pos

	if mesh is BoxMesh and box_size != Vector3.ZERO:
		(mesh as BoxMesh).size = box_size

	var mat := ShaderMaterial.new()
	mat.shader = ps1_shader
	mat.set_shader_parameter("albedo_color", color)
	mat.set_shader_parameter("vertex_snap_intensity", 4.0)
	mat.set_shader_parameter("color_depth", 12.0)
	mat.set_shader_parameter("fog_color", Color(0.05, 0.03, 0.1, 1.0))
	mat.set_shader_parameter("fog_distance", 100.0)
	mat.set_shader_parameter("fog_density", 0.3)
	if is_emissive:
		mat.set_shader_parameter("emissive", true)
		mat.set_shader_parameter("emission_color", emit_color)
		mat.set_shader_parameter("emission_strength", emit_strength)
	mi.set_surface_override_material(0, mat)

	parent.add_child(mi)

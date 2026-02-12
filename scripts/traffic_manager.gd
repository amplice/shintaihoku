extends Node3D

## Manages moving ground cars and flying cars along the street grid.

@export var num_ground_cars: int = 15
@export var num_flying_cars: int = 6
@export var grid_size: int = 3
@export var block_size: float = 20.0
@export var street_width: float = 8.0

var ps1_shader: Shader
var ground_cars: Array[Dictionary] = []
var flying_cars: Array[Dictionary] = []
var cell_stride: float
var grid_extent: float  # half-size of the entire grid in world units

const ENGINE_HUM_POOL_SIZE: int = 4
const ENGINE_HUM_RANGE: float = 40.0

var engine_hum_pool: Array[Dictionary] = []
var hum_rng := RandomNumberGenerator.new()

const HORN_POOL_SIZE: int = 2
var horn_pool: Array[Dictionary] = []
var horn_timer: float = 0.0
var horn_rng := RandomNumberGenerator.new()

var car_colors: Array[Color] = [
	Color(0.15, 0.15, 0.18),  # dark gray
	Color(0.18, 0.1, 0.25),   # dark purple
	Color(0.25, 0.08, 0.08),  # dark red
	Color(0.08, 0.18, 0.18),  # dark teal
	Color(0.12, 0.12, 0.12),  # charcoal
	Color(0.7, 0.6, 0.1),    # taxi yellow
]

func _ready() -> void:
	ps1_shader = load("res://shaders/ps1.gdshader")
	cell_stride = block_size + street_width
	grid_extent = grid_size * cell_stride

	var rng := RandomNumberGenerator.new()
	rng.seed = 777

	# Spawn ground cars
	for i in range(num_ground_cars):
		_spawn_ground_car(rng, i)

	# Spawn flying cars
	for i in range(num_flying_cars):
		_spawn_flying_car(rng, i)

	# Setup engine hum audio pool
	hum_rng.seed = 8888
	for i in range(ENGINE_HUM_POOL_SIZE):
		var player := AudioStreamPlayer3D.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.1
		player.stream = gen
		player.volume_db = -14.0
		player.max_distance = ENGINE_HUM_RANGE
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 8.0
		add_child(player)
		player.play()
		var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
		engine_hum_pool.append({
			"player": player,
			"playback": playback,
			"phase": 0.0,
			"target_car": null,
			"base_freq": 55.0 + float(i) * 8.0,  # slight freq variation per slot
		})

	# Setup horn audio pool
	horn_rng.seed = 6666
	horn_timer = horn_rng.randf_range(10.0, 30.0)
	for i in range(HORN_POOL_SIZE):
		var player := AudioStreamPlayer3D.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.15
		player.stream = gen
		player.volume_db = -6.0
		player.max_distance = 50.0
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 10.0
		add_child(player)
		player.play()
		var playback: AudioStreamGeneratorPlayback = player.get_stream_playback()
		horn_pool.append({
			"player": player,
			"playback": playback,
			"phase": 0.0,
			"active": false,
			"remaining": 0.0,
			"freq": 280.0 + float(i) * 40.0,
		})

func _process(delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0

	# Move ground cars
	for car_data in ground_cars:
		var node: Node3D = car_data["node"]
		var speed: float = car_data["speed"]
		var axis: String = car_data["axis"]
		var direction: float = car_data["direction"]

		if axis == "x":
			node.position.x += speed * direction * delta
			# Wrap at grid edges
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

	# Move flying cars
	for car_data in flying_cars:
		var node: Node3D = car_data["node"]
		var speed: float = car_data["speed"]
		var axis: String = car_data["axis"]
		var direction: float = car_data["direction"]
		var base_y: float = car_data["base_y"]
		var index: int = car_data["index"]

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

		# Gentle hover oscillation
		node.position.y = base_y + sin(time * 2.0 + float(index)) * 0.3

	# Engine hum: assign pool slots to nearest cars
	var cam := get_viewport().get_camera_3d()
	if cam:
		var cam_pos := cam.global_position
		# Collect all cars with distances
		var all_cars: Array[Dictionary] = []
		for gc in ground_cars:
			var gc_node: Node3D = gc["node"]
			var d := gc_node.global_position.distance_to(cam_pos)
			if d < ENGINE_HUM_RANGE:
				all_cars.append({"node": gc_node, "dist": d, "speed": gc["speed"], "flying": false})
		for fc in flying_cars:
			var fc_node: Node3D = fc["node"]
			var d := fc_node.global_position.distance_to(cam_pos)
			if d < ENGINE_HUM_RANGE:
				all_cars.append({"node": fc_node, "dist": d, "speed": fc["speed"], "flying": true})
		# Sort by distance (closest first)
		all_cars.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["dist"] < b["dist"])
		# Assign pool slots
		for i in range(ENGINE_HUM_POOL_SIZE):
			var slot: Dictionary = engine_hum_pool[i]
			if i < all_cars.size():
				var car_info: Dictionary = all_cars[i]
				var player3d: AudioStreamPlayer3D = slot["player"]
				var ci_node: Node3D = car_info["node"]
				player3d.global_position = ci_node.global_position
				# Fill hum buffer
				var pb: AudioStreamGeneratorPlayback = slot["playback"]
				if pb:
					var frames := pb.get_frames_available()
					var base_freq: float = slot["base_freq"]
					var car_speed: float = car_info["speed"]
					var is_flying: bool = car_info["flying"]
					var phase: float = slot["phase"]
					for _f in range(frames):
						phase += 1.0 / 22050.0
						var sample: float
						if is_flying:
							# Higher whine for flying cars
							sample = sin(phase * (base_freq * 3.0) * TAU) * 0.15
							sample += sin(phase * (base_freq * 4.5) * TAU) * 0.08
							sample += hum_rng.randf_range(-0.02, 0.02)
						else:
							# Low rumble for ground cars
							var rpm_factor := car_speed / 15.0
							sample = sin(phase * base_freq * rpm_factor * TAU) * 0.25
							sample += sin(phase * base_freq * 2.0 * rpm_factor * TAU) * 0.12
							sample += sin(phase * base_freq * 3.0 * rpm_factor * TAU) * 0.05
							sample += hum_rng.randf_range(-0.03, 0.03)
						sample *= 0.4
						if pb.can_push_buffer(1):
							pb.push_frame(Vector2(sample, sample))
					slot["phase"] = phase
			else:
				# No car for this slot, push silence
				var pb: AudioStreamGeneratorPlayback = slot["playback"]
				if pb:
					var frames := pb.get_frames_available()
					for _f in range(frames):
						if pb.can_push_buffer(1):
							pb.push_frame(Vector2.ZERO)

	# Horn honks: occasional honk from a random nearby ground car
	horn_timer -= delta
	if horn_timer <= 0.0 and cam:
		horn_timer = horn_rng.randf_range(15.0, 45.0)
		# Find a ground car within earshot
		var best_car: Node3D = null
		var best_dist := 999.0
		for gc in ground_cars:
			var gc_n: Node3D = gc["node"]
			var d := gc_n.global_position.distance_to(cam.global_position)
			if d < 50.0 and d < best_dist:
				best_dist = d
				best_car = gc_n
		if best_car:
			# Find an available horn slot
			for slot in horn_pool:
				if not slot["active"]:
					slot["active"] = true
					slot["remaining"] = horn_rng.randf_range(0.15, 0.4)
					slot["phase"] = 0.0
					slot["freq"] = horn_rng.randf_range(250.0, 400.0)
					var hp: AudioStreamPlayer3D = slot["player"]
					hp.global_position = best_car.global_position
					break

	# Fill horn buffers
	for slot in horn_pool:
		var pb: AudioStreamGeneratorPlayback = slot["playback"]
		if not pb:
			continue
		var frames := pb.get_frames_available()
		if slot["active"]:
			slot["remaining"] -= delta
			if slot["remaining"] <= 0.0:
				slot["active"] = false
			var freq: float = slot["freq"]
			var phase: float = slot["phase"]
			for _f in range(frames):
				phase += 1.0 / 22050.0
				var sample := sin(phase * freq * TAU) * 0.3
				sample += sin(phase * freq * 1.5 * TAU) * 0.15
				sample += sin(phase * freq * 2.0 * TAU) * 0.08
				if pb.can_push_buffer(1):
					pb.push_frame(Vector2(sample, sample))
			slot["phase"] = phase
		else:
			for _f in range(frames):
				if pb.can_push_buffer(1):
					pb.push_frame(Vector2.ZERO)

func _spawn_ground_car(rng: RandomNumberGenerator, _index: int) -> void:
	var car := _build_ground_car_mesh(rng)

	# Pick a street lane
	var axis := "x" if rng.randf() < 0.5 else "z"
	var lane_index := rng.randi_range(-grid_size, grid_size - 1)
	var lane_pos := lane_index * cell_stride + block_size * 0.5 + street_width * 0.5
	var along_pos := rng.randf_range(-grid_extent, grid_extent)
	var direction := 1.0 if rng.randf() < 0.5 else -1.0
	var speed := rng.randf_range(8.0, 15.0)

	if axis == "x":
		car.position = Vector3(along_pos, 0, lane_pos)
		car.rotation.y = 0.0 if direction > 0 else PI
	else:
		car.position = Vector3(lane_pos, 0, along_pos)
		car.rotation.y = PI * 0.5 if direction > 0 else -PI * 0.5

	add_child(car)

	ground_cars.append({
		"node": car,
		"speed": speed,
		"axis": axis,
		"direction": direction,
	})

func _spawn_flying_car(rng: RandomNumberGenerator, index: int) -> void:
	var car := _build_flying_car_mesh(rng)

	var axis := "x" if rng.randf() < 0.5 else "z"
	var base_y := rng.randf_range(25.0, 60.0)
	var lateral_pos := rng.randf_range(-grid_extent * 0.8, grid_extent * 0.8)
	var along_pos := rng.randf_range(-grid_extent, grid_extent)
	var direction := 1.0 if rng.randf() < 0.5 else -1.0
	var speed := rng.randf_range(12.0, 25.0)

	if axis == "x":
		car.position = Vector3(along_pos, base_y, lateral_pos)
		car.rotation.y = 0.0 if direction > 0 else PI
	else:
		car.position = Vector3(lateral_pos, base_y, along_pos)
		car.rotation.y = PI * 0.5 if direction > 0 else -PI * 0.5

	add_child(car)

	flying_cars.append({
		"node": car,
		"speed": speed,
		"axis": axis,
		"direction": direction,
		"base_y": base_y,
		"index": index,
	})

func _make_ps1_material(color: Color, is_emissive: bool = false,
		emit_color: Color = Color.BLACK, emit_strength: float = 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = ps1_shader
	mat.set_shader_parameter("albedo_color", color)
	mat.set_shader_parameter("vertex_snap_intensity", 1.0)
	mat.set_shader_parameter("color_depth", 12.0)
	mat.set_shader_parameter("fog_color", Color(0.05, 0.03, 0.1, 1.0))
	mat.set_shader_parameter("fog_distance", 100.0)
	mat.set_shader_parameter("fog_density", 0.3)
	if is_emissive:
		mat.set_shader_parameter("emissive", true)
		mat.set_shader_parameter("emission_color", emit_color)
		mat.set_shader_parameter("emission_strength", emit_strength)
	return mat

func _build_ground_car_mesh(rng: RandomNumberGenerator) -> Node3D:
	var car := Node3D.new()

	# Pick color
	var color_idx := rng.randi_range(0, car_colors.size() - 1)
	if color_idx == car_colors.size() - 1 and rng.randf() > 0.15:
		color_idx = rng.randi_range(0, car_colors.size() - 2)
	var car_color := car_colors[color_idx]
	var car_mat := _make_ps1_material(car_color)

	# Body
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(3.5, 1.0, 1.8)
	body.mesh = body_mesh
	body.position = Vector3(0, 0.5, 0)
	body.set_surface_override_material(0, car_mat)
	car.add_child(body)

	# Cabin
	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.8, 0.7, 1.6)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(-0.2, 1.2, 0)
	cabin.set_surface_override_material(0, _make_ps1_material(car_color * 0.6))
	car.add_child(cabin)

	# Wheels
	var wheel_positions := [
		Vector3(1.1, 0.3, 0.85), Vector3(1.1, 0.3, -0.85),
		Vector3(-1.1, 0.3, 0.85), Vector3(-1.1, 0.3, -0.85),
	]
	var wheel_mat := _make_ps1_material(Color(0.05, 0.05, 0.05))
	for wp in wheel_positions:
		var wheel := MeshInstance3D.new()
		var wheel_mesh := CylinderMesh.new()
		wheel_mesh.top_radius = 0.3
		wheel_mesh.bottom_radius = 0.3
		wheel_mesh.height = 0.2
		wheel.mesh = wheel_mesh
		wheel.position = wp
		wheel.rotation.x = PI * 0.5
		wheel.set_surface_override_material(0, wheel_mat)
		car.add_child(wheel)

	# Tail lights (always on for moving cars)
	var tail_color := Color(1.0, 0.0, 0.0)
	for side in [-0.5, 0.5]:
		var tl := MeshInstance3D.new()
		var tl_mesh := BoxMesh.new()
		tl_mesh.size = Vector3(0.05, 0.2, 0.3)
		tl.mesh = tl_mesh
		tl.position = Vector3(-1.76, 0.5, side)
		tl.set_surface_override_material(0,
			_make_ps1_material(tail_color * 0.5, true, tail_color, 2.5))
		car.add_child(tl)

	# Headlights (always on for moving cars)
	var headlight_color := Color(1.0, 0.95, 0.8)
	for side in [-0.5, 0.5]:
		var hl := MeshInstance3D.new()
		var hl_mesh := BoxMesh.new()
		hl_mesh.size = Vector3(0.05, 0.2, 0.3)
		hl.mesh = hl_mesh
		hl.position = Vector3(1.76, 0.5, side)
		hl.set_surface_override_material(0,
			_make_ps1_material(headlight_color * 0.5, true, headlight_color, 2.5))
		car.add_child(hl)

	# Headlight beam (actual light)
	var beam := OmniLight3D.new()
	beam.light_color = Color(1.0, 0.95, 0.8)
	beam.light_energy = 2.0
	beam.omni_range = 12.0
	beam.omni_attenuation = 1.5
	beam.shadow_enabled = false
	beam.position = Vector3(2.5, 0.5, 0)
	car.add_child(beam)

	# Tire spray particles (wet road mist behind rear wheels)
	for spray_side in [-0.9, 0.9]:
		var spray := GPUParticles3D.new()
		spray.amount = 8
		spray.lifetime = 0.5
		spray.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 3, 6))
		var spray_mat := ParticleProcessMaterial.new()
		spray_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		spray_mat.emission_box_extents = Vector3(0.1, 0, 0.1)
		spray_mat.direction = Vector3(-1, 0.5, 0)  # spray backward and up
		spray_mat.spread = 25.0
		spray_mat.initial_velocity_min = 2.0
		spray_mat.initial_velocity_max = 4.0
		spray_mat.gravity = Vector3(0, -3.0, 0)
		spray_mat.damping_min = 1.0
		spray_mat.damping_max = 2.0
		spray_mat.scale_min = 0.05
		spray_mat.scale_max = 0.15
		spray_mat.color = Color(0.5, 0.55, 0.65, 0.12)
		spray.process_material = spray_mat
		var spray_mesh := SphereMesh.new()
		spray_mesh.radius = 0.05
		spray_mesh.height = 0.1
		spray.draw_pass_1 = spray_mesh
		spray.position = Vector3(-1.1, 0.15, spray_side)
		car.add_child(spray)

	return car

func _build_flying_car_mesh(rng: RandomNumberGenerator) -> Node3D:
	var car := Node3D.new()

	var car_color := car_colors[rng.randi_range(0, car_colors.size() - 2)]
	var car_mat := _make_ps1_material(car_color)

	# Flatter body (no wheels, no cabin -- sleeker)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(4.0, 0.6, 2.0)
	body.mesh = body_mesh
	body.position = Vector3(0, 0, 0)
	body.set_surface_override_material(0, car_mat)
	car.add_child(body)

	# Canopy (low-profile cockpit)
	var canopy := MeshInstance3D.new()
	var canopy_mesh := BoxMesh.new()
	canopy_mesh.size = Vector3(1.5, 0.4, 1.4)
	canopy.mesh = canopy_mesh
	canopy.position = Vector3(0.3, 0.5, 0)
	canopy.set_surface_override_material(0,
		_make_ps1_material(Color(0.1, 0.15, 0.2)))
	car.add_child(canopy)

	# Underbody glow light
	var glow_colors: Array[Color] = [Color(0.0, 0.9, 1.0), Color(1.0, 0.4, 0.0), Color(0.6, 0.0, 1.0)]
	var glow_col: Color = glow_colors[rng.randi_range(0, glow_colors.size() - 1)]

	var glow_light := OmniLight3D.new()
	glow_light.light_color = glow_col
	glow_light.light_energy = 2.0
	glow_light.omni_range = 8.0
	glow_light.omni_attenuation = 1.5
	glow_light.shadow_enabled = false
	glow_light.position = Vector3(0, -0.5, 0)
	car.add_child(glow_light)

	# Underbody emissive strip
	var glow_strip := MeshInstance3D.new()
	var glow_mesh := BoxMesh.new()
	glow_mesh.size = Vector3(3.0, 0.05, 1.5)
	glow_strip.mesh = glow_mesh
	glow_strip.position = Vector3(0, -0.32, 0)
	glow_strip.set_surface_override_material(0,
		_make_ps1_material(glow_col * 0.3, true, glow_col, 4.0))
	car.add_child(glow_strip)

	# Tail lights
	var tail_color := Color(1.0, 0.0, 0.0)
	for side in [-0.6, 0.6]:
		var tl := MeshInstance3D.new()
		var tl_mesh := BoxMesh.new()
		tl_mesh.size = Vector3(0.05, 0.15, 0.3)
		tl.mesh = tl_mesh
		tl.position = Vector3(-2.0, 0, side)
		tl.set_surface_override_material(0,
			_make_ps1_material(tail_color * 0.5, true, tail_color, 3.0))
		car.add_child(tl)

	# Engine contrail particles
	var trail := GPUParticles3D.new()
	trail.position = Vector3(-2.5, -0.2, 0)
	trail.amount = 15
	trail.lifetime = 1.5
	trail.visibility_aabb = AABB(Vector3(-15, -3, -3), Vector3(30, 6, 6))
	var trail_mat := ParticleProcessMaterial.new()
	trail_mat.direction = Vector3(-1, 0, 0)
	trail_mat.spread = 10.0
	trail_mat.initial_velocity_min = 2.0
	trail_mat.initial_velocity_max = 4.0
	trail_mat.gravity = Vector3(0, 0.2, 0)
	trail_mat.damping_min = 1.0
	trail_mat.damping_max = 2.0
	trail_mat.scale_min = 0.1
	trail_mat.scale_max = 0.4
	trail_mat.color = Color(glow_col.r, glow_col.g, glow_col.b, 0.15)
	trail.process_material = trail_mat
	var trail_mesh := BoxMesh.new()
	trail_mesh.size = Vector3(0.15, 0.15, 0.15)
	trail.draw_pass_1 = trail_mesh
	car.add_child(trail)

	return car

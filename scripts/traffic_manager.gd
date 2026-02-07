extends Node3D

## Manages moving ground cars and flying cars along the street grid.

@export var num_ground_cars: int = 25
@export var num_flying_cars: int = 12
@export var grid_size: int = 6
@export var block_size: float = 20.0
@export var street_width: float = 8.0

var ps1_shader: Shader
var ground_cars: Array[Dictionary] = []
var flying_cars: Array[Dictionary] = []
var cell_stride: float
var grid_extent: float  # half-size of the entire grid in world units

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
	mat.set_shader_parameter("vertex_snap_intensity", 4.0)
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

	return car

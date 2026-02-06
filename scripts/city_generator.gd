extends Node3D

## Procedurally generates a grid of cyberpunk buildings with emissive windows and neon signs.

@export var grid_size: int = 8
@export var block_size: float = 20.0
@export var street_width: float = 8.0
@export var min_height: float = 10.0
@export var max_height: float = 40.0
@export var min_width: float = 6.0
@export var max_width: float = 14.0

var ps1_shader: Shader
var neon_colors := [
	Color(1.0, 0.05, 0.4),   # hot magenta
	Color(0.0, 0.9, 1.0),    # cyan
	Color(0.6, 0.0, 1.0),    # purple
	Color(1.0, 0.4, 0.0),    # orange
	Color(0.0, 1.0, 0.5),    # green neon
	Color(1.0, 0.0, 0.1),    # red
]

func _ready() -> void:
	ps1_shader = load("res://shaders/ps1.gdshader")
	_generate_city()

func _generate_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # deterministic for now

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			var cell_x := gx * (block_size + street_width)
			var cell_z := gz * (block_size + street_width)

			# 1-3 buildings per block
			var num_buildings := rng.randi_range(1, 3)
			for b in range(num_buildings):
				var bw := rng.randf_range(min_width, max_width)
				var bd := rng.randf_range(min_width, max_width)
				var bh := rng.randf_range(min_height, max_height)

				var offset_x := rng.randf_range(-block_size * 0.3, block_size * 0.3)
				var offset_z := rng.randf_range(-block_size * 0.3, block_size * 0.3)

				var pos := Vector3(cell_x + offset_x, bh * 0.5, cell_z + offset_z)
				_create_building(pos, Vector3(bw, bh, bd), rng)

func _create_building(pos: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
	# Main building body
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = pos

	# Dark concrete material with PS1 shader
	var mat := ShaderMaterial.new()
	mat.shader = ps1_shader
	var darkness := rng.randf_range(0.08, 0.18)
	mat.set_shader_parameter("albedo_color", Color(darkness, darkness, darkness + 0.02, 1.0))
	mat.set_shader_parameter("vertex_snap_intensity", 4.0)
	mat.set_shader_parameter("color_depth", 12.0)
	mat.set_shader_parameter("fog_color", Color(0.02, 0.02, 0.08, 1.0))
	mat.set_shader_parameter("fog_distance", 80.0)
	mat.set_shader_parameter("fog_density", 1.2)
	mesh_instance.set_surface_override_material(0, mat)

	# Static body for collision
	var static_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var col_shape := BoxShape3D.new()
	col_shape.size = size
	collision.shape = col_shape
	static_body.add_child(collision)
	mesh_instance.add_child(static_body)

	add_child(mesh_instance)

	# Emissive windows - scattered quads on building faces
	_add_windows(mesh_instance, size, rng)

	# Sometimes add a neon sign
	if rng.randf() < 0.35:
		_add_neon_sign(mesh_instance, size, rng)

func _add_windows(building: MeshInstance3D, size: Vector3, rng: RandomNumberGenerator) -> void:
	var window_color := Color(0.9, 0.8, 0.5)  # warm interior light
	var cold_color := Color(0.4, 0.6, 0.9)     # cold blue screens

	# Window grid on front and back faces (Z axis)
	for face in [1.0, -1.0]:
		var num_cols := int(size.x / 2.5)
		var num_rows := int(size.y / 3.5)
		for col in range(num_cols):
			for row in range(num_rows):
				if rng.randf() > 0.6:  # 60% of windows are dark
					continue
				var win := MeshInstance3D.new()
				var quad := QuadMesh.new()
				quad.size = Vector2(1.2, 1.5)
				win.mesh = quad

				var wx := -size.x * 0.5 + (col + 0.5) * (size.x / float(num_cols))
				var wy := -size.y * 0.5 + (row + 0.5) * (size.y / float(num_rows))
				win.position = Vector3(wx, wy, face * size.z * 0.501)
				if face < 0:
					win.rotation.y = PI

				var win_mat := ShaderMaterial.new()
				win_mat.shader = ps1_shader
				var wc := cold_color if rng.randf() > 0.5 else window_color
				win_mat.set_shader_parameter("albedo_color", wc * 0.3)
				win_mat.set_shader_parameter("emissive", true)
				win_mat.set_shader_parameter("emission_color", wc)
				win_mat.set_shader_parameter("emission_strength", rng.randf_range(1.5, 3.5))
				win_mat.set_shader_parameter("vertex_snap_intensity", 4.0)
				win_mat.set_shader_parameter("color_depth", 12.0)
				win_mat.set_shader_parameter("fog_color", Color(0.02, 0.02, 0.08, 1.0))
				win_mat.set_shader_parameter("fog_distance", 80.0)
				win_mat.set_shader_parameter("fog_density", 1.2)
				win.set_surface_override_material(0, win_mat)
				building.add_child(win)

	# Windows on side faces (X axis)
	for face in [1.0, -1.0]:
		var num_cols := int(size.z / 2.5)
		var num_rows := int(size.y / 3.5)
		for col in range(num_cols):
			for row in range(num_rows):
				if rng.randf() > 0.6:
					continue
				var win := MeshInstance3D.new()
				var quad := QuadMesh.new()
				quad.size = Vector2(1.2, 1.5)
				win.mesh = quad

				var wz := -size.z * 0.5 + (col + 0.5) * (size.z / float(num_cols))
				var wy := -size.y * 0.5 + (row + 0.5) * (size.y / float(num_rows))
				win.position = Vector3(face * size.x * 0.501, wy, wz)
				win.rotation.y = PI * 0.5
				if face < 0:
					win.rotation.y = -PI * 0.5

				var win_mat := ShaderMaterial.new()
				win_mat.shader = ps1_shader
				var wc := cold_color if rng.randf() > 0.5 else window_color
				win_mat.set_shader_parameter("albedo_color", wc * 0.3)
				win_mat.set_shader_parameter("emissive", true)
				win_mat.set_shader_parameter("emission_color", wc)
				win_mat.set_shader_parameter("emission_strength", rng.randf_range(1.5, 3.5))
				win_mat.set_shader_parameter("vertex_snap_intensity", 4.0)
				win_mat.set_shader_parameter("color_depth", 12.0)
				win_mat.set_shader_parameter("fog_color", Color(0.02, 0.02, 0.08, 1.0))
				win_mat.set_shader_parameter("fog_distance", 80.0)
				win_mat.set_shader_parameter("fog_density", 1.2)
				win.set_surface_override_material(0, win_mat)
				building.add_child(win)

func _add_neon_sign(building: MeshInstance3D, size: Vector3, rng: RandomNumberGenerator) -> void:
	var sign_mesh := MeshInstance3D.new()
	var quad := QuadMesh.new()
	var sign_w := rng.randf_range(2.0, 5.0)
	var sign_h := rng.randf_range(0.8, 2.0)
	quad.size = Vector2(sign_w, sign_h)
	sign_mesh.mesh = quad

	# Place on a random face
	var face_choice := rng.randi_range(0, 3)
	match face_choice:
		0:  # front
			sign_mesh.position = Vector3(
				rng.randf_range(-size.x * 0.3, size.x * 0.3),
				rng.randf_range(-size.y * 0.1, size.y * 0.2),
				size.z * 0.502
			)
		1:  # back
			sign_mesh.position = Vector3(
				rng.randf_range(-size.x * 0.3, size.x * 0.3),
				rng.randf_range(-size.y * 0.1, size.y * 0.2),
				-size.z * 0.502
			)
			sign_mesh.rotation.y = PI
		2:  # right
			sign_mesh.position = Vector3(
				size.x * 0.502,
				rng.randf_range(-size.y * 0.1, size.y * 0.2),
				rng.randf_range(-size.z * 0.3, size.z * 0.3)
			)
			sign_mesh.rotation.y = PI * 0.5
		3:  # left
			sign_mesh.position = Vector3(
				-size.x * 0.502,
				rng.randf_range(-size.y * 0.1, size.y * 0.2),
				rng.randf_range(-size.z * 0.3, size.z * 0.3)
			)
			sign_mesh.rotation.y = -PI * 0.5

	var neon_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]

	var sign_mat := ShaderMaterial.new()
	sign_mat.shader = ps1_shader
	sign_mat.set_shader_parameter("albedo_color", neon_col * 0.5)
	sign_mat.set_shader_parameter("emissive", true)
	sign_mat.set_shader_parameter("emission_color", neon_col)
	sign_mat.set_shader_parameter("emission_strength", rng.randf_range(3.0, 6.0))
	sign_mat.set_shader_parameter("vertex_snap_intensity", 4.0)
	sign_mat.set_shader_parameter("color_depth", 12.0)
	sign_mat.set_shader_parameter("fog_color", Color(0.02, 0.02, 0.08, 1.0))
	sign_mat.set_shader_parameter("fog_distance", 80.0)
	sign_mat.set_shader_parameter("fog_density", 1.2)
	sign_mesh.set_surface_override_material(0, sign_mat)

	# Add OmniLight3D near the neon sign for local glow
	var light := OmniLight3D.new()
	light.light_color = neon_col
	light.light_energy = rng.randf_range(1.5, 3.0)
	light.omni_range = rng.randf_range(6.0, 12.0)
	light.omni_attenuation = 1.5
	light.shadow_enabled = false
	light.position = Vector3(0, 0, 0.5)
	sign_mesh.add_child(light)

	building.add_child(sign_mesh)

extends Node3D

## Procedurally generates a grid of cyberpunk buildings with emissive windows and neon signs.

@export var grid_size: int = 6
@export var block_size: float = 20.0
@export var street_width: float = 8.0
@export var min_height: float = 10.0
@export var max_height: float = 40.0
@export var min_width: float = 6.0
@export var max_width: float = 14.0

var ps1_shader: Shader
var neon_font: Font
var neon_colors: Array[Color] = [
	Color(1.0, 0.05, 0.4),   # hot magenta
	Color(0.0, 0.9, 1.0),    # cyan
	Color(0.6, 0.0, 1.0),    # purple
	Color(1.0, 0.4, 0.0),    # orange
	Color(0.0, 1.0, 0.5),    # green neon
	Color(1.0, 0.0, 0.1),    # red
]

# Kanji/compound words for neon signs
const NEON_TEXTS: Array[String] = [
	"龍", "夜", "雨", "影", "薬局", "酒場", "警察",
	"刀", "鬼", "闇", "霧", "星", "風", "火",
	"電脳", "未来", "危険", "禁止", "出口", "入口",
	"歌舞伎", "新宿", "渋谷", "秋葉原", "新体北",
	"ラーメン", "カラオケ", "ホテル", "バー", "クラブ",
	"サイバー", "ネオン", "パチンコ",
]

func _ready() -> void:
	ps1_shader = load("res://shaders/ps1.gdshader")
	# Load CJK font for kanji neon signs
	var font_path := "res://fonts/NotoSansJP-Bold.ttf"
	if ResourceLoader.exists(font_path):
		neon_font = load(font_path)
	else:
		neon_font = null
		print("CityGenerator: CJK font not found, using quad-only neon signs")
	print("CityGenerator: starting generation with grid_size=", grid_size)
	_generate_city()
	_generate_cars()
	_generate_street_lights()
	_generate_puddles()
	_generate_steam_vents()
	print("CityGenerator: generation complete, total children=", get_child_count())

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
	# Check if this building qualifies as an enterable storefront
	var is_storefront := size.y < 20.0 and size.x > 8.0 and rng.randf() < 0.18
	if is_storefront:
		_create_storefront(pos, size, rng)
		return

	# Main building body
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = pos

	# Dark concrete material with PS1 shader
	var darkness := rng.randf_range(0.3, 0.5)
	mesh_instance.set_surface_override_material(0,
		_make_ps1_material(Color(darkness, darkness, darkness + 0.05, 1.0)))

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

	# Add 1-2 neon signs per building
	var num_signs := rng.randi_range(1, 2)
	for _s in range(num_signs):
		if rng.randf() < 0.7:
			_add_neon_sign(mesh_instance, size, rng)

	# Tall buildings (>25) get a large vertical sign (Blade Runner style)
	if size.y > 25.0 and neon_font and rng.randf() < 0.4:
		_add_vertical_neon_sign(mesh_instance, size, rng)

func _create_storefront(pos: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
	var building := Node3D.new()
	building.position = pos

	var w := size.x
	var h := size.y
	var d := size.z
	var half_w := w * 0.5
	var half_h := h * 0.5
	var half_d := d * 0.5
	var wall_thickness := 0.3
	var door_width := 2.0
	var door_height := 3.0

	var darkness := rng.randf_range(0.3, 0.5)
	var wall_color := Color(darkness, darkness, darkness + 0.05, 1.0)
	var wall_mat := _make_ps1_material(wall_color)
	var floor_mat := _make_ps1_material(Color(0.2, 0.18, 0.15))

	# Back wall (full, -Z side)
	_add_wall(building, Vector3(0, 0, -half_d + wall_thickness * 0.5),
		Vector3(w, h, wall_thickness), wall_mat)

	# Left wall (full, -X side)
	_add_wall(building, Vector3(-half_w + wall_thickness * 0.5, 0, 0),
		Vector3(wall_thickness, h, d), wall_mat)

	# Right wall (full, +X side)
	_add_wall(building, Vector3(half_w - wall_thickness * 0.5, 0, 0),
		Vector3(wall_thickness, h, d), wall_mat)

	# Front wall with door opening (+Z side, door centered)
	# Left section of front wall
	var left_front_w := (w - door_width) * 0.5
	_add_wall(building, Vector3(-half_w + left_front_w * 0.5, 0, half_d - wall_thickness * 0.5),
		Vector3(left_front_w, h, wall_thickness), wall_mat)

	# Right section of front wall
	_add_wall(building, Vector3(half_w - left_front_w * 0.5, 0, half_d - wall_thickness * 0.5),
		Vector3(left_front_w, h, wall_thickness), wall_mat)

	# Top section above door
	var top_section_h := h - door_height
	if top_section_h > 0.1:
		_add_wall(building, Vector3(0, half_h - top_section_h * 0.5, half_d - wall_thickness * 0.5),
			Vector3(door_width, top_section_h, wall_thickness), wall_mat)

	# Ceiling
	_add_wall(building, Vector3(0, half_h - wall_thickness * 0.5, 0),
		Vector3(w, wall_thickness, d), wall_mat)

	# Interior floor (slightly above ground to avoid z-fighting)
	_add_wall(building, Vector3(0, -half_h + 0.05, 0),
		Vector3(w - wall_thickness * 2, 0.1, d - wall_thickness * 2), floor_mat)

	# Interior warm light
	var interior_light := OmniLight3D.new()
	interior_light.light_color = Color(1.0, 0.85, 0.6)
	interior_light.light_energy = 1.5
	interior_light.omni_range = maxf(w, d) * 0.7
	interior_light.omni_attenuation = 1.5
	interior_light.shadow_enabled = false
	interior_light.position = Vector3(0, half_h - 1.0, 0)
	building.add_child(interior_light)

	# Door spill light -- warm light that spills out onto the street
	var spill_light := OmniLight3D.new()
	spill_light.light_color = Color(1.0, 0.85, 0.6)
	spill_light.light_energy = 3.0
	spill_light.omni_range = 8.0
	spill_light.omni_attenuation = 1.5
	spill_light.shadow_enabled = false
	spill_light.position = Vector3(0, -half_h + door_height * 0.5, half_d + 1.0)
	building.add_child(spill_light)

	# Emissive awning above door -- thin neon-colored box as visual beacon
	var awning_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
	var awning := MeshInstance3D.new()
	var awning_mesh := BoxMesh.new()
	awning_mesh.size = Vector3(door_width + 1.0, 0.12, 0.8)
	awning.mesh = awning_mesh
	awning.position = Vector3(0, -half_h + door_height + 0.15, half_d + 0.3)
	awning.set_surface_override_material(0,
		_make_ps1_material(awning_col * 0.5, true, awning_col, 4.0))
	building.add_child(awning)

	# Counter along back wall (70% chance)
	if rng.randf() < 0.7:
		var counter_w := w * 0.6
		var counter_mat := _make_ps1_material(Color(0.3, 0.2, 0.12))
		_add_wall(building, Vector3(0, -half_h + 0.5, -half_d + 1.2),
			Vector3(counter_w, 1.0, 0.6), counter_mat)

	# Table (50% chance)
	if rng.randf() < 0.5:
		var table_mat := _make_ps1_material(Color(0.25, 0.18, 0.1))
		var table_x := rng.randf_range(-half_w * 0.4, half_w * 0.4)
		var table_z := rng.randf_range(-half_d * 0.2, half_d * 0.3)
		_add_wall(building, Vector3(table_x, -half_h + 0.4, table_z),
			Vector3(1.2, 0.05, 0.8), table_mat)
		# Table legs
		for lx in [-0.5, 0.5]:
			for lz in [-0.3, 0.3]:
				_add_wall(building, Vector3(table_x + lx, -half_h + 0.2, table_z + lz),
					Vector3(0.08, 0.4, 0.08), table_mat)

	add_child(building)

	# Windows on exterior side faces
	_add_storefront_windows(building, size, rng)

	# Neon sign above door -- storefronts always use text if font available
	if rng.randf() < 0.8:
		var neon_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
		if neon_font:
			# Text sign for storefront (shop name)
			var label := Label3D.new()
			label.text = NEON_TEXTS[rng.randi_range(0, NEON_TEXTS.size() - 1)]
			label.font = neon_font
			label.font_size = rng.randi_range(48, 72)
			label.pixel_size = 0.01
			label.modulate = neon_col
			label.outline_modulate = neon_col * 0.6
			label.outline_size = 8
			label.position = Vector3(0, -half_h + door_height + 0.8, half_d + 0.08)
			label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			building.add_child(label)

			var sign_light := OmniLight3D.new()
			sign_light.light_color = neon_col
			sign_light.light_energy = 2.5
			sign_light.omni_range = 6.0
			sign_light.omni_attenuation = 1.5
			sign_light.shadow_enabled = false
			sign_light.position = Vector3(0, 0, 0.5)
			label.add_child(sign_light)
		else:
			# Fallback quad sign
			var sign_mesh := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(rng.randf_range(1.5, 3.0), rng.randf_range(0.5, 1.0))
			sign_mesh.mesh = quad
			sign_mesh.position = Vector3(0, -half_h + door_height + 0.8, half_d + 0.05)
			sign_mesh.set_surface_override_material(0,
				_make_ps1_material(neon_col * 0.5, true, neon_col, rng.randf_range(3.0, 5.0)))
			building.add_child(sign_mesh)

			var sign_light := OmniLight3D.new()
			sign_light.light_color = neon_col
			sign_light.light_energy = 2.0
			sign_light.omni_range = 6.0
			sign_light.omni_attenuation = 1.5
			sign_light.shadow_enabled = false
			sign_light.position = Vector3(0, 0, 0.5)
			sign_mesh.add_child(sign_light)

func _add_wall(parent: Node3D, pos: Vector3, wall_size: Vector3, mat: ShaderMaterial) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = wall_size
	mi.mesh = box
	mi.position = pos
	mi.set_surface_override_material(0, mat)

	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = wall_size
	col.shape = shape
	sb.add_child(col)
	mi.add_child(sb)

	parent.add_child(mi)

func _add_storefront_windows(building: Node3D, size: Vector3, rng: RandomNumberGenerator) -> void:
	# Windows on side walls (-X and +X faces) and back wall
	var window_color := Color(1.0, 0.2, 0.6)
	var cold_color := Color(0.0, 0.9, 0.9)
	var half_h := size.y * 0.5

	# Side walls (X axis)
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
				var wy := -half_h + (row + 0.5) * (size.y / float(num_rows))
				win.position = Vector3(face * size.x * 0.51, wy, wz)
				win.rotation.y = PI * 0.5 if face > 0 else -PI * 0.5
				var wc := cold_color if rng.randf() > 0.5 else window_color
				win.set_surface_override_material(0,
					_make_ps1_material(wc * 0.3, true, wc, rng.randf_range(2.5, 5.0)))
				building.add_child(win)

func _add_windows(building: MeshInstance3D, size: Vector3, rng: RandomNumberGenerator) -> void:
	var window_color := Color(1.0, 0.2, 0.6)   # hot pink / magenta
	var cold_color := Color(0.0, 0.9, 0.9)     # cyan / teal

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
				win.position = Vector3(wx, wy, face * size.z * 0.51)
				if face < 0:
					win.rotation.y = PI

				var wc := cold_color if rng.randf() > 0.5 else window_color
				win.set_surface_override_material(0,
					_make_ps1_material(wc * 0.3, true, wc, rng.randf_range(2.5, 5.0)))
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
				win.position = Vector3(face * size.x * 0.51, wy, wz)
				win.rotation.y = PI * 0.5
				if face < 0:
					win.rotation.y = -PI * 0.5

				var wc := cold_color if rng.randf() > 0.5 else window_color
				win.set_surface_override_material(0,
					_make_ps1_material(wc * 0.3, true, wc, rng.randf_range(2.5, 5.0)))
				building.add_child(win)

func _add_neon_sign(building: MeshInstance3D, size: Vector3, rng: RandomNumberGenerator) -> void:
	var neon_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
	var use_text := neon_font != null and rng.randf() < 0.5

	# Determine face placement
	var face_choice := rng.randi_range(0, 3)
	var sign_pos := Vector3.ZERO
	var sign_rot_y := 0.0
	match face_choice:
		0:  # front
			sign_pos = Vector3(
				rng.randf_range(-size.x * 0.3, size.x * 0.3),
				rng.randf_range(-size.y * 0.1, size.y * 0.2),
				size.z * 0.502
			)
		1:  # back
			sign_pos = Vector3(
				rng.randf_range(-size.x * 0.3, size.x * 0.3),
				rng.randf_range(-size.y * 0.1, size.y * 0.2),
				-size.z * 0.502
			)
			sign_rot_y = PI
		2:  # right
			sign_pos = Vector3(
				size.x * 0.502,
				rng.randf_range(-size.y * 0.1, size.y * 0.2),
				rng.randf_range(-size.z * 0.3, size.z * 0.3)
			)
			sign_rot_y = PI * 0.5
		3:  # left
			sign_pos = Vector3(
				-size.x * 0.502,
				rng.randf_range(-size.y * 0.1, size.y * 0.2),
				rng.randf_range(-size.z * 0.3, size.z * 0.3)
			)
			sign_rot_y = -PI * 0.5

	if use_text:
		# Label3D text sign with kanji
		var label := Label3D.new()
		label.text = NEON_TEXTS[rng.randi_range(0, NEON_TEXTS.size() - 1)]
		label.font = neon_font
		label.font_size = rng.randi_range(48, 96)
		label.pixel_size = 0.01
		label.modulate = neon_col
		label.outline_modulate = neon_col * 0.6
		label.outline_size = 8
		label.position = sign_pos
		label.rotation.y = sign_rot_y
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		building.add_child(label)

		var light := OmniLight3D.new()
		light.light_color = neon_col
		light.light_energy = rng.randf_range(1.5, 3.0)
		light.omni_range = rng.randf_range(6.0, 12.0)
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		light.position = Vector3(0, 0, 0.5)
		label.add_child(light)
	else:
		# Quad sign (original behavior)
		var sign_mesh := MeshInstance3D.new()
		var quad := QuadMesh.new()
		var sign_w := rng.randf_range(2.0, 5.0)
		var sign_h := rng.randf_range(0.8, 2.0)
		quad.size = Vector2(sign_w, sign_h)
		sign_mesh.mesh = quad
		sign_mesh.position = sign_pos
		sign_mesh.rotation.y = sign_rot_y

		sign_mesh.set_surface_override_material(0,
			_make_ps1_material(neon_col * 0.5, true, neon_col, rng.randf_range(3.0, 6.0)))

		var light := OmniLight3D.new()
		light.light_color = neon_col
		light.light_energy = rng.randf_range(1.5, 3.0)
		light.omni_range = rng.randf_range(6.0, 12.0)
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		light.position = Vector3(0, 0, 0.5)
		sign_mesh.add_child(light)

		building.add_child(sign_mesh)

func _add_vertical_neon_sign(building: MeshInstance3D, size: Vector3,
		rng: RandomNumberGenerator) -> void:
	var neon_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]

	# Pick 2-5 kanji characters for vertical text
	var num_chars := rng.randi_range(2, 5)
	var text := ""
	for _c in range(num_chars):
		# Use single-character entries for vertical stacking
		var idx := rng.randi_range(0, NEON_TEXTS.size() - 1)
		var entry: String = NEON_TEXTS[idx]
		text += entry[0] + "\n"

	# Place on front or side face
	var face := rng.randi_range(0, 1)
	var sign_pos := Vector3.ZERO
	var sign_rot_y := 0.0
	if face == 0:
		sign_pos = Vector3(
			rng.randf_range(-size.x * 0.35, size.x * 0.35),
			size.y * 0.1,
			size.z * 0.503
		)
	else:
		sign_pos = Vector3(
			size.x * 0.503,
			size.y * 0.1,
			rng.randf_range(-size.z * 0.35, size.z * 0.35)
		)
		sign_rot_y = PI * 0.5

	var label := Label3D.new()
	label.text = text
	label.font = neon_font
	label.font_size = rng.randi_range(72, 128)
	label.pixel_size = 0.01
	label.modulate = neon_col
	label.outline_modulate = neon_col * 0.6
	label.outline_size = 12
	label.position = sign_pos
	label.rotation.y = sign_rot_y
	label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	building.add_child(label)

	# Larger light for vertical signs -- visible from far away
	var light := OmniLight3D.new()
	light.light_color = neon_col
	light.light_energy = 4.0
	light.omni_range = 15.0
	light.omni_attenuation = 1.5
	light.shadow_enabled = false
	light.position = Vector3(0, 0, 1.0)
	label.add_child(light)

func _generate_cars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99  # separate seed so city layout stays stable

	var car_colors: Array[Color] = [
		Color(0.15, 0.15, 0.18),  # dark gray
		Color(0.18, 0.1, 0.25),   # dark purple
		Color(0.25, 0.08, 0.08),  # dark red
		Color(0.08, 0.18, 0.18),  # dark teal
		Color(0.12, 0.12, 0.12),  # charcoal
		Color(0.7, 0.6, 0.1),    # taxi yellow (rare)
	]

	var cell_stride := block_size + street_width

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride

			# Cars along +Z edge of block (street runs along Z) -- reduced from 0.6 to 0.3
			if rng.randf() < 0.3:
				var num_cars := rng.randi_range(1, 2)
				for c in range(num_cars):
					var car_z := cell_z + rng.randf_range(-block_size * 0.3, block_size * 0.3)
					var car_x := cell_x + block_size * 0.5 + street_width * 0.25
					_create_car(Vector3(car_x, 0, car_z), 0.0, car_colors, rng)

			# Cars along +X edge of block (street runs along X) -- reduced from 0.6 to 0.3
			if rng.randf() < 0.3:
				var num_cars := rng.randi_range(1, 2)
				for c in range(num_cars):
					var car_x := cell_x + rng.randf_range(-block_size * 0.3, block_size * 0.3)
					var car_z := cell_z + block_size * 0.5 + street_width * 0.25
					_create_car(Vector3(car_x, 0, car_z), PI * 0.5, car_colors, rng)

func _create_car(pos: Vector3, rot_y: float, colors: Array[Color],
		rng: RandomNumberGenerator) -> void:
	var car := Node3D.new()
	car.position = pos
	car.rotation.y = rot_y

	# Pick a color (last one = taxi yellow, make it rare)
	var color_idx := rng.randi_range(0, colors.size() - 1)
	if color_idx == colors.size() - 1 and rng.randf() > 0.15:
		color_idx = rng.randi_range(0, colors.size() - 2)
	var car_color := colors[color_idx]
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
	# Slightly darker for cabin windows
	cabin.set_surface_override_material(0,
		_make_ps1_material(car_color * 0.6))
	car.add_child(cabin)

	# Wheels (4 cylinders)
	var wheel_positions := [
		Vector3(1.1, 0.3, 0.85),
		Vector3(1.1, 0.3, -0.85),
		Vector3(-1.1, 0.3, 0.85),
		Vector3(-1.1, 0.3, -0.85),
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

	# 30% chance of emissive headlights
	if rng.randf() < 0.3:
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

	# Collision - single box for the whole car
	var static_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(3.5, 1.7, 1.8)
	collision.shape = col_shape
	collision.position = Vector3(0, 0.85, 0)
	static_body.add_child(collision)
	car.add_child(static_body)

	add_child(car)

func _generate_street_lights() -> void:
	var light_spacing := 14.0
	var cell_stride := block_size + street_width
	var pole_mat := _make_ps1_material(Color(0.2, 0.2, 0.22))
	var lamp_color := Color(1.0, 0.8, 0.4)
	var lamp_mat := _make_ps1_material(lamp_color * 0.3, true, lamp_color, 4.0)

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride

			# Lights along Z-streets (east side of block)
			var street_x := cell_x + block_size * 0.5 + street_width * 0.8
			var z_start := cell_z - block_size * 0.5
			var num_along_z := int(block_size / light_spacing)
			for i in range(num_along_z):
				var lz := z_start + (i + 0.5) * light_spacing
				_create_street_light(Vector3(street_x, 0, lz), pole_mat, lamp_mat, lamp_color)

			# Lights along X-streets (south side of block)
			var street_z := cell_z + block_size * 0.5 + street_width * 0.8
			var x_start := cell_x - block_size * 0.5
			var num_along_x := int(block_size / light_spacing)
			for i in range(num_along_x):
				var lx := x_start + (i + 0.5) * light_spacing
				_create_street_light(Vector3(lx, 0, street_z), pole_mat, lamp_mat, lamp_color)

func _create_street_light(pos: Vector3, pole_mat: ShaderMaterial,
		lamp_mat: ShaderMaterial, lamp_color: Color) -> void:
	var lamp := Node3D.new()
	lamp.position = pos

	# Pole (tall thin cylinder)
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.06
	pole_mesh.bottom_radius = 0.08
	pole_mesh.height = 6.0
	pole.mesh = pole_mesh
	pole.position = Vector3(0, 3.0, 0)
	pole.set_surface_override_material(0, pole_mat)
	lamp.add_child(pole)

	# Arm (horizontal extension)
	var arm := MeshInstance3D.new()
	var arm_mesh := CylinderMesh.new()
	arm_mesh.top_radius = 0.04
	arm_mesh.bottom_radius = 0.04
	arm_mesh.height = 1.2
	arm.mesh = arm_mesh
	arm.position = Vector3(0.5, 5.8, 0)
	arm.rotation.z = PI * 0.5
	arm.set_surface_override_material(0, pole_mat)
	lamp.add_child(arm)

	# Lamp head (emissive sphere)
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.2
	head_mesh.height = 0.4
	head.mesh = head_mesh
	head.position = Vector3(1.0, 5.7, 0)
	head.set_surface_override_material(0, lamp_mat)
	lamp.add_child(head)

	# Light source
	var light := OmniLight3D.new()
	light.light_color = lamp_color
	light.light_energy = 2.5
	light.omni_range = 12.0
	light.omni_attenuation = 1.5
	light.shadow_enabled = false
	light.position = Vector3(1.0, 5.5, 0)
	lamp.add_child(light)

	add_child(lamp)

func _generate_puddles() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 234
	var cell_stride := block_size + street_width

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride

			# 2-4 puddles per block intersection
			var num_puddles := rng.randi_range(2, 4)
			for _p in range(num_puddles):
				var puddle_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
				var px := cell_x + rng.randf_range(-street_width, block_size * 0.5 + street_width)
				var pz := cell_z + rng.randf_range(-street_width, block_size * 0.5 + street_width)
				var puddle_w := rng.randf_range(1.5, 4.0)
				var puddle_d := rng.randf_range(1.0, 3.0)

				var puddle := MeshInstance3D.new()
				var quad := QuadMesh.new()
				quad.size = Vector2(puddle_w, puddle_d)
				puddle.mesh = quad
				puddle.position = Vector3(px, 0.02, pz)
				puddle.rotation.x = -PI * 0.5  # lay flat on ground
				puddle.set_surface_override_material(0,
					_make_ps1_material(puddle_col * 0.08, true, puddle_col, rng.randf_range(0.8, 1.5)))
				add_child(puddle)

func _generate_steam_vents() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 345
	var cell_stride := block_size + street_width

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.3:  # 30% of blocks get a steam vent
				continue
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride
			var vx := cell_x + rng.randf_range(block_size * 0.3, block_size * 0.5 + street_width * 0.5)
			var vz := cell_z + rng.randf_range(block_size * 0.3, block_size * 0.5 + street_width * 0.5)

			# Steam particle system
			var steam := GPUParticles3D.new()
			steam.position = Vector3(vx, 0.1, vz)
			steam.amount = 20
			steam.lifetime = 2.5
			steam.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 8, 6))

			var mat := ParticleProcessMaterial.new()
			mat.direction = Vector3(0, 1, 0)
			mat.spread = 15.0
			mat.initial_velocity_min = 1.0
			mat.initial_velocity_max = 2.5
			mat.gravity = Vector3(0, 0.2, 0)
			mat.damping_min = 2.0
			mat.damping_max = 4.0
			mat.scale_min = 0.3
			mat.scale_max = 0.8
			mat.color = Color(0.6, 0.6, 0.7, 0.15)
			steam.process_material = mat

			var mesh := BoxMesh.new()
			mesh.size = Vector3(0.3, 0.3, 0.3)
			steam.draw_pass_1 = mesh

			add_child(steam)

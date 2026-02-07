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
var flickering_lights: Array[Dictionary] = []  # [{node, base_energy, phase, speed, style}]
var traffic_lights: Array[Dictionary] = []  # [{red, yellow, green, phase}]
var holo_signs: Array[Dictionary] = []  # [{node, base_y, phase, speed}]
var vending_screens: Array[Dictionary] = []  # [{node, phase, color}]
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
	_generate_skyline()
	_generate_rooftop_details()
	_generate_sidewalks()
	_generate_road_markings()
	_generate_vending_machines()
	_generate_traffic_lights()
	_generate_billboards()
	_generate_dumpsters()
	_generate_fire_escapes()
	_generate_window_ac_units()
	_generate_telephone_poles()
	_generate_graffiti()
	_generate_neon_underglow()
	_generate_manholes()
	_generate_litter()
	_generate_overhead_cables()
	_generate_skyline_warning_lights()
	_generate_holographic_signs()
	_generate_phone_booths()
	_generate_wind_debris()
	_generate_utility_boxes()
	_generate_street_furniture()
	_generate_construction_zones()
	_generate_drain_grates()
	_generate_building_setbacks()
	_generate_exposed_pipes()
	_generate_security_cameras()
	_generate_awning_lights()
	_generate_chain_link_fences()
	_generate_trash_bags()
	_generate_bus_stops()
	_generate_fire_hydrants()
	_generate_water_towers()
	_generate_satellite_dishes()
	_setup_neon_flicker()
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
	var rng := RandomNumberGenerator.new()
	rng.seed = 150
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
				_create_street_light(Vector3(street_x, 0, lz), pole_mat, lamp_mat, lamp_color, rng)

			# Lights along X-streets (south side of block)
			var street_z := cell_z + block_size * 0.5 + street_width * 0.8
			var x_start := cell_x - block_size * 0.5
			var num_along_x := int(block_size / light_spacing)
			for i in range(num_along_x):
				var lx := x_start + (i + 0.5) * light_spacing
				_create_street_light(Vector3(lx, 0, street_z), pole_mat, lamp_mat, lamp_color, rng)

func _create_street_light(pos: Vector3, pole_mat: ShaderMaterial,
		lamp_mat: ShaderMaterial, lamp_color: Color, rng: RandomNumberGenerator = null) -> void:
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

	# 18% of street lights flicker like a faulty sodium lamp
	if rng and rng.randf() < 0.18:
		flickering_lights.append({
			"node": light,
			"mesh": head,
			"base_energy": 2.5,
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(8.0, 20.0),
			"style": "buzz",
		})

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

func _generate_skyline() -> void:
	# Ring of tall dark silhouette buildings beyond the playable grid
	var rng := RandomNumberGenerator.new()
	rng.seed = 456
	var cell_stride := block_size + street_width
	var inner_edge := grid_size * cell_stride + street_width
	var outer_edge := inner_edge + 120.0
	var skyline_mat := _make_ps1_material(Color(0.03, 0.02, 0.05))

	# Place buildings around all four sides
	for side in range(4):
		var num_buildings := rng.randi_range(20, 35)
		for _b in range(num_buildings):
			var bh := rng.randf_range(30.0, 90.0)
			var bw := rng.randf_range(8.0, 25.0)
			var bd := rng.randf_range(8.0, 20.0)
			var dist := rng.randf_range(inner_edge + 5.0, outer_edge)
			var lateral := rng.randf_range(-outer_edge, outer_edge)

			var bpos := Vector3.ZERO
			match side:
				0: bpos = Vector3(lateral, bh * 0.5, dist)    # north
				1: bpos = Vector3(lateral, bh * 0.5, -dist)   # south
				2: bpos = Vector3(dist, bh * 0.5, lateral)    # east
				3: bpos = Vector3(-dist, bh * 0.5, lateral)   # west

			var mi := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(bw, bh, bd)
			mi.mesh = box
			mi.position = bpos
			mi.set_surface_override_material(0, skyline_mat)
			add_child(mi)

			# Scattered dim windows on skyline buildings (30% get windows)
			if rng.randf() < 0.3:
				var num_wins := rng.randi_range(3, 8)
				for _w in range(num_wins):
					var win := MeshInstance3D.new()
					var quad := QuadMesh.new()
					quad.size = Vector2(1.0, 1.2)
					win.mesh = quad
					var wy := rng.randf_range(-bh * 0.3, bh * 0.3)
					# Pick the face closest to the player (facing inward)
					match side:
						0:
							win.position = Vector3(rng.randf_range(-bw * 0.4, bw * 0.4), wy, -bd * 0.51)
							win.rotation.y = PI
						1:
							win.position = Vector3(rng.randf_range(-bw * 0.4, bw * 0.4), wy, bd * 0.51)
						2:
							win.position = Vector3(-bw * 0.51, wy, rng.randf_range(-bd * 0.4, bd * 0.4))
							win.rotation.y = -PI * 0.5
						3:
							win.position = Vector3(bw * 0.51, wy, rng.randf_range(-bd * 0.4, bd * 0.4))
							win.rotation.y = PI * 0.5
					var wc := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
					win.set_surface_override_material(0,
						_make_ps1_material(wc * 0.15, true, wc, rng.randf_range(1.0, 2.5)))
					mi.add_child(win)

func _generate_rooftop_details() -> void:
	# Add water tanks, antennas, and AC units to building rooftops
	var rng := RandomNumberGenerator.new()
	rng.seed = 567
	var tank_mat := _make_ps1_material(Color(0.25, 0.22, 0.2))
	var metal_mat := _make_ps1_material(Color(0.3, 0.3, 0.32))
	var red_light_color := Color(1.0, 0.0, 0.0)
	var red_mat := _make_ps1_material(red_light_color * 0.3, true, red_light_color, 3.0)

	# Iterate through city buildings (direct children that are MeshInstance3D with BoxMesh)
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		# Only add rooftop details to buildings tall enough
		if bsize.y < 15.0:
			continue

		var roof_y := bsize.y * 0.5  # top of building (local coords)

		# Water tank (40% of tall buildings)
		if rng.randf() < 0.4:
			var tank := MeshInstance3D.new()
			var tank_mesh := CylinderMesh.new()
			tank_mesh.top_radius = rng.randf_range(0.8, 1.5)
			tank_mesh.bottom_radius = tank_mesh.top_radius
			tank_mesh.height = rng.randf_range(1.5, 2.5)
			tank.mesh = tank_mesh
			var tx := rng.randf_range(-bsize.x * 0.3, bsize.x * 0.3)
			var tz := rng.randf_range(-bsize.z * 0.3, bsize.z * 0.3)
			tank.position = Vector3(tx, roof_y + tank_mesh.height * 0.5, tz)
			tank.set_surface_override_material(0, tank_mat)
			mi.add_child(tank)

			# Tank legs (4 thin cylinders)
			for lx in [-0.5, 0.5]:
				for lz in [-0.5, 0.5]:
					var leg := MeshInstance3D.new()
					var leg_mesh := CylinderMesh.new()
					leg_mesh.top_radius = 0.05
					leg_mesh.bottom_radius = 0.05
					leg_mesh.height = 1.2
					leg.mesh = leg_mesh
					leg.position = Vector3(tx + lx * tank_mesh.top_radius * 0.7, roof_y + 0.6, tz + lz * tank_mesh.top_radius * 0.7)
					leg.set_surface_override_material(0, metal_mat)
					mi.add_child(leg)

		# Antenna with blinking red light (50% of tall buildings)
		if rng.randf() < 0.5:
			var antenna_height := rng.randf_range(3.0, 6.0)
			var ax := rng.randf_range(-bsize.x * 0.3, bsize.x * 0.3)
			var az := rng.randf_range(-bsize.z * 0.3, bsize.z * 0.3)

			# Antenna pole
			var pole := MeshInstance3D.new()
			var pole_mesh := CylinderMesh.new()
			pole_mesh.top_radius = 0.03
			pole_mesh.bottom_radius = 0.05
			pole_mesh.height = antenna_height
			pole.mesh = pole_mesh
			pole.position = Vector3(ax, roof_y + antenna_height * 0.5, az)
			pole.set_surface_override_material(0, metal_mat)
			mi.add_child(pole)

			# Red blinking light at top
			var blinker := MeshInstance3D.new()
			var blinker_mesh := SphereMesh.new()
			blinker_mesh.radius = 0.1
			blinker_mesh.height = 0.2
			blinker.mesh = blinker_mesh
			blinker.position = Vector3(ax, roof_y + antenna_height + 0.1, az)
			blinker.set_surface_override_material(0, red_mat)
			mi.add_child(blinker)

			# Red OmniLight
			var red_light := OmniLight3D.new()
			red_light.light_color = red_light_color
			red_light.light_energy = 1.5
			red_light.omni_range = 5.0
			red_light.omni_attenuation = 1.5
			red_light.shadow_enabled = false
			red_light.position = blinker.position
			mi.add_child(red_light)

			# Register for blinking
			flickering_lights.append({
				"node": red_light,
				"mesh": blinker,
				"base_energy": 1.5,
				"phase": rng.randf() * TAU,
				"speed": rng.randf_range(1.5, 3.0),
				"style": "blink",
			})

		# AC unit / vent box (35% of buildings)
		if rng.randf() < 0.35:
			var ac := MeshInstance3D.new()
			var ac_mesh := BoxMesh.new()
			ac_mesh.size = Vector3(rng.randf_range(1.0, 2.0), rng.randf_range(0.6, 1.0), rng.randf_range(0.8, 1.5))
			ac.mesh = ac_mesh
			var acx := rng.randf_range(-bsize.x * 0.35, bsize.x * 0.35)
			var acz := rng.randf_range(-bsize.z * 0.35, bsize.z * 0.35)
			ac.position = Vector3(acx, roof_y + ac_mesh.size.y * 0.5, acz)
			ac.set_surface_override_material(0, metal_mat)
			mi.add_child(ac)

func _generate_sidewalks() -> void:
	var cell_stride := block_size + street_width
	var curb_height := 0.15
	var sidewalk_width := 2.0
	var sidewalk_mat := _make_ps1_material(Color(0.12, 0.12, 0.14))
	var curb_mat := _make_ps1_material(Color(0.18, 0.18, 0.2))

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride

			# Sidewalk along +Z street (east side of block)
			var sz_x := cell_x + block_size * 0.5 + sidewalk_width * 0.5
			_add_sidewalk_strip(Vector3(sz_x, curb_height * 0.5, cell_z),
				Vector3(sidewalk_width, curb_height, block_size), sidewalk_mat, curb_mat, curb_height, "z")

			# Sidewalk along +X street (south side of block)
			var sx_z := cell_z + block_size * 0.5 + sidewalk_width * 0.5
			_add_sidewalk_strip(Vector3(cell_x, curb_height * 0.5, sx_z),
				Vector3(block_size, curb_height, sidewalk_width), sidewalk_mat, curb_mat, curb_height, "x")

func _add_sidewalk_strip(pos: Vector3, size: Vector3, sidewalk_mat: ShaderMaterial,
		curb_mat: ShaderMaterial, curb_height: float, _street_axis: String) -> void:
	# Raised sidewalk platform
	var sidewalk := MeshInstance3D.new()
	var sidewalk_mesh := BoxMesh.new()
	sidewalk_mesh.size = size
	sidewalk.mesh = sidewalk_mesh
	sidewalk.position = pos
	sidewalk.set_surface_override_material(0, sidewalk_mat)
	add_child(sidewalk)

	# Curb edge (thin raised strip on street side)
	var curb := MeshInstance3D.new()
	var curb_mesh := BoxMesh.new()
	if _street_axis == "z":
		curb_mesh.size = Vector3(0.1, curb_height + 0.05, size.z)
		curb.position = pos + Vector3(size.x * 0.5, 0.025, 0)
	else:
		curb_mesh.size = Vector3(size.x, curb_height + 0.05, 0.1)
		curb.position = pos + Vector3(0, 0.025, size.z * 0.5)
	curb.mesh = curb_mesh
	curb.set_surface_override_material(0, curb_mat)
	add_child(curb)

func _generate_road_markings() -> void:
	var cell_stride := block_size + street_width
	var marking_mat := _make_ps1_material(Color(0.6, 0.6, 0.4) * 0.3, true,
		Color(0.6, 0.6, 0.4), 0.5)
	var crosswalk_mat := _make_ps1_material(Color(0.8, 0.8, 0.8) * 0.3, true,
		Color(0.8, 0.8, 0.8), 0.4)

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride

			# Center line dashes along Z-street
			var street_center_x := cell_x + block_size * 0.5 + street_width * 0.5
			var dash_spacing := 4.0
			var num_dashes := int(block_size / dash_spacing)
			for i in range(num_dashes):
				var dz := cell_z - block_size * 0.5 + (i + 0.5) * dash_spacing
				var dash := MeshInstance3D.new()
				var dash_mesh := QuadMesh.new()
				dash_mesh.size = Vector2(0.15, 1.5)
				dash.mesh = dash_mesh
				dash.position = Vector3(street_center_x, 0.01, dz)
				dash.rotation.x = -PI * 0.5
				dash.set_surface_override_material(0, marking_mat)
				add_child(dash)

			# Center line dashes along X-street
			var street_center_z := cell_z + block_size * 0.5 + street_width * 0.5
			for i in range(num_dashes):
				var dx := cell_x - block_size * 0.5 + (i + 0.5) * dash_spacing
				var dash := MeshInstance3D.new()
				var dash_mesh := QuadMesh.new()
				dash_mesh.size = Vector2(1.5, 0.15)
				dash.mesh = dash_mesh
				dash.position = Vector3(dx, 0.01, street_center_z)
				dash.rotation.x = -PI * 0.5
				dash.set_surface_override_material(0, marking_mat)
				add_child(dash)

			# Crosswalk at intersection (corner of block)
			var ix := cell_x + block_size * 0.5 + street_width * 0.5
			var iz := cell_z + block_size * 0.5 + street_width * 0.5
			# Crosswalk across Z-street (parallel to X)
			var num_stripes := 5
			for s in range(num_stripes):
				var stripe := MeshInstance3D.new()
				var stripe_mesh := QuadMesh.new()
				stripe_mesh.size = Vector2(street_width * 0.7, 0.4)
				stripe.mesh = stripe_mesh
				stripe.position = Vector3(ix, 0.015, iz - 2.0 + s * 1.0)
				stripe.rotation.x = -PI * 0.5
				stripe.set_surface_override_material(0, crosswalk_mat)
				add_child(stripe)
			# Crosswalk across X-street (parallel to Z)
			for s in range(num_stripes):
				var stripe := MeshInstance3D.new()
				var stripe_mesh := QuadMesh.new()
				stripe_mesh.size = Vector2(0.4, street_width * 0.7)
				stripe.mesh = stripe_mesh
				stripe.position = Vector3(ix - 2.0 + s * 1.0, 0.015, iz)
				stripe.rotation.x = -PI * 0.5
				stripe.set_surface_override_material(0, crosswalk_mat)
				add_child(stripe)

func _generate_vending_machines() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 789
	var cell_stride := block_size + street_width

	var vending_colors: Array[Color] = [
		Color(1.0, 0.05, 0.4),  # magenta
		Color(0.0, 0.9, 1.0),   # cyan
		Color(1.0, 0.4, 0.0),   # orange
		Color(0.0, 1.0, 0.5),   # green
	]

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.25:  # 25% of blocks get a vending machine
				continue
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride

			var vc := vending_colors[rng.randi_range(0, vending_colors.size() - 1)]

			# Place on sidewalk
			var side := rng.randi_range(0, 1)
			var vx: float
			var vz: float
			if side == 0:
				# Along Z-street sidewalk
				vx = cell_x + block_size * 0.5 + 1.0
				vz = cell_z + rng.randf_range(-block_size * 0.3, block_size * 0.3)
			else:
				# Along X-street sidewalk
				vx = cell_x + rng.randf_range(-block_size * 0.3, block_size * 0.3)
				vz = cell_z + block_size * 0.5 + 1.0

			var vm := Node3D.new()
			vm.position = Vector3(vx, 0, vz)

			# Main body
			var body := MeshInstance3D.new()
			var body_mesh := BoxMesh.new()
			body_mesh.size = Vector3(0.8, 1.8, 0.7)
			body.mesh = body_mesh
			body.position = Vector3(0, 0.9, 0)
			body.set_surface_override_material(0, _make_ps1_material(Color(0.15, 0.15, 0.18)))
			vm.add_child(body)

			# Glowing front panel
			var panel := MeshInstance3D.new()
			var panel_mesh := QuadMesh.new()
			panel_mesh.size = Vector2(0.7, 1.2)
			panel.mesh = panel_mesh
			panel.position = Vector3(0, 1.0, 0.351)
			panel.set_surface_override_material(0,
				_make_ps1_material(vc * 0.3, true, vc, 3.0))
			vm.add_child(panel)

			# Track for blinking animation (pre-cached materials)
			vending_screens.append({
				"node": panel,
				"phase": rng.randf() * TAU,
				"mat_bright": _make_ps1_material(vc * 0.3, true, vc, 4.0),
				"mat_dim": _make_ps1_material(vc * 0.15, true, vc, 1.5),
				"mat_off": _make_ps1_material(vc * 0.08, true, vc, 0.5),
			})

			# Small light
			var vlight := OmniLight3D.new()
			vlight.light_color = vc
			vlight.light_energy = 1.5
			vlight.omni_range = 4.0
			vlight.omni_attenuation = 1.5
			vlight.shadow_enabled = false
			vlight.position = Vector3(0, 1.0, 0.8)
			vm.add_child(vlight)

			# Collision
			var sb := StaticBody3D.new()
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.8, 1.8, 0.7)
			col.shape = shape
			col.position = Vector3(0, 0.9, 0)
			sb.add_child(col)
			vm.add_child(sb)

			add_child(vm)

func _generate_traffic_lights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 890
	var cell_stride := block_size + street_width
	var pole_mat := _make_ps1_material(Color(0.2, 0.2, 0.22))

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.4:  # 40% of intersections get traffic lights
				continue
			var ix := gx * cell_stride + block_size * 0.5 + street_width * 0.9
			var iz := gz * cell_stride + block_size * 0.5 + street_width * 0.9

			var phase := rng.randf() * 20.0  # stagger timing
			_create_traffic_light(Vector3(ix, 0, iz), pole_mat, phase)

func _create_traffic_light(pos: Vector3, pole_mat: ShaderMaterial, phase: float) -> void:
	var tl := Node3D.new()
	tl.position = pos

	# Pole
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.06
	pole_mesh.bottom_radius = 0.08
	pole_mesh.height = 5.0
	pole.mesh = pole_mesh
	pole.position = Vector3(0, 2.5, 0)
	pole.set_surface_override_material(0, pole_mat)
	tl.add_child(pole)

	# Signal housing
	var housing := MeshInstance3D.new()
	var housing_mesh := BoxMesh.new()
	housing_mesh.size = Vector3(0.4, 1.0, 0.3)
	housing.mesh = housing_mesh
	housing.position = Vector3(0, 5.2, 0)
	housing.set_surface_override_material(0, _make_ps1_material(Color(0.08, 0.08, 0.08)))
	tl.add_child(housing)

	# Red light
	var red_col := Color(1.0, 0.0, 0.0)
	var red := MeshInstance3D.new()
	var red_mesh := SphereMesh.new()
	red_mesh.radius = 0.1
	red_mesh.height = 0.2
	red.mesh = red_mesh
	red.position = Vector3(0, 5.5, 0.16)
	red.set_surface_override_material(0, _make_ps1_material(red_col * 0.3, true, red_col, 2.0))
	tl.add_child(red)

	# Yellow light
	var yellow_col := Color(1.0, 0.8, 0.0)
	var yellow := MeshInstance3D.new()
	var yellow_mesh := SphereMesh.new()
	yellow_mesh.radius = 0.1
	yellow_mesh.height = 0.2
	yellow.mesh = yellow_mesh
	yellow.position = Vector3(0, 5.2, 0.16)
	yellow.set_surface_override_material(0, _make_ps1_material(yellow_col * 0.3, true, yellow_col, 2.0))
	tl.add_child(yellow)

	# Green light
	var green_col := Color(0.0, 1.0, 0.2)
	var green := MeshInstance3D.new()
	var green_mesh := SphereMesh.new()
	green_mesh.radius = 0.1
	green_mesh.height = 0.2
	green.mesh = green_mesh
	green.position = Vector3(0, 4.9, 0.16)
	green.set_surface_override_material(0, _make_ps1_material(green_col * 0.3, true, green_col, 2.0))
	tl.add_child(green)

	add_child(tl)

	traffic_lights.append({
		"red": red,
		"yellow": yellow,
		"green": green,
		"phase": phase,
		"red_mat_on": _make_ps1_material(red_col * 0.3, true, red_col, 4.0),
		"red_mat_off": _make_ps1_material(red_col * 0.1),
		"yellow_mat_on": _make_ps1_material(yellow_col * 0.3, true, yellow_col, 4.0),
		"yellow_mat_off": _make_ps1_material(yellow_col * 0.1),
		"green_mat_on": _make_ps1_material(green_col * 0.3, true, green_col, 4.0),
		"green_mat_off": _make_ps1_material(green_col * 0.1),
	})

func _generate_billboards() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 901
	var cell_stride := block_size + street_width
	var pole_mat := _make_ps1_material(Color(0.15, 0.15, 0.18))

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.12:  # ~12% of blocks get a billboard
				continue
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride
			var bx := cell_x + rng.randf_range(-block_size * 0.2, block_size * 0.2)
			var bz := cell_z + rng.randf_range(-block_size * 0.2, block_size * 0.2)
			var bb_height := rng.randf_range(15.0, 25.0)
			var neon_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]

			var bb := Node3D.new()
			bb.position = Vector3(bx, 0, bz)

			# Support pole
			var pole := MeshInstance3D.new()
			var pole_mesh := CylinderMesh.new()
			pole_mesh.top_radius = 0.15
			pole_mesh.bottom_radius = 0.2
			pole_mesh.height = bb_height
			pole.mesh = pole_mesh
			pole.position = Vector3(0, bb_height * 0.5, 0)
			pole.set_surface_override_material(0, pole_mat)
			bb.add_child(pole)

			# Billboard frame
			var frame_w := rng.randf_range(5.0, 8.0)
			var frame_h := rng.randf_range(3.0, 5.0)
			var frame := MeshInstance3D.new()
			var frame_mesh := BoxMesh.new()
			frame_mesh.size = Vector3(frame_w, frame_h, 0.2)
			frame.mesh = frame_mesh
			frame.position = Vector3(0, bb_height + frame_h * 0.5, 0)
			frame.rotation.y = rng.randf_range(0, PI)
			frame.set_surface_override_material(0, _make_ps1_material(Color(0.05, 0.05, 0.08)))
			bb.add_child(frame)

			# Glowing front face
			var front := MeshInstance3D.new()
			var front_mesh := QuadMesh.new()
			front_mesh.size = Vector2(frame_w - 0.3, frame_h - 0.3)
			front.mesh = front_mesh
			front.position = Vector3(0, 0, 0.11)
			front.set_surface_override_material(0,
				_make_ps1_material(neon_col * 0.2, true, neon_col, 2.5))
			frame.add_child(front)

			# Glowing back face
			var back := MeshInstance3D.new()
			var back_mesh := QuadMesh.new()
			back_mesh.size = Vector2(frame_w - 0.3, frame_h - 0.3)
			back.mesh = back_mesh
			back.position = Vector3(0, 0, -0.11)
			back.rotation.y = PI
			var back_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
			back.set_surface_override_material(0,
				_make_ps1_material(back_col * 0.2, true, back_col, 2.5))
			frame.add_child(back)

			# Kanji text overlay on front
			if neon_font:
				var label := Label3D.new()
				label.text = NEON_TEXTS[rng.randi_range(0, NEON_TEXTS.size() - 1)]
				label.font = neon_font
				label.font_size = rng.randi_range(96, 160)
				label.pixel_size = 0.01
				label.modulate = Color.WHITE
				label.outline_modulate = neon_col * 0.8
				label.outline_size = 6
				label.position = Vector3(0, 0, 0.12)
				label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
				frame.add_child(label)

			# Billboard light
			var bb_light := OmniLight3D.new()
			bb_light.light_color = neon_col
			bb_light.light_energy = 3.0
			bb_light.omni_range = 12.0
			bb_light.omni_attenuation = 1.5
			bb_light.shadow_enabled = false
			bb_light.position = Vector3(0, bb_height + frame_h * 0.5, 2.0)
			bb.add_child(bb_light)

			add_child(bb)

func _generate_dumpsters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1012
	var cell_stride := block_size + street_width
	var dumpster_mat := _make_ps1_material(Color(0.1, 0.15, 0.1))
	var rust_mat := _make_ps1_material(Color(0.2, 0.1, 0.05))

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.3:  # 30% of blocks
				continue
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride

			# Place near building edges (alley-like)
			var dx := cell_x + rng.randf_range(-block_size * 0.4, block_size * 0.4)
			var dz := cell_z + block_size * 0.5 + rng.randf_range(1.0, 2.5)
			var mat := dumpster_mat if rng.randf() > 0.4 else rust_mat

			var dumpster := Node3D.new()
			dumpster.position = Vector3(dx, 0, dz)

			# Body
			var body := MeshInstance3D.new()
			var body_mesh := BoxMesh.new()
			body_mesh.size = Vector3(1.8, 1.2, 1.0)
			body.mesh = body_mesh
			body.position = Vector3(0, 0.6, 0)
			body.set_surface_override_material(0, mat)
			dumpster.add_child(body)

			# Lid (slightly open)
			var lid := MeshInstance3D.new()
			var lid_mesh := BoxMesh.new()
			lid_mesh.size = Vector3(1.8, 0.05, 1.0)
			lid.mesh = lid_mesh
			lid.position = Vector3(0, 1.22, -0.15)
			lid.rotation.x = rng.randf_range(-0.3, 0.0)
			lid.set_surface_override_material(0, mat)
			dumpster.add_child(lid)

			# Collision
			var sb := StaticBody3D.new()
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.8, 1.2, 1.0)
			col.shape = shape
			col.position = Vector3(0, 0.6, 0)
			sb.add_child(col)
			dumpster.add_child(sb)

			add_child(dumpster)

func _generate_fire_escapes() -> void:
	# Zigzag metal fire escapes on building side walls
	var rng := RandomNumberGenerator.new()
	rng.seed = 1100
	var metal_mat := _make_ps1_material(Color(0.22, 0.22, 0.24))
	var railing_mat := _make_ps1_material(Color(0.18, 0.18, 0.2))

	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 15.0 or rng.randf() > 0.3:  # 30% of tall buildings
			continue

		var num_floors := int(bsize.y / 3.5)
		var face := 1.0 if rng.randf() < 0.5 else -1.0  # left or right side
		var platform_z := rng.randf_range(-bsize.z * 0.3, bsize.z * 0.3)

		for f in range(1, num_floors):
			var floor_y := -bsize.y * 0.5 + f * 3.5

			# Platform
			var platform := MeshInstance3D.new()
			var plat_mesh := BoxMesh.new()
			plat_mesh.size = Vector3(1.5, 0.06, 1.2)
			platform.mesh = plat_mesh
			platform.position = Vector3(face * (bsize.x * 0.5 + 0.75), floor_y, platform_z)
			platform.set_surface_override_material(0, metal_mat)
			mi.add_child(platform)

			# Railing (thin vertical bars on outer edge)
			var rail := MeshInstance3D.new()
			var rail_mesh := BoxMesh.new()
			rail_mesh.size = Vector3(0.04, 1.0, 1.2)
			rail.mesh = rail_mesh
			rail.position = Vector3(face * (bsize.x * 0.5 + 1.45), floor_y + 0.5, platform_z)
			rail.set_surface_override_material(0, railing_mat)
			mi.add_child(rail)

			# Diagonal stair to next floor (angled box)
			if f < num_floors - 1:
				var stair := MeshInstance3D.new()
				var stair_mesh := BoxMesh.new()
				stair_mesh.size = Vector3(0.5, 0.06, 0.6)
				stair.mesh = stair_mesh
				stair.position = Vector3(face * (bsize.x * 0.5 + 0.75), floor_y + 1.75, platform_z)
				stair.rotation.z = face * 0.9  # angled
				stair.set_surface_override_material(0, metal_mat)
				mi.add_child(stair)

func _generate_window_ac_units() -> void:
	# Small box meshes sticking out from building walls below windows
	var rng := RandomNumberGenerator.new()
	rng.seed = 1200
	var ac_mat := _make_ps1_material(Color(0.28, 0.28, 0.3))

	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 10.0:
			continue

		var num_units := rng.randi_range(0, 4)
		for _u in range(num_units):
			if rng.randf() > 0.5:
				continue
			var face := rng.randi_range(0, 3)
			var unit_y := rng.randf_range(-bsize.y * 0.3, bsize.y * 0.3)

			var unit := MeshInstance3D.new()
			var unit_mesh := BoxMesh.new()
			unit_mesh.size = Vector3(0.6, 0.4, 0.5)
			unit.mesh = unit_mesh
			unit.set_surface_override_material(0, ac_mat)

			match face:
				0:  # front
					unit.position = Vector3(rng.randf_range(-bsize.x * 0.3, bsize.x * 0.3),
						unit_y, bsize.z * 0.5 + 0.25)
				1:  # back
					unit.position = Vector3(rng.randf_range(-bsize.x * 0.3, bsize.x * 0.3),
						unit_y, -bsize.z * 0.5 - 0.25)
				2:  # right
					unit.position = Vector3(bsize.x * 0.5 + 0.25, unit_y,
						rng.randf_range(-bsize.z * 0.3, bsize.z * 0.3))
					unit.rotation.y = PI * 0.5
				3:  # left
					unit.position = Vector3(-bsize.x * 0.5 - 0.25, unit_y,
						rng.randf_range(-bsize.z * 0.3, bsize.z * 0.3))
					unit.rotation.y = PI * 0.5

			mi.add_child(unit)

func _generate_telephone_poles() -> void:
	# Wooden/metal telephone poles along streets with crossarms
	var rng := RandomNumberGenerator.new()
	rng.seed = 1300
	var cell_stride := block_size + street_width
	var pole_spacing := 28.0  # every 28 units
	var pole_mat := _make_ps1_material(Color(0.2, 0.18, 0.15))
	var wire_mat := _make_ps1_material(Color(0.1, 0.1, 0.12))

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.5:  # 50% of streets get poles
				continue
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride

			# Poles along Z-street
			var street_x := cell_x + block_size * 0.5 + street_width * 0.15
			var num_poles := int(block_size / pole_spacing)
			for i in range(num_poles):
				var pz := cell_z - block_size * 0.5 + (i + 0.5) * pole_spacing
				_create_telephone_pole(Vector3(street_x, 0, pz), pole_mat, wire_mat)

func _create_telephone_pole(pos: Vector3, pole_mat: ShaderMaterial, wire_mat: ShaderMaterial) -> void:
	var pole_node := Node3D.new()
	pole_node.position = pos

	# Main pole
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.08
	pole_mesh.bottom_radius = 0.12
	pole_mesh.height = 8.0
	pole.mesh = pole_mesh
	pole.position = Vector3(0, 4.0, 0)
	pole.set_surface_override_material(0, pole_mat)
	pole_node.add_child(pole)

	# Crossarm
	var crossarm := MeshInstance3D.new()
	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(2.5, 0.1, 0.1)
	crossarm.mesh = arm_mesh
	crossarm.position = Vector3(0, 7.5, 0)
	crossarm.set_surface_override_material(0, pole_mat)
	pole_node.add_child(crossarm)

	# Insulators (small cylinders on crossarm)
	for ix in [-0.9, -0.3, 0.3, 0.9]:
		var insulator := MeshInstance3D.new()
		var ins_mesh := CylinderMesh.new()
		ins_mesh.top_radius = 0.04
		ins_mesh.bottom_radius = 0.04
		ins_mesh.height = 0.15
		insulator.mesh = ins_mesh
		insulator.position = Vector3(ix, 7.6, 0)
		insulator.set_surface_override_material(0, wire_mat)
		pole_node.add_child(insulator)

	# Wire stubs (short horizontal lines from each insulator)
	for ix in [-0.9, -0.3, 0.3, 0.9]:
		var wire := MeshInstance3D.new()
		var wire_mesh := BoxMesh.new()
		wire_mesh.size = Vector3(0.02, 0.02, 3.0)
		wire.mesh = wire_mesh
		wire.position = Vector3(ix, 7.65, 0)
		wire.set_surface_override_material(0, wire_mat)
		pole_node.add_child(wire)

	add_child(pole_node)

func _generate_graffiti() -> void:
	# Colored emissive quads on lower building walls
	var rng := RandomNumberGenerator.new()
	rng.seed = 1400

	var graffiti_colors: Array[Color] = [
		Color(1.0, 0.05, 0.4),   # magenta
		Color(0.0, 0.9, 1.0),    # cyan
		Color(0.6, 0.0, 1.0),    # purple
		Color(1.0, 0.4, 0.0),    # orange
		Color(0.0, 1.0, 0.5),    # green
		Color(1.0, 1.0, 0.0),    # yellow
	]

	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 10.0 or rng.randf() > 0.25:  # 25% of buildings
			continue

		var num_tags := rng.randi_range(1, 3)
		for _t in range(num_tags):
			var gc := graffiti_colors[rng.randi_range(0, graffiti_colors.size() - 1)]
			var tag_w := rng.randf_range(1.0, 3.0)
			var tag_h := rng.randf_range(0.5, 1.5)

			var face := rng.randi_range(0, 3)
			var tag_y := -bsize.y * 0.5 + rng.randf_range(0.5, 3.0)  # near ground level

			var tag := MeshInstance3D.new()
			var tag_mesh := QuadMesh.new()
			tag_mesh.size = Vector2(tag_w, tag_h)
			tag.mesh = tag_mesh
			tag.set_surface_override_material(0,
				_make_ps1_material(gc * 0.2, true, gc, rng.randf_range(0.5, 1.5)))

			match face:
				0:
					tag.position = Vector3(rng.randf_range(-bsize.x * 0.35, bsize.x * 0.35),
						tag_y, bsize.z * 0.502)
				1:
					tag.position = Vector3(rng.randf_range(-bsize.x * 0.35, bsize.x * 0.35),
						tag_y, -bsize.z * 0.502)
					tag.rotation.y = PI
				2:
					tag.position = Vector3(bsize.x * 0.502, tag_y,
						rng.randf_range(-bsize.z * 0.35, bsize.z * 0.35))
					tag.rotation.y = PI * 0.5
				3:
					tag.position = Vector3(-bsize.x * 0.502, tag_y,
						rng.randf_range(-bsize.z * 0.35, bsize.z * 0.35))
					tag.rotation.y = -PI * 0.5

			mi.add_child(tag)

func _generate_neon_underglow() -> void:
	# Emissive colored strips at building bases casting light onto sidewalks
	var rng := RandomNumberGenerator.new()
	rng.seed = 1500

	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 8.0 or rng.randf() > 0.3:  # 30% of buildings
			continue

		var gc := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
		var strip_y := -bsize.y * 0.5 + 0.1  # just above ground
		var num_faces := rng.randi_range(1, 2)  # 1-2 faces get underglow

		for _f in range(num_faces):
			var face := rng.randi_range(0, 3)
			var strip := MeshInstance3D.new()
			var strip_mesh := BoxMesh.new()

			match face:
				0:  # front
					strip_mesh.size = Vector3(bsize.x * 0.8, 0.08, 0.08)
					strip.position = Vector3(0, strip_y, bsize.z * 0.5 + 0.05)
				1:  # back
					strip_mesh.size = Vector3(bsize.x * 0.8, 0.08, 0.08)
					strip.position = Vector3(0, strip_y, -bsize.z * 0.5 - 0.05)
				2:  # right
					strip_mesh.size = Vector3(0.08, 0.08, bsize.z * 0.8)
					strip.position = Vector3(bsize.x * 0.5 + 0.05, strip_y, 0)
				3:  # left
					strip_mesh.size = Vector3(0.08, 0.08, bsize.z * 0.8)
					strip.position = Vector3(-bsize.x * 0.5 - 0.05, strip_y, 0)

			strip.mesh = strip_mesh
			strip.set_surface_override_material(0,
				_make_ps1_material(gc * 0.3, true, gc, 4.0))
			mi.add_child(strip)

			# Ground light for underglow effect
			var glow := OmniLight3D.new()
			glow.light_color = gc
			glow.light_energy = 1.5
			glow.omni_range = 5.0
			glow.omni_attenuation = 1.8
			glow.shadow_enabled = false
			glow.position = strip.position + Vector3(0, -0.2, 0)
			mi.add_child(glow)

func _generate_manholes() -> void:
	# Metal disc covers on streets at/near intersections with steam
	var rng := RandomNumberGenerator.new()
	rng.seed = 1600
	var cell_stride := block_size + street_width
	var manhole_mat := _make_ps1_material(Color(0.18, 0.18, 0.16))

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.35:  # 35% of intersections
				continue
			var ix := gx * cell_stride + block_size * 0.5 + street_width * rng.randf_range(0.2, 0.8)
			var iz := gz * cell_stride + block_size * 0.5 + street_width * rng.randf_range(0.2, 0.8)

			# Manhole cover (flat cylinder)
			var cover := MeshInstance3D.new()
			var cover_mesh := CylinderMesh.new()
			cover_mesh.top_radius = 0.5
			cover_mesh.bottom_radius = 0.5
			cover_mesh.height = 0.03
			cover.mesh = cover_mesh
			cover.position = Vector3(ix, 0.02, iz)
			cover.set_surface_override_material(0, manhole_mat)
			add_child(cover)

			# 40% of manholes have steam rising
			if rng.randf() < 0.4:
				var steam := GPUParticles3D.new()
				steam.position = Vector3(ix, 0.05, iz)
				steam.amount = 10
				steam.lifetime = 2.0
				steam.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 6, 4))

				var mat := ParticleProcessMaterial.new()
				mat.direction = Vector3(0, 1, 0)
				mat.spread = 20.0
				mat.initial_velocity_min = 0.5
				mat.initial_velocity_max = 1.5
				mat.gravity = Vector3(0, 0.1, 0)
				mat.damping_min = 1.0
				mat.damping_max = 3.0
				mat.scale_min = 0.2
				mat.scale_max = 0.5
				mat.color = Color(0.5, 0.5, 0.6, 0.1)
				steam.process_material = mat

				var mesh := BoxMesh.new()
				mesh.size = Vector3(0.2, 0.2, 0.2)
				steam.draw_pass_1 = mesh
				add_child(steam)

func _generate_litter() -> void:
	# Small flat debris on sidewalks and gutters
	var rng := RandomNumberGenerator.new()
	rng.seed = 1700
	var cell_stride := block_size + street_width

	var litter_colors: Array[Color] = [
		Color(0.35, 0.3, 0.25),   # paper
		Color(0.25, 0.25, 0.3),   # wrapper
		Color(0.4, 0.35, 0.2),    # cardboard
		Color(0.15, 0.15, 0.18),  # dark trash
		Color(0.3, 0.1, 0.1),     # food wrapper
	]

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride
			var num_pieces := rng.randi_range(0, 5)

			for _p in range(num_pieces):
				var lc := litter_colors[rng.randi_range(0, litter_colors.size() - 1)]
				# Place on sidewalk areas
				var side := rng.randi_range(0, 1)
				var lx: float
				var lz: float
				if side == 0:
					lx = cell_x + block_size * 0.5 + rng.randf_range(0.3, 2.0)
					lz = cell_z + rng.randf_range(-block_size * 0.4, block_size * 0.4)
				else:
					lx = cell_x + rng.randf_range(-block_size * 0.4, block_size * 0.4)
					lz = cell_z + block_size * 0.5 + rng.randf_range(0.3, 2.0)

				var piece := MeshInstance3D.new()
				var piece_mesh := QuadMesh.new()
				piece_mesh.size = Vector2(rng.randf_range(0.1, 0.4), rng.randf_range(0.08, 0.3))
				piece.mesh = piece_mesh
				piece.position = Vector3(lx, 0.17, lz)  # on sidewalk level
				piece.rotation.x = -PI * 0.5
				piece.rotation.y = rng.randf_range(0, TAU)
				piece.set_surface_override_material(0, _make_ps1_material(lc))
				add_child(piece)

func _generate_overhead_cables() -> void:
	# Thin wires stretched across streets between buildings
	var rng := RandomNumberGenerator.new()
	rng.seed = 1800
	var cell_stride := block_size + street_width
	var wire_mat := _make_ps1_material(Color(0.08, 0.08, 0.1))

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.35:  # 35% of street segments get overhead cables
				continue
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride

			var cable_type := rng.randi_range(0, 1)
			var num_cables := rng.randi_range(1, 3)

			for _c in range(num_cables):
				var cable_y := rng.randf_range(8.0, 16.0)
				var offset := rng.randf_range(-block_size * 0.3, block_size * 0.3)

				if cable_type == 0:
					# Cable across Z-street (east-west direction)
					var cx := cell_x + block_size * 0.5 + street_width * 0.5
					var cz := cell_z + offset
					# Main span
					var cable := MeshInstance3D.new()
					var cable_mesh := BoxMesh.new()
					cable_mesh.size = Vector3(street_width * 0.9, 0.02, 0.02)
					cable.mesh = cable_mesh
					cable.position = Vector3(cx, cable_y, cz)
					cable.set_surface_override_material(0, wire_mat)
					add_child(cable)
					# Slight sag in middle (second segment angled down)
					var sag := MeshInstance3D.new()
					var sag_mesh := BoxMesh.new()
					sag_mesh.size = Vector3(street_width * 0.4, 0.02, 0.02)
					sag.mesh = sag_mesh
					sag.position = Vector3(cx, cable_y - 0.3, cz)
					sag.set_surface_override_material(0, wire_mat)
					add_child(sag)
				else:
					# Cable across X-street (north-south direction)
					var cx := cell_x + offset
					var cz := cell_z + block_size * 0.5 + street_width * 0.5
					var cable := MeshInstance3D.new()
					var cable_mesh := BoxMesh.new()
					cable_mesh.size = Vector3(0.02, 0.02, street_width * 0.9)
					cable.mesh = cable_mesh
					cable.position = Vector3(cx, cable_y, cz)
					cable.set_surface_override_material(0, wire_mat)
					add_child(cable)
					var sag := MeshInstance3D.new()
					var sag_mesh := BoxMesh.new()
					sag_mesh.size = Vector3(0.02, 0.02, street_width * 0.4)
					sag.mesh = sag_mesh
					sag.position = Vector3(cx, cable_y - 0.3, cz)
					sag.set_surface_override_material(0, wire_mat)
					add_child(sag)

func _generate_skyline_warning_lights() -> void:
	# Add prominent red blinking lights to skyline buildings
	var rng := RandomNumberGenerator.new()
	rng.seed = 1900
	var red_col := Color(1.0, 0.0, 0.0)
	var red_mat := _make_ps1_material(red_col * 0.3, true, red_col, 5.0)

	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		# Only skyline buildings (very tall, dark material)
		if bsize.y < 40.0 or rng.randf() > 0.4:
			continue

		var roof_y := bsize.y * 0.5
		var blinker := MeshInstance3D.new()
		var blinker_mesh := SphereMesh.new()
		blinker_mesh.radius = 0.2
		blinker_mesh.height = 0.4
		blinker.mesh = blinker_mesh
		blinker.position = Vector3(0, roof_y + 0.3, 0)
		blinker.set_surface_override_material(0, red_mat)
		mi.add_child(blinker)

		var light := OmniLight3D.new()
		light.light_color = red_col
		light.light_energy = 3.0
		light.omni_range = 15.0
		light.omni_attenuation = 1.2
		light.shadow_enabled = false
		light.position = blinker.position
		mi.add_child(light)

		flickering_lights.append({
			"node": light,
			"mesh": blinker,
			"base_energy": 3.0,
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(1.5, 2.5),
			"style": "blink",
		})

func _generate_holographic_signs() -> void:
	# Floating semi-transparent kanji text above some buildings
	var rng := RandomNumberGenerator.new()
	rng.seed = 2000

	if not neon_font:
		return

	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 20.0 or rng.randf() > 0.08:  # 8% of tall buildings
			continue

		var neon_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
		var holo_text := NEON_TEXTS[rng.randi_range(0, NEON_TEXTS.size() - 1)]
		var roof_y := bsize.y * 0.5

		var label := Label3D.new()
		label.text = holo_text
		label.font = neon_font
		label.font_size = rng.randi_range(120, 200)
		label.pixel_size = 0.01
		label.modulate = Color(neon_col.r, neon_col.g, neon_col.b, 0.5)
		label.outline_modulate = Color(neon_col.r, neon_col.g, neon_col.b, 0.3)
		label.outline_size = 4
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		var float_height := rng.randf_range(3.0, 6.0)
		label.position = Vector3(0, roof_y + float_height, 0)
		mi.add_child(label)

		holo_signs.append({
			"node": label,
			"base_y": label.position.y,
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(0.5, 1.5),
		})

func _generate_phone_booths() -> void:
	# Enclosed glass/metal boxes on sidewalks with interior light
	var rng := RandomNumberGenerator.new()
	rng.seed = 2100
	var cell_stride := block_size + street_width
	var frame_mat := _make_ps1_material(Color(0.15, 0.15, 0.18))
	var glass_mat := _make_ps1_material(Color(0.2, 0.3, 0.4) * 0.3, true,
		Color(0.3, 0.4, 0.5), 0.5)

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.15:  # 15% of blocks
				continue
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride

			var side := rng.randi_range(0, 1)
			var bx: float
			var bz: float
			if side == 0:
				bx = cell_x + block_size * 0.5 + 1.2
				bz = cell_z + rng.randf_range(-block_size * 0.3, block_size * 0.3)
			else:
				bx = cell_x + rng.randf_range(-block_size * 0.3, block_size * 0.3)
				bz = cell_z + block_size * 0.5 + 1.2

			var booth := Node3D.new()
			booth.position = Vector3(bx, 0, bz)

			# Frame (vertical pillars at corners)
			for fx in [-0.4, 0.4]:
				for fz in [-0.4, 0.4]:
					var pillar := MeshInstance3D.new()
					var pillar_mesh := BoxMesh.new()
					pillar_mesh.size = Vector3(0.06, 2.4, 0.06)
					pillar.mesh = pillar_mesh
					pillar.position = Vector3(fx, 1.2, fz)
					pillar.set_surface_override_material(0, frame_mat)
					booth.add_child(pillar)

			# Roof
			var roof := MeshInstance3D.new()
			var roof_mesh := BoxMesh.new()
			roof_mesh.size = Vector3(0.9, 0.06, 0.9)
			roof.mesh = roof_mesh
			roof.position = Vector3(0, 2.4, 0)
			roof.set_surface_override_material(0, frame_mat)
			booth.add_child(roof)

			# Glass panels (3 sides, front open)
			for panel_face in [0, 1, 2]:
				var panel := MeshInstance3D.new()
				var panel_mesh := QuadMesh.new()
				panel_mesh.size = Vector2(0.8, 2.2)
				panel.mesh = panel_mesh
				panel.set_surface_override_material(0, glass_mat)
				match panel_face:
					0:  # back
						panel.position = Vector3(0, 1.2, -0.4)
						panel.rotation.y = PI
					1:  # left
						panel.position = Vector3(-0.4, 1.2, 0)
						panel.rotation.y = -PI * 0.5
					2:  # right
						panel.position = Vector3(0.4, 1.2, 0)
						panel.rotation.y = PI * 0.5
				booth.add_child(panel)

			# Screen panel inside (glowing)
			var screen_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
			var screen := MeshInstance3D.new()
			var screen_mesh := QuadMesh.new()
			screen_mesh.size = Vector2(0.4, 0.3)
			screen.mesh = screen_mesh
			screen.position = Vector3(0, 1.5, -0.35)
			screen.set_surface_override_material(0,
				_make_ps1_material(screen_col * 0.3, true, screen_col, 2.5))
			booth.add_child(screen)

			# Interior light
			var interior := OmniLight3D.new()
			interior.light_color = Color(0.8, 0.9, 1.0)
			interior.light_energy = 1.0
			interior.omni_range = 3.0
			interior.omni_attenuation = 1.5
			interior.shadow_enabled = false
			interior.position = Vector3(0, 2.0, 0)
			booth.add_child(interior)

			# Collision
			var sb := StaticBody3D.new()
			var col := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.9, 2.4, 0.9)
			col.shape = shape
			col.position = Vector3(0, 1.2, 0)
			sb.add_child(col)
			booth.add_child(sb)

			add_child(booth)

func _generate_wind_debris() -> void:
	# Particles that drift horizontally through streets like blowing trash/papers
	var rng := RandomNumberGenerator.new()
	rng.seed = 2200
	var cell_stride := block_size + street_width

	# Place a few debris emitters around the city
	for _i in range(8):
		var gx := rng.randi_range(-grid_size + 1, grid_size - 2)
		var gz := rng.randi_range(-grid_size + 1, grid_size - 2)
		var cell_x := gx * cell_stride
		var cell_z := gz * cell_stride

		var debris := GPUParticles3D.new()
		debris.position = Vector3(cell_x, 0.5, cell_z)
		debris.amount = 8
		debris.lifetime = 6.0
		debris.visibility_aabb = AABB(Vector3(-30, -2, -30), Vector3(60, 10, 60))

		var mat := ParticleProcessMaterial.new()
		mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mat.emission_box_extents = Vector3(20, 0.5, 20)
		# Wind direction (diagonal drift)
		mat.direction = Vector3(0.7, 0.2, 0.3).normalized()
		mat.spread = 25.0
		mat.initial_velocity_min = 1.5
		mat.initial_velocity_max = 3.5
		mat.gravity = Vector3(0, -0.3, 0)
		mat.damping_min = 0.5
		mat.damping_max = 1.5
		mat.angular_velocity_min = -180.0
		mat.angular_velocity_max = 180.0
		mat.scale_min = 0.15
		mat.scale_max = 0.4
		mat.color = Color(0.3, 0.28, 0.22, 0.4)
		debris.process_material = mat

		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.15, 0.1)
		debris.draw_pass_1 = mesh

		add_child(debris)

func _generate_utility_boxes() -> void:
	# Small transformer/utility boxes on street light and telephone poles
	var rng := RandomNumberGenerator.new()
	rng.seed = 2300
	var box_mat := _make_ps1_material(Color(0.15, 0.18, 0.14))

	# Iterate through Node3D children (street lights and telephone poles are Node3D)
	for child in get_children():
		if not child is Node3D:
			continue
		# Skip MeshInstance3D children (buildings) - we want Node3D groups (lamps, poles)
		if child is MeshInstance3D:
			continue
		# Check if this node has a cylinder child (pole indicator)
		var has_pole := false
		for sub in child.get_children():
			if sub is MeshInstance3D:
				var mi := sub as MeshInstance3D
				if mi.mesh is CylinderMesh:
					has_pole = true
					break
		if not has_pole or rng.randf() > 0.25:  # 25% of poles
			continue

		var box := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.3, 0.4, 0.25)
		box.mesh = box_mesh
		box.position = Vector3(0.15, rng.randf_range(2.5, 4.0), 0)
		box.set_surface_override_material(0, box_mat)
		child.add_child(box)

func _generate_street_furniture() -> void:
	# Benches and newspaper stands on sidewalks
	var rng := RandomNumberGenerator.new()
	rng.seed = 2400
	var cell_stride := block_size + street_width
	var bench_mat := _make_ps1_material(Color(0.15, 0.12, 0.08))
	var metal_mat := _make_ps1_material(Color(0.2, 0.2, 0.22))
	var news_mat := _make_ps1_material(Color(0.18, 0.22, 0.15))

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride

			# Bench (20% of blocks)
			if rng.randf() < 0.2:
				var side := rng.randi_range(0, 1)
				var bx: float
				var bz: float
				var rot_y := 0.0
				if side == 0:
					bx = cell_x + block_size * 0.5 + 0.8
					bz = cell_z + rng.randf_range(-block_size * 0.3, block_size * 0.3)
					rot_y = PI * 0.5
				else:
					bx = cell_x + rng.randf_range(-block_size * 0.3, block_size * 0.3)
					bz = cell_z + block_size * 0.5 + 0.8
				var bench := Node3D.new()
				bench.position = Vector3(bx, 0, bz)
				bench.rotation.y = rot_y

				# Seat
				var seat := MeshInstance3D.new()
				var seat_mesh := BoxMesh.new()
				seat_mesh.size = Vector3(1.5, 0.06, 0.4)
				seat.mesh = seat_mesh
				seat.position = Vector3(0, 0.45, 0)
				seat.set_surface_override_material(0, bench_mat)
				bench.add_child(seat)

				# Back
				var back := MeshInstance3D.new()
				var back_mesh := BoxMesh.new()
				back_mesh.size = Vector3(1.5, 0.5, 0.04)
				back.mesh = back_mesh
				back.position = Vector3(0, 0.7, -0.18)
				back.set_surface_override_material(0, bench_mat)
				bench.add_child(back)

				# Legs
				for lx in [-0.6, 0.6]:
					var leg := MeshInstance3D.new()
					var leg_mesh := BoxMesh.new()
					leg_mesh.size = Vector3(0.04, 0.45, 0.35)
					leg.mesh = leg_mesh
					leg.position = Vector3(lx, 0.225, 0)
					leg.set_surface_override_material(0, metal_mat)
					bench.add_child(leg)

				add_child(bench)

			# Newspaper stand (15% of blocks)
			if rng.randf() < 0.15:
				var side := rng.randi_range(0, 1)
				var nx: float
				var nz: float
				if side == 0:
					nx = cell_x + block_size * 0.5 + 1.5
					nz = cell_z + rng.randf_range(-block_size * 0.2, block_size * 0.2)
				else:
					nx = cell_x + rng.randf_range(-block_size * 0.2, block_size * 0.2)
					nz = cell_z + block_size * 0.5 + 1.5

				var stand := MeshInstance3D.new()
				var stand_mesh := BoxMesh.new()
				stand_mesh.size = Vector3(0.5, 1.0, 0.4)
				stand.mesh = stand_mesh
				stand.position = Vector3(nx, 0.5, nz)
				stand.set_surface_override_material(0, news_mat)
				add_child(stand)

func _generate_construction_zones() -> void:
	# Orange barriers and traffic cones on some streets
	var rng := RandomNumberGenerator.new()
	rng.seed = 2500
	var cell_stride := block_size + street_width
	var orange := Color(1.0, 0.5, 0.0)
	var cone_mat := _make_ps1_material(orange * 0.8, true, orange, 1.0)
	var barrier_mat := _make_ps1_material(orange * 0.4, true, orange, 1.5)
	var stripe_mat := _make_ps1_material(Color(0.9, 0.9, 0.9) * 0.5, true,
		Color(0.9, 0.9, 0.9), 0.5)

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.1:  # 10% of blocks
				continue
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride

			# Place at street edge
			var cx := cell_x + block_size * 0.5 + street_width * 0.3
			var cz := cell_z + rng.randf_range(-block_size * 0.2, block_size * 0.2)

			# Barrier
			var barrier := Node3D.new()
			barrier.position = Vector3(cx, 0, cz)

			var bar := MeshInstance3D.new()
			var bar_mesh := BoxMesh.new()
			bar_mesh.size = Vector3(2.0, 0.8, 0.15)
			bar.mesh = bar_mesh
			bar.position = Vector3(0, 0.8, 0)
			bar.set_surface_override_material(0, barrier_mat)
			barrier.add_child(bar)

			# White reflective stripe
			var stripe := MeshInstance3D.new()
			var stripe_mesh := BoxMesh.new()
			stripe_mesh.size = Vector3(2.0, 0.12, 0.16)
			stripe.mesh = stripe_mesh
			stripe.position = Vector3(0, 0.9, 0)
			stripe.set_surface_override_material(0, stripe_mat)
			barrier.add_child(stripe)

			# Support legs
			for lx in [-0.8, 0.8]:
				var leg := MeshInstance3D.new()
				var leg_mesh := BoxMesh.new()
				leg_mesh.size = Vector3(0.06, 0.8, 0.3)
				leg.mesh = leg_mesh
				leg.position = Vector3(lx, 0.4, 0)
				leg.set_surface_override_material(0, _make_ps1_material(Color(0.15, 0.15, 0.18)))
				barrier.add_child(leg)

			add_child(barrier)

			# 2-4 traffic cones nearby
			var num_cones := rng.randi_range(2, 4)
			for _c in range(num_cones):
				var cone := MeshInstance3D.new()
				var cone_mesh := CylinderMesh.new()
				cone_mesh.top_radius = 0.02
				cone_mesh.bottom_radius = 0.12
				cone_mesh.height = 0.5
				cone.mesh = cone_mesh
				cone.position = Vector3(
					cx + rng.randf_range(-2.0, 2.0),
					0.25,
					cz + rng.randf_range(-1.5, 1.5)
				)
				cone.set_surface_override_material(0, cone_mat)
				add_child(cone)

func _generate_drain_grates() -> void:
	# Metal grates along curbs for drainage
	var rng := RandomNumberGenerator.new()
	rng.seed = 2600
	var cell_stride := block_size + street_width
	var grate_mat := _make_ps1_material(Color(0.12, 0.12, 0.1))

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride
			var num_grates := rng.randi_range(1, 3)
			for _g in range(num_grates):
				var side := rng.randi_range(0, 1)
				var grate := MeshInstance3D.new()
				var grate_mesh := BoxMesh.new()
				grate_mesh.size = Vector3(0.6, 0.02, 0.4)
				grate.mesh = grate_mesh
				grate.set_surface_override_material(0, grate_mat)

				if side == 0:
					grate.position = Vector3(
						cell_x + block_size * 0.5 + 2.1,
						0.16,
						cell_z + rng.randf_range(-block_size * 0.4, block_size * 0.4)
					)
				else:
					grate.position = Vector3(
						cell_x + rng.randf_range(-block_size * 0.4, block_size * 0.4),
						0.16,
						cell_z + block_size * 0.5 + 2.1
					)
				add_child(grate)

func _generate_building_setbacks() -> void:
	# Add tiered upper sections to tall buildings (setback architecture)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2700

	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 22.0 or rng.randf() > 0.25:  # 25% of tall buildings
			continue

		# Add a narrower upper tier
		var tier_w := bsize.x * rng.randf_range(0.5, 0.75)
		var tier_d := bsize.z * rng.randf_range(0.5, 0.75)
		var tier_h := rng.randf_range(5.0, 12.0)
		var roof_y := bsize.y * 0.5

		var tier := MeshInstance3D.new()
		var tier_mesh := BoxMesh.new()
		tier_mesh.size = Vector3(tier_w, tier_h, tier_d)
		tier.mesh = tier_mesh
		tier.position = Vector3(0, roof_y + tier_h * 0.5, 0)
		var darkness := rng.randf_range(0.25, 0.45)
		tier.set_surface_override_material(0,
			_make_ps1_material(Color(darkness, darkness, darkness + 0.05)))
		mi.add_child(tier)

		# A few windows on the upper tier
		var num_wins := rng.randi_range(2, 6)
		for _w in range(num_wins):
			var win := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(1.0, 1.2)
			win.mesh = quad
			var wy := rng.randf_range(-tier_h * 0.3, tier_h * 0.3)
			var face := rng.randi_range(0, 3)
			match face:
				0:
					win.position = Vector3(rng.randf_range(-tier_w * 0.3, tier_w * 0.3), wy, tier_d * 0.51)
				1:
					win.position = Vector3(rng.randf_range(-tier_w * 0.3, tier_w * 0.3), wy, -tier_d * 0.51)
					win.rotation.y = PI
				2:
					win.position = Vector3(tier_w * 0.51, wy, rng.randf_range(-tier_d * 0.3, tier_d * 0.3))
					win.rotation.y = PI * 0.5
				3:
					win.position = Vector3(-tier_w * 0.51, wy, rng.randf_range(-tier_d * 0.3, tier_d * 0.3))
					win.rotation.y = -PI * 0.5
			var wc := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
			win.set_surface_override_material(0,
				_make_ps1_material(wc * 0.2, true, wc, rng.randf_range(2.0, 4.0)))
			tier.add_child(win)

		# Ledge at the setback (horizontal strip)
		var ledge := MeshInstance3D.new()
		var ledge_mesh := BoxMesh.new()
		ledge_mesh.size = Vector3(bsize.x + 0.3, 0.15, bsize.z + 0.3)
		ledge.mesh = ledge_mesh
		ledge.position = Vector3(0, roof_y + 0.075, 0)
		ledge.set_surface_override_material(0,
			_make_ps1_material(Color(darkness * 0.8, darkness * 0.8, darkness * 0.8 + 0.03)))
		mi.add_child(ledge)

func _generate_exposed_pipes() -> void:
	# Vertical and horizontal pipes on building walls
	var rng := RandomNumberGenerator.new()
	rng.seed = 2800
	var pipe_mat := _make_ps1_material(Color(0.22, 0.22, 0.2))

	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 12.0 or rng.randf() > 0.2:  # 20% of buildings
			continue

		var num_pipes := rng.randi_range(1, 3)
		for _p in range(num_pipes):
			var face := rng.randi_range(0, 3)
			var pipe_height := bsize.y * rng.randf_range(0.5, 0.9)

			# Vertical pipe
			var pipe := MeshInstance3D.new()
			var pipe_mesh := CylinderMesh.new()
			pipe_mesh.top_radius = 0.04
			pipe_mesh.bottom_radius = 0.04
			pipe_mesh.height = pipe_height
			pipe.mesh = pipe_mesh
			pipe.set_surface_override_material(0, pipe_mat)

			var pipe_y := -bsize.y * 0.5 + pipe_height * 0.5
			match face:
				0:
					pipe.position = Vector3(rng.randf_range(-bsize.x * 0.3, bsize.x * 0.3),
						pipe_y, bsize.z * 0.51)
				1:
					pipe.position = Vector3(rng.randf_range(-bsize.x * 0.3, bsize.x * 0.3),
						pipe_y, -bsize.z * 0.51)
				2:
					pipe.position = Vector3(bsize.x * 0.51, pipe_y,
						rng.randf_range(-bsize.z * 0.3, bsize.z * 0.3))
				3:
					pipe.position = Vector3(-bsize.x * 0.51, pipe_y,
						rng.randf_range(-bsize.z * 0.3, bsize.z * 0.3))
			mi.add_child(pipe)

			# Horizontal elbow at top (short horizontal segment)
			var elbow := MeshInstance3D.new()
			var elbow_mesh := CylinderMesh.new()
			elbow_mesh.top_radius = 0.04
			elbow_mesh.bottom_radius = 0.04
			elbow_mesh.height = 0.4
			elbow.mesh = elbow_mesh
			elbow.rotation.z = PI * 0.5
			elbow.position = pipe.position + Vector3(0, pipe_height * 0.5 - 0.1, 0)
			elbow.set_surface_override_material(0, pipe_mat)
			mi.add_child(elbow)

func _generate_security_cameras() -> void:
	# Small camera boxes on building corners
	var rng := RandomNumberGenerator.new()
	rng.seed = 2900
	var cam_mat := _make_ps1_material(Color(0.15, 0.15, 0.18))
	var red_col := Color(1.0, 0.0, 0.0)
	var led_mat := _make_ps1_material(red_col * 0.3, true, red_col, 2.0)

	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 10.0 or rng.randf() > 0.2:  # 20% of buildings
			continue

		var cam_y := rng.randf_range(bsize.y * 0.1, bsize.y * 0.35)
		var corner := rng.randi_range(0, 3)

		var camera_node := Node3D.new()
		match corner:
			0: camera_node.position = Vector3(bsize.x * 0.5, cam_y, bsize.z * 0.5)
			1: camera_node.position = Vector3(-bsize.x * 0.5, cam_y, bsize.z * 0.5)
			2: camera_node.position = Vector3(bsize.x * 0.5, cam_y, -bsize.z * 0.5)
			3: camera_node.position = Vector3(-bsize.x * 0.5, cam_y, -bsize.z * 0.5)

		# Mount bracket
		var bracket := MeshInstance3D.new()
		var bracket_mesh := BoxMesh.new()
		bracket_mesh.size = Vector3(0.15, 0.08, 0.4)
		bracket.mesh = bracket_mesh
		bracket.position = Vector3(0, 0, 0.15)
		bracket.set_surface_override_material(0, cam_mat)
		camera_node.add_child(bracket)

		# Camera body
		var body := MeshInstance3D.new()
		var body_mesh := BoxMesh.new()
		body_mesh.size = Vector3(0.12, 0.1, 0.2)
		body.mesh = body_mesh
		body.position = Vector3(0, -0.05, 0.35)
		body.set_surface_override_material(0, cam_mat)
		camera_node.add_child(body)

		# Red LED
		var led := MeshInstance3D.new()
		var led_mesh := SphereMesh.new()
		led_mesh.radius = 0.025
		led_mesh.height = 0.05
		led.mesh = led_mesh
		led.position = Vector3(0, -0.02, 0.46)
		led.set_surface_override_material(0, led_mat)
		camera_node.add_child(led)

		mi.add_child(camera_node)

		# Register LED for blinking
		var led_light := OmniLight3D.new()
		led_light.light_color = red_col
		led_light.light_energy = 0.5
		led_light.omni_range = 2.0
		led_light.omni_attenuation = 1.5
		led_light.shadow_enabled = false
		led_light.position = led.position
		camera_node.add_child(led_light)

		flickering_lights.append({
			"node": led_light,
			"mesh": led,
			"base_energy": 0.5,
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(2.0, 4.0),
			"style": "blink",
		})

func _generate_awning_lights() -> void:
	# Add flickering fluorescent tubes under storefront awnings
	# We iterate through the Node3D storefront buildings looking for awning meshes
	var rng := RandomNumberGenerator.new()
	rng.seed = 3000
	var tube_color := Color(1.0, 0.95, 0.85)

	for child in get_children():
		if not child is Node3D:
			continue
		# Storefronts are Node3D (not MeshInstance3D)
		if child is MeshInstance3D:
			continue
		# Check if this has an OmniLight3D child (storefronts have interior lights)
		var has_interior_light := false
		for sub in child.get_children():
			if sub is OmniLight3D:
				has_interior_light = true
				break
		if not has_interior_light or rng.randf() > 0.5:
			continue

		# Add a fluorescent tube under the awning area
		var tube := MeshInstance3D.new()
		var tube_mesh := BoxMesh.new()
		tube_mesh.size = Vector3(1.5, 0.04, 0.04)
		tube.mesh = tube_mesh
		# Position: try to find the awning position, or use a reasonable default
		tube.position = Vector3(0, 3.2, child.position.z + 0.5) if child.position.z > 0 else Vector3(0, 3.2, 0.5)
		# Use local coordinates relative to the storefront
		tube.position = Vector3(0, 2.8, 0)
		tube.set_surface_override_material(0,
			_make_ps1_material(tube_color * 0.3, true, tube_color, 3.0))
		child.add_child(tube)

		var tube_light := OmniLight3D.new()
		tube_light.light_color = tube_color
		tube_light.light_energy = 2.0
		tube_light.omni_range = 5.0
		tube_light.omni_attenuation = 1.5
		tube_light.shadow_enabled = false
		tube_light.position = tube.position
		child.add_child(tube_light)

		# Register for buzzing flicker
		flickering_lights.append({
			"node": tube_light,
			"mesh": tube,
			"base_energy": 2.0,
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(10.0, 18.0),
			"style": "buzz",
		})

func _generate_chain_link_fences() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3100
	var cell_stride := block_size + street_width
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.12:
				continue
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride
			# Place fence along one edge of the block
			var fence_h := rng.randf_range(2.0, 3.5)
			var fence_len := rng.randf_range(6.0, block_size * 0.8)
			var along_x := rng.randf() < 0.5
			var offset := rng.randf_range(-block_size * 0.3, block_size * 0.3)
			var fence_pos: Vector3
			if along_x:
				fence_pos = Vector3(cell_x + offset, fence_h * 0.5, cell_z + block_size * 0.45)
			else:
				fence_pos = Vector3(cell_x + block_size * 0.45, fence_h * 0.5, cell_z + offset)
			# Main fence panel (semi-transparent dark gray)
			var panel := MeshInstance3D.new()
			var panel_mesh := BoxMesh.new()
			if along_x:
				panel_mesh.size = Vector3(fence_len, fence_h, 0.05)
			else:
				panel_mesh.size = Vector3(0.05, fence_h, fence_len)
			panel.mesh = panel_mesh
			panel.position = fence_pos
			var fence_mat := _make_ps1_material(Color(0.35, 0.35, 0.38))
			fence_mat.set_shader_parameter("albedo_color", Color(0.35, 0.35, 0.38, 0.7))
			panel.set_surface_override_material(0, fence_mat)
			add_child(panel)
			# Top rail (thin cylinder-like bar)
			var rail := MeshInstance3D.new()
			var rail_mesh := BoxMesh.new()
			if along_x:
				rail_mesh.size = Vector3(fence_len, 0.06, 0.06)
			else:
				rail_mesh.size = Vector3(0.06, 0.06, fence_len)
			rail.mesh = rail_mesh
			rail.position = fence_pos + Vector3(0, fence_h * 0.5, 0)
			rail.set_surface_override_material(0, _make_ps1_material(Color(0.4, 0.4, 0.45)))
			add_child(rail)
			# Two posts at ends
			for end in [-1.0, 1.0]:
				var post := MeshInstance3D.new()
				var post_mesh := BoxMesh.new()
				post_mesh.size = Vector3(0.08, fence_h + 0.3, 0.08)
				post.mesh = post_mesh
				var post_offset: Vector3
				if along_x:
					post_offset = Vector3(fence_len * 0.5 * end, 0.15, 0)
				else:
					post_offset = Vector3(0, 0.15, fence_len * 0.5 * end)
				post.position = fence_pos + post_offset
				post.set_surface_override_material(0, _make_ps1_material(Color(0.4, 0.4, 0.45)))
				add_child(post)

func _generate_trash_bags() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3200
	for child in get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if not (mi.mesh is BoxMesh):
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 5.0 or bsize.y > 50.0:
			continue
		if rng.randf() > 0.18:
			continue
		# Place a cluster of trash bags at building base
		var face := rng.randi_range(0, 3)
		var bag_x := mi.position.x
		var bag_z := mi.position.z
		match face:
			0: bag_z += bsize.z * 0.5 + 0.4
			1: bag_z -= bsize.z * 0.5 + 0.4
			2: bag_x += bsize.x * 0.5 + 0.4
			3: bag_x -= bsize.x * 0.5 + 0.4
		var num_bags := rng.randi_range(2, 5)
		for _b in range(num_bags):
			var bag := MeshInstance3D.new()
			var bag_mesh := SphereMesh.new()
			var sx := rng.randf_range(0.3, 0.6)
			var sy := rng.randf_range(0.3, 0.7)
			bag_mesh.radius = sx
			bag_mesh.height = sy * 2.0
			bag.mesh = bag_mesh
			var scatter_x := rng.randf_range(-0.6, 0.6)
			var scatter_z := rng.randf_range(-0.6, 0.6)
			bag.position = Vector3(bag_x + scatter_x, sy * 0.5, bag_z + scatter_z)
			# Black or dark green bags
			var bag_color: Color
			if rng.randf() < 0.6:
				bag_color = Color(0.05, 0.05, 0.05)
			else:
				bag_color = Color(0.03, 0.1, 0.03)
			bag.set_surface_override_material(0, _make_ps1_material(bag_color))
			add_child(bag)

func _generate_bus_stops() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3300
	var cell_stride := block_size + street_width
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.08:
				continue
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride
			var along_x := rng.randf() < 0.5
			var shelter := Node3D.new()
			var sx: float
			var sz: float
			if along_x:
				sx = cell_x + block_size * 0.5 + street_width * 0.3
				sz = cell_z + rng.randf_range(-block_size * 0.2, block_size * 0.2)
			else:
				sx = cell_x + rng.randf_range(-block_size * 0.2, block_size * 0.2)
				sz = cell_z + block_size * 0.5 + street_width * 0.3
			shelter.position = Vector3(sx, 0, sz)
			# Roof
			var roof := MeshInstance3D.new()
			var roof_mesh := BoxMesh.new()
			roof_mesh.size = Vector3(3.0, 0.08, 1.8)
			roof.mesh = roof_mesh
			roof.position = Vector3(0, 2.8, 0)
			roof.set_surface_override_material(0, _make_ps1_material(Color(0.2, 0.25, 0.3, 0.5)))
			shelter.add_child(roof)
			# Two support poles
			for side in [-1.0, 1.0]:
				var pole := MeshInstance3D.new()
				var pole_mesh := BoxMesh.new()
				pole_mesh.size = Vector3(0.06, 2.8, 0.06)
				pole.mesh = pole_mesh
				pole.position = Vector3(1.3 * side, 1.4, 0.8)
				pole.set_surface_override_material(0, _make_ps1_material(Color(0.4, 0.4, 0.45)))
				shelter.add_child(pole)
			# Back panel (translucent)
			var back := MeshInstance3D.new()
			var back_mesh := BoxMesh.new()
			back_mesh.size = Vector3(3.0, 2.0, 0.04)
			back.mesh = back_mesh
			back.position = Vector3(0, 1.2, -0.85)
			back.set_surface_override_material(0, _make_ps1_material(Color(0.2, 0.25, 0.35, 0.4)))
			shelter.add_child(back)
			# Bench
			var bench := MeshInstance3D.new()
			var bench_mesh := BoxMesh.new()
			bench_mesh.size = Vector3(2.0, 0.08, 0.5)
			bench.mesh = bench_mesh
			bench.position = Vector3(0, 0.55, -0.5)
			bench.set_surface_override_material(0, _make_ps1_material(Color(0.3, 0.25, 0.15)))
			shelter.add_child(bench)
			# Route sign (emissive)
			var sign_node := MeshInstance3D.new()
			var sign_mesh := BoxMesh.new()
			sign_mesh.size = Vector3(0.6, 0.4, 0.04)
			sign_node.mesh = sign_mesh
			sign_node.position = Vector3(1.3, 2.2, 0.82)
			var sign_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
			sign_node.set_surface_override_material(0,
				_make_ps1_material(sign_col, true, sign_col, 2.5))
			shelter.add_child(sign_node)
			# Kanji route text
			if neon_font:
				var label := Label3D.new()
				label.text = NEON_TEXTS[rng.randi_range(0, NEON_TEXTS.size() - 1)]
				label.font = neon_font
				label.font_size = 32
				label.pixel_size = 0.008
				label.modulate = sign_col
				label.outline_modulate = Color(0, 0, 0, 0.6)
				label.outline_size = 4
				label.position = Vector3(1.3, 2.2, 0.86)
				label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				shelter.add_child(label)
			add_child(shelter)

func _generate_fire_hydrants() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3400
	var cell_stride := block_size + street_width
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.18:
				continue
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride
			var side := rng.randi_range(0, 3)
			var hx: float
			var hz: float
			match side:
				0:
					hx = cell_x + block_size * 0.5 + 1.0
					hz = cell_z + rng.randf_range(-block_size * 0.3, block_size * 0.3)
				1:
					hx = cell_x - block_size * 0.5 - 1.0
					hz = cell_z + rng.randf_range(-block_size * 0.3, block_size * 0.3)
				2:
					hx = cell_x + rng.randf_range(-block_size * 0.3, block_size * 0.3)
					hz = cell_z + block_size * 0.5 + 1.0
				_:
					hx = cell_x + rng.randf_range(-block_size * 0.3, block_size * 0.3)
					hz = cell_z - block_size * 0.5 - 1.0
			var hydrant := Node3D.new()
			hydrant.position = Vector3(hx, 0, hz)
			# Body (main cylinder - box approximation)
			var body := MeshInstance3D.new()
			var body_mesh := BoxMesh.new()
			body_mesh.size = Vector3(0.3, 0.6, 0.3)
			body.mesh = body_mesh
			body.position = Vector3(0, 0.3, 0)
			var hydrant_col := Color(0.7, 0.15, 0.1) if rng.randf() < 0.6 else Color(0.7, 0.6, 0.1)
			body.set_surface_override_material(0, _make_ps1_material(hydrant_col))
			hydrant.add_child(body)
			# Cap top
			var cap := MeshInstance3D.new()
			var cap_mesh := BoxMesh.new()
			cap_mesh.size = Vector3(0.35, 0.12, 0.35)
			cap.mesh = cap_mesh
			cap.position = Vector3(0, 0.65, 0)
			cap.set_surface_override_material(0, _make_ps1_material(hydrant_col * 0.8))
			hydrant.add_child(cap)
			# Side nozzles
			for nz_side in [-1.0, 1.0]:
				var nozzle := MeshInstance3D.new()
				var nozzle_mesh := BoxMesh.new()
				nozzle_mesh.size = Vector3(0.18, 0.12, 0.12)
				nozzle.mesh = nozzle_mesh
				nozzle.position = Vector3(0.2 * nz_side, 0.4, 0)
				nozzle.set_surface_override_material(0, _make_ps1_material(hydrant_col * 0.7))
				hydrant.add_child(nozzle)
			add_child(hydrant)

func _generate_water_towers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3500
	for child in get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if not (mi.mesh is BoxMesh):
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 28.0:
			continue
		if rng.randf() > 0.25:
			continue
		var tower := Node3D.new()
		tower.position = Vector3(
			mi.position.x + rng.randf_range(-bsize.x * 0.2, bsize.x * 0.2),
			mi.position.y + bsize.y * 0.5,
			mi.position.z + rng.randf_range(-bsize.z * 0.2, bsize.z * 0.2)
		)
		# Tank body (cylinder approximated as octagonal - just use a box for PS1 vibe)
		var tank := MeshInstance3D.new()
		var tank_mesh := CylinderMesh.new()
		tank_mesh.top_radius = 1.2
		tank_mesh.bottom_radius = 1.2
		tank_mesh.height = 2.5
		tank_mesh.radial_segments = 8
		tank.mesh = tank_mesh
		tank.position = Vector3(0, 3.5, 0)
		var wood_col := Color(0.25, 0.15, 0.08)
		tank.set_surface_override_material(0, _make_ps1_material(wood_col))
		tower.add_child(tank)
		# Conical roof
		var roof := MeshInstance3D.new()
		var roof_mesh := CylinderMesh.new()
		roof_mesh.top_radius = 0.1
		roof_mesh.bottom_radius = 1.4
		roof_mesh.height = 0.8
		roof_mesh.radial_segments = 8
		roof.mesh = roof_mesh
		roof.position = Vector3(0, 5.15, 0)
		roof.set_surface_override_material(0, _make_ps1_material(Color(0.15, 0.15, 0.18)))
		tower.add_child(roof)
		# Support legs (4 posts)
		for lx in [-0.7, 0.7]:
			for lz in [-0.7, 0.7]:
				var leg := MeshInstance3D.new()
				var leg_mesh := BoxMesh.new()
				leg_mesh.size = Vector3(0.1, 2.2, 0.1)
				leg.mesh = leg_mesh
				leg.position = Vector3(lx, 1.1, lz)
				leg.set_surface_override_material(0, _make_ps1_material(Color(0.3, 0.3, 0.35)))
				tower.add_child(leg)
		# Cross braces
		var brace := MeshInstance3D.new()
		var brace_mesh := BoxMesh.new()
		brace_mesh.size = Vector3(1.4, 0.06, 0.06)
		brace.mesh = brace_mesh
		brace.position = Vector3(0, 1.5, 0)
		brace.set_surface_override_material(0, _make_ps1_material(Color(0.3, 0.3, 0.35)))
		tower.add_child(brace)
		var brace2 := MeshInstance3D.new()
		var brace2_mesh := BoxMesh.new()
		brace2_mesh.size = Vector3(0.06, 0.06, 1.4)
		brace2.mesh = brace2_mesh
		brace2.position = Vector3(0, 1.5, 0)
		brace2.set_surface_override_material(0, _make_ps1_material(Color(0.3, 0.3, 0.35)))
		tower.add_child(brace2)
		add_child(tower)

func _generate_satellite_dishes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3600
	for child in get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if not (mi.mesh is BoxMesh):
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 18.0:
			continue
		if rng.randf() > 0.20:
			continue
		var dish_parent := Node3D.new()
		dish_parent.position = Vector3(
			mi.position.x + rng.randf_range(-bsize.x * 0.3, bsize.x * 0.3),
			mi.position.y + bsize.y * 0.5,
			mi.position.z + rng.randf_range(-bsize.z * 0.3, bsize.z * 0.3)
		)
		# Pole
		var pole := MeshInstance3D.new()
		var pole_mesh := BoxMesh.new()
		pole_mesh.size = Vector3(0.06, 1.2, 0.06)
		pole.mesh = pole_mesh
		pole.position = Vector3(0, 0.6, 0)
		pole.set_surface_override_material(0, _make_ps1_material(Color(0.4, 0.4, 0.45)))
		dish_parent.add_child(pole)
		# Dish (tilted cylinder disc)
		var dish := MeshInstance3D.new()
		var dish_mesh := CylinderMesh.new()
		dish_mesh.top_radius = 0.5
		dish_mesh.bottom_radius = 0.6
		dish_mesh.height = 0.12
		dish_mesh.radial_segments = 8
		dish.mesh = dish_mesh
		dish.position = Vector3(0, 1.2, 0.1)
		dish.rotation.x = deg_to_rad(rng.randf_range(30.0, 55.0))
		dish.rotation.y = rng.randf_range(0, TAU)
		dish.set_surface_override_material(0, _make_ps1_material(Color(0.6, 0.6, 0.65)))
		dish_parent.add_child(dish)
		# Small receiver arm
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.03, 0.03, 0.4)
		arm.mesh = arm_mesh
		arm.position = Vector3(0, 1.3, 0.3)
		arm.rotation.x = deg_to_rad(40.0)
		arm.set_surface_override_material(0, _make_ps1_material(Color(0.4, 0.4, 0.45)))
		dish_parent.add_child(arm)
		add_child(dish_parent)

func _setup_neon_flicker() -> void:
	# Register existing neon sign lights for flickering
	var rng := RandomNumberGenerator.new()
	rng.seed = 678
	# Walk through all children recursively looking for OmniLight3D nodes
	# that are children of Label3D or neon sign meshes
	_collect_neon_lights(self, rng)

func _collect_neon_lights(node: Node, rng: RandomNumberGenerator) -> void:
	for child in node.get_children():
		if child is OmniLight3D:
			var light := child as OmniLight3D
			# Only flicker neon-colored lights (not street lights or interiors)
			var is_neon := false
			for nc in neon_colors:
				if light.light_color.is_equal_approx(nc):
					is_neon = true
					break
			if is_neon and rng.randf() < 0.15:  # 15% of neon lights flicker
				flickering_lights.append({
					"node": light,
					"mesh": null,
					"base_energy": light.light_energy,
					"phase": rng.randf() * TAU,
					"speed": rng.randf_range(3.0, 12.0),
					"style": "flicker",
				})
		_collect_neon_lights(child, rng)

func _process(_delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0

	# Neon flickering and antenna blinking
	for data in flickering_lights:
		var light: OmniLight3D = data["node"]
		if not is_instance_valid(light):
			continue
		var phase: float = data["phase"]
		var speed: float = data["speed"]
		var base: float = data["base_energy"]
		var style: String = data["style"]

		if style == "blink":
			var val := sin(time * speed + phase)
			var on := 1.0 if val > 0.0 else 0.0
			light.light_energy = base * on
			var mesh_node = data["mesh"]
			if mesh_node and is_instance_valid(mesh_node):
				(mesh_node as MeshInstance3D).visible = val > 0.0
		elif style == "buzz":
			# Faulty sodium lamp: mostly on, occasional rapid flicker/dropout
			var buzz := sin(time * speed + phase) * sin(time * speed * 2.3 + phase * 0.7)
			var dropout := 1.0
			# Random-feeling dropouts (rapid off-on)
			if sin(time * speed * 5.0 + phase * 3.0) > 0.85:
				dropout = 0.05
			elif sin(time * speed * 7.0 + phase * 1.5) > 0.93:
				dropout = 0.3
			light.light_energy = base * (0.7 + 0.3 * buzz) * dropout
			var mesh_node = data["mesh"]
			if mesh_node and is_instance_valid(mesh_node):
				(mesh_node as MeshInstance3D).visible = dropout > 0.1
		else:
			var flick := sin(time * speed + phase) * sin(time * speed * 1.7 + phase * 0.5)
			var sputter := 1.0
			if sin(time * speed * 3.0 + phase * 2.0) > 0.92:
				sputter = 0.1
			light.light_energy = base * (0.5 + 0.5 * flick) * sputter

	# Traffic light cycling (10s cycle: 5s green, 1s yellow, 4s red)
	for tl_data in traffic_lights:
		var red_node: MeshInstance3D = tl_data["red"]
		var yellow_node: MeshInstance3D = tl_data["yellow"]
		var green_node: MeshInstance3D = tl_data["green"]
		if not is_instance_valid(red_node):
			continue
		var phase: float = tl_data["phase"]
		var cycle := fmod(time + phase, 10.0)
		if cycle < 5.0:
			# Green
			red_node.set_surface_override_material(0, tl_data["red_mat_off"])
			yellow_node.set_surface_override_material(0, tl_data["yellow_mat_off"])
			green_node.set_surface_override_material(0, tl_data["green_mat_on"])
		elif cycle < 6.0:
			# Yellow
			red_node.set_surface_override_material(0, tl_data["red_mat_off"])
			yellow_node.set_surface_override_material(0, tl_data["yellow_mat_on"])
			green_node.set_surface_override_material(0, tl_data["green_mat_off"])
		else:
			# Red
			red_node.set_surface_override_material(0, tl_data["red_mat_on"])
			yellow_node.set_surface_override_material(0, tl_data["yellow_mat_off"])
			green_node.set_surface_override_material(0, tl_data["green_mat_off"])

	# Holographic sign floating animation
	for holo in holo_signs:
		var node: Label3D = holo["node"]
		if not is_instance_valid(node):
			continue
		var base_y: float = holo["base_y"]
		var phase: float = holo["phase"]
		var speed: float = holo["speed"]
		node.position.y = base_y + sin(time * speed + phase) * 0.5
		# Subtle alpha pulse
		var alpha := 0.35 + 0.15 * sin(time * speed * 0.7 + phase)
		node.modulate.a = alpha

	# Vending machine screen pulse (pre-cached materials)
	for vs in vending_screens:
		var screen: MeshInstance3D = vs["node"]
		if not is_instance_valid(screen):
			continue
		var phase: float = vs["phase"]
		var pulse := sin(time * 1.5 + phase)
		var is_blink := sin(time * 4.0 + phase * 2.0) > 0.9
		if is_blink:
			screen.set_surface_override_material(0, vs["mat_off"])
		elif pulse > 0.0:
			screen.set_surface_override_material(0, vs["mat_bright"])
		else:
			screen.set_surface_override_material(0, vs["mat_dim"])

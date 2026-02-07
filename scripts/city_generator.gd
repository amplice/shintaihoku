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
var puddle_shader: Shader
var neon_font: Font
var flickering_lights: Array[Dictionary] = []  # [{node, base_energy, phase, speed, style}]
var traffic_lights: Array[Dictionary] = []  # [{red, yellow, green, phase}]
var holo_signs: Array[Dictionary] = []  # [{node, base_y, phase, speed}]
var vending_screens: Array[Dictionary] = []  # [{node, phase, color}]
var color_shift_signs: Array[Dictionary] = []  # [{node, light, phase, speed, base_hue}]
var rotating_fans: Array[Dictionary] = []  # [{node, speed}]
var crosswalk_signals: Array[Dictionary] = []  # [{walk_mesh, stop_mesh, phase}]
var drone_node: Node3D = null
var drone_time: float = 0.0
var drone_light: OmniLight3D = null
var pipe_arcs: Array[Dictionary] = []  # [{light, phase, speed}]
var police_red_light: OmniLight3D = null
var police_blue_light: OmniLight3D = null
var hologram_projections: Array[Dictionary] = []  # [{mesh, light, phase, speed}]
var aircraft_node: Node3D = null
var aircraft_time: float = 0.0
var aircraft_nav_light: OmniLight3D = null
var helicopter_node: Node3D = null
var helicopter_time: float = 0.0
var helicopter_searchlight: SpotLight3D = null
var helicopter_nav_red: OmniLight3D = null
var helicopter_nav_green: OmniLight3D = null
# Neon buzz audio pool
const NEON_BUZZ_POOL_SIZE: int = 2
const NEON_BUZZ_RANGE: float = 10.0
var neon_buzz_pool: Array[Dictionary] = []
var neon_buzz_positions: Array[Vector3] = []
var buzz_rng := RandomNumberGenerator.new()
# Distant radio music
const RADIO_POOL_SIZE: int = 2
const RADIO_RANGE: float = 15.0
var radio_pool: Array[Dictionary] = []
var radio_positions: Array[Vector3] = []
var radio_rng := RandomNumberGenerator.new()
var stray_cats: Array[Dictionary] = []  # [{node, home_pos, fleeing, flee_dir}]
var steam_bursts: Array[Dictionary] = []  # [{particles, timer, interval}]
var boot_time: float = 0.0
var boot_complete: bool = false

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
	puddle_shader = load("res://shaders/puddle.gdshader")
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
	_generate_roof_access_doors()
	_generate_rain_gutters()
	_generate_parking_meters()
	_generate_shipping_containers()
	_generate_scaffolding()
	_generate_antenna_arrays()
	_generate_laundry_lines()
	_generate_ground_fog()
	_generate_sparking_boxes()
	_generate_ventilation_fans()
	_generate_power_cables()
	_generate_rooftop_ac_units()
	_generate_rain_drips()
	_generate_neon_arrows()
	_generate_surveillance_drone()
	_generate_pipe_arcs()
	_generate_open_signs()
	_generate_police_car()
	_generate_car_rain_splashes()
	_generate_haze_layers()
	_generate_neon_reflections()
	_generate_rooftop_exhaust()
	_generate_hologram_projections()
	_generate_newspaper_boxes()
	_generate_crosswalks()
	_generate_aircraft_flyover()
	_generate_helicopter_patrol()
	_generate_subway_entrances()
	_generate_neon_light_shafts()
	_generate_distant_city_glow()
	_generate_rooftop_water_tanks()
	_setup_neon_buzz_audio()
	_setup_radio_audio()
	_generate_stray_cats()
	_generate_building_entrances()
	_generate_street_vendors()
	_generate_alleys()
	_generate_pigeon_flocks()
	_generate_rooftop_gardens()
	_setup_neon_flicker()
	_setup_color_shift_signs()
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

	# Shelves on side walls
	var shelf_mat := _make_ps1_material(Color(0.25, 0.2, 0.15))
	for shelf_side in [-1.0, 1.0]:
		if rng.randf() < 0.6:
			for shelf_row in range(rng.randi_range(1, 3)):
				var shelf_y := -half_h + 1.2 + shelf_row * 0.8
				_add_wall(building, Vector3(shelf_side * (half_w - 0.6), shelf_y, -half_d * 0.3),
					Vector3(0.4, 0.05, d * 0.4), shelf_mat)
				# Small items on shelf (bottles/jars)
				for _item in range(rng.randi_range(2, 4)):
					var bottle := MeshInstance3D.new()
					var bottle_mesh := BoxMesh.new()
					bottle_mesh.size = Vector3(0.06, rng.randf_range(0.08, 0.15), 0.06)
					bottle.mesh = bottle_mesh
					bottle.position = Vector3(
						shelf_side * (half_w - 0.6) + rng.randf_range(-0.12, 0.12),
						shelf_y + 0.06,
						-half_d * 0.3 + rng.randf_range(-d * 0.15, d * 0.15))
					var item_col := Color(rng.randf_range(0.3, 0.8), rng.randf_range(0.2, 0.6), rng.randf_range(0.1, 0.5))
					bottle.set_surface_override_material(0, _make_ps1_material(item_col))
					building.add_child(bottle)

	# Cash register on counter (if counter exists)
	if rng.randf() < 0.5:
		var reg := MeshInstance3D.new()
		var reg_mesh := BoxMesh.new()
		reg_mesh.size = Vector3(0.3, 0.25, 0.25)
		reg.mesh = reg_mesh
		reg.position = Vector3(rng.randf_range(-0.5, 0.5), -half_h + 1.15, -half_d + 1.2)
		reg.set_surface_override_material(0, _make_ps1_material(Color(0.15, 0.15, 0.18)))
		building.add_child(reg)

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
				# 10% of lit windows get horizontal blinds overlay
				if rng.randf() < 0.10:
					for blind_row in range(4):
						var blind := MeshInstance3D.new()
						var blind_mesh := QuadMesh.new()
						blind_mesh.size = Vector2(1.15, 0.08)
						blind.mesh = blind_mesh
						blind.position = Vector3(wx, wy - 0.5 + blind_row * 0.35, face * (size.z * 0.51 + 0.005))
						if face < 0:
							blind.rotation.y = PI
						blind.set_surface_override_material(0,
							_make_ps1_material(Color(0.06, 0.05, 0.04)))
						blind.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
						building.add_child(blind)
				# 8% of lit windows get a person silhouette
				if rng.randf() < 0.08:
					var sil := MeshInstance3D.new()
					var sil_mesh := QuadMesh.new()
					sil_mesh.size = Vector2(0.4, 0.9)
					sil.mesh = sil_mesh
					var sil_offset_x := rng.randf_range(-0.2, 0.2)
					sil.position = Vector3(wx + sil_offset_x, wy + 0.1, face * (size.z * 0.51 + 0.01))
					if face < 0:
						sil.rotation.y = PI
					sil.set_surface_override_material(0,
						_make_ps1_material(Color(0.02, 0.02, 0.03)))
					sil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					building.add_child(sil)
				# 5% of lit windows get a TV glow
				if rng.randf() < 0.05:
					var tv_light := OmniLight3D.new()
					tv_light.light_color = Color(0.3, 0.4, 0.9)
					tv_light.light_energy = 1.5
					tv_light.omni_range = 3.0
					tv_light.omni_attenuation = 1.5
					tv_light.shadow_enabled = false
					tv_light.position = win.position + Vector3(0, 0, -face * 0.3)
					building.add_child(tv_light)
					flickering_lights.append({
						"node": tv_light, "mesh": null,
						"base_energy": 1.5, "phase": rng.randf() * TAU,
						"speed": rng.randf_range(5.0, 15.0), "style": "tv",
					})

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
				# 10% blinds on side windows
				if rng.randf() < 0.10:
					for blind_row in range(4):
						var blind := MeshInstance3D.new()
						var blind_mesh := QuadMesh.new()
						blind_mesh.size = Vector2(1.15, 0.08)
						blind.mesh = blind_mesh
						blind.position = Vector3(face * (size.x * 0.51 + 0.005), wy - 0.5 + blind_row * 0.35, wz)
						blind.rotation.y = PI * 0.5
						if face < 0:
							blind.rotation.y = -PI * 0.5
						blind.set_surface_override_material(0,
							_make_ps1_material(Color(0.06, 0.05, 0.04)))
						blind.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
						building.add_child(blind)
				# 8% silhouette on side windows too
				if rng.randf() < 0.08:
					var sil := MeshInstance3D.new()
					var sil_mesh := QuadMesh.new()
					sil_mesh.size = Vector2(0.4, 0.9)
					sil.mesh = sil_mesh
					var sil_off_z := rng.randf_range(-0.2, 0.2)
					sil.position = Vector3(face * (size.x * 0.51 + 0.01), wy + 0.1, wz + sil_off_z)
					sil.rotation.y = PI * 0.5
					if face < 0:
						sil.rotation.y = -PI * 0.5
					sil.set_surface_override_material(0,
						_make_ps1_material(Color(0.02, 0.02, 0.03)))
					sil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					building.add_child(sil)
				if rng.randf() < 0.05:
					var tv_light := OmniLight3D.new()
					tv_light.light_color = Color(0.3, 0.4, 0.9)
					tv_light.light_energy = 1.5
					tv_light.omni_range = 3.0
					tv_light.omni_attenuation = 1.5
					tv_light.shadow_enabled = false
					tv_light.position = win.position + Vector3(-face * 0.3, 0, 0)
					building.add_child(tv_light)
					flickering_lights.append({
						"node": tv_light, "mesh": null,
						"base_energy": 1.5, "phase": rng.randf() * TAU,
						"speed": rng.randf_range(5.0, 15.0), "style": "tv",
					})

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
				var puddle_mat := ShaderMaterial.new()
				puddle_mat.shader = puddle_shader
				puddle_mat.set_shader_parameter("puddle_tint", puddle_col * 0.08)
				puddle_mat.set_shader_parameter("neon_tint", puddle_col)
				puddle_mat.set_shader_parameter("neon_strength", rng.randf_range(0.5, 1.2))
				puddle_mat.set_shader_parameter("reflection_strength", rng.randf_range(0.25, 0.45))
				puddle_mat.set_shader_parameter("ripple_speed", rng.randf_range(1.5, 3.0))
				puddle_mat.set_shader_parameter("ripple_scale", rng.randf_range(6.0, 12.0))
				puddle.set_surface_override_material(0, puddle_mat)
				add_child(puddle)
				# Subtle ground glow from puddle reflecting neon
				if rng.randf() < 0.35:
					var puddle_glow := OmniLight3D.new()
					puddle_glow.light_color = puddle_col
					puddle_glow.light_energy = rng.randf_range(0.3, 0.8)
					puddle_glow.omni_range = maxf(puddle_w, puddle_d) * 0.8
					puddle_glow.omni_attenuation = 2.0
					puddle_glow.shadow_enabled = false
					puddle_glow.position = Vector3(px, 0.1, pz)
					add_child(puddle_glow)

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
	sidewalk_mat.set_shader_parameter("wet_surface", true)
	sidewalk_mat.set_shader_parameter("wet_strength", 0.25)
	var curb_mat := _make_ps1_material(Color(0.18, 0.18, 0.2))
	curb_mat.set_shader_parameter("wet_surface", true)
	curb_mat.set_shader_parameter("wet_strength", 0.2)

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

			# Bottom ladder from ground to first platform
			if f == 1:
				var ladder_h := floor_y + bsize.y * 0.5
				# Two side rails
				for lr in [-0.2, 0.2]:
					var l_rail := MeshInstance3D.new()
					var lr_mesh := BoxMesh.new()
					lr_mesh.size = Vector3(0.04, ladder_h, 0.04)
					l_rail.mesh = lr_mesh
					l_rail.position = Vector3(face * (bsize.x * 0.5 + 0.75) + lr, -bsize.y * 0.5 + ladder_h * 0.5, platform_z)
					l_rail.set_surface_override_material(0, railing_mat)
					mi.add_child(l_rail)
				# Rungs
				var num_rungs := int(ladder_h / 0.35)
				for r in range(num_rungs):
					var rung := MeshInstance3D.new()
					var rung_mesh := BoxMesh.new()
					rung_mesh.size = Vector3(0.4, 0.03, 0.04)
					rung.mesh = rung_mesh
					rung.position = Vector3(
						face * (bsize.x * 0.5 + 0.75),
						-bsize.y * 0.5 + r * 0.35 + 0.2,
						platform_z
					)
					rung.set_surface_override_material(0, metal_mat)
					mi.add_child(rung)

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
			# 15% of AC units drip water
			if rng.randf() < 0.15:
				var drip := GPUParticles3D.new()
				drip.amount = 2
				drip.lifetime = 1.5
				drip.visibility_aabb = AABB(Vector3(-1, -4, -1), Vector3(2, 5, 2))
				var drip_mat := ParticleProcessMaterial.new()
				drip_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
				drip_mat.emission_box_extents = Vector3(0.15, 0, 0.15)
				drip_mat.direction = Vector3(0, -1, 0)
				drip_mat.spread = 5.0
				drip_mat.initial_velocity_min = 0.3
				drip_mat.initial_velocity_max = 0.8
				drip_mat.gravity = Vector3(0, -6.0, 0)
				drip_mat.scale_min = 0.01
				drip_mat.scale_max = 0.025
				drip_mat.color = Color(0.4, 0.45, 0.6, 0.2)
				drip.process_material = drip_mat
				var drip_mesh := SphereMesh.new()
				drip_mesh.radius = 0.015
				drip_mesh.height = 0.03
				drip.draw_pass_1 = drip_mesh
				drip.position = Vector3(0, -0.25, 0)
				unit.add_child(drip)

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

	# 15% chance of a wanted poster
	var poster_rng := RandomNumberGenerator.new()
	poster_rng.seed = hash(pos)
	if poster_rng.randf() < 0.15 and neon_font:
		var poster := Label3D.new()
		var poster_texts := ["指名手配", "WANTED", "懸賞金", "危険人物"]
		poster.text = poster_texts[poster_rng.randi_range(0, poster_texts.size() - 1)]
		poster.font = neon_font
		poster.font_size = 24
		poster.pixel_size = 0.008
		poster.modulate = Color(0.8, 0.75, 0.6)  # aged paper yellow
		poster.outline_modulate = Color(0.3, 0.25, 0.15)
		poster.outline_size = 3
		poster.position = Vector3(0.13, 2.5 + poster_rng.randf_range(-0.5, 0.5), 0)
		poster.rotation.y = poster_rng.randf_range(-0.3, 0.3)
		pole_node.add_child(poster)

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
	var graffiti_texts: Array[String] = [
		"FREEDOM", "WAKE UP", "404", "NO GODS", "RESIST", "WHY",
		"VOID", "GLITCH", "RUN", "0xFF", "OBEY", "REBEL",
		"龍", "闇", "鬼", "火", "危険", "禁止", "未来", "自由",
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
			var face := rng.randi_range(0, 3)
			var tag_y := -bsize.y * 0.5 + rng.randf_range(0.5, 3.0)
			var use_text := rng.randf() < 0.5 and neon_font != null

			var tag: Node3D
			if use_text:
				var label := Label3D.new()
				label.text = graffiti_texts[rng.randi_range(0, graffiti_texts.size() - 1)]
				label.font = neon_font
				label.font_size = rng.randi_range(32, 72)
				label.pixel_size = 0.01
				label.modulate = gc * 0.6
				label.outline_modulate = gc * 0.2
				label.outline_size = 4
				label.no_depth_test = false
				label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
				tag = label
			else:
				var mesh_tag := MeshInstance3D.new()
				var tag_mesh := QuadMesh.new()
				tag_mesh.size = Vector2(rng.randf_range(1.0, 3.0), rng.randf_range(0.5, 1.5))
				mesh_tag.mesh = tag_mesh
				mesh_tag.set_surface_override_material(0,
					_make_ps1_material(gc * 0.2, true, gc, rng.randf_range(0.5, 1.5)))
				tag = mesh_tag

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
				# 30% of steam manholes also do periodic bursts
				if rng.randf() < 0.30:
					var burst := GPUParticles3D.new()
					burst.position = Vector3(ix, 0.05, iz)
					burst.amount = 20
					burst.lifetime = 1.5
					burst.one_shot = true
					burst.emitting = false
					burst.explosiveness = 0.9
					burst.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 8, 4))
					var burst_mat := ParticleProcessMaterial.new()
					burst_mat.direction = Vector3(0, 1, 0)
					burst_mat.spread = 15.0
					burst_mat.initial_velocity_min = 3.0
					burst_mat.initial_velocity_max = 6.0
					burst_mat.gravity = Vector3(0, -1.0, 0)
					burst_mat.damping_min = 2.0
					burst_mat.damping_max = 4.0
					burst_mat.scale_min = 0.3
					burst_mat.scale_max = 0.8
					burst_mat.color = Color(0.6, 0.6, 0.7, 0.15)
					burst.process_material = burst_mat
					var burst_mesh := BoxMesh.new()
					burst_mesh.size = Vector3(0.25, 0.25, 0.25)
					burst.draw_pass_1 = burst_mesh
					add_child(burst)
					steam_bursts.append({
						"particles": burst,
						"timer": rng.randf_range(5.0, 15.0),
						"interval_min": 8.0,
						"interval_max": 20.0,
					})
				# Neon-tinted underglow from below
				var glow_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
				var underglow := OmniLight3D.new()
				underglow.light_color = glow_col
				underglow.light_energy = rng.randf_range(0.5, 1.2)
				underglow.omni_range = 3.0
				underglow.omni_attenuation = 1.5
				underglow.shadow_enabled = false
				underglow.position = Vector3(ix, 0.0, iz)
				add_child(underglow)

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
		# Buildings 25m+ get aviation warning lights
		if bsize.y < 25.0 or rng.randf() > 0.35:
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
			# Barbed wire coil on top (40% of fences)
			if rng.randf() < 0.4:
				var wire_mat := _make_ps1_material(Color(0.35, 0.32, 0.3))
				var num_coils := int(fence_len / 0.6)
				for c in range(num_coils):
					var coil := MeshInstance3D.new()
					var coil_mesh := BoxMesh.new()
					coil_mesh.size = Vector3(0.12, 0.15, 0.12)
					coil.mesh = coil_mesh
					var t := float(c) / float(num_coils)
					var coil_pos: Vector3
					if along_x:
						coil_pos = Vector3(
							fence_pos.x - fence_len * 0.5 + t * fence_len,
							fence_pos.y + fence_h * 0.5 + 0.1 + sin(t * 20.0) * 0.06,
							fence_pos.z + cos(t * 20.0) * 0.08
						)
					else:
						coil_pos = Vector3(
							fence_pos.x + cos(t * 20.0) * 0.08,
							fence_pos.y + fence_h * 0.5 + 0.1 + sin(t * 20.0) * 0.06,
							fence_pos.z - fence_len * 0.5 + t * fence_len
						)
					coil.position = coil_pos
					coil.rotation = Vector3(t * 3.0, t * 2.0, t * 1.5)
					coil.set_surface_override_material(0, wire_mat)
					add_child(coil)

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

func _generate_roof_access_doors() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3700
	for child in get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if not (mi.mesh is BoxMesh):
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 15.0:
			continue
		if rng.randf() > 0.30:
			continue
		var door_struct := Node3D.new()
		var dx := rng.randf_range(-bsize.x * 0.25, bsize.x * 0.25)
		var dz := rng.randf_range(-bsize.z * 0.25, bsize.z * 0.25)
		door_struct.position = Vector3(
			mi.position.x + dx,
			mi.position.y + bsize.y * 0.5,
			mi.position.z + dz
		)
		# Enclosure walls
		var enclosure := MeshInstance3D.new()
		var enc_mesh := BoxMesh.new()
		enc_mesh.size = Vector3(2.0, 2.8, 2.0)
		enclosure.mesh = enc_mesh
		enclosure.position = Vector3(0, 1.4, 0)
		enclosure.set_surface_override_material(0, _make_ps1_material(Color(0.25, 0.25, 0.28)))
		door_struct.add_child(enclosure)
		# Door (darker rectangle on one face)
		var door := MeshInstance3D.new()
		var door_mesh := BoxMesh.new()
		door_mesh.size = Vector3(0.9, 2.0, 0.04)
		door.mesh = door_mesh
		door.position = Vector3(0, 1.0, 1.02)
		door.set_surface_override_material(0, _make_ps1_material(Color(0.15, 0.15, 0.18)))
		door_struct.add_child(door)
		# Small roof on top
		var door_roof := MeshInstance3D.new()
		var dr_mesh := BoxMesh.new()
		dr_mesh.size = Vector3(2.2, 0.1, 2.2)
		door_roof.mesh = dr_mesh
		door_roof.position = Vector3(0, 2.85, 0)
		door_roof.set_surface_override_material(0, _make_ps1_material(Color(0.2, 0.2, 0.22)))
		door_struct.add_child(door_roof)
		add_child(door_struct)

func _generate_rain_gutters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3800
	var gutter_mat := _make_ps1_material(Color(0.3, 0.3, 0.33))
	for child in get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if not (mi.mesh is BoxMesh):
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 8.0:
			continue
		if rng.randf() > 0.15:
			continue
		var face := rng.randi_range(0, 1)  # 0 = +x face, 1 = +z face
		# Horizontal gutter at roofline
		var gutter := MeshInstance3D.new()
		var g_mesh := BoxMesh.new()
		if face == 0:
			g_mesh.size = Vector3(0.08, 0.08, bsize.z * 0.9)
			gutter.position = Vector3(bsize.x * 0.5 + 0.04, bsize.y * 0.5 - 0.1, 0)
		else:
			g_mesh.size = Vector3(bsize.x * 0.9, 0.08, 0.08)
			gutter.position = Vector3(0, bsize.y * 0.5 - 0.1, bsize.z * 0.5 + 0.04)
		gutter.mesh = g_mesh
		gutter.set_surface_override_material(0, gutter_mat)
		mi.add_child(gutter)
		# Vertical downspout from gutter to ground
		var spout := MeshInstance3D.new()
		var s_mesh := BoxMesh.new()
		s_mesh.size = Vector3(0.06, bsize.y, 0.06)
		spout.mesh = s_mesh
		if face == 0:
			var spout_z := rng.randf_range(-bsize.z * 0.35, bsize.z * 0.35)
			spout.position = Vector3(bsize.x * 0.5 + 0.04, 0, spout_z)
		else:
			var spout_x := rng.randf_range(-bsize.x * 0.35, bsize.x * 0.35)
			spout.position = Vector3(spout_x, 0, bsize.z * 0.5 + 0.04)
		spout.set_surface_override_material(0, gutter_mat)
		mi.add_child(spout)

func _generate_parking_meters() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3900
	var cell_stride := block_size + street_width
	var meter_pole_mat := _make_ps1_material(Color(0.35, 0.35, 0.38))
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.12:
				continue
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride
			var num_meters := rng.randi_range(1, 3)
			for _m in range(num_meters):
				var side := rng.randi_range(0, 3)
				var mx: float
				var mz: float
				match side:
					0:
						mx = cell_x + block_size * 0.5 + 1.2
						mz = cell_z + rng.randf_range(-block_size * 0.3, block_size * 0.3)
					1:
						mx = cell_x - block_size * 0.5 - 1.2
						mz = cell_z + rng.randf_range(-block_size * 0.3, block_size * 0.3)
					2:
						mx = cell_x + rng.randf_range(-block_size * 0.3, block_size * 0.3)
						mz = cell_z + block_size * 0.5 + 1.2
					_:
						mx = cell_x + rng.randf_range(-block_size * 0.3, block_size * 0.3)
						mz = cell_z - block_size * 0.5 - 1.2
				var meter := Node3D.new()
				meter.position = Vector3(mx, 0, mz)
				# Pole
				var pole := MeshInstance3D.new()
				var pole_mesh := BoxMesh.new()
				pole_mesh.size = Vector3(0.05, 1.1, 0.05)
				pole.mesh = pole_mesh
				pole.position = Vector3(0, 0.55, 0)
				pole.set_surface_override_material(0, meter_pole_mat)
				meter.add_child(pole)
				# Head (payment box)
				var head := MeshInstance3D.new()
				var head_mesh := BoxMesh.new()
				head_mesh.size = Vector3(0.15, 0.25, 0.12)
				head.mesh = head_mesh
				head.position = Vector3(0, 1.2, 0)
				head.set_surface_override_material(0, _make_ps1_material(Color(0.4, 0.4, 0.42)))
				meter.add_child(head)
				# Small screen (faint emissive)
				var screen := MeshInstance3D.new()
				var scr_mesh := BoxMesh.new()
				scr_mesh.size = Vector3(0.1, 0.08, 0.02)
				screen.mesh = scr_mesh
				screen.position = Vector3(0, 1.25, 0.07)
				var scr_col := Color(0.2, 0.8, 0.2)
				screen.set_surface_override_material(0,
					_make_ps1_material(scr_col, true, scr_col, 1.0))
				meter.add_child(screen)
				add_child(meter)

func _generate_shipping_containers() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4000
	var cell_stride := block_size + street_width
	var container_colors: Array[Color] = [
		Color(0.5, 0.15, 0.1),  # rust red
		Color(0.1, 0.3, 0.5),   # blue
		Color(0.15, 0.4, 0.15), # green
		Color(0.5, 0.35, 0.1),  # orange
		Color(0.3, 0.3, 0.32),  # gray
		Color(0.4, 0.15, 0.35), # purple
	]
	# Only place at city edges
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if abs(gx) < grid_size - 1 and abs(gz) < grid_size - 1:
				continue
			if rng.randf() > 0.25:
				continue
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride
			var num_containers := rng.randi_range(2, 4)
			var base_x := cell_x + rng.randf_range(-block_size * 0.3, block_size * 0.3)
			var base_z := cell_z + rng.randf_range(-block_size * 0.3, block_size * 0.3)
			for _c in range(num_containers):
				var container := MeshInstance3D.new()
				var c_mesh := BoxMesh.new()
				c_mesh.size = Vector3(rng.randf_range(5.0, 7.0), 2.6, 2.4)
				container.mesh = c_mesh
				var stack := rng.randi_range(0, 1)
				container.position = Vector3(
					base_x + rng.randf_range(-2.0, 2.0),
					1.3 + stack * 2.6,
					base_z + rng.randf_range(-1.0, 1.0)
				)
				container.rotation.y = rng.randf_range(-0.2, 0.2)
				var cc := container_colors[rng.randi_range(0, container_colors.size() - 1)]
				# Add rust variation
				if rng.randf() < 0.3:
					cc = cc.lerp(Color(0.35, 0.2, 0.1), rng.randf_range(0.2, 0.6))
				container.set_surface_override_material(0, _make_ps1_material(cc))
				add_child(container)

func _generate_scaffolding() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4100
	var pipe_mat := _make_ps1_material(Color(0.4, 0.4, 0.42))
	var plank_mat := _make_ps1_material(Color(0.3, 0.2, 0.1))
	for child in get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if not (mi.mesh is BoxMesh):
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 20.0:
			continue
		if rng.randf() > 0.08:
			continue
		var face := 1.0 if rng.randf() < 0.5 else -1.0
		var scaffold_h := minf(bsize.y * 0.6, rng.randf_range(8.0, 18.0))
		var num_levels := int(scaffold_h / 3.0)
		var scaffold_z := rng.randf_range(-bsize.z * 0.2, bsize.z * 0.2)
		# Vertical poles (4 corners)
		for pz_off in [-1.0, 1.0]:
			for px_off in [0.0, 1.5]:
				var pole := MeshInstance3D.new()
				var p_mesh := BoxMesh.new()
				p_mesh.size = Vector3(0.06, scaffold_h, 0.06)
				pole.mesh = p_mesh
				pole.position = Vector3(
					face * (bsize.x * 0.5 + 0.3 + px_off),
					-bsize.y * 0.5 + scaffold_h * 0.5,
					scaffold_z + pz_off * 0.8
				)
				pole.set_surface_override_material(0, pipe_mat)
				mi.add_child(pole)
		# Horizontal members and planks at each level
		for lvl in range(num_levels):
			var level_y := -bsize.y * 0.5 + (lvl + 1) * 3.0
			# Cross bar
			var cross := MeshInstance3D.new()
			var cr_mesh := BoxMesh.new()
			cr_mesh.size = Vector3(1.8, 0.05, 0.05)
			cross.mesh = cr_mesh
			cross.position = Vector3(face * (bsize.x * 0.5 + 1.05), level_y, scaffold_z)
			cross.set_surface_override_material(0, pipe_mat)
			mi.add_child(cross)
			# Plank (walking platform)
			var plank := MeshInstance3D.new()
			var pl_mesh := BoxMesh.new()
			pl_mesh.size = Vector3(1.6, 0.08, 1.6)
			plank.mesh = pl_mesh
			plank.position = Vector3(face * (bsize.x * 0.5 + 1.05), level_y + 0.04, scaffold_z)
			plank.set_surface_override_material(0, plank_mat)
			mi.add_child(plank)

func _generate_antenna_arrays() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4200
	var pole_mat := _make_ps1_material(Color(0.35, 0.35, 0.38))
	for child in get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if not (mi.mesh is BoxMesh):
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 25.0:
			continue
		if rng.randf() > 0.15:
			continue
		var num_antennas := rng.randi_range(2, 5)
		for _a in range(num_antennas):
			var ant_h := rng.randf_range(1.5, 4.0)
			var ant := MeshInstance3D.new()
			var ant_mesh := BoxMesh.new()
			ant_mesh.size = Vector3(0.04, ant_h, 0.04)
			ant.mesh = ant_mesh
			ant.position = Vector3(
				mi.position.x + rng.randf_range(-bsize.x * 0.3, bsize.x * 0.3),
				mi.position.y + bsize.y * 0.5 + ant_h * 0.5,
				mi.position.z + rng.randf_range(-bsize.z * 0.3, bsize.z * 0.3)
			)
			ant.set_surface_override_material(0, pole_mat)
			add_child(ant)
			# 50% get a blinking tip light (red or white, varied patterns)
			if rng.randf() < 0.5:
				var tip := MeshInstance3D.new()
				var tip_mesh := SphereMesh.new()
				tip_mesh.radius = 0.06
				tip_mesh.height = 0.12
				tip.mesh = tip_mesh
				tip.position = ant.position + Vector3(0, ant_h * 0.5, 0)
				# 70% red, 30% white
				var is_white := rng.randf() < 0.3
				var tip_col := Color(1.0, 0.95, 0.9) if is_white else Color(1.0, 0.05, 0.0)
				tip.set_surface_override_material(0, _make_ps1_material(tip_col, true, tip_col, 3.0))
				add_child(tip)
				var tip_light := OmniLight3D.new()
				tip_light.light_color = tip_col
				tip_light.light_energy = 1.0 if is_white else 0.8
				tip_light.omni_range = 2.5 if is_white else 2.0
				tip_light.shadow_enabled = false
				tip_light.position = tip.position
				add_child(tip_light)
				# Varied blink styles
				var pattern_roll := rng.randi_range(0, 2)
				var blink_style := "blink"
				if pattern_roll == 1:
					blink_style = "double_flash"
				elif pattern_roll == 2:
					blink_style = "slow_pulse"
				flickering_lights.append({
					"node": tip_light, "mesh": tip,
					"base_energy": tip_light.light_energy,
					"phase": rng.randf() * TAU,
					"speed": rng.randf_range(2.0, 4.0), "style": blink_style,
				})

func _generate_laundry_lines() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4300
	var cell_stride := block_size + street_width
	var cloth_colors: Array[Color] = [
		Color(0.6, 0.2, 0.2),  # red
		Color(0.2, 0.2, 0.5),  # blue
		Color(0.5, 0.5, 0.45), # off-white
		Color(0.15, 0.15, 0.15), # dark
		Color(0.5, 0.35, 0.2), # brown
	]
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.10:
				continue
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride
			# String a line across the street
			var line_y := rng.randf_range(6.0, 12.0)
			var along_x := rng.randf() < 0.5
			var line_len := street_width + rng.randf_range(-2.0, 2.0)
			var offset := rng.randf_range(-block_size * 0.2, block_size * 0.2)
			var start_pos: Vector3
			if along_x:
				start_pos = Vector3(cell_x + block_size * 0.5, line_y, cell_z + offset)
			else:
				start_pos = Vector3(cell_x + offset, line_y, cell_z + block_size * 0.5)
			# The line itself (thin box)
			var line := MeshInstance3D.new()
			var line_mesh := BoxMesh.new()
			if along_x:
				line_mesh.size = Vector3(0.02, 0.02, line_len)
			else:
				line_mesh.size = Vector3(line_len, 0.02, 0.02)
			line.mesh = line_mesh
			if along_x:
				line.position = start_pos + Vector3(0, 0, line_len * 0.5)
			else:
				line.position = start_pos + Vector3(line_len * 0.5, 0, 0)
			line.set_surface_override_material(0, _make_ps1_material(Color(0.3, 0.3, 0.3)))
			add_child(line)
			# Hanging clothes (small quads)
			var num_clothes := rng.randi_range(3, 7)
			for _cl in range(num_clothes):
				var cloth := MeshInstance3D.new()
				var cloth_mesh := BoxMesh.new()
				cloth_mesh.size = Vector3(
					rng.randf_range(0.3, 0.6),
					rng.randf_range(0.4, 0.8),
					0.02
				)
				cloth.mesh = cloth_mesh
				var t := rng.randf()
				var cloth_pos: Vector3
				if along_x:
					cloth_pos = Vector3(
						start_pos.x,
						line_y - rng.randf_range(0.1, 0.35),
						start_pos.z + t * line_len
					)
				else:
					cloth_pos = Vector3(
						start_pos.x + t * line_len,
						line_y - rng.randf_range(0.1, 0.35),
						start_pos.z
					)
				cloth.position = cloth_pos
				cloth.rotation.z = rng.randf_range(-0.15, 0.15)
				var cc := cloth_colors[rng.randi_range(0, cloth_colors.size() - 1)]
				cloth.set_surface_override_material(0, _make_ps1_material(cc))
				add_child(cloth)

func _generate_ground_fog() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4400
	var cell_stride := block_size + street_width
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.08:
				continue
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride
			var fog := GPUParticles3D.new()
			fog.position = Vector3(
				cell_x + rng.randf_range(-block_size * 0.3, block_size * 0.3),
				0.3,
				cell_z + rng.randf_range(-block_size * 0.3, block_size * 0.3)
			)
			fog.amount = 15
			fog.lifetime = 6.0
			fog.visibility_aabb = AABB(Vector3(-10, -2, -10), Vector3(20, 4, 20))
			var mat := ParticleProcessMaterial.new()
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(6.0, 0.2, 6.0)
			mat.direction = Vector3(0.3, 0.05, 0.1)
			mat.spread = 30.0
			mat.initial_velocity_min = 0.1
			mat.initial_velocity_max = 0.4
			mat.gravity = Vector3(0, 0, 0)
			mat.damping_min = 0.5
			mat.damping_max = 1.5
			mat.scale_min = 1.0
			mat.scale_max = 3.0
			mat.color = Color(0.15, 0.1, 0.2, 0.04)
			fog.process_material = mat
			var mesh := BoxMesh.new()
			mesh.size = Vector3(1.0, 0.3, 1.0)
			fog.draw_pass_1 = mesh
			add_child(fog)

func _generate_sparking_boxes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4500
	for child in get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if not (mi.mesh is BoxMesh):
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 10.0:
			continue
		if rng.randf() > 0.03:
			continue
		# Place spark emitter on building wall
		var face := rng.randi_range(0, 1)
		var spark := GPUParticles3D.new()
		var spark_y := rng.randf_range(2.0, 6.0) - bsize.y * 0.5
		if face == 0:
			spark.position = Vector3(bsize.x * 0.5 + 0.1, spark_y, rng.randf_range(-bsize.z * 0.3, bsize.z * 0.3))
		else:
			spark.position = Vector3(rng.randf_range(-bsize.x * 0.3, bsize.x * 0.3), spark_y, bsize.z * 0.5 + 0.1)
		spark.amount = 8
		spark.lifetime = 0.5
		spark.explosiveness = 0.9  # burst-like
		spark.visibility_aabb = AABB(Vector3(-2, -2, -2), Vector3(4, 4, 4))
		var mat := ParticleProcessMaterial.new()
		mat.direction = Vector3(0, -1, 0)
		mat.spread = 60.0
		mat.initial_velocity_min = 2.0
		mat.initial_velocity_max = 5.0
		mat.gravity = Vector3(0, -8.0, 0)
		mat.scale_min = 0.02
		mat.scale_max = 0.06
		mat.color = Color(1.0, 0.9, 0.3, 1.0)
		spark.process_material = mat
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.03, 0.03, 0.03)
		spark.draw_pass_1 = mesh
		mi.add_child(spark)
		# Small flickering light at spark source
		var spark_light := OmniLight3D.new()
		spark_light.light_color = Color(1.0, 0.8, 0.3)
		spark_light.light_energy = 1.5
		spark_light.omni_range = 3.0
		spark_light.shadow_enabled = false
		spark_light.position = spark.position
		mi.add_child(spark_light)
		flickering_lights.append({
			"node": spark_light, "mesh": null,
			"base_energy": 1.5, "phase": rng.randf() * TAU,
			"speed": rng.randf_range(15.0, 30.0), "style": "buzz",
		})

func _generate_ventilation_fans() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4600
	var housing_mat := _make_ps1_material(Color(0.3, 0.3, 0.33))
	var blade_mat := _make_ps1_material(Color(0.35, 0.35, 0.38))
	for child in get_children():
		if not (child is MeshInstance3D):
			continue
		var mi := child as MeshInstance3D
		if not (mi.mesh is BoxMesh):
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 16.0:
			continue
		if rng.randf() > 0.12:
			continue
		var fan_parent := Node3D.new()
		fan_parent.position = Vector3(
			mi.position.x + rng.randf_range(-bsize.x * 0.25, bsize.x * 0.25),
			mi.position.y + bsize.y * 0.5,
			mi.position.z + rng.randf_range(-bsize.z * 0.25, bsize.z * 0.25)
		)
		# Housing box
		var housing := MeshInstance3D.new()
		var h_mesh := BoxMesh.new()
		h_mesh.size = Vector3(1.2, 0.6, 1.2)
		housing.mesh = h_mesh
		housing.position = Vector3(0, 0.3, 0)
		housing.set_surface_override_material(0, housing_mat)
		fan_parent.add_child(housing)
		# Fan blade cross (will rotate)
		var blade := MeshInstance3D.new()
		var bl_mesh := BoxMesh.new()
		bl_mesh.size = Vector3(0.8, 0.04, 0.1)
		blade.mesh = bl_mesh
		blade.position = Vector3(0, 0.65, 0)
		blade.set_surface_override_material(0, blade_mat)
		fan_parent.add_child(blade)
		var blade2 := MeshInstance3D.new()
		var bl2_mesh := BoxMesh.new()
		bl2_mesh.size = Vector3(0.1, 0.04, 0.8)
		blade2.mesh = bl2_mesh
		blade2.position = Vector3(0, 0.65, 0)
		blade2.set_surface_override_material(0, blade_mat)
		fan_parent.add_child(blade2)
		add_child(fan_parent)
		rotating_fans.append({
			"blade1": blade,
			"blade2": blade2,
			"speed": rng.randf_range(2.0, 6.0),
		})

func _setup_color_shift_signs() -> void:
	# Find some Label3D neon signs and register for color shifting
	var rng := RandomNumberGenerator.new()
	rng.seed = 4700
	_find_color_shift_candidates(self, rng)

func _find_color_shift_candidates(node: Node, rng: RandomNumberGenerator) -> void:
	for child in node.get_children():
		if child is Label3D:
			var label := child as Label3D
			if label.modulate != Color.WHITE and rng.randf() < 0.10:
				# Find associated OmniLight3D sibling
				var associated_light: OmniLight3D = null
				for sibling in node.get_children():
					if sibling is OmniLight3D:
						associated_light = sibling as OmniLight3D
						break
				color_shift_signs.append({
					"node": label,
					"light": associated_light,
					"phase": rng.randf() * TAU,
					"speed": rng.randf_range(0.2, 0.5),
					"base_hue": label.modulate.h,
				})
		if child.get_child_count() > 0:
			_find_color_shift_candidates(child, rng)

func _generate_power_cables() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5100
	var cell_stride_local := block_size + street_width
	var cable_mat := _make_ps1_material(Color(0.06, 0.06, 0.06))

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.08:
				continue
			var cell_x := gx * cell_stride_local
			var cell_z := gz * cell_stride_local
			# Cable across X-street (east-west)
			var cable_y := rng.randf_range(8.0, 14.0)
			var z_pos := cell_z + block_size * 0.5 + street_width * 0.5
			var x_start := cell_x - block_size * 0.3
			var x_end := cell_x + block_size * 0.3
			var cable_len := x_end - x_start
			var cable := MeshInstance3D.new()
			var cable_mesh := BoxMesh.new()
			cable_mesh.size = Vector3(cable_len, 0.03, 0.03)
			cable.mesh = cable_mesh
			cable.position = Vector3((x_start + x_end) * 0.5, cable_y, z_pos)
			cable.set_surface_override_material(0, cable_mat)
			add_child(cable)
			# Sag in the middle (second cable lower)
			var sag := MeshInstance3D.new()
			var sag_mesh := BoxMesh.new()
			sag_mesh.size = Vector3(cable_len * 0.6, 0.03, 0.03)
			sag.mesh = sag_mesh
			sag.position = Vector3((x_start + x_end) * 0.5, cable_y - 0.4, z_pos + 0.15)
			sag.set_surface_override_material(0, cable_mat)
			add_child(sag)

func _generate_rooftop_ac_units() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5200
	var ac_body_mat := _make_ps1_material(Color(0.18, 0.18, 0.2))
	var ac_grill_mat := _make_ps1_material(Color(0.1, 0.1, 0.12))

	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 12.0 or bsize.x < 3.0:
			continue
		if rng.randf() > 0.20:
			continue
		var bpos := mi.position
		var roof_y := bpos.y + bsize.y * 0.5
		var num_units := rng.randi_range(1, 3)
		for _u in range(num_units):
			var ac := Node3D.new()
			var ux := bpos.x + rng.randf_range(-bsize.x * 0.3, bsize.x * 0.3)
			var uz := bpos.z + rng.randf_range(-bsize.z * 0.3, bsize.z * 0.3)
			ac.position = Vector3(ux, roof_y, uz)
			# AC body
			var body := MeshInstance3D.new()
			var body_mesh := BoxMesh.new()
			body_mesh.size = Vector3(1.2, 0.8, 0.8)
			body.mesh = body_mesh
			body.position = Vector3(0, 0.4, 0)
			body.set_surface_override_material(0, ac_body_mat)
			ac.add_child(body)
			# Grill on front
			var grill := MeshInstance3D.new()
			var grill_mesh := BoxMesh.new()
			grill_mesh.size = Vector3(1.0, 0.5, 0.05)
			grill.mesh = grill_mesh
			grill.position = Vector3(0, 0.4, 0.43)
			grill.set_surface_override_material(0, ac_grill_mat)
			ac.add_child(grill)
			add_child(ac)

func _generate_rain_drips() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4900
	# Find awnings (MeshInstance3D named with thin Y dimension at storefront height)
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		# Awnings are thin (y < 0.15) and wide (x > 1.5), at low height
		if bsize.y > 0.15 or bsize.x < 1.5 or mi.position.y < 2.5 or mi.position.y > 5.0:
			continue
		if rng.randf() > 0.20:
			continue
		# Place drip emitter at front edge of awning
		var drip := GPUParticles3D.new()
		drip.position = Vector3(mi.position.x, mi.position.y - 0.05, mi.position.z + bsize.z * 0.5)
		drip.amount = 6
		drip.lifetime = 0.6
		drip.visibility_aabb = AABB(Vector3(-2, -2, -1), Vector3(4, 4, 2))
		var drip_mat := ParticleProcessMaterial.new()
		drip_mat.direction = Vector3(0, -1, 0)
		drip_mat.spread = 5.0
		drip_mat.initial_velocity_min = 1.0
		drip_mat.initial_velocity_max = 2.0
		drip_mat.gravity = Vector3(0, -8.0, 0)
		drip_mat.scale_min = 0.02
		drip_mat.scale_max = 0.05
		drip_mat.color = Color(0.6, 0.7, 0.9, 0.3)
		drip_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		drip_mat.emission_box_extents = Vector3(bsize.x * 0.4, 0.02, 0.02)
		drip.process_material = drip_mat
		var drip_mesh := SphereMesh.new()
		drip_mesh.radius = 0.03
		drip_mesh.height = 0.06
		drip.draw_pass_1 = drip_mesh
		add_child(drip)

func _generate_neon_arrows() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5000
	var neon_colors_local: Array[Color] = [
		Color(1.0, 0.05, 0.4), Color(0.0, 0.9, 1.0),
		Color(1.0, 0.4, 0.0), Color(0.6, 0.0, 1.0),
	]
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		# Target building fronts (tall enough, reasonable width)
		if bsize.y < 6.0 or bsize.x < 4.0:
			continue
		if rng.randf() > 0.06:
			continue
		var ncol := neon_colors_local[rng.randi_range(0, neon_colors_local.size() - 1)]
		var arrow_mat := _make_ps1_material(ncol * 0.4, true, ncol, 3.5)
		var arrow := Node3D.new()
		var arrow_x := mi.position.x + rng.randf_range(-bsize.x * 0.2, bsize.x * 0.2)
		var arrow_y := mi.position.y - bsize.y * 0.5 + rng.randf_range(3.0, 5.0)
		var arrow_z := mi.position.z + bsize.z * 0.5 + 0.15
		arrow.position = Vector3(arrow_x, arrow_y, arrow_z)
		# Arrow shaft (vertical bar pointing down)
		var shaft := MeshInstance3D.new()
		var shaft_mesh := BoxMesh.new()
		shaft_mesh.size = Vector3(0.15, 1.2, 0.08)
		shaft.mesh = shaft_mesh
		shaft.position = Vector3(0, 0, 0)
		shaft.set_surface_override_material(0, arrow_mat)
		arrow.add_child(shaft)
		# Arrow head left diagonal
		var head_l := MeshInstance3D.new()
		var head_l_mesh := BoxMesh.new()
		head_l_mesh.size = Vector3(0.6, 0.12, 0.08)
		head_l.mesh = head_l_mesh
		head_l.position = Vector3(-0.2, -0.5, 0)
		head_l.rotation.z = 0.6
		head_l.set_surface_override_material(0, arrow_mat)
		arrow.add_child(head_l)
		# Arrow head right diagonal
		var head_r := MeshInstance3D.new()
		var head_r_mesh := BoxMesh.new()
		head_r_mesh.size = Vector3(0.6, 0.12, 0.08)
		head_r.mesh = head_r_mesh
		head_r.position = Vector3(0.2, -0.5, 0)
		head_r.rotation.z = -0.6
		head_r.set_surface_override_material(0, arrow_mat)
		arrow.add_child(head_r)
		# Glow light
		var glow := OmniLight3D.new()
		glow.light_color = ncol
		glow.light_energy = 1.5
		glow.omni_range = 5.0
		glow.omni_attenuation = 1.5
		glow.shadow_enabled = false
		glow.position = Vector3(0, -0.3, 0.5)
		arrow.add_child(glow)
		add_child(arrow)

func _generate_surveillance_drone() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4800
	drone_node = Node3D.new()
	drone_node.position = Vector3(0, 35.0, 0)
	# Body
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.8, 0.3, 0.5)
	body.mesh = body_mesh
	body.set_surface_override_material(0, _make_ps1_material(Color(0.15, 0.15, 0.18)))
	drone_node.add_child(body)
	# Rotor arms (4 arms extending outward)
	var arm_mat := _make_ps1_material(Color(0.1, 0.1, 0.12))
	for corner in [Vector3(0.5, 0, 0.35), Vector3(-0.5, 0, 0.35),
			Vector3(0.5, 0, -0.35), Vector3(-0.5, 0, -0.35)]:
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(0.4, 0.06, 0.06)
		arm.mesh = arm_mesh
		arm.position = corner
		arm.set_surface_override_material(0, arm_mat)
		drone_node.add_child(arm)
		# Rotor disc
		var rotor := MeshInstance3D.new()
		var rotor_mesh := CylinderMesh.new()
		rotor_mesh.top_radius = 0.2
		rotor_mesh.bottom_radius = 0.2
		rotor_mesh.height = 0.02
		rotor.mesh = rotor_mesh
		rotor.position = Vector3(corner.x, corner.y + 0.05, corner.z)
		rotor.set_surface_override_material(0, _make_ps1_material(Color(0.2, 0.2, 0.2, 0.5)))
		drone_node.add_child(rotor)
	# Red searchlight pointing down
	drone_light = OmniLight3D.new()
	drone_light.light_color = Color(1.0, 0.1, 0.1)
	drone_light.light_energy = 3.0
	drone_light.omni_range = 20.0
	drone_light.omni_attenuation = 1.2
	drone_light.shadow_enabled = false
	drone_light.position = Vector3(0, -1.0, 0)
	drone_node.add_child(drone_light)
	# Blinking nav light (green)
	var nav := MeshInstance3D.new()
	var nav_mesh := SphereMesh.new()
	nav_mesh.radius = 0.05
	nav_mesh.height = 0.1
	nav.mesh = nav_mesh
	nav.position = Vector3(0, 0.18, -0.25)
	var nav_col := Color(0.0, 1.0, 0.0)
	nav.set_surface_override_material(0, _make_ps1_material(nav_col * 0.3, true, nav_col, 3.0))
	drone_node.add_child(nav)
	# Register nav light for blinking
	var nav_light := OmniLight3D.new()
	nav_light.light_color = nav_col
	nav_light.light_energy = 1.0
	nav_light.omni_range = 3.0
	nav_light.shadow_enabled = false
	nav_light.position = Vector3(0, 0.18, -0.25)
	drone_node.add_child(nav_light)
	flickering_lights.append({
		"node": nav_light, "mesh": nav, "base_energy": 1.0,
		"phase": 0.0, "speed": 4.0, "style": "blink",
	})
	add_child(drone_node)

func _generate_pipe_arcs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5300
	# Find exposed pipes (thin horizontal/vertical cylinders on building faces)
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is CylinderMesh:
			continue
		var cm := mi.mesh as CylinderMesh
		# Pipes are thin cylinders
		if cm.top_radius > 0.12 or cm.top_radius < 0.03:
			continue
		if rng.randf() > 0.03:
			continue
		# Place a sparking light at mid-point of pipe
		var arc_light := OmniLight3D.new()
		arc_light.light_color = Color(0.5, 0.7, 1.0)
		arc_light.light_energy = 0.0
		arc_light.omni_range = 3.0
		arc_light.omni_attenuation = 1.5
		arc_light.shadow_enabled = false
		arc_light.position = mi.position + Vector3(0, 0.1, 0)
		add_child(arc_light)
		pipe_arcs.append({
			"light": arc_light,
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(15.0, 30.0),
		})

func _generate_open_signs() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5500
	var font := load("res://fonts/NotoSansJP-Bold.ttf") as Font
	if not font:
		return
	var open_texts := ["OPEN", "営業中", "OPEN", "24H"]
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		# Target storefront-sized buildings (wide, not too tall)
		if bsize.y > 8.0 or bsize.x < 4.0 or bsize.y < 3.0:
			continue
		if rng.randf() > 0.12:
			continue
		var sign_col := Color(0.0, 1.0, 0.3) if rng.randf() < 0.7 else Color(1.0, 0.2, 0.2)
		var label := Label3D.new()
		label.text = open_texts[rng.randi_range(0, open_texts.size() - 1)]
		label.font = font
		label.font_size = 28
		label.pixel_size = 0.01
		label.modulate = sign_col
		label.outline_modulate = Color(0, 0, 0, 0.5)
		label.outline_size = 4
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		var sx := mi.position.x + rng.randf_range(-bsize.x * 0.2, bsize.x * 0.2)
		var sy := mi.position.y - bsize.y * 0.5 + 2.2
		var sz := mi.position.z + bsize.z * 0.5 + 0.08
		label.position = Vector3(sx, sy, sz)
		add_child(label)
		# Glow
		var glow := OmniLight3D.new()
		glow.light_color = sign_col
		glow.light_energy = 1.0
		glow.omni_range = 3.0
		glow.shadow_enabled = false
		glow.position = Vector3(sx, sy, sz + 0.3)
		add_child(glow)
		# 40% flicker with buzz style
		if rng.randf() < 0.40:
			flickering_lights.append({
				"node": glow, "mesh": null, "base_energy": 1.0,
				"phase": rng.randf() * TAU, "speed": rng.randf_range(8.0, 15.0),
				"style": "buzz",
			})

func _generate_police_car() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5600
	var cell_stride_local := block_size + street_width
	# Pick a random street position
	var gx := rng.randi_range(-grid_size + 1, grid_size - 2)
	var gz := rng.randi_range(-grid_size + 1, grid_size - 2)
	var cell_x := gx * cell_stride_local
	var cell_z := gz * cell_stride_local
	var px := cell_x + block_size * 0.5 + street_width * 0.3
	var pz := cell_z + rng.randf_range(-block_size * 0.3, block_size * 0.3)
	var police := Node3D.new()
	police.position = Vector3(px, 0, pz)
	# Car body (dark with white accents)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(3.8, 1.0, 1.8)
	body.mesh = body_mesh
	body.position = Vector3(0, 0.5, 0)
	body.set_surface_override_material(0, _make_ps1_material(Color(0.05, 0.05, 0.08)))
	police.add_child(body)
	# Cabin
	var cabin := MeshInstance3D.new()
	var cabin_mesh := BoxMesh.new()
	cabin_mesh.size = Vector3(1.8, 0.7, 1.6)
	cabin.mesh = cabin_mesh
	cabin.position = Vector3(-0.2, 1.2, 0)
	cabin.set_surface_override_material(0, _make_ps1_material(Color(0.03, 0.03, 0.05)))
	police.add_child(cabin)
	# Light bar
	var bar := MeshInstance3D.new()
	var bar_mesh := BoxMesh.new()
	bar_mesh.size = Vector3(1.4, 0.15, 0.4)
	bar.mesh = bar_mesh
	bar.position = Vector3(-0.2, 1.65, 0)
	bar.set_surface_override_material(0, _make_ps1_material(Color(0.2, 0.2, 0.25)))
	police.add_child(bar)
	# Red light (left)
	police_red_light = OmniLight3D.new()
	police_red_light.light_color = Color(1.0, 0.0, 0.0)
	police_red_light.light_energy = 0.0
	police_red_light.omni_range = 15.0
	police_red_light.omni_attenuation = 1.2
	police_red_light.shadow_enabled = false
	police_red_light.position = Vector3(-0.5, 1.8, 0)
	police.add_child(police_red_light)
	# Blue light (right)
	police_blue_light = OmniLight3D.new()
	police_blue_light.light_color = Color(0.0, 0.2, 1.0)
	police_blue_light.light_energy = 0.0
	police_blue_light.omni_range = 15.0
	police_blue_light.omni_attenuation = 1.2
	police_blue_light.shadow_enabled = false
	police_blue_light.position = Vector3(0.1, 1.8, 0)
	police.add_child(police_blue_light)
	# Wheels
	var wheel_mat := _make_ps1_material(Color(0.05, 0.05, 0.05))
	for wp in [Vector3(1.1, 0.3, 0.85), Vector3(1.1, 0.3, -0.85),
			Vector3(-1.1, 0.3, 0.85), Vector3(-1.1, 0.3, -0.85)]:
		var wheel := MeshInstance3D.new()
		var wheel_mesh := CylinderMesh.new()
		wheel_mesh.top_radius = 0.3
		wheel_mesh.bottom_radius = 0.3
		wheel_mesh.height = 0.2
		wheel.mesh = wheel_mesh
		wheel.position = wp
		wheel.rotation.x = PI * 0.5
		wheel.set_surface_override_material(0, wheel_mat)
		police.add_child(wheel)
	add_child(police)

func _generate_car_rain_splashes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5700
	# Find parked cars (Node3D with BoxMesh children at y ~0.5)
	for child in get_children():
		if not child is Node3D or child is MeshInstance3D:
			continue
		# Check if this looks like a car (has children with box meshes at car height)
		var has_car_body := false
		for sub in child.get_children():
			if sub is MeshInstance3D and sub.mesh is BoxMesh:
				var bs: Vector3 = (sub.mesh as BoxMesh).size
				if bs.x > 2.5 and bs.x < 5.0 and bs.y > 0.6 and bs.y < 1.5:
					has_car_body = true
					break
		if not has_car_body:
			continue
		if child.position.y > 2.0:
			continue  # skip flying cars
		if rng.randf() > 0.30:
			continue
		var splash := GPUParticles3D.new()
		splash.position = Vector3(child.position.x, child.position.y + 1.3, child.position.z)
		splash.amount = 8
		splash.lifetime = 0.4
		splash.visibility_aabb = AABB(Vector3(-2, -1, -1), Vector3(4, 2, 2))
		var splash_mat := ParticleProcessMaterial.new()
		splash_mat.direction = Vector3(0, 1, 0)
		splash_mat.spread = 30.0
		splash_mat.initial_velocity_min = 0.5
		splash_mat.initial_velocity_max = 1.5
		splash_mat.gravity = Vector3(0, -5.0, 0)
		splash_mat.scale_min = 0.01
		splash_mat.scale_max = 0.03
		splash_mat.color = Color(0.6, 0.7, 0.9, 0.2)
		splash_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		splash_mat.emission_box_extents = Vector3(1.5, 0.02, 0.7)
		splash.process_material = splash_mat
		var splash_mesh := SphereMesh.new()
		splash_mesh.radius = 0.02
		splash_mesh.height = 0.04
		splash.draw_pass_1 = splash_mesh
		add_child(splash)

func _generate_haze_layers() -> void:
	var cell_stride_local := block_size + street_width
	var extent := grid_size * cell_stride_local
	var haze_color := Color(0.08, 0.05, 0.15, 0.12)
	var haze_mat := ShaderMaterial.new()
	haze_mat.shader = ps1_shader
	haze_mat.set_shader_parameter("albedo_color", haze_color)
	haze_mat.set_shader_parameter("vertex_snap_intensity", 0.0)
	haze_mat.set_shader_parameter("color_depth", 32.0)
	haze_mat.set_shader_parameter("fog_distance", 200.0)
	haze_mat.set_shader_parameter("fog_density", 0.0)
	# 4 haze walls at grid edges
	var directions := [
		{"pos": Vector3(extent + 20, 20, 0), "rot": 0.0, "sx": 1.0, "sz": extent * 2.0},
		{"pos": Vector3(-extent - 20, 20, 0), "rot": 0.0, "sx": 1.0, "sz": extent * 2.0},
		{"pos": Vector3(0, 20, extent + 20), "rot": PI * 0.5, "sx": 1.0, "sz": extent * 2.0},
		{"pos": Vector3(0, 20, -extent - 20), "rot": PI * 0.5, "sx": 1.0, "sz": extent * 2.0},
	]
	for dir in directions:
		var plane := MeshInstance3D.new()
		var plane_mesh := BoxMesh.new()
		plane_mesh.size = Vector3(0.1, 50.0, dir["sz"])
		plane.mesh = plane_mesh
		plane.position = dir["pos"]
		plane.rotation.y = dir["rot"]
		plane.set_surface_override_material(0, haze_mat)
		add_child(plane)
	# Horizontal smog layer at mid-height
	var smog := MeshInstance3D.new()
	var smog_mesh := BoxMesh.new()
	smog_mesh.size = Vector3(extent * 3.0, 0.1, extent * 3.0)
	smog.mesh = smog_mesh
	smog.position = Vector3(0, 40.0, 0)
	var smog_mat := ShaderMaterial.new()
	smog_mat.shader = ps1_shader
	smog_mat.set_shader_parameter("albedo_color", Color(0.06, 0.04, 0.12, 0.08))
	smog_mat.set_shader_parameter("vertex_snap_intensity", 0.0)
	smog_mat.set_shader_parameter("color_depth", 32.0)
	smog_mat.set_shader_parameter("fog_distance", 200.0)
	smog_mat.set_shader_parameter("fog_density", 0.0)
	smog.set_surface_override_material(0, smog_mat)
	add_child(smog)

func _generate_neon_reflections() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5900
	# Collect reflection data first, then add children (avoid modifying array while iterating)
	var reflections_to_add: Array[Dictionary] = []
	var children_snapshot := get_children()
	for raw_child in children_snapshot:
		if not raw_child is Node3D:
			continue
		var child := raw_child as Node3D
		for sub in child.get_children():
			if not sub is OmniLight3D:
				continue
			var light := sub as OmniLight3D
			var world_y := child.position.y + light.position.y
			if world_y < 3.0 or world_y > 15.0:
				continue
			if light.light_energy < 1.0:
				continue
			if rng.randf() > 0.15:
				continue
			var ref_size := rng.randf_range(1.5, 3.5)
			var rx := child.position.x + light.position.x
			var rz := child.position.z + light.position.z
			reflections_to_add.append({
				"pos": Vector3(rx, 0.01, rz),
				"size": ref_size,
				"color": light.light_color,
			})
	for rd in reflections_to_add:
		var ref := MeshInstance3D.new()
		var ref_mesh := BoxMesh.new()
		ref_mesh.size = Vector3(rd["size"], 0.02, rd["size"])
		ref.mesh = ref_mesh
		ref.position = rd["pos"]
		var rcol: Color = rd["color"]
		ref.set_surface_override_material(0,
			_make_ps1_material(rcol * 0.15, true, rcol, 1.5))
		add_child(ref)

func _generate_rooftop_exhaust() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6000
	var exhaust_positions: Array[Vector3] = []
	var children_snapshot := get_children()
	for raw_child in children_snapshot:
		if not raw_child is Node3D or raw_child is MeshInstance3D:
			continue
		var child := raw_child as Node3D
		if child.position.y < 10.0:
			continue
		var has_ac_body := false
		for sub in child.get_children():
			if sub is MeshInstance3D and sub.mesh is BoxMesh:
				var bs: Vector3 = (sub.mesh as BoxMesh).size
				if bs.x > 0.8 and bs.x < 1.5 and bs.y > 0.5 and bs.y < 1.2:
					has_ac_body = true
					break
		if not has_ac_body:
			continue
		if rng.randf() > 0.30:
			continue
		exhaust_positions.append(Vector3(child.position.x, child.position.y + 1.0, child.position.z))
	for epos in exhaust_positions:
		var exhaust := GPUParticles3D.new()
		exhaust.position = epos
		exhaust.amount = 5
		exhaust.lifetime = 2.5
		exhaust.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4))
		var ex_mat := ParticleProcessMaterial.new()
		ex_mat.direction = Vector3(0, 1, 0)
		ex_mat.spread = 12.0
		ex_mat.initial_velocity_min = 0.3
		ex_mat.initial_velocity_max = 0.8
		ex_mat.gravity = Vector3(0, 0.1, 0)
		ex_mat.damping_min = 0.5
		ex_mat.damping_max = 1.0
		ex_mat.scale_min = 0.1
		ex_mat.scale_max = 0.3
		ex_mat.color = Color(0.5, 0.5, 0.55, 0.08)
		exhaust.process_material = ex_mat
		var ex_mesh := BoxMesh.new()
		ex_mesh.size = Vector3(0.15, 0.15, 0.15)
		exhaust.draw_pass_1 = ex_mesh
		add_child(exhaust)

func _generate_hologram_projections() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6100
	var holo_data: Array[Dictionary] = []
	var children_snapshot := get_children()
	for raw_child in children_snapshot:
		if holo_data.size() >= 3:
			break
		if not raw_child is MeshInstance3D:
			continue
		var mi := raw_child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 20.0 or bsize.x < 6.0:
			continue
		if rng.randf() > 0.03:
			continue
		var holo_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
		var px := mi.position.x
		var py := mi.position.y - bsize.y * 0.5 + 8.0
		var pz := mi.position.z + bsize.z * 0.5 + 3.0
		holo_data.append({
			"pos": Vector3(px, py, pz),
			"color": holo_col,
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(0.5, 1.5),
		})
	for hd in holo_data:
		var holo_col: Color = hd["color"]
		var pos: Vector3 = hd["pos"]
		var proj := MeshInstance3D.new()
		var proj_mesh := BoxMesh.new()
		proj_mesh.size = Vector3(4.0, 6.0, 0.05)
		proj.mesh = proj_mesh
		proj.position = pos
		proj.rotation.x = -0.3
		proj.set_surface_override_material(0,
			_make_ps1_material(holo_col * 0.1, true, holo_col, 2.0))
		add_child(proj)
		var proj_light := OmniLight3D.new()
		proj_light.light_color = holo_col
		proj_light.light_energy = 2.0
		proj_light.omni_range = 10.0
		proj_light.omni_attenuation = 1.5
		proj_light.shadow_enabled = false
		proj_light.position = Vector3(pos.x, pos.y, pos.z + 1.0)
		add_child(proj_light)
		hologram_projections.append({
			"mesh": proj,
			"light": proj_light,
			"phase": hd["phase"],
			"speed": hd["speed"],
			"base_hue": holo_col.h,
		})

func _generate_newspaper_boxes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6200
	var cell_stride_local := block_size + street_width
	var box_colors: Array[Color] = [
		Color(0.05, 0.1, 0.3),  # dark blue
		Color(0.3, 0.05, 0.05), # dark red
		Color(0.05, 0.2, 0.08), # dark green
		Color(0.25, 0.2, 0.0),  # dark yellow
	]
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.10:
				continue
			var cell_x := gx * cell_stride_local
			var cell_z := gz * cell_stride_local
			var bx := cell_x + block_size * 0.5 + street_width * rng.randf_range(0.15, 0.35)
			var bz := cell_z + rng.randf_range(-block_size * 0.3, block_size * 0.3)
			var box := Node3D.new()
			box.position = Vector3(bx, 0, bz)
			var bcol := box_colors[rng.randi_range(0, box_colors.size() - 1)]
			# Body
			var body := MeshInstance3D.new()
			var body_mesh := BoxMesh.new()
			body_mesh.size = Vector3(0.5, 1.0, 0.4)
			body.mesh = body_mesh
			body.position = Vector3(0, 0.5, 0)
			body.set_surface_override_material(0, _make_ps1_material(bcol))
			box.add_child(body)
			# Glass panel
			var glass := MeshInstance3D.new()
			var glass_mesh := BoxMesh.new()
			glass_mesh.size = Vector3(0.35, 0.5, 0.02)
			glass.mesh = glass_mesh
			glass.position = Vector3(0, 0.6, 0.21)
			glass.set_surface_override_material(0,
				_make_ps1_material(Color(0.15, 0.2, 0.25, 0.6)))
			box.add_child(glass)
			add_child(box)

func _generate_crosswalks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6400
	var cell_stride_local := block_size + street_width
	var stripe_mat := _make_ps1_material(Color(0.7, 0.7, 0.7), true, Color(0.8, 0.8, 0.8), 0.5)
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.60:
				continue
			var cell_x := gx * cell_stride_local
			var cell_z := gz * cell_stride_local
			# Crosswalk across X-street (north-south crossing)
			var cross_x := cell_x + block_size * 0.5 + street_width * 0.5
			var cross_z := cell_z + block_size * 0.5
			var num_stripes := 5
			for s in range(num_stripes):
				var stripe := MeshInstance3D.new()
				var stripe_mesh := BoxMesh.new()
				stripe_mesh.size = Vector3(street_width * 0.7, 0.02, 0.4)
				stripe.mesh = stripe_mesh
				stripe.position = Vector3(cross_x, 0.015, cross_z + (s - 2) * 0.8)
				stripe.set_surface_override_material(0, stripe_mat)
				add_child(stripe)
			# Crosswalk signal pole at corner
			if rng.randf() < 0.5:
				var sig_node := Node3D.new()
				var sig_side := 1.0 if rng.randf() < 0.5 else -1.0
				sig_node.position = Vector3(cross_x + sig_side * street_width * 0.4, 0, cross_z - 2.5)
				# Pole
				var sig_pole := MeshInstance3D.new()
				var sp_mesh := CylinderMesh.new()
				sp_mesh.top_radius = 0.04
				sp_mesh.bottom_radius = 0.06
				sp_mesh.height = 3.0
				sig_pole.mesh = sp_mesh
				sig_pole.position = Vector3(0, 1.5, 0)
				sig_pole.set_surface_override_material(0, _make_ps1_material(Color(0.3, 0.3, 0.32)))
				sig_node.add_child(sig_pole)
				# Signal box
				var sig_box := MeshInstance3D.new()
				var sb_mesh := BoxMesh.new()
				sb_mesh.size = Vector3(0.2, 0.3, 0.12)
				sig_box.mesh = sb_mesh
				sig_box.position = Vector3(0, 3.1, 0)
				sig_box.set_surface_override_material(0, _make_ps1_material(Color(0.2, 0.2, 0.22)))
				sig_node.add_child(sig_box)
				# Walk signal (white/green quad)
				var walk_quad := MeshInstance3D.new()
				var wq_mesh := QuadMesh.new()
				wq_mesh.size = Vector2(0.12, 0.12)
				walk_quad.mesh = wq_mesh
				walk_quad.position = Vector3(0, 3.15, 0.07)
				var walk_col := Color(0.2, 1.0, 0.4)
				walk_quad.set_surface_override_material(0,
					_make_ps1_material(walk_col * 0.3, true, walk_col, 3.0))
				walk_quad.visible = false
				sig_node.add_child(walk_quad)
				# Stop signal (red quad)
				var stop_quad := MeshInstance3D.new()
				var sq_mesh := QuadMesh.new()
				sq_mesh.size = Vector2(0.12, 0.12)
				stop_quad.mesh = sq_mesh
				stop_quad.position = Vector3(0, 3.05, 0.07)
				var stop_col := Color(1.0, 0.15, 0.0)
				stop_quad.set_surface_override_material(0,
					_make_ps1_material(stop_col * 0.3, true, stop_col, 3.0))
				sig_node.add_child(stop_quad)
				add_child(sig_node)
				crosswalk_signals.append({
					"walk_mesh": walk_quad,
					"stop_mesh": stop_quad,
					"phase": rng.randf() * 10.0,
				})

func _generate_aircraft_flyover() -> void:
	aircraft_node = Node3D.new()
	aircraft_node.position = Vector3(-200, 120, -200)
	# Body (very simple - just lights visible from distance)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(2.0, 0.5, 0.8)
	body.mesh = body_mesh
	body.set_surface_override_material(0, _make_ps1_material(Color(0.15, 0.15, 0.18)))
	aircraft_node.add_child(body)
	# White strobe (main nav light)
	aircraft_nav_light = OmniLight3D.new()
	aircraft_nav_light.light_color = Color(1.0, 1.0, 1.0)
	aircraft_nav_light.light_energy = 0.0
	aircraft_nav_light.omni_range = 40.0
	aircraft_nav_light.omni_attenuation = 1.0
	aircraft_nav_light.shadow_enabled = false
	aircraft_nav_light.position = Vector3(0, -0.3, 0)
	aircraft_node.add_child(aircraft_nav_light)
	# Red port light
	var red_light := OmniLight3D.new()
	red_light.light_color = Color(1.0, 0.0, 0.0)
	red_light.light_energy = 1.5
	red_light.omni_range = 8.0
	red_light.shadow_enabled = false
	red_light.position = Vector3(-1.0, 0, 0.5)
	aircraft_node.add_child(red_light)
	# Green starboard light
	var green_light := OmniLight3D.new()
	green_light.light_color = Color(0.0, 1.0, 0.0)
	green_light.light_energy = 1.5
	green_light.omni_range = 8.0
	green_light.shadow_enabled = false
	green_light.position = Vector3(1.0, 0, 0.5)
	aircraft_node.add_child(green_light)
	# Register strobe for blinking
	flickering_lights.append({
		"node": aircraft_nav_light, "mesh": null, "base_energy": 5.0,
		"phase": 0.0, "speed": 3.0, "style": "blink",
	})
	add_child(aircraft_node)

func _generate_subway_entrances() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7200
	var stride := block_size + street_width
	var stair_mat := _make_ps1_material(Color(0.2, 0.2, 0.22))
	var rail_mat := _make_ps1_material(Color(0.3, 0.3, 0.32))
	for _i in range(3):
		var gx := rng.randi_range(-grid_size + 1, grid_size - 1)
		var gz := rng.randi_range(-grid_size + 1, grid_size - 1)
		var sx := gx * stride + block_size * 0.5 + street_width * 0.3
		var sz := gz * stride + block_size * 0.5 + rng.randf_range(-1.0, 1.0)
		var entrance := Node3D.new()
		entrance.position = Vector3(sx, 0, sz)
		entrance.rotation.y = rng.randf_range(0, TAU)
		# Descending steps (6 steps going down)
		for step in range(6):
			var s := MeshInstance3D.new()
			var s_mesh := BoxMesh.new()
			s_mesh.size = Vector3(2.0, 0.2, 0.5)
			s.mesh = s_mesh
			s.position = Vector3(0, -step * 0.3, -step * 0.5)
			s.set_surface_override_material(0, stair_mat)
			entrance.add_child(s)
		# Side railings
		for rail_side in [-1.1, 1.1]:
			var rail := MeshInstance3D.new()
			var rail_mesh := BoxMesh.new()
			rail_mesh.size = Vector3(0.05, 1.0, 3.5)
			rail.mesh = rail_mesh
			rail.position = Vector3(rail_side, -0.3, -1.5)
			rail.rotation.x = -0.25
			rail.set_surface_override_material(0, rail_mat)
			entrance.add_child(rail)
		# Warm glow from below
		var glow := OmniLight3D.new()
		glow.light_color = Color(1.0, 0.7, 0.3)
		glow.light_energy = 4.0
		glow.omni_range = 8.0
		glow.omni_attenuation = 1.5
		glow.shadow_enabled = false
		glow.position = Vector3(0, -1.8, -2.5)
		entrance.add_child(glow)
		# 地下鉄 sign above entrance
		if neon_font:
			var sign_label := Label3D.new()
			sign_label.text = "地下鉄"
			sign_label.font = neon_font
			sign_label.font_size = 48
			sign_label.pixel_size = 0.01
			sign_label.modulate = Color(1.0, 0.7, 0.2)
			sign_label.outline_modulate = Color(0.5, 0.3, 0.1)
			sign_label.outline_size = 6
			sign_label.position = Vector3(0, 1.5, 0.3)
			entrance.add_child(sign_label)
			# Sign glow
			var sign_glow := OmniLight3D.new()
			sign_glow.light_color = Color(1.0, 0.7, 0.2)
			sign_glow.light_energy = 2.0
			sign_glow.omni_range = 4.0
			sign_glow.shadow_enabled = false
			sign_glow.position = Vector3(0, 1.5, 0.5)
			entrance.add_child(sign_glow)
		add_child(entrance)

func _generate_helicopter_patrol() -> void:
	helicopter_node = Node3D.new()
	helicopter_node.position = Vector3(70, 85, 0)
	# Body (box fuselage)
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.2, 0.8, 2.5)
	body.mesh = body_mesh
	body.set_surface_override_material(0, _make_ps1_material(Color(0.1, 0.1, 0.12)))
	helicopter_node.add_child(body)
	# Tail boom
	var tail := MeshInstance3D.new()
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(0.2, 0.3, 2.0)
	tail.mesh = tail_mesh
	tail.position = Vector3(0, 0, -2.0)
	tail.set_surface_override_material(0, _make_ps1_material(Color(0.08, 0.08, 0.1)))
	helicopter_node.add_child(tail)
	# Main rotor disc (flat cylinder)
	var rotor := MeshInstance3D.new()
	var rotor_mesh := CylinderMesh.new()
	rotor_mesh.top_radius = 2.5
	rotor_mesh.bottom_radius = 2.5
	rotor_mesh.height = 0.03
	rotor.mesh = rotor_mesh
	rotor.position = Vector3(0, 0.5, 0)
	rotor.set_surface_override_material(0,
		_make_ps1_material(Color(0.15, 0.15, 0.18, 0.3)))
	helicopter_node.add_child(rotor)
	# Searchlight (SpotLight3D pointing down)
	helicopter_searchlight = SpotLight3D.new()
	helicopter_searchlight.light_color = Color(1.0, 0.95, 0.85)
	helicopter_searchlight.light_energy = 8.0
	helicopter_searchlight.spot_range = 120.0
	helicopter_searchlight.spot_angle = 12.0
	helicopter_searchlight.spot_attenuation = 1.2
	helicopter_searchlight.shadow_enabled = false
	helicopter_searchlight.position = Vector3(0, -0.5, 0.5)
	helicopter_searchlight.rotation.x = -1.3  # point downward
	helicopter_node.add_child(helicopter_searchlight)
	# Nav lights (red port, green starboard)
	helicopter_nav_red = OmniLight3D.new()
	helicopter_nav_red.light_color = Color(1.0, 0.0, 0.0)
	helicopter_nav_red.light_energy = 0.0
	helicopter_nav_red.omni_range = 15.0
	helicopter_nav_red.shadow_enabled = false
	helicopter_nav_red.position = Vector3(-0.7, 0, 1.0)
	helicopter_node.add_child(helicopter_nav_red)
	helicopter_nav_green = OmniLight3D.new()
	helicopter_nav_green.light_color = Color(0.0, 1.0, 0.0)
	helicopter_nav_green.light_energy = 0.0
	helicopter_nav_green.omni_range = 15.0
	helicopter_nav_green.shadow_enabled = false
	helicopter_nav_green.position = Vector3(0.7, 0, 1.0)
	helicopter_node.add_child(helicopter_nav_green)
	# White belly light (always on, dim)
	var belly := OmniLight3D.new()
	belly.light_color = Color(0.8, 0.8, 1.0)
	belly.light_energy = 1.5
	belly.omni_range = 10.0
	belly.shadow_enabled = false
	belly.position = Vector3(0, -0.5, 0)
	helicopter_node.add_child(belly)
	add_child(helicopter_node)

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
				# Find parent Label3D if any (to flicker the text too)
				var parent_node: Node = light.get_parent()
				var label_ref: Label3D = null
				if parent_node is Label3D:
					label_ref = parent_node as Label3D
				var style_roll := rng.randi_range(0, 2)
				var pick: String = "flicker"
				if style_roll == 1:
					pick = "stutter"
				elif style_roll == 2:
					pick = "dying"
				flickering_lights.append({
					"node": light,
					"mesh": null,
					"label": label_ref,
					"base_energy": light.light_energy,
					"phase": rng.randf() * TAU,
					"speed": rng.randf_range(3.0, 12.0),
					"style": pick,
				})
		_collect_neon_lights(child, rng)

func _process(_delta: float) -> void:
	var time := Time.get_ticks_msec() / 1000.0

	# Neon boot-up sequence (first 5 seconds)
	if not boot_complete:
		boot_time += _delta
		if boot_time > 5.0:
			boot_complete = true

	# Neon flickering and antenna blinking
	for data in flickering_lights:
		var light: OmniLight3D = data["node"]
		if not is_instance_valid(light):
			continue
		var phase: float = data["phase"]
		var speed: float = data["speed"]
		var base: float = data["base_energy"]
		var style: String = data["style"]

		# Boot-up: lights stay off until their distance-based delay passes
		if not boot_complete:
			var light_dist := light.global_position.length()
			var delay := clampf(light_dist * 0.03, 0.0, 4.5)
			if boot_time < delay:
				light.light_energy = 0.0
				var boot_mesh = data.get("mesh")
				if boot_mesh and is_instance_valid(boot_mesh):
					(boot_mesh as MeshInstance3D).visible = false
				var boot_label = data.get("label")
				if boot_label and is_instance_valid(boot_label):
					(boot_label as Label3D).modulate.a = 0.0
				continue

		if style == "blink":
			var val := sin(time * speed + phase)
			var on := 1.0 if val > 0.0 else 0.0
			light.light_energy = base * on
			var mesh_node = data["mesh"]
			if mesh_node and is_instance_valid(mesh_node):
				(mesh_node as MeshInstance3D).visible = val > 0.0
		elif style == "tv":
			# TV screen flicker: irregular brightness changes
			var tv_val := 0.6 + 0.4 * sin(time * speed + phase) * sin(time * speed * 0.37 + phase * 1.7)
			# Occasional brightness spike (scene change)
			if sin(time * speed * 0.1 + phase) > 0.9:
				tv_val = 1.2
			light.light_energy = base * tv_val
			# Slight color shift
			var r_shift := 0.3 + 0.1 * sin(time * speed * 0.5 + phase)
			light.light_color = Color(r_shift, 0.4, 0.9)
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
		elif style == "double_flash":
			# Aviation double-flash: two quick blinks then pause
			var df_cycle := fmod(time * speed * 0.5 + phase, 3.0)
			var on_val := 0.0
			if df_cycle < 0.08:
				on_val = 1.0
			elif df_cycle > 0.2 and df_cycle < 0.28:
				on_val = 1.0
			light.light_energy = base * on_val
			var df_mesh = data["mesh"]
			if df_mesh and is_instance_valid(df_mesh):
				(df_mesh as MeshInstance3D).visible = on_val > 0.0
		elif style == "slow_pulse":
			# Slow sinusoidal glow
			var pulse := (sin(time * speed * 0.3 + phase) + 1.0) * 0.5
			light.light_energy = base * pulse
			var sp_mesh = data["mesh"]
			if sp_mesh and is_instance_valid(sp_mesh):
				(sp_mesh as MeshInstance3D).visible = pulse > 0.1
		elif style == "stutter":
			# Rapid on-off stutter
			var stut := sin(time * speed * 8.0 + phase) * sin(time * speed * 5.3 + phase * 2.1)
			var on_val := 1.0 if stut > -0.3 else 0.0
			light.light_energy = base * on_val
			var stut_label = data.get("label")
			if stut_label and is_instance_valid(stut_label):
				(stut_label as Label3D).modulate.a = on_val
		elif style == "dying":
			# Slow fade out then snap back on
			var fade_cycle := fmod(time * speed * 0.3 + phase, 6.0)
			var energy_mult := 1.0
			if fade_cycle > 4.0:
				energy_mult = maxf(0.0, 1.0 - (fade_cycle - 4.0))
			elif fade_cycle > 3.8:
				energy_mult = 0.05  # almost dead
			light.light_energy = base * energy_mult
			var dying_label = data.get("label")
			if dying_label and is_instance_valid(dying_label):
				(dying_label as Label3D).modulate.a = clampf(energy_mult, 0.1, 1.0)
		else:
			var flick := sin(time * speed + phase) * sin(time * speed * 1.7 + phase * 0.5)
			var sputter := 1.0
			if sin(time * speed * 3.0 + phase * 2.0) > 0.92:
				sputter = 0.1
			light.light_energy = base * (0.5 + 0.5 * flick) * sputter
			var flick_label = data.get("label")
			if flick_label and is_instance_valid(flick_label):
				(flick_label as Label3D).modulate.a = 0.3 + 0.7 * (0.5 + 0.5 * flick) * sputter

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

	# Color-shifting neon signs
	for cs in color_shift_signs:
		var cs_node: Label3D = cs["node"]
		if not is_instance_valid(cs_node):
			continue
		var cs_phase: float = cs["phase"]
		var cs_speed: float = cs["speed"]
		var cs_base_hue: float = cs["base_hue"]
		var hue := fmod(cs_base_hue + sin(time * cs_speed + cs_phase) * 0.15 + 0.5, 1.0)
		var col := Color.from_hsv(hue, 0.9, 1.0)
		cs_node.modulate = col
		var cs_light = cs["light"]
		if cs_light and is_instance_valid(cs_light):
			(cs_light as OmniLight3D).light_color = col

	# Crosswalk walk/stop signals (synced to 10s traffic cycle)
	for cs in crosswalk_signals:
		var walk_m: MeshInstance3D = cs["walk_mesh"]
		var stop_m: MeshInstance3D = cs["stop_mesh"]
		if not is_instance_valid(walk_m):
			continue
		var cs_phase: float = cs["phase"]
		var cs_cycle := fmod(time + cs_phase, 10.0)
		# Walk when traffic is red (6-10s), stop when green/yellow (0-6s)
		if cs_cycle > 6.0:
			walk_m.visible = true
			stop_m.visible = false
		else:
			walk_m.visible = false
			stop_m.visible = true
			# Blink stop signal in last second before walk
			if cs_cycle > 5.0:
				stop_m.visible = fmod(time * 4.0, 1.0) < 0.5

	# Rotating ventilation fans
	for fan in rotating_fans:
		var blade1: MeshInstance3D = fan["blade1"]
		var blade2: MeshInstance3D = fan["blade2"]
		if not is_instance_valid(blade1):
			continue
		var fan_speed: float = fan["speed"]
		blade1.rotation.y = time * fan_speed
		blade2.rotation.y = time * fan_speed

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

	# Surveillance drone patrol (figure-8 path)
	if drone_node and is_instance_valid(drone_node):
		drone_time += _delta
		var patrol_radius := 50.0
		var patrol_speed := 0.15
		var t := drone_time * patrol_speed
		drone_node.position.x = sin(t) * patrol_radius
		drone_node.position.z = sin(t * 2.0) * patrol_radius * 0.5
		drone_node.position.y = 35.0 + sin(drone_time * 0.3) * 2.0
		# Face direction of travel
		var next_x := sin(t + 0.01) * patrol_radius
		var next_z := sin((t + 0.01) * 2.0) * patrol_radius * 0.5
		drone_node.rotation.y = atan2(next_x - drone_node.position.x, next_z - drone_node.position.z)

	# Pipe arc flicker (rapid blue-white sparking)
	for pa in pipe_arcs:
		var arc_light: OmniLight3D = pa["light"]
		if not is_instance_valid(arc_light):
			continue
		var pa_phase: float = pa["phase"]
		var pa_speed: float = pa["speed"]
		# Sparse sparking: mostly off, occasional rapid flashes
		var spark_val := sin(time * pa_speed + pa_phase) * sin(time * pa_speed * 0.7 + pa_phase * 1.3)
		if spark_val > 0.85:
			arc_light.light_energy = 2.5 + sin(time * 60.0) * 1.5
		else:
			arc_light.light_energy = 0.0

	# Police car light bar (alternating red/blue)
	if police_red_light and is_instance_valid(police_red_light):
		var siren_cycle := fmod(time * 3.0, 2.0)
		if siren_cycle < 0.5:
			police_red_light.light_energy = 6.0
			police_blue_light.light_energy = 0.0
		elif siren_cycle < 0.7:
			police_red_light.light_energy = 0.0
			police_blue_light.light_energy = 0.0
		elif siren_cycle < 1.2:
			police_red_light.light_energy = 0.0
			police_blue_light.light_energy = 6.0
		else:
			police_red_light.light_energy = 0.0
			police_blue_light.light_energy = 0.0

	# Aircraft flyover (slow linear path, wraps)
	if aircraft_node and is_instance_valid(aircraft_node):
		aircraft_time += _delta
		var flight_speed := 15.0
		var extent := grid_size * (block_size + street_width)
		aircraft_node.position.x = -extent * 1.5 + fmod(aircraft_time * flight_speed, extent * 3.0)
		aircraft_node.position.z = sin(aircraft_time * 0.05) * extent * 0.5
		aircraft_node.position.y = 120.0 + sin(aircraft_time * 0.1) * 10.0

	# Helicopter patrol (circular path with searchlight)
	if helicopter_node and is_instance_valid(helicopter_node):
		helicopter_time += _delta
		var orbit_radius := 70.0
		var orbit_speed := 0.12
		var ht := helicopter_time * orbit_speed
		helicopter_node.position.x = cos(ht) * orbit_radius
		helicopter_node.position.z = sin(ht) * orbit_radius
		helicopter_node.position.y = 85.0 + sin(helicopter_time * 0.2) * 5.0
		# Face direction of travel
		helicopter_node.rotation.y = -ht + PI * 0.5
		# Searchlight sweeps in a small circle below
		if helicopter_searchlight:
			var sweep_angle := helicopter_time * 0.8
			helicopter_searchlight.rotation.x = -1.3 + sin(sweep_angle) * 0.15
			helicopter_searchlight.rotation.z = cos(sweep_angle * 0.7) * 0.2
		# Blinking nav lights
		if helicopter_nav_red and helicopter_nav_green:
			var blink := fmod(time, 1.0)
			helicopter_nav_red.light_energy = 3.0 if blink < 0.15 else 0.0
			helicopter_nav_green.light_energy = 3.0 if (blink > 0.5 and blink < 0.65) else 0.0

	# Hologram projection shimmer
	for hp in hologram_projections:
		var hp_mesh: MeshInstance3D = hp["mesh"]
		var hp_light: OmniLight3D = hp["light"]
		if not is_instance_valid(hp_mesh):
			continue
		var hp_phase: float = hp["phase"]
		var hp_speed: float = hp["speed"]
		var hp_base_hue: float = hp["base_hue"]
		var hue := fmod(hp_base_hue + sin(time * hp_speed + hp_phase) * 0.1 + 0.5, 1.0)
		var hcol := Color.from_hsv(hue, 0.8, 1.0)
		hp_mesh.set_surface_override_material(0,
			_make_ps1_material(hcol * 0.1, true, hcol, 2.0 + sin(time * 3.0 + hp_phase) * 0.5))
		if is_instance_valid(hp_light):
			hp_light.light_color = hcol
			hp_light.light_energy = 2.0 + sin(time * 2.0 + hp_phase) * 0.8

	# Distant radio music (proximity-based)
	if radio_pool.size() > 0:
		var radio_cam := get_viewport().get_camera_3d()
		if radio_cam:
			var rc_pos := radio_cam.global_position
			# Find nearest radio positions
			var nearest_radios: Array[Dictionary] = []
			for rpos in radio_positions:
				var d := rpos.distance_to(rc_pos)
				if d < RADIO_RANGE:
					nearest_radios.append({"pos": rpos, "dist": d})
			nearest_radios.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["dist"] < b["dist"])
			for i in range(RADIO_POOL_SIZE):
				var slot: Dictionary = radio_pool[i]
				var player: AudioStreamPlayer3D = slot["player"]
				var playback: AudioStreamGeneratorPlayback = slot["playback"]
				if i < nearest_radios.size():
					player.global_position = nearest_radios[i]["pos"]
					if playback:
						var frames := playback.get_frames_available()
						var ph: float = slot["phase"]
						var note_timer: float = slot["note_timer"]
						var current_freq: float = slot["current_freq"]
						var filter_state: float = slot["filter_state"]
						var beat_phase: float = slot["beat_phase"]
						var mix_rate := 22050.0
						# Pentatonic scale frequencies (muffled, lo-fi feel)
						var pentatonic: Array[float] = [220.0, 246.9, 293.7, 329.6, 392.0, 440.0, 493.9]
						for _f in range(frames):
							ph += 1.0 / mix_rate
							note_timer -= 1.0 / mix_rate
							beat_phase += 1.0 / mix_rate
							if note_timer <= 0.0:
								note_timer = radio_rng.randf_range(0.2, 0.5)
								current_freq = pentatonic[radio_rng.randi_range(0, pentatonic.size() - 1)]
							# Simple sine melody
							var melody := sin(ph * current_freq * TAU) * 0.15
							# Muffled kick drum on beat
							var beat_pos := fmod(beat_phase, 0.5)
							var kick := 0.0
							if beat_pos < 0.05:
								kick = sin(beat_pos * 80.0 * TAU) * (1.0 - beat_pos / 0.05) * 0.2
							var raw := melody + kick
							# Heavy low-pass filter (muffled through wall)
							filter_state = filter_state * 0.92 + raw * 0.08
							var sample := filter_state * 0.4
							playback.push_frame(Vector2(sample, sample))
						slot["phase"] = ph
						slot["note_timer"] = note_timer
						slot["current_freq"] = current_freq
						slot["filter_state"] = filter_state
						slot["beat_phase"] = beat_phase
				else:
					if playback:
						var frames := playback.get_frames_available()
						for _f in range(frames):
							playback.push_frame(Vector2.ZERO)

	# Steam burst timers
	for sb in steam_bursts:
		sb["timer"] -= _delta
		if sb["timer"] <= 0.0:
			var burst_p: GPUParticles3D = sb["particles"]
			if is_instance_valid(burst_p):
				burst_p.restart()
				burst_p.emitting = true
			sb["timer"] = randf_range(sb["interval_min"], sb["interval_max"])

	# Stray cat AI (flee from player)
	var cam2 := get_viewport().get_camera_3d()
	if cam2:
		var player_pos := cam2.global_position
		for cat_data in stray_cats:
			var cat_node: Node3D = cat_data["node"]
			var home_pos: Vector3 = cat_data["home_pos"]
			var dist_to_player := cat_node.global_position.distance_to(player_pos)
			var is_fleeing: bool = cat_data["fleeing"]
			if dist_to_player < 5.0 and not is_fleeing:
				# Start fleeing
				cat_data["fleeing"] = true
				var away := (cat_node.global_position - player_pos).normalized()
				away.y = 0.0
				cat_data["flee_dir"] = away
			if is_fleeing:
				var flee_dir: Vector3 = cat_data["flee_dir"]
				cat_node.position += flee_dir * 6.0 * _delta
				cat_node.rotation.y = atan2(flee_dir.x, flee_dir.z)
				var dist_from_home := cat_node.global_position.distance_to(home_pos)
				if dist_from_home > 15.0 or dist_to_player > 20.0:
					# Return home
					cat_data["fleeing"] = false
					cat_node.position = home_pos

	# Neon buzz audio (proximity-based)
	if neon_buzz_pool.size() > 0:
		var cam := get_viewport().get_camera_3d()
		if cam:
			var cam_pos := cam.global_position
			# Find nearest neon sign positions
			var nearest: Array[Dictionary] = []
			for pos in neon_buzz_positions:
				var d := pos.distance_to(cam_pos)
				if d < NEON_BUZZ_RANGE:
					nearest.append({"pos": pos, "dist": d})
			nearest.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["dist"] < b["dist"])
			for i in range(NEON_BUZZ_POOL_SIZE):
				var slot: Dictionary = neon_buzz_pool[i]
				var player: AudioStreamPlayer3D = slot["player"]
				var playback: AudioStreamGeneratorPlayback = slot["playback"]
				if i < nearest.size():
					player.global_position = nearest[i]["pos"]
					if playback:
						var frames := playback.get_frames_available()
						var ph: float = slot["phase"]
						var mix_rate := 22050.0
						for _f in range(frames):
							ph += 1.0 / mix_rate
							# 120Hz buzz with harmonics + slight warble
							var buzz := sin(ph * 120.0 * TAU) * 0.4
							buzz += sin(ph * 240.0 * TAU) * 0.2
							buzz += sin(ph * 360.0 * TAU) * 0.1
							# Warble modulation
							buzz *= 0.8 + 0.2 * sin(ph * 3.0 * TAU)
							var sample := buzz * 0.15
							playback.push_frame(Vector2(sample, sample))
						slot["phase"] = ph
				else:
					if playback:
						var frames := playback.get_frames_available()
						for _f in range(frames):
							playback.push_frame(Vector2.ZERO)

func _generate_neon_light_shafts() -> void:
	# Add translucent light cones below bright neon sign lights (fog shaft effect)
	var rng := RandomNumberGenerator.new()
	rng.seed = 6500
	var shafts_to_add: Array[Dictionary] = []
	var children_snapshot := get_children()
	for raw_child in children_snapshot:
		if not raw_child is Node3D:
			continue
		var child := raw_child as Node3D
		for sub in child.get_children():
			if not sub is OmniLight3D:
				continue
			var light := sub as OmniLight3D
			if light.light_energy < 2.0:
				continue
			var world_y := child.position.y + light.position.y
			if world_y < 4.0 or world_y > 20.0:
				continue
			if rng.randf() > 0.10:
				continue
			# Create a downward-pointing light shaft
			var shaft_height := minf(world_y - 0.5, rng.randf_range(3.0, 8.0))
			var shaft_top_x := child.position.x + light.position.x
			var shaft_top_z := child.position.z + light.position.z
			shafts_to_add.append({
				"pos": Vector3(shaft_top_x, world_y - shaft_height * 0.5, shaft_top_z),
				"height": shaft_height,
				"color": light.light_color,
				"width": rng.randf_range(0.5, 1.2),
			})
	for sd in shafts_to_add:
		var shaft := MeshInstance3D.new()
		var shaft_mesh := BoxMesh.new()
		var sw: float = sd["width"]
		var sh: float = sd["height"]
		shaft_mesh.size = Vector3(sw, sh, sw * 0.3)
		shaft.mesh = shaft_mesh
		shaft.position = sd["pos"]
		var scol: Color = sd["color"]
		# Faint emissive material for volumetric look
		shaft.set_surface_override_material(0,
			_make_ps1_material(scol * 0.02, true, scol, 0.4))
		shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(shaft)

func _generate_distant_city_glow() -> void:
	# Ring of faint emissive walls at city boundary to simulate infinite city
	var extent := grid_size * (block_size + street_width)
	var glow_distance := extent + 10.0
	var glow_height := 60.0
	var glow_color := Color(0.15, 0.08, 0.12)
	var warm_glow := Color(1.0, 0.5, 0.25)

	# 4 walls (N, S, E, W) forming a boundary ring
	var wall_positions := [
		{"pos": Vector3(0, glow_height * 0.5, glow_distance), "size": Vector3(glow_distance * 2.0, glow_height, 2.0)},
		{"pos": Vector3(0, glow_height * 0.5, -glow_distance), "size": Vector3(glow_distance * 2.0, glow_height, 2.0)},
		{"pos": Vector3(glow_distance, glow_height * 0.5, 0), "size": Vector3(2.0, glow_height, glow_distance * 2.0)},
		{"pos": Vector3(-glow_distance, glow_height * 0.5, 0), "size": Vector3(2.0, glow_height, glow_distance * 2.0)},
	]
	for wall_data in wall_positions:
		var wall := MeshInstance3D.new()
		var wall_mesh := BoxMesh.new()
		wall_mesh.size = wall_data["size"]
		wall.mesh = wall_mesh
		wall.position = wall_data["pos"]
		wall.set_surface_override_material(0,
			_make_ps1_material(glow_color, true, warm_glow, 0.6))
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wall)

	# Ground-level smog ring (horizontal plane at city boundary)
	var smog := MeshInstance3D.new()
	var smog_mesh := BoxMesh.new()
	smog_mesh.size = Vector3(glow_distance * 3.0, 0.5, glow_distance * 3.0)
	smog.mesh = smog_mesh
	smog.position = Vector3(0, 5.0, 0)
	var smog_color := Color(0.08, 0.04, 0.06)
	smog.set_surface_override_material(0,
		_make_ps1_material(smog_color, true, warm_glow * 0.3, 0.2))
	smog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smog)

func _setup_neon_buzz_audio() -> void:
	buzz_rng.seed = 6600
	# Collect world positions of bright neon sign lights
	var children_snapshot := get_children()
	for raw_child in children_snapshot:
		if not raw_child is Node3D:
			continue
		var child := raw_child as Node3D
		for sub in child.get_children():
			if sub is OmniLight3D:
				var light := sub as OmniLight3D
				if light.light_energy >= 2.0:
					var world_pos := child.position + light.position
					if world_pos.y > 2.0 and world_pos.y < 25.0:
						neon_buzz_positions.append(world_pos)
			# Check grandchildren (labels with lights)
			if sub is Node3D:
				var sub3d := sub as Node3D
				for subsub in sub3d.get_children():
					if subsub is OmniLight3D:
						var light2 := subsub as OmniLight3D
						if light2.light_energy >= 2.0:
							var world_pos2 := child.position + sub3d.position + light2.position
							if world_pos2.y > 2.0 and world_pos2.y < 25.0:
								neon_buzz_positions.append(world_pos2)
	# Create audio pool
	for _i in range(NEON_BUZZ_POOL_SIZE):
		var player := AudioStreamPlayer3D.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.1
		player.stream = gen
		player.volume_db = -20.0
		player.max_distance = NEON_BUZZ_RANGE
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 4.0
		add_child(player)
		player.play()
		neon_buzz_pool.append({
			"player": player,
			"generator": gen,
			"playback": player.get_stream_playback(),
			"phase": 0.0,
		})

func _generate_rooftop_water_tanks() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6700
	var children_snapshot := get_children()
	var tanks_to_add: Array[Dictionary] = []
	for raw_child in children_snapshot:
		if not raw_child is MeshInstance3D:
			continue
		var child := raw_child as MeshInstance3D
		if not child.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (child.mesh as BoxMesh).size
		if bsize.y < 20.0:
			continue
		if rng.randf() > 0.10:
			continue
		tanks_to_add.append({
			"pos": Vector3(child.position.x, child.position.y + bsize.y * 0.5, child.position.z),
			"roof_w": bsize.x,
			"roof_d": bsize.z,
		})
	var tank_color := Color(0.15, 0.13, 0.12)
	var leg_color := Color(0.1, 0.1, 0.1)
	for td in tanks_to_add:
		var tank_parent := Node3D.new()
		var roof_pos: Vector3 = td["pos"]
		var rw: float = td["roof_w"]
		var rd: float = td["roof_d"]
		var offset_x := rng.randf_range(-rw * 0.25, rw * 0.25)
		var offset_z := rng.randf_range(-rd * 0.25, rd * 0.25)
		tank_parent.position = Vector3(roof_pos.x + offset_x, roof_pos.y, roof_pos.z + offset_z)
		# Cylinder tank body
		var tank := MeshInstance3D.new()
		var tank_mesh := CylinderMesh.new()
		tank_mesh.top_radius = 0.8
		tank_mesh.bottom_radius = 0.8
		tank_mesh.height = 1.5
		tank.mesh = tank_mesh
		tank.position = Vector3(0, 2.5, 0)
		tank.set_surface_override_material(0, _make_ps1_material(tank_color))
		tank_parent.add_child(tank)
		# 4 legs
		for li in range(4):
			var leg := MeshInstance3D.new()
			var leg_mesh := BoxMesh.new()
			leg_mesh.size = Vector3(0.08, 1.8, 0.08)
			leg.mesh = leg_mesh
			var lx := 0.5 if li % 2 == 0 else -0.5
			var lz := 0.5 if li < 2 else -0.5
			leg.position = Vector3(lx, 0.9, lz)
			leg.set_surface_override_material(0, _make_ps1_material(leg_color))
			tank_parent.add_child(leg)
		add_child(tank_parent)

func _setup_radio_audio() -> void:
	radio_rng.seed = 7100
	# Pick 4 random building positions for radio sources
	var stride := block_size + street_width
	for _i in range(4):
		var gx := radio_rng.randi_range(-grid_size + 1, grid_size - 1)
		var gz := radio_rng.randi_range(-grid_size + 1, grid_size - 1)
		var rx := gx * stride + radio_rng.randf_range(2.0, block_size - 2.0)
		var rz := gz * stride + radio_rng.randf_range(2.0, block_size - 2.0)
		radio_positions.append(Vector3(rx, 2.5, rz))
	# Create audio pool
	for _i in range(RADIO_POOL_SIZE):
		var player := AudioStreamPlayer3D.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.1
		player.stream = gen
		player.volume_db = -14.0
		player.max_distance = RADIO_RANGE
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 5.0
		add_child(player)
		player.play()
		radio_pool.append({
			"player": player,
			"generator": gen,
			"playback": player.get_stream_playback(),
			"phase": 0.0,
			"note_timer": 0.0,
			"current_freq": 220.0,
			"filter_state": 0.0,
			"beat_phase": 0.0,
		})

func _generate_stray_cats() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6900
	var num_cats := 7
	for _i in range(num_cats):
		var cat := Node3D.new()
		# Place near a random sidewalk edge
		var gx := rng.randi_range(-grid_size + 1, grid_size - 1)
		var gz := rng.randi_range(-grid_size + 1, grid_size - 1)
		var stride := block_size + street_width
		var cat_x := gx * stride + block_size * 0.5 + rng.randf_range(-2.0, 2.0)
		var cat_z := gz * stride + block_size * 0.5 + rng.randf_range(-2.0, 2.0)
		var cat_y := rng.randf_range(0.0, 0.3)  # ground level or on something
		cat.position = Vector3(cat_x, cat_y, cat_z)
		cat.rotation.y = rng.randf_range(0, TAU)
		# Cat colors
		var cat_colors_arr: Array[Color] = [
			Color(0.15, 0.12, 0.1),  # dark brown
			Color(0.1, 0.1, 0.1),    # black
			Color(0.5, 0.35, 0.2),   # orange tabby
			Color(0.3, 0.3, 0.3),    # gray
			Color(0.6, 0.55, 0.45),  # cream
		]
		var cat_col := cat_colors_arr[rng.randi_range(0, cat_colors_arr.size() - 1)]
		# Body (elongated box)
		var body := MeshInstance3D.new()
		var body_mesh := BoxMesh.new()
		body_mesh.size = Vector3(0.12, 0.1, 0.25)
		body.mesh = body_mesh
		body.position = Vector3(0, 0.12, 0)
		body.set_surface_override_material(0, _make_ps1_material(cat_col))
		cat.add_child(body)
		# Head (smaller box)
		var head := MeshInstance3D.new()
		var head_mesh := BoxMesh.new()
		head_mesh.size = Vector3(0.1, 0.08, 0.08)
		head.mesh = head_mesh
		head.position = Vector3(0, 0.18, 0.14)
		head.set_surface_override_material(0, _make_ps1_material(cat_col))
		cat.add_child(head)
		# Eyes (tiny green emissive dots)
		for side in [-0.025, 0.025]:
			var eye := MeshInstance3D.new()
			var eye_mesh := BoxMesh.new()
			eye_mesh.size = Vector3(0.015, 0.015, 0.01)
			eye.mesh = eye_mesh
			eye.position = Vector3(side, 0.19, 0.185)
			var eye_col := Color(0.2, 1.0, 0.3)
			eye.set_surface_override_material(0,
				_make_ps1_material(eye_col * 0.3, true, eye_col, 2.5))
			cat.add_child(eye)
		# Tail (thin elongated box, angled up)
		var tail := MeshInstance3D.new()
		var tail_mesh := BoxMesh.new()
		tail_mesh.size = Vector3(0.03, 0.03, 0.2)
		tail.mesh = tail_mesh
		tail.position = Vector3(0, 0.18, -0.18)
		tail.rotation.x = -0.5  # angled up
		tail.set_surface_override_material(0, _make_ps1_material(cat_col))
		cat.add_child(tail)
		# Ears (two small prisms approximated with boxes)
		for ear_side in [-0.03, 0.03]:
			var ear := MeshInstance3D.new()
			var ear_mesh := BoxMesh.new()
			ear_mesh.size = Vector3(0.025, 0.04, 0.02)
			ear.mesh = ear_mesh
			ear.position = Vector3(ear_side, 0.24, 0.14)
			ear.set_surface_override_material(0, _make_ps1_material(cat_col * 0.8))
			cat.add_child(ear)
		add_child(cat)
		stray_cats.append({
			"node": cat,
			"home_pos": cat.position,
			"fleeing": false,
			"flee_dir": Vector3.ZERO,
		})

func _generate_building_entrances() -> void:
	# Add lobby entrance features (recessed door, overhead light, number plate)
	# to regular (non-storefront) buildings at ground level
	var rng := RandomNumberGenerator.new()
	rng.seed = 7300
	var children_snapshot := get_children()
	for raw_child in children_snapshot:
		if not raw_child is MeshInstance3D:
			continue
		var child := raw_child as MeshInstance3D
		if not child.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (child.mesh as BoxMesh).size
		# Only buildings tall enough to have a lobby, not too small
		if bsize.y < 12.0 or bsize.x < 7.0:
			continue
		if rng.randf() > 0.35:
			continue
		var half_w := bsize.x * 0.5
		var half_h := bsize.y * 0.5
		var half_d := bsize.z * 0.5
		# Pick a face (+Z front, -Z back, +X right, -X left)
		var face := rng.randi_range(0, 1)
		var door_pos := Vector3.ZERO
		var door_rot := 0.0
		if face == 0:
			# +Z face
			door_pos = Vector3(rng.randf_range(-half_w * 0.3, half_w * 0.3), -half_h + 1.5, half_d + 0.01)
		else:
			# -Z face
			door_pos = Vector3(rng.randf_range(-half_w * 0.3, half_w * 0.3), -half_h + 1.5, -half_d - 0.01)
			door_rot = PI
		# Dark recessed door frame
		var door_frame := MeshInstance3D.new()
		var frame_mesh := BoxMesh.new()
		frame_mesh.size = Vector3(1.8, 3.0, 0.15)
		door_frame.mesh = frame_mesh
		door_frame.position = door_pos
		door_frame.rotation.y = door_rot
		door_frame.set_surface_override_material(0, _make_ps1_material(Color(0.08, 0.07, 0.06)))
		child.add_child(door_frame)
		# Warm overhead light above door
		var door_light := OmniLight3D.new()
		var light_warm := rng.randf() < 0.7
		if light_warm:
			door_light.light_color = Color(1.0, 0.8, 0.5)
		else:
			door_light.light_color = Color(0.7, 0.85, 1.0)  # cool fluorescent
		door_light.light_energy = rng.randf_range(1.5, 3.0)
		door_light.omni_range = 5.0
		door_light.omni_attenuation = 1.5
		door_light.shadow_enabled = false
		door_light.position = door_pos + Vector3(0, 1.8, 0)
		child.add_child(door_light)
		# 30% of entrance lights flicker
		if rng.randf() < 0.3:
			var flick_style := "buzz" if not light_warm else "flicker"
			flickering_lights.append({
				"node": door_light, "mesh": null,
				"base_energy": door_light.light_energy,
				"phase": rng.randf() * TAU,
				"speed": rng.randf_range(8.0, 15.0),
				"style": flick_style,
			})
		# Small emissive light fixture above door
		var fixture := MeshInstance3D.new()
		var fix_mesh := BoxMesh.new()
		fix_mesh.size = Vector3(0.4, 0.08, 0.12)
		fixture.mesh = fix_mesh
		fixture.position = door_pos + Vector3(0, 3.15, 0)
		var fix_col := door_light.light_color
		fixture.set_surface_override_material(0,
			_make_ps1_material(fix_col * 0.5, true, fix_col, 3.0))
		child.add_child(fixture)
		# Address number plate (small label beside door)
		if neon_font and rng.randf() < 0.5:
			var addr := Label3D.new()
			addr.text = str(rng.randi_range(100, 9999))
			addr.font = neon_font
			addr.font_size = 18
			addr.pixel_size = 0.006
			addr.modulate = Color(0.7, 0.65, 0.55)
			addr.outline_modulate = Color(0.2, 0.18, 0.12)
			addr.outline_size = 2
			var side_offset := 1.2 if rng.randf() < 0.5 else -1.2
			addr.position = door_pos + Vector3(side_offset, 0.5, 0.02)
			addr.rotation.y = door_rot
			child.add_child(addr)

func _generate_street_vendors() -> void:
	# Small street vendor stalls along sidewalks with canopy, counter, and warm light
	var rng := RandomNumberGenerator.new()
	rng.seed = 7400
	var num_vendors := 5
	for _i in range(num_vendors):
		var gx := rng.randi_range(-grid_size + 1, grid_size - 1)
		var gz := rng.randi_range(-grid_size + 1, grid_size - 1)
		var stride := block_size + street_width
		var vx := gx * stride + block_size * 0.5 + rng.randf_range(1.0, 3.0)
		var vz := gz * stride + rng.randf_range(-block_size * 0.3, block_size * 0.3)
		var vendor := Node3D.new()
		vendor.position = Vector3(vx, 0, vz)
		vendor.rotation.y = rng.randf_range(0, TAU)
		# Counter (wooden box)
		var counter := MeshInstance3D.new()
		var counter_mesh := BoxMesh.new()
		counter_mesh.size = Vector3(2.0, 1.0, 0.8)
		counter.mesh = counter_mesh
		counter.position = Vector3(0, 0.5, 0)
		counter.set_surface_override_material(0, _make_ps1_material(Color(0.3, 0.22, 0.12)))
		vendor.add_child(counter)
		# Canopy roof (thin angled box)
		var canopy := MeshInstance3D.new()
		var canopy_mesh := BoxMesh.new()
		canopy_mesh.size = Vector3(2.5, 0.05, 1.5)
		canopy.mesh = canopy_mesh
		canopy.position = Vector3(0, 2.3, -0.2)
		canopy.rotation.x = 0.1  # slight tilt
		var canopy_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)] * 0.4
		canopy.set_surface_override_material(0, _make_ps1_material(canopy_col))
		vendor.add_child(canopy)
		# Support poles (4 corners)
		var pole_mat := _make_ps1_material(Color(0.3, 0.3, 0.33))
		for px in [-1.1, 1.1]:
			for pz in [-0.6, 0.4]:
				var pole := MeshInstance3D.new()
				var pole_mesh := BoxMesh.new()
				pole_mesh.size = Vector3(0.05, 2.3, 0.05)
				pole.mesh = pole_mesh
				pole.position = Vector3(px, 1.15, pz)
				pole.set_surface_override_material(0, pole_mat)
				vendor.add_child(pole)
		# Warm light under canopy
		var stall_light := OmniLight3D.new()
		stall_light.light_color = Color(1.0, 0.85, 0.5)
		stall_light.light_energy = 2.5
		stall_light.omni_range = 5.0
		stall_light.omni_attenuation = 1.5
		stall_light.shadow_enabled = false
		stall_light.position = Vector3(0, 2.1, 0)
		vendor.add_child(stall_light)
		# Small items on counter (tiny colored boxes)
		for _item in range(rng.randi_range(3, 6)):
			var item := MeshInstance3D.new()
			var item_mesh := BoxMesh.new()
			item_mesh.size = Vector3(
				rng.randf_range(0.08, 0.2),
				rng.randf_range(0.08, 0.15),
				rng.randf_range(0.08, 0.15))
			item.mesh = item_mesh
			item.position = Vector3(
				rng.randf_range(-0.7, 0.7),
				1.05,
				rng.randf_range(-0.2, 0.2))
			var item_col := Color(rng.randf_range(0.2, 0.8), rng.randf_range(0.2, 0.6), rng.randf_range(0.1, 0.5))
			item.set_surface_override_material(0, _make_ps1_material(item_col))
			vendor.add_child(item)
		# Small neon sign (60% chance)
		if neon_font and rng.randf() < 0.6:
			var sign_label := Label3D.new()
			var vendor_names := ["ラーメン", "焼鳥", "たこ焼き", "おでん", "餃子", "弁当"]
			sign_label.text = vendor_names[rng.randi_range(0, vendor_names.size() - 1)]
			sign_label.font = neon_font
			sign_label.font_size = 32
			sign_label.pixel_size = 0.008
			var sign_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
			sign_label.modulate = sign_col
			sign_label.outline_modulate = sign_col * 0.3
			sign_label.outline_size = 4
			sign_label.position = Vector3(0, 2.5, 0.6)
			vendor.add_child(sign_label)
			var sign_glow := OmniLight3D.new()
			sign_glow.light_color = sign_col
			sign_glow.light_energy = 1.5
			sign_glow.omni_range = 3.0
			sign_glow.shadow_enabled = false
			sign_glow.position = sign_label.position
			vendor.add_child(sign_glow)
		add_child(vendor)

func _generate_alleys() -> void:
	# Find narrow gaps between buildings and add atmospheric fog + dim colored light
	var rng := RandomNumberGenerator.new()
	rng.seed = 7500
	var alley_count := 0
	var max_alleys := 10
	var children_snapshot := get_children()
	for idx in range(children_snapshot.size()):
		if alley_count >= max_alleys:
			break
		var child_a = children_snapshot[idx]
		if not child_a is MeshInstance3D:
			continue
		var mi_a := child_a as MeshInstance3D
		if not mi_a.mesh is BoxMesh:
			continue
		var size_a: Vector3 = (mi_a.mesh as BoxMesh).size
		if size_a.y < 12.0:
			continue
		# Check next few buildings for proximity
		for jdx in range(idx + 1, mini(idx + 8, children_snapshot.size())):
			if alley_count >= max_alleys:
				break
			var child_b = children_snapshot[jdx]
			if not child_b is MeshInstance3D:
				continue
			var mi_b := child_b as MeshInstance3D
			if not mi_b.mesh is BoxMesh:
				continue
			var size_b: Vector3 = (mi_b.mesh as BoxMesh).size
			if size_b.y < 12.0:
				continue
			var dist := mi_a.position.distance_to(mi_b.position)
			# Gap should be narrow (3-8 units) for an alley feel
			var gap := dist - (size_a.x + size_b.x) * 0.4
			if gap < 2.0 or gap > 8.0:
				continue
			if rng.randf() > 0.4:
				continue
			alley_count += 1
			# Midpoint between buildings
			var mid := (mi_a.position + mi_b.position) * 0.5
			mid.y = 0.0  # ground level
			# Ground fog plane
			var fog := MeshInstance3D.new()
			var fog_mesh := BoxMesh.new()
			fog_mesh.size = Vector3(gap * 0.8, 0.3, minf(size_a.z, size_b.z) * 0.6)
			fog.mesh = fog_mesh
			fog.position = mid + Vector3(0, 0.15, 0)
			var fog_col := Color(0.1, 0.06, 0.08)
			fog.set_surface_override_material(0,
				_make_ps1_material(fog_col * 0.3, true, fog_col, 0.5))
			fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(fog)
			# Dim colored alley light (red or amber, moody)
			var alley_light := OmniLight3D.new()
			var light_roll := rng.randf()
			if light_roll < 0.4:
				alley_light.light_color = Color(1.0, 0.15, 0.05)  # red
			elif light_roll < 0.7:
				alley_light.light_color = Color(1.0, 0.6, 0.1)   # amber
			else:
				alley_light.light_color = Color(0.6, 0.0, 0.8)   # purple
			alley_light.light_energy = rng.randf_range(1.5, 3.0)
			alley_light.omni_range = gap * 1.2
			alley_light.omni_attenuation = 1.5
			alley_light.shadow_enabled = false
			alley_light.position = mid + Vector3(0, 3.0, 0)
			add_child(alley_light)

func _generate_pigeon_flocks() -> void:
	# Small clusters of pigeon shapes sitting on building rooftop edges
	var rng := RandomNumberGenerator.new()
	rng.seed = 7600
	var pigeon_col := Color(0.3, 0.28, 0.25)  # gray-brown
	var pigeon_dark := Color(0.15, 0.14, 0.13)
	var flock_count := 0
	var max_flocks := 8
	for child in get_children():
		if flock_count >= max_flocks:
			break
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 15.0:
			continue
		if rng.randf() > 0.12:
			continue
		flock_count += 1
		var roof_y := mi.position.y + bsize.y * 0.5
		var num_birds := rng.randi_range(3, 5)
		# Pick an edge (front or side)
		var edge_x := rng.randf() < 0.5
		for _b in range(num_birds):
			var bird := Node3D.new()
			var bx: float
			var bz: float
			if edge_x:
				bx = mi.position.x + rng.randf_range(-bsize.x * 0.3, bsize.x * 0.3)
				bz = mi.position.z + (bsize.z * 0.5 - 0.1) * (1.0 if rng.randf() < 0.5 else -1.0)
			else:
				bx = mi.position.x + (bsize.x * 0.5 - 0.1) * (1.0 if rng.randf() < 0.5 else -1.0)
				bz = mi.position.z + rng.randf_range(-bsize.z * 0.3, bsize.z * 0.3)
			bird.position = Vector3(bx, roof_y + 0.08, bz)
			bird.rotation.y = rng.randf_range(0, TAU)
			# Body (small elongated sphere)
			var body := MeshInstance3D.new()
			var body_mesh := SphereMesh.new()
			body_mesh.radius = 0.06
			body_mesh.height = 0.12
			body.mesh = body_mesh
			body.position = Vector3(0, 0, 0)
			var col := pigeon_col if rng.randf() < 0.7 else pigeon_dark
			body.set_surface_override_material(0, _make_ps1_material(col))
			bird.add_child(body)
			# Head (tiny sphere)
			var head := MeshInstance3D.new()
			var head_mesh := SphereMesh.new()
			head_mesh.radius = 0.03
			head_mesh.height = 0.06
			head.mesh = head_mesh
			head.position = Vector3(0, 0.04, 0.06)
			head.set_surface_override_material(0, _make_ps1_material(col * 0.8))
			bird.add_child(head)
			add_child(bird)

func _generate_rooftop_gardens() -> void:
	# Green plant clusters on some tall building rooftops
	var rng := RandomNumberGenerator.new()
	rng.seed = 7700
	var garden_count := 0
	var max_gardens := 8
	for child in get_children():
		if garden_count >= max_gardens:
			break
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 15.0 or bsize.x < 8.0:
			continue
		if rng.randf() > 0.10:
			continue
		garden_count += 1
		var roof_y := mi.position.y + bsize.y * 0.5
		# Cluster of green boxes (plants)
		var num_plants := rng.randi_range(4, 8)
		for _p in range(num_plants):
			var plant := MeshInstance3D.new()
			var plant_mesh := BoxMesh.new()
			var ph := rng.randf_range(0.3, 0.8)
			plant_mesh.size = Vector3(
				rng.randf_range(0.3, 0.7),
				ph,
				rng.randf_range(0.3, 0.7))
			plant.mesh = plant_mesh
			var px := mi.position.x + rng.randf_range(-bsize.x * 0.25, bsize.x * 0.25)
			var pz := mi.position.z + rng.randf_range(-bsize.z * 0.25, bsize.z * 0.25)
			plant.position = Vector3(px, roof_y + ph * 0.5, pz)
			# Varied greens
			var green := Color(
				rng.randf_range(0.05, 0.15),
				rng.randf_range(0.2, 0.4),
				rng.randf_range(0.05, 0.12))
			plant.set_surface_override_material(0, _make_ps1_material(green))
			add_child(plant)
		# Planter box (dark border)
		var planter := MeshInstance3D.new()
		var planter_mesh := BoxMesh.new()
		var pw := rng.randf_range(2.0, bsize.x * 0.4)
		var pd := rng.randf_range(2.0, bsize.z * 0.4)
		planter_mesh.size = Vector3(pw, 0.3, pd)
		planter.mesh = planter_mesh
		planter.position = Vector3(mi.position.x, roof_y + 0.15, mi.position.z)
		planter.set_surface_override_material(0, _make_ps1_material(Color(0.15, 0.12, 0.08)))
		add_child(planter)

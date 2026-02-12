extends Node3D

## Procedurally generates a grid of cyberpunk buildings with emissive windows and neon signs.

@export var grid_size: int = 3
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
var cycling_windows: Array[Dictionary] = []  # [{mesh, base_energy, period, phase}]
var wall_screen_anims: Array[Dictionary] = []  # [{node, light, phase, colors}]
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
# Fly buzz audio near trash
const FLY_POOL_SIZE: int = 2
const FLY_RANGE: float = 8.0
var fly_pool: Array[Dictionary] = []
var fly_positions: Array[Vector3] = []
var fly_rng := RandomNumberGenerator.new()
var steam_bursts: Array[Dictionary] = []  # [{particles, timer, interval}]
var dish_nodes: Array[Node3D] = []  # satellite dishes for slow rotation
var walkway_map: Dictionary = {}  # populated during generation, read by NPCManager
var boot_time: float = 0.0
var boot_complete: bool = false
var prefab_buildings: Array[PackedScene] = []  # preloaded GLB building scenes

var neon_colors: Array[Color] = [
	Color(1.0, 0.05, 0.4),   # hot magenta
	Color(0.0, 0.9, 1.0),    # cyan
	Color(0.6, 0.0, 1.0),    # purple
	Color(1.0, 0.4, 0.0),    # orange
	Color(0.0, 1.0, 0.5),    # green neon
	Color(1.0, 0.0, 0.1),    # red
	Color(1.0, 0.75, 0.1),   # warm gold/amber
	Color(0.95, 0.9, 0.85),  # warm white
	Color(1.0, 0.3, 0.6),    # soft pink
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

# Mixed English/kanji for HK-style protruding neon signs
const HK_SIGN_TEXTS: Array[String] = [
	"酒場", "薬局", "電器", "旅館", "夜光", "歌舞",
	"BAR", "NOODLES", "HOTEL", "CLUB", "CYBER",
	"GIRLS", "LOANS", "24HR", "OPEN", "KARAOKE",
	"MASSAGE", "CAFE", "TAXI", "PAWN",
	"危険", "出口", "未来", "電脳", "新体北",
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
	_load_prefab_buildings()
	print("CityGenerator: starting generation with grid_size=", grid_size)
	_generate_city()
	#_generate_cars()
	_generate_street_lights()
	#_generate_puddles()
	#_generate_steam_vents()
	#_generate_skyline()
	#_generate_rooftop_details()
	_generate_sidewalks()
	_generate_elevated_walkways()
	_generate_walkway_ramps()
	_generate_walkway_bridges()
	_generate_walkway_building_doors()
	_generate_walkway_passthroughs()
	_generate_walkway_elevated_details()
	_generate_walkway_furniture()
	_generate_walkway_window_glow()
	_generate_walkway_underside_lights()
	_generate_walkway_drip_puddles()
	_generate_walkway_rain_drips()
	_generate_road_markings()
	_generate_vending_machines()
	_generate_traffic_lights()
	_generate_billboards()
	#_generate_dumpsters()
	#_generate_fire_escapes()
	_generate_window_ac_units()
	#_generate_telephone_poles()
	#_generate_graffiti()
	#_generate_neon_underglow()
	#_generate_manholes()
	#_generate_litter()
	_generate_overhead_cables()
	#_generate_skyline_warning_lights()
	_generate_holographic_signs()
	#_generate_phone_booths()
	#_generate_wind_debris()
	_generate_utility_boxes()
	#_generate_street_furniture()
	#_generate_construction_zones()
	#_generate_drain_grates()
	_generate_building_setbacks()
	#_generate_exposed_pipes()
	#_generate_security_cameras()
	#_generate_awning_lights()
	#_generate_chain_link_fences()
	#_generate_trash_bags()
	#_generate_bus_stops()
	#_generate_fire_hydrants()
	_generate_water_towers()
	_generate_satellite_dishes()
	#_generate_roof_access_doors()
	#_generate_rain_gutters()
	#_generate_parking_meters()
	#_generate_shipping_containers()
	#_generate_scaffolding()
	#_generate_antenna_arrays()
	#_generate_laundry_lines()
	#_generate_ground_fog()
	#_generate_sparking_boxes()
	#_generate_ventilation_fans()
	_generate_power_cables()
	#_generate_rooftop_ac_units()
	#_generate_rain_drips()
	#_generate_neon_arrows()
	#_generate_surveillance_drone()
	#_generate_pipe_arcs()
	#_generate_open_signs()
	#_generate_police_car()
	#_generate_car_rain_splashes()
	#_generate_haze_layers()
	#_generate_neon_reflections()
	#_generate_rooftop_exhaust()
	#_generate_hologram_projections()
	#_generate_newspaper_boxes()
	_generate_crosswalks()
	#_generate_aircraft_flyover()
	#_generate_helicopter_patrol()
	#_generate_subway_entrances()
	#_generate_neon_light_shafts()
	#_generate_distant_city_glow()
	_generate_rooftop_water_tanks()
	#_setup_neon_buzz_audio()
	#_setup_radio_audio()
	#_generate_stray_cats()
	_generate_building_entrances()
	#_generate_street_vendors()
	#_generate_alleys()
	#_generate_pigeon_flocks()
	#_generate_rooftop_gardens()
	#_generate_scattered_papers()
	#_generate_facade_stripes()
	_generate_balcony_ledges()
	_generate_roof_parapets()
	_generate_building_cornices()
	#_generate_window_frames()
	_generate_building_stoops()
	_generate_exit_signs()
	#_generate_puddle_splash_rings()
	#_generate_lobby_lights()
	#_generate_barricade_tape()
	#_generate_cardboard_boxes()
	#_generate_puddle_mist()
	#_setup_fly_buzz_audio()
	#_setup_neon_flicker()
	#_setup_color_shift_signs()
	#_generate_chimney_smoke()
	#_generate_fluorescent_tubes()
	#_generate_fire_barrels()
	#_generate_security_spotlights()
	#_generate_wall_drips()
	#_generate_gutter_overflow()
	#_generate_street_name_signs()
	#_generate_wall_screens()
	#_generate_overhead_intersection_lights()
	# (elevated walkways now called earlier in _ready)
	_generate_hk_neon_signs()
	print("CityGenerator: generation complete, total children=", get_child_count())

func _make_ps1_material(color: Color, is_emissive: bool = false,
	emit_color: Color = Color.BLACK, emit_strength: float = 0.0) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = ps1_shader
	mat.set_shader_parameter("albedo_color", color)
	mat.set_shader_parameter("vertex_snap_intensity", 1.0)
	mat.set_shader_parameter("color_depth", 12.0)
	mat.set_shader_parameter("fog_color", Color(0.03, 0.02, 0.06, 1.0))
	mat.set_shader_parameter("fog_distance", 250.0)
	mat.set_shader_parameter("fog_density", 0.08)
	if is_emissive:
		mat.set_shader_parameter("emissive", true)
		mat.set_shader_parameter("emission_color", emit_color)
		mat.set_shader_parameter("emission_strength", emit_strength)
	return mat

func _load_prefab_buildings() -> void:
	# Prefab buildings removed — using modular box-based buildings instead
	pass

func _apply_ps1_materials(node: Node, facade_color: Color, rng: RandomNumberGenerator) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var mesh := mi.mesh
		if mesh:
			for surf_idx in range(mesh.get_surface_count()):
				mi.set_surface_override_material(surf_idx, _make_ps1_material(facade_color))
	for child in node.get_children():
		_apply_ps1_materials(child, facade_color, rng)

## Modular building system — assembles interesting silhouettes from BoxMesh pieces.
## Each piece is an exact box, so windows always sit flush on the surface.

func _add_building_piece(parent: MeshInstance3D, local_pos: Vector3, piece_size: Vector3,
		facade_color: Color, rng: RandomNumberGenerator, add_win: bool = true) -> void:
	var mi := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = piece_size
	mi.mesh = box
	mi.position = local_pos
	mi.set_surface_override_material(0, _make_ps1_material(facade_color))
	# Collision
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = piece_size
	col.shape = cs
	sb.add_child(col)
	mi.add_child(sb)
	parent.add_child(mi)
	if add_win:
		_add_windows(mi, piece_size, rng)

func _create_modular_building(pos: Vector3, size: Vector3, rng: RandomNumberGenerator, rot_y: float) -> void:
	# Root node for the whole building (positioned, rotated)
	var root := MeshInstance3D.new()
	root.position = pos
	root.rotation.y = rot_y
	add_child(root)

	var facade_color := _pick_facade_color(rng)
	var template := rng.randi_range(0, 5)

	match template:
		0:
			# Stepped tower: wide base + narrower mid + narrow top
			var base_h := size.y * 0.45
			var mid_h := size.y * 0.3
			var top_h := size.y * 0.25
			# Base (full width)
			_add_building_piece(root, Vector3(0, -size.y * 0.5 + base_h * 0.5, 0),
				Vector3(size.x, base_h, size.z), facade_color, rng)
			# Mid section (75% width, offset slightly)
			var mid_w := size.x * 0.75
			var mid_d := size.z * 0.8
			var off_x := rng.randf_range(-1.0, 1.0)
			_add_building_piece(root, Vector3(off_x, -size.y * 0.5 + base_h + mid_h * 0.5, 0),
				Vector3(mid_w, mid_h, mid_d), facade_color * 0.95, rng)
			# Top tower (50% width)
			var top_w := size.x * 0.5
			var top_d := size.z * 0.55
			_add_building_piece(root, Vector3(off_x, -size.y * 0.5 + base_h + mid_h + top_h * 0.5, 0),
				Vector3(top_w, top_h, top_d), facade_color * 0.9, rng)
		1:
			# Twin towers: two slim towers connected by a low bridge
			var tower_w := size.x * 0.4
			var gap := size.x * 0.2
			var bridge_h := size.y * 0.25
			# Left tower
			_add_building_piece(root, Vector3(-tower_w * 0.5 - gap * 0.5, 0, 0),
				Vector3(tower_w, size.y, size.z * 0.8), facade_color, rng)
			# Right tower (slightly different height)
			var rh := size.y * rng.randf_range(0.75, 1.0)
			_add_building_piece(root, Vector3(tower_w * 0.5 + gap * 0.5, (rh - size.y) * 0.5, 0),
				Vector3(tower_w, rh, size.z * 0.8), facade_color * 0.95, rng)
			# Bridge connecting them
			_add_building_piece(root, Vector3(0, -size.y * 0.5 + bridge_h * 0.5, 0),
				Vector3(size.x, bridge_h, size.z * 0.6), facade_color * 0.9, rng, false)
		2:
			# Cantilever: base with wider overhang on top
			var base_h := size.y * 0.6
			var over_h := size.y * 0.4
			var base_w := size.x * 0.7
			# Narrow base
			_add_building_piece(root, Vector3(0, -size.y * 0.5 + base_h * 0.5, 0),
				Vector3(base_w, base_h, size.z * 0.8), facade_color, rng)
			# Wide overhang
			_add_building_piece(root, Vector3(0, -size.y * 0.5 + base_h + over_h * 0.5, 0),
				Vector3(size.x * 1.1, over_h, size.z), facade_color * 0.95, rng)
		3:
			# U-shape: main body with two forward wings
			var body_d := size.z * 0.4
			var wing_w := size.x * 0.3
			var wing_d := size.z * 0.6
			var wing_h := size.y * rng.randf_range(0.7, 0.9)
			# Main body (back)
			_add_building_piece(root, Vector3(0, 0, -size.z * 0.5 + body_d * 0.5),
				Vector3(size.x, size.y, body_d), facade_color, rng)
			# Left wing
			_add_building_piece(root, Vector3(-size.x * 0.5 + wing_w * 0.5, (wing_h - size.y) * 0.5, size.z * 0.5 - wing_d * 0.5),
				Vector3(wing_w, wing_h, wing_d), facade_color * 0.95, rng)
			# Right wing
			_add_building_piece(root, Vector3(size.x * 0.5 - wing_w * 0.5, (wing_h - size.y) * 0.5, size.z * 0.5 - wing_d * 0.5),
				Vector3(wing_w, wing_h, wing_d), facade_color * 0.95, rng)
		4:
			# Wedge: tall front, shorter back (like a sloped roofline simulated with steps)
			var num_steps := rng.randi_range(3, 5)
			var step_d := size.z / float(num_steps)
			for i in range(num_steps):
				var step_h := size.y * (1.0 - float(i) * 0.15)
				var step_z := -size.z * 0.5 + step_d * (float(i) + 0.5)
				_add_building_piece(root, Vector3(0, (step_h - size.y) * 0.5, step_z),
					Vector3(size.x, step_h, step_d * 0.95), facade_color * (1.0 - float(i) * 0.03), rng)
		5:
			# Offset stack: 2-3 boxes stacked with random XZ offsets
			var num_sections := rng.randi_range(2, 3)
			var section_h := size.y / float(num_sections)
			var cur_y := -size.y * 0.5 + section_h * 0.5
			for i in range(num_sections):
				var sw := size.x * rng.randf_range(0.65, 1.0)
				var sd := size.z * rng.randf_range(0.65, 1.0)
				var ox := rng.randf_range(-2.0, 2.0)
				var oz := rng.randf_range(-2.0, 2.0)
				_add_building_piece(root, Vector3(ox, cur_y, oz),
					Vector3(sw, section_h * 0.95, sd), facade_color * (1.0 - float(i) * 0.04), rng)
				cur_y += section_h

	# --- Architectural detail elements (randomly applied to any template) ---
	var top_y := size.y * 0.5  # top of building relative to root

	# Pilotis: raise building on columns (25% of tall buildings)
	if size.y > 15.0 and rng.randf() < 0.25:
		_add_pilotis(root, size, top_y, facade_color, rng)
		top_y += 4.0  # building is now 4m higher

	# Pitched roof (25%)
	if rng.randf() < 0.25:
		_add_pitched_roof(root, top_y, size, facade_color, rng)

	# Smokestacks (30%)
	if rng.randf() < 0.30:
		_add_smokestacks(root, top_y, size, facade_color, rng)

	# Antenna spires (25%)
	if rng.randf() < 0.25:
		_add_antenna_spire(root, top_y, rng)

	# Mechanical penthouse (35%)
	if rng.randf() < 0.35:
		_add_mech_penthouse(root, top_y, size, facade_color, rng)

	# Radar dome (15%)
	if rng.randf() < 0.15:
		_add_radar_dome(root, top_y, size, facade_color, rng)

 	# Balconies (30%)
	if rng.randf() < 0.30:
		_add_balconies(root, size, facade_color, rng)

	# Corner turret (20%)
	if rng.randf() < 0.20:
		_add_corner_turret(root, size, facade_color, rng)


func _add_pilotis(root: MeshInstance3D, size: Vector3, _top_y: float,
		facade_color: Color, rng: RandomNumberGenerator) -> void:
	var lift := 4.0
	# Raise all existing building pieces
	for child in root.get_children():
		child.position.y += lift
	# Floor plate under the raised building
	var plate := MeshInstance3D.new()
	var plate_box := BoxMesh.new()
	plate_box.size = Vector3(size.x * 1.05, 0.3, size.z * 1.05)
	plate.mesh = plate_box
	plate.position = Vector3(0, -size.y * 0.5 + lift - 0.15, 0)
	plate.set_surface_override_material(0, _make_ps1_material(facade_color * 0.85))
	# Plate collision
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = plate_box.size
	col.shape = cs
	sb.add_child(col)
	plate.add_child(sb)
	root.add_child(plate)
	# Columns
	var num_cols := rng.randi_range(4, 6)
	var col_positions: Array[Vector2] = []
	# Place columns in a grid-ish pattern
	for i in range(num_cols):
		var cx := lerpf(-size.x * 0.35, size.x * 0.35, float(i % 3) / 2.0)
		var cz := -size.z * 0.25 if i < 3 else size.z * 0.25
		col_positions.append(Vector2(cx, cz))
	for cp in col_positions:
		var pillar := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.35
		cyl.bottom_radius = 0.4
		cyl.height = lift
		cyl.radial_segments = 8
		pillar.mesh = cyl
		pillar.position = Vector3(cp.x, -size.y * 0.5 + lift * 0.5, cp.y)
		pillar.set_surface_override_material(0, _make_ps1_material(facade_color * 0.8))
		root.add_child(pillar)

func _add_pitched_roof(root: MeshInstance3D, top_y: float, size: Vector3,
	facade_color: Color, rng: RandomNumberGenerator) -> void:
	var roof_h := rng.randf_range(2.0, 4.5)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(size.x * 0.95, roof_h, size.z * 0.9)
	prism.left_to_right = 0.5  # centered peak
	roof.mesh = prism
	roof.position = Vector3(0, top_y + roof_h * 0.5, 0)
	roof.set_surface_override_material(0, _make_ps1_material(facade_color * 0.7))
	roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	root.add_child(roof)

func _add_smokestacks(root: MeshInstance3D, top_y: float, size: Vector3,
	facade_color: Color, rng: RandomNumberGenerator) -> void:
	var num := rng.randi_range(1, 3)
	for i in range(num):
		var stack := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		var h := rng.randf_range(3.0, 6.0)
		cyl.top_radius = rng.randf_range(0.3, 0.6)
		cyl.bottom_radius = rng.randf_range(0.5, 0.8)
		cyl.height = h
		cyl.radial_segments = 8
		stack.mesh = cyl
		var sx := rng.randf_range(-size.x * 0.3, size.x * 0.3)
		var sz := rng.randf_range(-size.z * 0.3, size.z * 0.3)
		stack.position = Vector3(sx, top_y + h * 0.5, sz)
		stack.set_surface_override_material(0, _make_ps1_material(facade_color * 0.6))
		root.add_child(stack)

func _add_antenna_spire(root: MeshInstance3D, top_y: float,
	rng: RandomNumberGenerator) -> void:
	var h := rng.randf_range(4.0, 8.0)
	var spire := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.03
	cyl.bottom_radius = 0.06
	cyl.height = h
	cyl.radial_segments = 6
	spire.mesh = cyl
	spire.position = Vector3(rng.randf_range(-1.0, 1.0), top_y + h * 0.5, rng.randf_range(-1.0, 1.0))
	spire.set_surface_override_material(0, _make_ps1_material(Color(0.5, 0.5, 0.55)))
	root.add_child(spire)
	# Small sphere at tip
	var ball := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	sphere.radial_segments = 6
	sphere.rings = 4
	ball.mesh = sphere
	ball.position = Vector3(0, h * 0.5 + 0.15, 0)
	ball.set_surface_override_material(0, _make_ps1_material(Color(0.8, 0.2, 0.2), true, Color(1, 0.1, 0.1), 2.0))
	spire.add_child(ball)

func _add_mech_penthouse(root: MeshInstance3D, top_y: float, size: Vector3,
	facade_color: Color, rng: RandomNumberGenerator) -> void:
	var pw := rng.randf_range(3.0, min(5.0, size.x * 0.5))
	var ph := rng.randf_range(2.0, 3.0)
	var pd := rng.randf_range(3.0, min(4.0, size.z * 0.5))
	var pent := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(pw, ph, pd)
	pent.mesh = box
	var ox := rng.randf_range(-size.x * 0.2, size.x * 0.2)
	var oz := rng.randf_range(-size.z * 0.2, size.z * 0.2)
	pent.position = Vector3(ox, top_y + ph * 0.5, oz)
	pent.set_surface_override_material(0, _make_ps1_material(facade_color * 0.85))
	root.add_child(pent)
	_add_windows(pent, Vector3(pw, ph, pd), rng)

func _add_radar_dome(root: MeshInstance3D, top_y: float, size: Vector3,
	_facade_color: Color, rng: RandomNumberGenerator) -> void:
	var r := rng.randf_range(1.2, 2.5)
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = r
	sphere.height = r * 2.0
	sphere.radial_segments = 10
	sphere.rings = 6
	dome.mesh = sphere
	# Sink bottom half into roof surface
	var ox := rng.randf_range(-size.x * 0.2, size.x * 0.2)
	var oz := rng.randf_range(-size.z * 0.2, size.z * 0.2)
	dome.position = Vector3(ox, top_y + r * 0.3, oz)
	dome.set_surface_override_material(0, _make_ps1_material(Color(0.7, 0.75, 0.8)))
	root.add_child(dome)

func _add_balconies(root: MeshInstance3D, size: Vector3,
	facade_color: Color, rng: RandomNumberGenerator) -> void:
	var floor_h := 3.5
	var num_floors := int(size.y / floor_h)
	var balcony_mat := _make_ps1_material(facade_color * 0.75)
	var rail_mat := _make_ps1_material(Color(0.4, 0.4, 0.45))
	# Pick one or two faces to add balconies (front=+Z, back=-Z)
	var face_sign := 1.0 if rng.randf() < 0.5 else -1.0
	var num_per_floor := rng.randi_range(1, max(1, int(size.x / 4.0)))
	for floor_i in range(1, num_floors):  # skip ground floor
		for bi in range(num_per_floor):
			if rng.randf() > 0.6:
				continue
			var bx := -size.x * 0.35 + (float(bi) + 0.5) * (size.x * 0.7 / float(num_per_floor))
			var by := -size.y * 0.5 + (floor_i + 0.3) * floor_h
			var bz := face_sign * (size.z * 0.5 + 0.6)
			# Floor slab
			var slab := MeshInstance3D.new()
			var slab_box := BoxMesh.new()
			slab_box.size = Vector3(2.0, 0.15, 1.2)
			slab.mesh = slab_box
			slab.position = Vector3(bx, by, bz)
			slab.set_surface_override_material(0, balcony_mat)
			root.add_child(slab)
			# Railing
			var rail := MeshInstance3D.new()
			var rail_box := BoxMesh.new()
			rail_box.size = Vector3(2.0, 0.8, 0.06)
			rail.mesh = rail_box
			rail.position = Vector3(bx, by + 0.45, bz + face_sign * 0.57)
			rail.set_surface_override_material(0, rail_mat)
			root.add_child(rail)

func _add_corner_turret(root: MeshInstance3D, size: Vector3,
	facade_color: Color, rng: RandomNumberGenerator) -> void:
	var turret_r := rng.randf_range(1.5, min(2.5, size.x * 0.25))
	var turret_h := size.y * rng.randf_range(0.6, 1.0)
	var turret := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = turret_r * 0.9
	cyl.bottom_radius = turret_r
	cyl.height = turret_h
	cyl.radial_segments = 10
	turret.mesh = cyl
	# Pick a corner
	var cx := (size.x * 0.5) * (1.0 if rng.randf() < 0.5 else -1.0)
	var cz := (size.z * 0.5) * (1.0 if rng.randf() < 0.5 else -1.0)
	turret.position = Vector3(cx, (turret_h - size.y) * 0.5, cz)
	turret.set_surface_override_material(0, _make_ps1_material(facade_color * 0.9))
	root.add_child(turret)
	# Collision
	var sb := StaticBody3D.new()
	var col := CollisionShape3D.new()
	var cs := BoxShape3D.new()
	cs.size = Vector3(turret_r * 1.6, turret_h, turret_r * 1.6)
	col.shape = cs
	sb.add_child(col)
	turret.add_child(sb)
	# Cylinder windows
	_add_cylinder_windows(turret, turret_h, turret_r, cyl.radial_segments, rng)

func _pick_window_color(rng: RandomNumberGenerator) -> Color:
	var color_roll := rng.randf()
	if color_roll < 0.45:
		return Color(1.0, 0.85, 0.5)   # warm apartment yellow
	elif color_roll < 0.70:
		return Color(0.95, 0.9, 0.75)  # soft warm white
	elif color_roll < 0.88:
		return Color(0.85, 0.95, 1.0)  # cool office fluorescent
	else:
		return Color(0.7, 0.8, 0.6)    # dim greenish (TV glow)

func _pick_facade_color(rng: RandomNumberGenerator) -> Color:
	var darkness := rng.randf_range(0.5, 0.75)
	var tint_roll := rng.randf()
	if tint_roll < 0.4:
		return Color(darkness, darkness, darkness + 0.05, 1.0)
	elif tint_roll < 0.6:
		return Color(darkness * 0.8, darkness * 0.85, darkness * 1.2, 1.0)
	elif tint_roll < 0.75:
		return Color(darkness * 1.1, darkness * 0.9, darkness * 0.7, 1.0)
	elif tint_roll < 0.9:
		return Color(darkness * 0.8, darkness * 1.0, darkness * 1.1, 1.0)
	else:
		return Color(darkness * 0.95, darkness * 0.85, darkness * 1.0, 1.0)

func _create_cylindrical_building(pos: Vector3, height: float, radius: float, rng: RandomNumberGenerator, rot_y: float) -> void:
	var segments := rng.randi_range(8, 12)
	var mesh_instance := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = segments
	cyl.rings = 1
	mesh_instance.mesh = cyl
	mesh_instance.position = pos
	mesh_instance.rotation.y = rot_y

	var facade_color := _pick_facade_color(rng)
	mesh_instance.set_surface_override_material(0, _make_ps1_material(facade_color))

	# Box collision approximation (good enough for PS1 aesthetic)
	var static_body := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var col_shape := BoxShape3D.new()
	col_shape.size = Vector3(radius * 1.6, height, radius * 1.6)
	collision.shape = col_shape
	static_body.add_child(collision)
	mesh_instance.add_child(static_body)

	add_child(mesh_instance)

	# Windows around circumference
	_add_cylinder_windows(mesh_instance, height, radius, segments, rng)
	# Neon ring accents
	_add_cylinder_ring_accents(mesh_instance, height, radius, rng)

func _add_cylinder_windows(building: MeshInstance3D, height: float, radius: float, segments: int, rng: RandomNumberGenerator) -> void:
	var floor_h := 3.5
	var num_rows := int(height / floor_h)
	var num_cols := segments  # one window per segment around circumference
	for row in range(num_rows):
		for col in range(num_cols):
			if rng.randf() > 0.5:
				continue
			var angle := (float(col) / float(num_cols)) * TAU
			var wy := -height * 0.5 + (row + 0.5) * floor_h
			var wx := cos(angle) * (radius + 0.02)
			var wz := sin(angle) * (radius + 0.02)
			var win := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(1.0, 1.4)
			win.mesh = quad
			win.position = Vector3(wx, wy, wz)
			win.rotation.y = -angle + PI * 0.5
			var wc := _pick_window_color(rng)
			win.set_surface_override_material(0,
				_make_ps1_material(wc * 0.3, true, wc, rng.randf_range(2.5, 5.0)))
			building.add_child(win)

func _add_cylinder_ring_accents(building: MeshInstance3D, height: float, radius: float, rng: RandomNumberGenerator) -> void:
	var num_rings := rng.randi_range(1, 3)
	for _i in range(num_rings):
		var ring_y := rng.randf_range(-height * 0.3, height * 0.4)
		var ring_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
		# Create ring from small segments
		var ring_segments := 12
		for seg in range(ring_segments):
			var angle := (float(seg) / float(ring_segments)) * TAU
			var next_angle := (float(seg + 1) / float(ring_segments)) * TAU
			var mid_angle := (angle + next_angle) * 0.5
			var seg_len := radius * TAU / float(ring_segments)
			var strip := MeshInstance3D.new()
			var strip_mesh := BoxMesh.new()
			strip_mesh.size = Vector3(seg_len, 0.12, 0.08)
			strip.mesh = strip_mesh
			strip.position = Vector3(
				cos(mid_angle) * (radius + 0.04),
				ring_y,
				sin(mid_angle) * (radius + 0.04)
			)
			strip.rotation.y = -mid_angle + PI * 0.5
			strip.set_surface_override_material(0,
				_make_ps1_material(ring_col * 0.5, true, ring_col, 3.0))
			strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			building.add_child(strip)

func _create_l_shaped_building(pos: Vector3, size: Vector3, rng: RandomNumberGenerator, rot_y: float) -> void:
	# Primary body is a regular building (BoxMesh) - all downstream functions will find it
	_create_building(pos, size, rng, rot_y)

	# Add perpendicular wing as child of the city generator (same parent)
	var wing_width := size.x * rng.randf_range(0.4, 0.7)
	var wing_depth := size.z * rng.randf_range(0.5, 0.9)
	var wing_height := size.y * rng.randf_range(0.5, 0.85)
	var wing_size := Vector3(wing_width, wing_height, wing_depth)

	# Pick which corner the wing attaches to
	var corner_x := (rng.randf() < 0.5)
	var corner_z := (rng.randf() < 0.5)
	var attach_x := (size.x * 0.5 - wing_width * 0.5) * (1.0 if corner_x else -1.0)
	var attach_z := (size.z * 0.5 + wing_depth * 0.5 - 0.5) * (1.0 if corner_z else -1.0)

	# Apply parent rotation to offset
	var cos_r := cos(rot_y)
	var sin_r := sin(rot_y)
	var rotated_x := attach_x * cos_r - attach_z * sin_r
	var rotated_z := attach_x * sin_r + attach_z * cos_r

	var wing_pos := Vector3(
		pos.x + rotated_x,
		wing_height * 0.5,
		pos.z + rotated_z
	)
	_create_building(wing_pos, wing_size, rng, rot_y)

func _generate_city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42  # deterministic for now

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			var cell_x := gx * (block_size + street_width)
			var cell_z := gz * (block_size + street_width)

			# 1-4 buildings per block (more variety)
			var num_buildings := rng.randi_range(1, 2)
			for b in range(num_buildings):
				var bw := rng.randf_range(min_width, max_width)
				var bd := rng.randf_range(min_width, max_width)
				var bh := rng.randf_range(min_height, max_height)

				# Wider offset range breaks grid regularity
				var offset_x := rng.randf_range(-block_size * 0.45, block_size * 0.45)
				var offset_z := rng.randf_range(-block_size * 0.45, block_size * 0.45)

				# Keep buildings within block (0.5m clearance from street edge)
				var max_off_x := block_size * 0.5 - bw * 0.5 - 0.5
				var max_off_z := block_size * 0.5 - bd * 0.5 - 0.5
				offset_x = clampf(offset_x, -max_off_x, max_off_x)
				offset_z = clampf(offset_z, -max_off_z, max_off_z)

				var pos := Vector3(cell_x + offset_x, bh * 0.5, cell_z + offset_z)
				# Random Y rotation breaks axis-aligned box feel
				var rot_y := rng.randf_range(-0.2, 0.2)  # ±~12 degrees

				# 35% of buildings are enterable (hollow ground floor + solid upper)
				var is_enterable := rng.randf() < 0.35
				if is_enterable and bh > 8.0 and bw > 6.0 and bd > 6.0:
					_create_enterable_building(pos, Vector3(bw, bh, bd), rng, rot_y)
					continue

				# Shape variety: modular, cylindrical, L-shaped, or regular box
				var shape_roll := rng.randf()
				if shape_roll < 0.45:
					# Modular building (~45% — interesting silhouettes from box pieces)
					_create_modular_building(pos, Vector3(bw, bh, bd), rng, rot_y)
				elif bh > 20.0 and shape_roll < 0.55:
					# Cylindrical tower (~10%)
					var radius: float = min(bw, bd) * 0.45
					_create_cylindrical_building(pos, bh, radius, rng, rot_y)
				elif bw > 9.0 and bd > 9.0 and shape_roll < 0.65:
					# L-shaped building (~10% of wide buildings)
					_create_l_shaped_building(pos, Vector3(bw, bh, bd), rng, rot_y)
				else:
					# Regular box building
					_create_building(pos, Vector3(bw, bh, bd), rng, rot_y)

func _create_building(pos: Vector3, size: Vector3, rng: RandomNumberGenerator, rot_y: float = 0.0) -> void:
	# Check if this building qualifies as an enterable storefront
	var is_storefront := size.y < 20.0 and size.x > 8.0 and rng.randf() < 0.18
	if is_storefront:
		_create_storefront(pos, size, rng, rot_y)
		return

	# Main building body
	var mesh_instance := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh_instance.mesh = box
	mesh_instance.position = pos
	mesh_instance.rotation.y = rot_y

	# Concrete material with PS1 shader - per-building color tint for facade variety
	var darkness := rng.randf_range(0.5, 0.75)
	var tint_roll := rng.randf()
	var facade_color: Color
	if tint_roll < 0.4:
		# 40% gray concrete (original)
		facade_color = Color(darkness, darkness, darkness + 0.05, 1.0)
	elif tint_roll < 0.6:
		# 20% dark blue-gray (office blocks)
		facade_color = Color(darkness * 0.8, darkness * 0.85, darkness * 1.2, 1.0)
	elif tint_roll < 0.75:
		# 15% dark brown (old brick)
		facade_color = Color(darkness * 1.1, darkness * 0.9, darkness * 0.7, 1.0)
	elif tint_roll < 0.9:
		# 15% dark teal (modern glass)
		facade_color = Color(darkness * 0.8, darkness * 1.0, darkness * 1.1, 1.0)
	else:
		# 10% dark purple-gray (residential)
		facade_color = Color(darkness * 0.95, darkness * 0.85, darkness * 1.0, 1.0)
	mesh_instance.set_surface_override_material(0, _make_ps1_material(facade_color))

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

	# Add 0-1 neon signs per building (stripped down to see architecture)
	if rng.randf() < 0.2:
		_add_neon_sign(mesh_instance, size, rng)

	# Facade accents: horizontal neon strips + concrete floor ledges
	_add_facade_accents(mesh_instance, size, facade_color, rng)

	# Stepped upper sections for tall buildings (terraced roofline)
	if size.y > 18.0 and rng.randf() < 0.55:
		var tower_w := size.x * rng.randf_range(0.45, 0.8)
		var tower_d := size.z * rng.randf_range(0.45, 0.8)
		var tower_h := size.y * rng.randf_range(0.2, 0.45)
		var tower := MeshInstance3D.new()
		var tower_box := BoxMesh.new()
		tower_box.size = Vector3(tower_w, tower_h, tower_d)
		tower.mesh = tower_box
		var tower_off_x := rng.randf_range(-0.15, 0.15) * size.x
		var tower_off_z := rng.randf_range(-0.15, 0.15) * size.z
		tower.position = Vector3(tower_off_x, size.y * 0.5 + tower_h * 0.5, tower_off_z)
		tower.set_surface_override_material(0, _make_ps1_material(facade_color * 0.95))
		tower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		mesh_instance.add_child(tower)
		# Windows on tower section
		_add_windows(tower, Vector3(tower_w, tower_h, tower_d), rng)
		# Neon strips on tower too
		_add_facade_accents(tower, Vector3(tower_w, tower_h, tower_d), facade_color, rng)

func _create_enterable_building(pos: Vector3, size: Vector3, rng: RandomNumberGenerator, rot_y: float = 0.0) -> void:
	# Hollow ground floor + solid upper stories
	var building := Node3D.new()
	building.position = pos
	building.rotation.y = rot_y

	var w := size.x
	var h := size.y
	var d := size.z
	var half_w := w * 0.5
	var half_h := h * 0.5
	var half_d := d * 0.5
	var wall_thickness := 0.3
	var ground_h := 5.0
	var door_width := 2.0
	var door_height := 3.2

	# Facade color (same palette as regular buildings)
	var darkness := rng.randf_range(0.4, 0.65)
	var tint_roll := rng.randf()
	var wall_color: Color
	if tint_roll < 0.4:
		wall_color = Color(darkness, darkness, darkness + 0.05, 1.0)
	elif tint_roll < 0.6:
		wall_color = Color(darkness * 0.8, darkness * 0.85, darkness * 1.2, 1.0)
	elif tint_roll < 0.75:
		wall_color = Color(darkness * 1.1, darkness * 0.9, darkness * 0.7, 1.0)
	elif tint_roll < 0.9:
		wall_color = Color(darkness * 0.8, darkness * 1.0, darkness * 1.1, 1.0)
	else:
		wall_color = Color(darkness * 0.95, darkness * 0.85, darkness * 1.0, 1.0)
	var wall_mat := _make_ps1_material(wall_color)
	var floor_mat := _make_ps1_material(Color(0.2, 0.18, 0.15))

	# --- Ground floor (hollow, 3.5m tall) ---
	# Back wall (full, -Z side)
	_add_wall(building, Vector3(0, -half_h + ground_h * 0.5, -half_d + wall_thickness * 0.5),
		Vector3(w, ground_h, wall_thickness), wall_mat)

	# Left wall (full, -X side)
	_add_wall(building, Vector3(-half_w + wall_thickness * 0.5, -half_h + ground_h * 0.5, 0),
		Vector3(wall_thickness, ground_h, d), wall_mat)

	# Right wall (full, +X side)
	_add_wall(building, Vector3(half_w - wall_thickness * 0.5, -half_h + ground_h * 0.5, 0),
		Vector3(wall_thickness, ground_h, d), wall_mat)

	# Front wall with door opening (+Z side)
	var left_front_w := (w - door_width) * 0.5
	_add_wall(building, Vector3(-half_w + left_front_w * 0.5, -half_h + ground_h * 0.5, half_d - wall_thickness * 0.5),
		Vector3(left_front_w, ground_h, wall_thickness), wall_mat)
	_add_wall(building, Vector3(half_w - left_front_w * 0.5, -half_h + ground_h * 0.5, half_d - wall_thickness * 0.5),
		Vector3(left_front_w, ground_h, wall_thickness), wall_mat)
	# Transom above door
	var transom_h := ground_h - door_height
	if transom_h > 0.1:
		_add_wall(building, Vector3(0, -half_h + door_height + transom_h * 0.5, half_d - wall_thickness * 0.5),
			Vector3(door_width, transom_h, wall_thickness), wall_mat)

	# Ceiling (separates ground from upper)
	_add_wall(building, Vector3(0, -half_h + ground_h - wall_thickness * 0.5, 0),
		Vector3(w, wall_thickness, d), wall_mat)

	# Interior floor
	_add_wall(building, Vector3(0, -half_h + 0.05, 0),
		Vector3(w - wall_thickness * 2, 0.1, d - wall_thickness * 2), floor_mat)

	# Interior warm light
	var interior_light := OmniLight3D.new()
	interior_light.light_color = Color(1.0, 0.85, 0.6)
	interior_light.light_energy = 1.5
	interior_light.omni_range = maxf(w, d) * 0.7
	interior_light.omni_attenuation = 1.5
	interior_light.shadow_enabled = false
	interior_light.position = Vector3(0, -half_h + ground_h - 1.0, 0)
	building.add_child(interior_light)

	# Door spill light (warm, outward-facing)
	var spill_light := OmniLight3D.new()
	spill_light.light_color = Color(1.0, 0.85, 0.6)
	spill_light.light_energy = 5.0
	spill_light.omni_range = 14.0
	spill_light.omni_attenuation = 1.5
	spill_light.shadow_enabled = false
	spill_light.position = Vector3(0, -half_h + door_height * 0.5, half_d + 1.0)
	building.add_child(spill_light)

	# Emissive neon awning above door
	var awning_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
	var awning := MeshInstance3D.new()
	var awning_mesh := BoxMesh.new()
	awning_mesh.size = Vector3(door_width + 1.0, 0.12, 0.8)
	awning.mesh = awning_mesh
	awning.position = Vector3(0, -half_h + door_height + 0.15, half_d + 0.3)
	awning.set_surface_override_material(0,
		_make_ps1_material(awning_col * 0.5, true, awning_col, 4.0))
	building.add_child(awning)

	# Interior furniture
	# Counter along back wall (70%)
	if rng.randf() < 0.7:
		var counter_w := w * 0.6
		var counter_mat := _make_ps1_material(Color(0.3, 0.2, 0.12))
		_add_wall(building, Vector3(0, -half_h + 0.5, -half_d + 1.2),
			Vector3(counter_w, 1.0, 0.6), counter_mat)

	# Table (50%)
	if rng.randf() < 0.5:
		var table_mat := _make_ps1_material(Color(0.25, 0.18, 0.1))
		var table_x := rng.randf_range(-half_w * 0.4, half_w * 0.4)
		var table_z := rng.randf_range(-half_d * 0.2, half_d * 0.3)
		_add_wall(building, Vector3(table_x, -half_h + 0.4, table_z),
			Vector3(1.2, 0.05, 0.8), table_mat)
		for lx in [-0.5, 0.5]:
			for lz in [-0.3, 0.3]:
				_add_wall(building, Vector3(table_x + lx, -half_h + 0.2, table_z + lz),
					Vector3(0.08, 0.4, 0.08), table_mat)

	# Shelves on side walls (60% each side)
	var shelf_mat := _make_ps1_material(Color(0.25, 0.2, 0.15))
	for shelf_side in [-1.0, 1.0]:
		if rng.randf() < 0.6:
			for shelf_row in range(rng.randi_range(1, 3)):
				var shelf_y := -half_h + 1.2 + shelf_row * 0.8
				_add_wall(building, Vector3(shelf_side * (half_w - 0.6), shelf_y, -half_d * 0.3),
					Vector3(0.4, 0.05, d * 0.4), shelf_mat)
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

	add_child(building)

	# --- Upper stories (solid box with windows) ---
	var upper_h := h - ground_h
	if upper_h > 1.0:
		var upper := MeshInstance3D.new()
		var upper_box := BoxMesh.new()
		upper_box.size = Vector3(w, upper_h, d)
		upper.mesh = upper_box
		upper.position = Vector3(0, -half_h + ground_h + upper_h * 0.5, 0)
		upper.set_surface_override_material(0, _make_ps1_material(wall_color))
		# Collision for upper stories
		var sb := StaticBody3D.new()
		var col := CollisionShape3D.new()
		var cs := BoxShape3D.new()
		cs.size = Vector3(w, upper_h, d)
		col.shape = cs
		sb.add_child(col)
		upper.add_child(sb)
		building.add_child(upper)
		# Windows on upper stories
		_add_windows(upper, Vector3(w, upper_h, d), rng)
		# Facade accents
		_add_facade_accents(upper, Vector3(w, upper_h, d), wall_color, rng)
		# Stepped roof for tall buildings
		if h > 18.0 and rng.randf() < 0.55:
			var tower_w := w * rng.randf_range(0.45, 0.8)
			var tower_d := d * rng.randf_range(0.45, 0.8)
			var tower_h := upper_h * rng.randf_range(0.2, 0.45)
			var tower := MeshInstance3D.new()
			var tower_box := BoxMesh.new()
			tower_box.size = Vector3(tower_w, tower_h, tower_d)
			tower.mesh = tower_box
			tower.position = Vector3(0, upper_h * 0.5 + tower_h * 0.5, 0)
			tower.set_surface_override_material(0, _make_ps1_material(wall_color * 0.95))
			upper.add_child(tower)
			_add_windows(tower, Vector3(tower_w, tower_h, tower_d), rng)

	# Ground floor windows — small frosted windows on side walls above eye level
	for gf_side in [1.0, -1.0]:
		if rng.randf() < 0.6:
			var gf_win := MeshInstance3D.new()
			var gf_quad := QuadMesh.new()
			gf_quad.size = Vector2(0.8, 0.6)
			gf_win.mesh = gf_quad
			gf_win.position = Vector3(gf_side * half_w * 1.01, -half_h + ground_h * 0.75, rng.randf_range(-half_d * 0.3, half_d * 0.3))
			gf_win.rotation.y = PI * 0.5 if gf_side > 0 else -PI * 0.5
			var gf_wc := Color(0.6, 0.55, 0.4)
			gf_win.set_surface_override_material(0,
				_make_ps1_material(gf_wc * 0.3, true, gf_wc, 1.5))
			building.add_child(gf_win)

	# Neon sign above door
	if rng.randf() < 0.8 and neon_font:
		var neon_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
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
		sign_light.light_energy = 4.0
		sign_light.omni_range = 10.0
		sign_light.omni_attenuation = 1.5
		sign_light.shadow_enabled = false
		sign_light.position = Vector3(0, 0, 0.5)
		label.add_child(sign_light)

func _add_facade_accents(building: Node3D, size: Vector3, facade_color: Color, rng: RandomNumberGenerator) -> void:
	var floor_h := 3.5
	var num_floors := int(size.y / floor_h)
	if num_floors < 2:
		return

	# Horizontal neon accent strips (1-3 per building, wrapping 1-2 faces)
	var num_strips := rng.randi_range(1, 3)
	for _i in range(num_strips):
		var strip_floor := rng.randi_range(1, num_floors)
		var strip_y := -size.y * 0.5 + strip_floor * floor_h
		var strip_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
		var strip_width := rng.randf_range(0.6, 1.0)
		# Place on 1-2 faces
		var face_idx := rng.randi_range(0, 3)
		var strip := MeshInstance3D.new()
		var strip_mesh := BoxMesh.new()
		match face_idx:
			0:  # front
				strip_mesh.size = Vector3(size.x * strip_width, 0.12, 0.06)
				strip.position = Vector3(0, strip_y, size.z * 0.51)
			1:  # back
				strip_mesh.size = Vector3(size.x * strip_width, 0.12, 0.06)
				strip.position = Vector3(0, strip_y, -size.z * 0.51)
			2:  # right
				strip_mesh.size = Vector3(0.06, 0.12, size.z * strip_width)
				strip.position = Vector3(size.x * 0.51, strip_y, 0)
			3:  # left
				strip_mesh.size = Vector3(0.06, 0.12, size.z * strip_width)
				strip.position = Vector3(-size.x * 0.51, strip_y, 0)
		strip.mesh = strip_mesh
		strip.set_surface_override_material(0,
			_make_ps1_material(strip_col * 0.4, true, strip_col, rng.randf_range(2.5, 4.5)))
		strip.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		building.add_child(strip)
		# 50% chance: wrap around corner to adjacent face
		if rng.randf() < 0.5:
			var corner := MeshInstance3D.new()
			var corner_mesh := BoxMesh.new()
			if face_idx < 2:  # was on Z face, wrap to X face
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				corner_mesh.size = Vector3(0.06, 0.12, size.z * rng.randf_range(0.3, 0.6))
				corner.position = Vector3(side * size.x * 0.51, strip_y, 0)
			else:  # was on X face, wrap to Z face
				var side := 1.0 if rng.randf() < 0.5 else -1.0
				corner_mesh.size = Vector3(size.x * rng.randf_range(0.3, 0.6), 0.12, 0.06)
				corner.position = Vector3(0, strip_y, side * size.z * 0.51)
			corner.mesh = corner_mesh
			corner.set_surface_override_material(0,
				_make_ps1_material(strip_col * 0.4, true, strip_col, rng.randf_range(2.5, 4.5)))
			corner.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			building.add_child(corner)

	# Concrete floor ledges (2-4 protruding strips on front face)
	var num_ledges := rng.randi_range(2, mini(num_floors - 1, 4))
	var used_floors: Array[int] = []
	for _j in range(num_ledges):
		var ledge_floor := rng.randi_range(1, num_floors - 1)
		if ledge_floor in used_floors:
			continue
		used_floors.append(ledge_floor)
		var ledge_y := -size.y * 0.5 + ledge_floor * floor_h
		# Front face ledge
		var ledge := MeshInstance3D.new()
		var ledge_mesh := BoxMesh.new()
		ledge_mesh.size = Vector3(size.x + 0.1, 0.12, 0.3)
		ledge.mesh = ledge_mesh
		ledge.position = Vector3(0, ledge_y, size.z * 0.5 + 0.13)
		ledge.set_surface_override_material(0, _make_ps1_material(facade_color * 1.15))
		ledge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		building.add_child(ledge)
		# Side face ledge (one side, 60% chance)
		if rng.randf() < 0.6:
			var side_ledge := MeshInstance3D.new()
			var side_mesh := BoxMesh.new()
			var side_dir := 1.0 if rng.randf() < 0.5 else -1.0
			side_mesh.size = Vector3(0.3, 0.12, size.z + 0.1)
			side_ledge.mesh = side_mesh
			side_ledge.position = Vector3(side_dir * (size.x * 0.5 + 0.13), ledge_y, 0)
			side_ledge.set_surface_override_material(0, _make_ps1_material(facade_color * 1.15))
			side_ledge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			building.add_child(side_ledge)

func _create_storefront(pos: Vector3, size: Vector3, rng: RandomNumberGenerator, rot_y: float = 0.0) -> void:
	var building := Node3D.new()
	building.position = pos
	building.rotation.y = rot_y

	var w := size.x
	var h := size.y
	var d := size.z
	var half_w := w * 0.5
	var half_h := h * 0.5
	var half_d := d * 0.5
	var wall_thickness := 0.3
	var door_width := 2.0
	var door_height := 3.0

	var darkness := rng.randf_range(0.4, 0.65)
	var tint_roll := rng.randf()
	var wall_color: Color
	if tint_roll < 0.4:
		wall_color = Color(darkness, darkness, darkness + 0.05, 1.0)
	elif tint_roll < 0.6:
		wall_color = Color(darkness * 0.8, darkness * 0.85, darkness * 1.2, 1.0)
	elif tint_roll < 0.75:
		wall_color = Color(darkness * 1.1, darkness * 0.9, darkness * 0.7, 1.0)
	elif tint_roll < 0.9:
		wall_color = Color(darkness * 0.8, darkness * 1.0, darkness * 1.1, 1.0)
	else:
		wall_color = Color(darkness * 0.95, darkness * 0.85, darkness * 1.0, 1.0)
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
	spill_light.light_energy = 5.0
	spill_light.omni_range = 14.0
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
			sign_light.light_energy = 4.0
			sign_light.omni_range = 10.0
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
			sign_light.light_energy = 3.5
			sign_light.omni_range = 10.0
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
				var wc := _pick_window_color(rng)
				win.set_surface_override_material(0,
					_make_ps1_material(wc * 0.3, true, wc, rng.randf_range(2.5, 5.0)))
				building.add_child(win)

func _add_windows(building: MeshInstance3D, size: Vector3, rng: RandomNumberGenerator) -> void:
	# Window grid on front and back faces (Z axis)
	for face in [1.0, -1.0]:
		var num_cols := int(size.x / 2.5)
		var num_rows := int(size.y / 3.5)
		for col in range(num_cols):
			for row in range(num_rows):
				if rng.randf() > 0.5:  # 50% of windows are dark
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

				var wc := _pick_window_color(rng)
				win.set_surface_override_material(0,
					_make_ps1_material(wc * 0.3, true, wc, rng.randf_range(2.5, 5.0)))
				building.add_child(win)
				# 18% of lit windows get horizontal blinds overlay
				if rng.randf() < 0.18:
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
				# 15% of lit windows get a half-drawn curtain
				elif rng.randf() < 0.15:
					var curtain := MeshInstance3D.new()
					var curtain_mesh := QuadMesh.new()
					var curtain_height := rng.randf_range(0.4, 0.8)
					curtain_mesh.size = Vector2(1.15, curtain_height)
					curtain.mesh = curtain_mesh
					# Curtain hangs from top of window
					curtain.position = Vector3(wx, wy + (1.5 - curtain_height) * 0.5, face * (size.z * 0.51 + 0.003))
					if face < 0:
						curtain.rotation.y = PI
					curtain.set_surface_override_material(0,
						_make_ps1_material(Color(0.08, 0.06, 0.1)))
					curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					building.add_child(curtain)
				# 15% of lit windows get a person silhouette
				if rng.randf() < 0.15:
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
				# 10% of lit windows get a TV glow
				if rng.randf() < 0.10:
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
				# 5% of lit windows slowly cycle on/off
				if rng.randf() < 0.05 and cycling_windows.size() < 30:
					cycling_windows.append({
						"mesh": win,
						"base_energy": rng.randf_range(2.5, 5.0),
						"period": rng.randf_range(30.0, 60.0),
						"phase": rng.randf() * TAU,
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

				var wc := _pick_window_color(rng)
				win.set_surface_override_material(0,
					_make_ps1_material(wc * 0.3, true, wc, rng.randf_range(2.5, 5.0)))
				building.add_child(win)
				# 18% blinds on side windows
				if rng.randf() < 0.18:
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
				# 15% silhouette on side windows too
				if rng.randf() < 0.15:
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
				if rng.randf() < 0.10:
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

		# Backing panel behind text sign
		var text_w: float = label.text.length() * label.font_size * label.pixel_size * 0.7
		var text_h: float = label.font_size * label.pixel_size * 1.4
		var backing := MeshInstance3D.new()
		var backing_box := BoxMesh.new()
		backing_box.size = Vector3(text_w + 0.5, text_h + 0.3, 0.12)
		backing.mesh = backing_box
		backing.position = Vector3(0, 0, -0.08)
		var back_col := neon_col * 0.08
		backing.set_surface_override_material(0, _make_ps1_material(Color(back_col.r + 0.04, back_col.g + 0.04, back_col.b + 0.05)))
		backing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		label.add_child(backing)

		var light := OmniLight3D.new()
		light.light_color = neon_col
		light.light_energy = rng.randf_range(3.0, 5.0)
		light.omni_range = rng.randf_range(8.0, 14.0)
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		light.position = Vector3(0, 0, 0.5)
		label.add_child(light)

		# 10% of text signs get pop-on flicker
		if rng.randf() < 0.10:
			flickering_lights.append({
				"node": light,
				"base_energy": light.light_energy,
				"phase": rng.randf() * 20.0,
				"speed": rng.randf_range(0.8, 1.5),
				"style": "pop_on",
				"mesh": null,
				"label": label,
			})
	else:
		# Quad sign with backing panel
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

		# Backing panel
		var backing := MeshInstance3D.new()
		var backing_box := BoxMesh.new()
		backing_box.size = Vector3(sign_w + 0.4, sign_h + 0.3, 0.15)
		backing.mesh = backing_box
		backing.position = Vector3(0, 0, -0.1)
		backing.set_surface_override_material(0, _make_ps1_material(Color(0.06, 0.06, 0.08)))
		backing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		sign_mesh.add_child(backing)

		var light := OmniLight3D.new()
		light.light_color = neon_col
		light.light_energy = rng.randf_range(3.0, 5.0)
		light.omni_range = rng.randf_range(8.0, 14.0)
		light.omni_attenuation = 1.5
		light.shadow_enabled = false
		light.position = Vector3(0, 0, 0.5)
		sign_mesh.add_child(light)

		# 10% of quad signs get pop-on flicker
		if rng.randf() < 0.10:
			flickering_lights.append({
				"node": light,
				"base_energy": light.light_energy,
				"phase": rng.randf() * 20.0,
				"speed": rng.randf_range(0.8, 1.5),
				"style": "pop_on",
				"mesh": sign_mesh,
				"label": null,
			})

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
	var light_spacing := 10.0
	var cell_stride := block_size + street_width
	var pole_mat := _make_ps1_material(Color(0.2, 0.2, 0.22))
	var lamp_color := Color(1.0, 0.8, 0.4)
	var lamp_mat := _make_ps1_material(lamp_color * 0.3, true, lamp_color, 4.0)

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			var cell_x := gx * cell_stride
			var cell_z := gz * cell_stride

			# Lights along Z-streets — BOTH sides of the street
			var street_x_east := cell_x + block_size * 0.5 + street_width * 0.8
			var street_x_west := cell_x + block_size * 0.5 + street_width * 0.2
			var z_start := cell_z - block_size * 0.5
			var num_along_z := int(block_size / light_spacing)
			for i in range(num_along_z):
				var lz := z_start + (i + 0.5) * light_spacing
				_create_street_light(Vector3(street_x_east, 0, lz), pole_mat, lamp_mat, lamp_color, rng)
				_create_street_light(Vector3(street_x_west, 0, lz), pole_mat, lamp_mat, lamp_color, rng)

			# Lights along X-streets — BOTH sides of the street
			var street_z_south := cell_z + block_size * 0.5 + street_width * 0.8
			var street_z_north := cell_z + block_size * 0.5 + street_width * 0.2
			var x_start := cell_x - block_size * 0.5
			var num_along_x := int(block_size / light_spacing)
			for i in range(num_along_x):
				var lx := x_start + (i + 0.5) * light_spacing
				_create_street_light(Vector3(lx, 0, street_z_south), pole_mat, lamp_mat, lamp_color, rng)
				_create_street_light(Vector3(lx, 0, street_z_north), pole_mat, lamp_mat, lamp_color, rng)

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
	light.light_energy = 4.0
	light.omni_range = 18.0
	light.omni_attenuation = 1.5
	light.shadow_enabled = false
	light.position = Vector3(1.0, 5.5, 0)
	lamp.add_child(light)

	# 18% of street lights flicker like a faulty sodium lamp
	if rng and rng.randf() < 0.18:
		flickering_lights.append({
			"node": light,
			"mesh": head,
			"base_energy": 4.0,
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
					puddle_glow.light_energy = rng.randf_range(0.5, 1.2)
					puddle_glow.omni_range = maxf(puddle_w, puddle_d) * 1.1
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
	var skyline_mat := _make_ps1_material(Color(0.06, 0.04, 0.09))

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

			# Scattered dim windows on skyline buildings (50% get windows)
			if rng.randf() < 0.5:
				var num_wins := rng.randi_range(5, 12)
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
	var sidewalk_mat := _make_ps1_material(Color(0.16, 0.15, 0.17))
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
			if rng.randf() > 0.20:  # ~20% of blocks get a billboard
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
		if bsize.y < 8.0 or rng.randf() > 0.45:  # 45% of buildings
			continue

		var gc := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
		var strip_y := -bsize.y * 0.5 + 0.1  # just above ground
		var num_faces := rng.randi_range(1, 3)  # 1-3 faces get underglow

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
			glow.light_energy = 2.5
			glow.omni_range = 7.0
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
		if bsize.y < 20.0 or rng.randf() > 0.15:  # 15% of tall buildings
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

		# Projector device on rooftop — makes the hologram look grounded
		var proj := Node3D.new()
		proj.position = Vector3(0, roof_y, 0)

		# Base unit (dark metal box)
		var base := MeshInstance3D.new()
		var base_mesh := BoxMesh.new()
		base_mesh.size = Vector3(0.5, 0.25, 0.5)
		base.mesh = base_mesh
		base.position = Vector3(0, 0.125, 0)
		base.set_surface_override_material(0, _make_ps1_material(Color(0.1, 0.1, 0.12)))
		base.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		proj.add_child(base)

		# Emitter lens (cylinder pointing up, glowing)
		var lens := MeshInstance3D.new()
		var lens_mesh := CylinderMesh.new()
		lens_mesh.top_radius = 0.08
		lens_mesh.bottom_radius = 0.12
		lens_mesh.height = 0.15
		lens.mesh = lens_mesh
		lens.position = Vector3(0, 0.325, 0)
		lens.set_surface_override_material(0,
			_make_ps1_material(neon_col * 0.3, true, neon_col, 3.0))
		lens.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		proj.add_child(lens)

		# Small accent ring around base
		var ring := MeshInstance3D.new()
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 0.3
		ring_mesh.bottom_radius = 0.3
		ring_mesh.height = 0.04
		ring.mesh = ring_mesh
		ring.position = Vector3(0, 0.27, 0)
		ring.set_surface_override_material(0,
			_make_ps1_material(neon_col * 0.15, true, neon_col, 1.5))
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		proj.add_child(ring)

		# Upward glow light from projector
		var proj_light := OmniLight3D.new()
		proj_light.light_color = neon_col
		proj_light.light_energy = 2.0
		proj_light.omni_range = 5.0
		proj_light.omni_attenuation = 1.5
		proj_light.shadow_enabled = false
		proj_light.position = Vector3(0, 0.5, 0)
		proj.add_child(proj_light)

		mi.add_child(proj)

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
		var tint_roll := rng.randf()
		var tier_color: Color
		if tint_roll < 0.4:
			tier_color = Color(darkness, darkness, darkness + 0.05)
		elif tint_roll < 0.6:
			tier_color = Color(darkness * 0.8, darkness * 0.85, darkness * 1.2)
		elif tint_roll < 0.75:
			tier_color = Color(darkness * 1.1, darkness * 0.9, darkness * 0.7)
		elif tint_roll < 0.9:
			tier_color = Color(darkness * 0.8, darkness * 1.0, darkness * 1.1)
		else:
			tier_color = Color(darkness * 0.95, darkness * 0.85, darkness * 1.0)
		tier.set_surface_override_material(0, _make_ps1_material(tier_color))
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
		if bsize.y < 12.0 or rng.randf() > 0.35:  # 35% of buildings
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
		if not has_interior_light or rng.randf() > 0.7:
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
		tube_light.light_energy = 3.5
		tube_light.omni_range = 8.0
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
		dish_nodes.append(dish_parent)

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
	# Haze walls and smog layer removed — they created a visible ceiling
	pass

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
			# Alternate direction per intersection to avoid waffle overlap
			var cross_dir := (gx + gz) % 2
			var num_stripes := 5
			var cross_x := 0.0
			var cross_z := 0.0
			if cross_dir == 0:
				# Crosswalk across X-street (stripes run along X)
				cross_x = cell_x + block_size * 0.5 + street_width * 0.5
				cross_z = cell_z + block_size * 0.5
				for s in range(num_stripes):
					var stripe := MeshInstance3D.new()
					var stripe_mesh := BoxMesh.new()
					stripe_mesh.size = Vector3(street_width * 0.7, 0.02, 0.4)
					stripe.mesh = stripe_mesh
					stripe.position = Vector3(cross_x, 0.015, cross_z + (s - 2) * 0.8)
					stripe.set_surface_override_material(0, stripe_mat)
					add_child(stripe)
			else:
				# Crosswalk across Z-street (stripes run along Z)
				cross_x = cell_x + block_size * 0.5
				cross_z = cell_z + block_size * 0.5 + street_width * 0.5
				for s in range(num_stripes):
					var stripe := MeshInstance3D.new()
					var stripe_mesh := BoxMesh.new()
					stripe_mesh.size = Vector3(0.4, 0.02, street_width * 0.7)
					stripe.mesh = stripe_mesh
					stripe.position = Vector3(cross_x + (s - 2) * 0.8, 0.015, cross_z)
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
		# Warm draft particles rising from underground
		var draft := GPUParticles3D.new()
		draft.amount = 8
		draft.lifetime = 2.0
		draft.visibility_aabb = AABB(Vector3(-2, -2, -4), Vector3(4, 6, 6))
		var draft_mat := ParticleProcessMaterial.new()
		draft_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		draft_mat.emission_box_extents = Vector3(0.8, 0.1, 0.3)
		draft_mat.direction = Vector3(0, 1, 0)
		draft_mat.spread = 25.0
		draft_mat.initial_velocity_min = 0.5
		draft_mat.initial_velocity_max = 1.2
		draft_mat.gravity = Vector3(0, 0.3, 0)
		draft_mat.damping_min = 0.5
		draft_mat.damping_max = 1.5
		draft_mat.scale_min = 0.05
		draft_mat.scale_max = 0.15
		draft_mat.color = Color(0.6, 0.5, 0.3, 0.06)
		draft.process_material = draft_mat
		var draft_mesh := SphereMesh.new()
		draft_mesh.radius = 0.08
		draft_mesh.height = 0.16
		draft.draw_pass_1 = draft_mesh
		draft.position = Vector3(0, -1.2, -2.0)
		entrance.add_child(draft)
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
		elif style == "pop_on":
			# Long off period then sudden pop back on with bright flash
			var pop_cycle := fmod(time * speed * 0.15 + phase, 8.0)
			var pop_energy := 0.0
			if pop_cycle < 5.0:
				pop_energy = 1.0  # normal on
			elif pop_cycle < 6.8:
				pop_energy = 0.0  # dead (off)
			elif pop_cycle < 6.85:
				pop_energy = 2.5  # bright pop-on flash
			else:
				pop_energy = 1.0  # back to normal
			light.light_energy = base * pop_energy
			var pop_mesh = data.get("mesh")
			if pop_mesh and is_instance_valid(pop_mesh):
				(pop_mesh as MeshInstance3D).visible = pop_energy > 0.01
			var pop_label = data.get("label")
			if pop_label and is_instance_valid(pop_label):
				(pop_label as Label3D).modulate.a = clampf(pop_energy, 0.0, 1.0)
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

	# Cycling window lights (slow on/off)
	for cw in cycling_windows:
		var win_mesh: MeshInstance3D = cw["mesh"]
		if not is_instance_valid(win_mesh):
			continue
		var cw_period: float = cw["period"]
		var cw_phase: float = cw["phase"]
		var cw_base: float = cw["base_energy"]
		# Smooth sine cycle from 0 to 1
		var brightness := (sin(time * TAU / cw_period + cw_phase) + 1.0) * 0.5
		# Apply to emission strength via material
		var mat := win_mesh.get_surface_override_material(0) as ShaderMaterial
		if mat:
			mat.set_shader_parameter("emission_strength", cw_base * brightness)

	# Rotating ventilation fans
	for fan in rotating_fans:
		var blade1: MeshInstance3D = fan["blade1"]
		var blade2: MeshInstance3D = fan["blade2"]
		if not is_instance_valid(blade1):
			continue
		var fan_speed: float = fan["speed"]
		blade1.rotation.y = time * fan_speed
		blade2.rotation.y = time * fan_speed

	# Satellite dish slow oscillation
	for dish in dish_nodes:
		if is_instance_valid(dish):
			dish.rotation.y += sin(time * 0.3 + dish.position.x) * 0.002

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

	# Wall screen color cycling (hold color for 4-8s, brief transition)
	for ws in wall_screen_anims:
		var wscreen: MeshInstance3D = ws["node"]
		if not is_instance_valid(wscreen):
			continue
		var wlight: OmniLight3D = ws["light"]
		var wphase: float = ws["phase"]
		var wcolors: Array = ws["colors"]
		# Each color held for ~6 seconds, 0.5s transition between
		var cycle_period := 6.5  # 6s hold + 0.5s transition
		var color_t := fmod(time * 0.15 + wphase * 3.0, float(wcolors.size()) * cycle_period)
		var ci := int(color_t / cycle_period) % wcolors.size()
		var within := fmod(color_t, cycle_period)
		var c1: Color = wcolors[ci]
		var c2: Color = wcolors[(ci + 1) % wcolors.size()]
		var cur_color: Color
		if within > cycle_period - 0.5:
			# Brief transition phase
			var blend := (within - (cycle_period - 0.5)) / 0.5
			cur_color = c1.lerp(c2, blend)
		else:
			cur_color = c1
		# Rare brief static flicker (5% of time)
		var flicker := sin(time * 8.0 + wphase * 5.0) > 0.95
		if flicker:
			cur_color = Color(0.7, 0.7, 0.7)
		# Update shader parameters (no material allocation)
		var smat: ShaderMaterial = wscreen.get_surface_override_material(0)
		if smat:
			smat.set_shader_parameter("albedo_color", cur_color * 0.3)
			smat.set_shader_parameter("emission_color", cur_color)
		if is_instance_valid(wlight):
			wlight.light_color = cur_color

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

	# Fly buzz audio near trash (proximity-based)
	if fly_pool.size() > 0:
		var fly_cam := get_viewport().get_camera_3d()
		if fly_cam:
			var fly_cam_pos := fly_cam.global_position
			var nearest_flies: Array[Dictionary] = []
			for fpos in fly_positions:
				var d := fpos.distance_to(fly_cam_pos)
				if d < FLY_RANGE:
					nearest_flies.append({"pos": fpos, "dist": d})
			nearest_flies.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["dist"] < b["dist"])
			for i in range(FLY_POOL_SIZE):
				var slot: Dictionary = fly_pool[i]
				var player: AudioStreamPlayer3D = slot["player"]
				var playback: AudioStreamGeneratorPlayback = slot["playback"]
				if i < nearest_flies.size():
					player.global_position = nearest_flies[i]["pos"]
					if playback:
						var frames := playback.get_frames_available()
						var ph: float = slot["phase"]
						var mix_rate := 22050.0
						for _f in range(frames):
							ph += 1.0 / mix_rate
							# Fly buzz: ~220Hz with rapid wobble
							var wobble := 1.0 + sin(ph * 15.0 * TAU) * 0.12
							var buzz := sin(ph * 220.0 * wobble * TAU) * 0.3
							buzz += sin(ph * 330.0 * wobble * TAU) * 0.15
							# Random intensity variation (fly moving around)
							var intensity := 0.5 + 0.5 * sin(ph * 2.5 * TAU)
							var sample := buzz * intensity * 0.08
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

	# (Ground-level smog ring removed — created visible ceiling)

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
	## Adds water tanks, antenna clusters, satellite dishes, and aviation warning lights
	## to building rooftops. Creates iconic cyberpunk skyline silhouettes.
	var rng := RandomNumberGenerator.new()
	rng.seed = 6700
	var children_snapshot := get_children()
	var rooftops: Array[Dictionary] = []
	for raw_child in children_snapshot:
		if not raw_child is MeshInstance3D:
			continue
		var child := raw_child as MeshInstance3D
		if not child.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (child.mesh as BoxMesh).size
		if bsize.y < 12.0:
			continue
		rooftops.append({
			"node": child,
			"pos": Vector3(child.position.x, child.position.y + bsize.y * 0.5, child.position.z),
			"roof_w": bsize.x,
			"roof_d": bsize.z,
			"height": bsize.y,
		})

	var tank_color := Color(0.15, 0.13, 0.12)
	var rust_color := Color(0.22, 0.12, 0.08)
	var leg_color := Color(0.1, 0.1, 0.1)
	var metal_color := Color(0.2, 0.2, 0.22)
	var antenna_color := Color(0.12, 0.12, 0.15)
	var tank_count := 0
	var antenna_count := 0

	for td in rooftops:
		var roof_pos: Vector3 = td["pos"]
		var rw: float = td["roof_w"]
		var rd: float = td["roof_d"]
		var bh: float = td["height"]

		# Water tank (30% of buildings > 15m tall)
		if bh > 15.0 and rng.randf() < 0.30:
			var tank_parent := Node3D.new()
			var offset_x := rng.randf_range(-rw * 0.25, rw * 0.25)
			var offset_z := rng.randf_range(-rd * 0.25, rd * 0.25)
			tank_parent.position = Vector3(roof_pos.x + offset_x, roof_pos.y, roof_pos.z + offset_z)

			# Tank body (cylinder)
			var tank := MeshInstance3D.new()
			var tank_mesh := CylinderMesh.new()
			var tank_r := rng.randf_range(0.6, 1.2)
			var tank_h := rng.randf_range(1.2, 2.0)
			tank_mesh.top_radius = tank_r
			tank_mesh.bottom_radius = tank_r
			tank_mesh.height = tank_h
			tank_mesh.radial_segments = 8
			tank.mesh = tank_mesh
			tank.position = Vector3(0, 1.8 + tank_h * 0.5, 0)
			var use_rust := rng.randf() < 0.4
			tank.set_surface_override_material(0,
				_make_ps1_material(rust_color if use_rust else tank_color))
			tank_parent.add_child(tank)

			# Tank lid (slightly wider disc)
			var lid := MeshInstance3D.new()
			var lid_mesh := CylinderMesh.new()
			lid_mesh.top_radius = tank_r + 0.05
			lid_mesh.bottom_radius = tank_r + 0.05
			lid_mesh.height = 0.08
			lid_mesh.radial_segments = 8
			lid.mesh = lid_mesh
			lid.position = Vector3(0, 1.8 + tank_h + 0.04, 0)
			lid.set_surface_override_material(0, _make_ps1_material(metal_color))
			tank_parent.add_child(lid)

			# 4 support legs
			for li in range(4):
				var leg := MeshInstance3D.new()
				var leg_mesh := BoxMesh.new()
				leg_mesh.size = Vector3(0.08, 1.8, 0.08)
				leg.mesh = leg_mesh
				var lx := (tank_r - 0.15) * (1.0 if li % 2 == 0 else -1.0)
				var lz := (tank_r - 0.15) * (1.0 if li < 2 else -1.0)
				leg.position = Vector3(lx, 0.9, lz)
				leg.set_surface_override_material(0, _make_ps1_material(leg_color))
				tank_parent.add_child(leg)

			# Pipe running down from tank (40%)
			if rng.randf() < 0.4:
				var pipe := MeshInstance3D.new()
				var pipe_mesh := BoxMesh.new()
				pipe_mesh.size = Vector3(0.06, 1.8, 0.06)
				pipe.mesh = pipe_mesh
				pipe.position = Vector3(tank_r + 0.1, 0.9, 0)
				pipe.set_surface_override_material(0, _make_ps1_material(leg_color))
				tank_parent.add_child(pipe)

			add_child(tank_parent)
			tank_count += 1

		# Antenna cluster (35% of buildings > 12m)
		if rng.randf() < 0.35:
			var ant_parent := Node3D.new()
			var ax := rng.randf_range(-rw * 0.3, rw * 0.3)
			var az := rng.randf_range(-rd * 0.3, rd * 0.3)
			ant_parent.position = Vector3(roof_pos.x + ax, roof_pos.y, roof_pos.z + az)

			# Main antenna pole
			var pole := MeshInstance3D.new()
			var pole_mesh := BoxMesh.new()
			var pole_h := rng.randf_range(2.0, 5.0)
			pole_mesh.size = Vector3(0.06, pole_h, 0.06)
			pole.mesh = pole_mesh
			pole.position = Vector3(0, pole_h * 0.5, 0)
			pole.set_surface_override_material(0, _make_ps1_material(antenna_color))
			ant_parent.add_child(pole)

			# Cross-bars (1-3)
			var num_bars := rng.randi_range(1, 3)
			for bi in range(num_bars):
				var bar := MeshInstance3D.new()
				var bar_mesh := BoxMesh.new()
				var bar_w := rng.randf_range(0.8, 1.8)
				bar_mesh.size = Vector3(bar_w, 0.04, 0.04)
				bar.mesh = bar_mesh
				bar.position = Vector3(0, pole_h * (0.5 + bi * 0.2), 0)
				bar.set_surface_override_material(0, _make_ps1_material(antenna_color))
				ant_parent.add_child(bar)

			# Small red warning light at top (50% of tall antennas)
			if pole_h > 3.0 and rng.randf() < 0.50:
				var warn_light := OmniLight3D.new()
				warn_light.light_color = Color(1.0, 0.1, 0.05)
				warn_light.light_energy = 1.5
				warn_light.omni_range = 8.0
				warn_light.omni_attenuation = 1.5
				warn_light.shadow_enabled = false
				warn_light.position = Vector3(0, pole_h + 0.1, 0)
				ant_parent.add_child(warn_light)

				# Red light bulb mesh
				var bulb := MeshInstance3D.new()
				var bulb_mesh := BoxMesh.new()
				bulb_mesh.size = Vector3(0.12, 0.12, 0.12)
				bulb.mesh = bulb_mesh
				bulb.position = Vector3(0, pole_h + 0.1, 0)
				bulb.set_surface_override_material(0,
					_make_ps1_material(Color(0.3, 0.02, 0.01), true, Color(1.0, 0.1, 0.05), 5.0))
				ant_parent.add_child(bulb)

				# Slow blink
				flickering_lights.append({
					"node": warn_light, "mesh": bulb,
					"base_energy": 1.5, "phase": rng.randf() * TAU,
					"speed": rng.randf_range(1.5, 3.0), "style": "slow_pulse",
				})

			add_child(ant_parent)
			antenna_count += 1

		# Satellite dish (15% of buildings > 18m)
		if bh > 18.0 and rng.randf() < 0.15:
			var dish_parent := Node3D.new()
			var dx := rng.randf_range(-rw * 0.3, rw * 0.3)
			var dz := rng.randf_range(-rd * 0.3, rd * 0.3)
			dish_parent.position = Vector3(roof_pos.x + dx, roof_pos.y, roof_pos.z + dz)

			# Dish base pole
			var dpole := MeshInstance3D.new()
			var dpole_mesh := BoxMesh.new()
			dpole_mesh.size = Vector3(0.1, 1.0, 0.1)
			dpole.mesh = dpole_mesh
			dpole.position = Vector3(0, 0.5, 0)
			dpole.set_surface_override_material(0, _make_ps1_material(metal_color))
			dish_parent.add_child(dpole)

			# Dish (tilted flat disc approximated as a thin cylinder)
			var dish := MeshInstance3D.new()
			var dish_mesh := CylinderMesh.new()
			var dish_r := rng.randf_range(0.5, 1.0)
			dish_mesh.top_radius = dish_r
			dish_mesh.bottom_radius = dish_r * 0.3
			dish_mesh.height = 0.15
			dish_mesh.radial_segments = 8
			dish.mesh = dish_mesh
			dish.position = Vector3(0, 1.1, 0)
			dish.rotation.x = rng.randf_range(0.4, 0.8)  # tilted upward
			dish.rotation.y = rng.randf_range(0, TAU)
			dish.set_surface_override_material(0, _make_ps1_material(metal_color))
			dish_parent.add_child(dish)

			add_child(dish_parent)
			antenna_count += 1

	print("CityGenerator: rooftop tanks=", tank_count, " antennas=", antenna_count)

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
	# to regular buildings at ground level. Skips enterable buildings (Node3D with interior).
	var rng := RandomNumberGenerator.new()
	rng.seed = 7300
	var children_snapshot := get_children()
	for raw_child in children_snapshot:
		var bsize := Vector3.ZERO
		var child: Node3D = null
		if raw_child is MeshInstance3D:
			var mi := raw_child as MeshInstance3D
			if mi.mesh is BoxMesh:
				bsize = (mi.mesh as BoxMesh).size
				child = mi
		elif raw_child is Node3D:
			# Modular buildings — estimate size from child pieces, skip enterable (they have doors)
			var n3d := raw_child as Node3D
			# Enterable buildings have OmniLight3D children (interior light) — skip them
			var has_interior_light := false
			for gc in n3d.get_children():
				if gc is OmniLight3D:
					has_interior_light = true
					break
			if has_interior_light:
				continue
			# Estimate building size from child MeshInstance3D bounding
			var max_extent := Vector3.ZERO
			for gc in n3d.get_children():
				if gc is MeshInstance3D and (gc as MeshInstance3D).mesh is BoxMesh:
					var piece: MeshInstance3D = gc as MeshInstance3D
					var ps: Vector3 = (piece.mesh as BoxMesh).size
					var top: float = piece.position.y + ps.y * 0.5
					var right: float = absf(piece.position.x) + ps.x * 0.5
					var front: float = absf(piece.position.z) + ps.z * 0.5
					max_extent.y = maxf(max_extent.y, top)
					max_extent.x = maxf(max_extent.x, right * 2.0)
					max_extent.z = maxf(max_extent.z, front * 2.0)
			if max_extent.y > 0:
				bsize = max_extent
				child = n3d
		if child == null:
			continue
		# Filter: only buildings tall enough and wide enough
		if bsize.y < 5.0 or bsize.x < 4.0:
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
		door_light.light_energy = rng.randf_range(3.0, 5.0)
		door_light.omni_range = 8.0
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
	var num_vendors := 12
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
		stall_light.light_energy = 4.0
		stall_light.omni_range = 8.0
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
		# Cooking steam rising from the stall
		var steam := GPUParticles3D.new()
		steam.position = Vector3(rng.randf_range(-0.3, 0.3), 1.2, rng.randf_range(-0.2, 0.2))
		steam.amount = 8
		steam.lifetime = 2.0
		steam.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4))
		var steam_mat := ParticleProcessMaterial.new()
		steam_mat.direction = Vector3(0, 1, 0)
		steam_mat.spread = 20.0
		steam_mat.initial_velocity_min = 0.5
		steam_mat.initial_velocity_max = 1.2
		steam_mat.gravity = Vector3(0, 0.1, 0)
		steam_mat.damping_min = 1.0
		steam_mat.damping_max = 2.0
		steam_mat.scale_min = 0.15
		steam_mat.scale_max = 0.4
		steam_mat.color = Color(0.7, 0.7, 0.75, 0.12)
		steam.process_material = steam_mat
		var steam_mesh := BoxMesh.new()
		steam_mesh.size = Vector3(0.15, 0.15, 0.15)
		steam.draw_pass_1 = steam_mesh
		vendor.add_child(steam)
		add_child(vendor)

func _generate_alleys() -> void:
	# Find narrow gaps between buildings and add atmospheric fog + dim colored light
	var rng := RandomNumberGenerator.new()
	rng.seed = 7500
	var alley_count := 0
	var max_alleys := 18
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
			# Alley puddle with neon reflection
			var apuddle := MeshInstance3D.new()
			var apud_mesh := QuadMesh.new()
			apud_mesh.size = Vector2(gap * 0.6, minf(size_a.z, size_b.z) * 0.4)
			apuddle.mesh = apud_mesh
			apuddle.position = mid + Vector3(0, 0.015, 0)
			apuddle.rotation.x = -PI * 0.5
			var apud_mat := ShaderMaterial.new()
			apud_mat.shader = puddle_shader
			apud_mat.set_shader_parameter("puddle_tint", alley_light.light_color * 0.08)
			apud_mat.set_shader_parameter("neon_tint", alley_light.light_color)
			apud_mat.set_shader_parameter("neon_strength", 0.8)
			apud_mat.set_shader_parameter("reflection_strength", 0.4)
			apud_mat.set_shader_parameter("ripple_speed", 2.0)
			apud_mat.set_shader_parameter("ripple_scale", 8.0)
			apuddle.set_surface_override_material(0, apud_mat)
			add_child(apuddle)

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

func _generate_scattered_papers() -> void:
	# Flat quads on ground simulating scattered newspapers/flyers
	var rng := RandomNumberGenerator.new()
	rng.seed = 7800
	for _i in range(18):
		var gx := rng.randi_range(-grid_size + 1, grid_size - 1)
		var gz := rng.randi_range(-grid_size + 1, grid_size - 1)
		var stride := block_size + street_width
		var px := gx * stride + rng.randf_range(-block_size * 0.4, block_size * 0.5 + street_width)
		var pz := gz * stride + rng.randf_range(-block_size * 0.4, block_size * 0.5 + street_width)
		var paper := MeshInstance3D.new()
		var paper_mesh := QuadMesh.new()
		paper_mesh.size = Vector2(rng.randf_range(0.2, 0.4), rng.randf_range(0.25, 0.45))
		paper.mesh = paper_mesh
		paper.position = Vector3(px, 0.02, pz)
		paper.rotation.x = -PI * 0.5  # lay flat
		paper.rotation.y = rng.randf_range(0, TAU)
		# Slight crumple tilt
		paper.rotation.z = rng.randf_range(-0.15, 0.15)
		var color_idx := rng.randi_range(0, 3)
		var pcol := Color(0.65, 0.62, 0.55)  # aged newspaper
		if color_idx == 1: pcol = Color(0.7, 0.5, 0.3)    # manila
		elif color_idx == 2: pcol = Color(0.5, 0.48, 0.42) # gray paper
		elif color_idx == 3: pcol = Color(0.75, 0.7, 0.6)  # cream
		paper.set_surface_override_material(0, _make_ps1_material(pcol * 0.5))
		paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(paper)

func _generate_facade_stripes() -> void:
	# Horizontal stripe details on building facades for architectural variety
	var rng := RandomNumberGenerator.new()
	rng.seed = 7900
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 12.0:
			continue
		if rng.randf() > 0.40:
			continue
		var num_stripes := rng.randi_range(2, 5)
		var stripe_color_offset := rng.randf_range(-0.08, 0.08)
		for _s in range(num_stripes):
			var stripe_y := mi.position.y + rng.randf_range(-bsize.y * 0.35, bsize.y * 0.35)
			# Front face stripe
			var stripe := MeshInstance3D.new()
			var smesh := BoxMesh.new()
			smesh.size = Vector3(bsize.x + 0.02, rng.randf_range(0.15, 0.3), 0.05)
			stripe.mesh = smesh
			stripe.position = Vector3(mi.position.x, stripe_y, mi.position.z + bsize.z * 0.51)
			var base_dark := 0.35 + stripe_color_offset
			stripe.set_surface_override_material(0,
				_make_ps1_material(Color(base_dark, base_dark, base_dark + 0.03)))
			stripe.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(stripe)
			# Back face stripe
			var stripe_b := MeshInstance3D.new()
			stripe_b.mesh = smesh
			stripe_b.position = Vector3(mi.position.x, stripe_y, mi.position.z - bsize.z * 0.51)
			stripe_b.set_surface_override_material(0, stripe.get_surface_override_material(0))
			stripe_b.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(stripe_b)

func _generate_balcony_ledges() -> void:
	# Small protruding balcony platforms on building faces
	var rng := RandomNumberGenerator.new()
	rng.seed = 8000
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 14.0:
			continue
		if rng.randf() > 0.25:
			continue
		var num_balc := rng.randi_range(1, 4)
		for _b in range(num_balc):
			var balc_y := mi.position.y + rng.randf_range(-bsize.y * 0.3, bsize.y * 0.25)
			var face_side := rng.randi_range(0, 1)  # 0=front(+Z), 1=back(-Z)
			var face_sign := 1.0 if face_side == 0 else -1.0
			var balc_x := mi.position.x + rng.randf_range(-bsize.x * 0.3, bsize.x * 0.3)
			var balc_z := mi.position.z + face_sign * (bsize.z * 0.5 + 0.4)
			# Floor slab
			var slab := MeshInstance3D.new()
			var slab_mesh := BoxMesh.new()
			var balc_w := rng.randf_range(1.5, 2.5)
			slab_mesh.size = Vector3(balc_w, 0.08, 0.8)
			slab.mesh = slab_mesh
			slab.position = Vector3(balc_x, balc_y, balc_z)
			slab.set_surface_override_material(0, _make_ps1_material(Color(0.25, 0.24, 0.22)))
			slab.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(slab)
			# Railing posts (3 thin cylinders)
			var rail_mat := _make_ps1_material(Color(0.18, 0.18, 0.16))
			for ri in range(3):
				var rail := MeshInstance3D.new()
				var rail_mesh := CylinderMesh.new()
				rail_mesh.top_radius = 0.02
				rail_mesh.bottom_radius = 0.02
				rail_mesh.height = 0.7
				rail.mesh = rail_mesh
				rail.position = Vector3(
					balc_x - balc_w * 0.4 + ri * balc_w * 0.4,
					balc_y + 0.35,
					balc_z + face_sign * 0.35
				)
				rail.set_surface_override_material(0, rail_mat)
				rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(rail)
			# Top rail (horizontal bar)
			var top_rail := MeshInstance3D.new()
			var top_mesh := BoxMesh.new()
			top_mesh.size = Vector3(balc_w, 0.03, 0.03)
			top_rail.mesh = top_mesh
			top_rail.position = Vector3(balc_x, balc_y + 0.7, balc_z + face_sign * 0.35)
			top_rail.set_surface_override_material(0, rail_mat)
			top_rail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(top_rail)
			# Potted plant on balcony (25% chance)
			if rng.randf() < 0.25:
				var pot := MeshInstance3D.new()
				var pot_mesh := CylinderMesh.new()
				pot_mesh.top_radius = 0.12
				pot_mesh.bottom_radius = 0.08
				pot_mesh.height = 0.2
				pot.mesh = pot_mesh
				var pot_x := balc_x + rng.randf_range(-balc_w * 0.25, balc_w * 0.25)
				pot.position = Vector3(pot_x, balc_y + 0.14, balc_z)
				pot.set_surface_override_material(0, _make_ps1_material(Color(0.35, 0.18, 0.08)))
				pot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(pot)
				# Green foliage ball
				var leaf := MeshInstance3D.new()
				var leaf_mesh := SphereMesh.new()
				leaf_mesh.radius = 0.15
				leaf_mesh.height = 0.25
				leaf.mesh = leaf_mesh
				leaf.position = Vector3(pot_x, balc_y + 0.36, balc_z)
				var green := Color(rng.randf_range(0.1, 0.2), rng.randf_range(0.25, 0.45), rng.randf_range(0.05, 0.15))
				leaf.set_surface_override_material(0, _make_ps1_material(green))
				leaf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(leaf)

func _generate_roof_parapets() -> void:
	# Raised lip around building rooftop edges
	var rng := RandomNumberGenerator.new()
	rng.seed = 8100
	var parapet_mat := _make_ps1_material(Color(0.28, 0.27, 0.25))
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 10.0:
			continue
		if rng.randf() > 0.25:
			continue
		var roof_y := mi.position.y + bsize.y * 0.5
		var lip_h := rng.randf_range(0.3, 0.6)
		var lip_thick := 0.12
		# Front parapet (+Z)
		var pf := MeshInstance3D.new()
		var pf_mesh := BoxMesh.new()
		pf_mesh.size = Vector3(bsize.x + lip_thick * 2.0, lip_h, lip_thick)
		pf.mesh = pf_mesh
		pf.position = Vector3(mi.position.x, roof_y + lip_h * 0.5, mi.position.z + bsize.z * 0.5)
		pf.set_surface_override_material(0, parapet_mat)
		pf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pf)
		# Back parapet (-Z)
		var pb := MeshInstance3D.new()
		pb.mesh = pf_mesh
		pb.position = Vector3(mi.position.x, roof_y + lip_h * 0.5, mi.position.z - bsize.z * 0.5)
		pb.set_surface_override_material(0, parapet_mat)
		pb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pb)
		# Left parapet (+X)
		var pl := MeshInstance3D.new()
		var pl_mesh := BoxMesh.new()
		pl_mesh.size = Vector3(lip_thick, lip_h, bsize.z)
		pl.mesh = pl_mesh
		pl.position = Vector3(mi.position.x + bsize.x * 0.5, roof_y + lip_h * 0.5, mi.position.z)
		pl.set_surface_override_material(0, parapet_mat)
		pl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pl)
		# Right parapet (-X)
		var pr := MeshInstance3D.new()
		pr.mesh = pl_mesh
		pr.position = Vector3(mi.position.x - bsize.x * 0.5, roof_y + lip_h * 0.5, mi.position.z)
		pr.set_surface_override_material(0, parapet_mat)
		pr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(pr)

func _generate_building_cornices() -> void:
	# Decorative horizontal trim at roofline
	var rng := RandomNumberGenerator.new()
	rng.seed = 8200
	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 12.0:
			continue
		if rng.randf() > 0.35:
			continue
		var roof_y := mi.position.y + bsize.y * 0.5
		var cornice_h := rng.randf_range(0.2, 0.4)
		var cornice_depth := rng.randf_range(0.15, 0.3)
		var cornice_color := Color(0.32, 0.30, 0.28) + Color(rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05), rng.randf_range(-0.05, 0.05))
		var c_mat := _make_ps1_material(cornice_color)
		# Front cornice (+Z) — slightly wider/deeper than building face
		var cf := MeshInstance3D.new()
		var cf_mesh := BoxMesh.new()
		cf_mesh.size = Vector3(bsize.x + cornice_depth * 2.0, cornice_h, cornice_depth)
		cf.mesh = cf_mesh
		cf.position = Vector3(mi.position.x, roof_y - cornice_h * 0.5 - 0.1, mi.position.z + bsize.z * 0.5 + cornice_depth * 0.5)
		cf.set_surface_override_material(0, c_mat)
		cf.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cf)
		# Back cornice (-Z)
		var cb := MeshInstance3D.new()
		cb.mesh = cf_mesh
		cb.position = Vector3(mi.position.x, roof_y - cornice_h * 0.5 - 0.1, mi.position.z - bsize.z * 0.5 - cornice_depth * 0.5)
		cb.set_surface_override_material(0, c_mat)
		cb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cb)

func _generate_window_frames() -> void:
	# Raised frame borders around some lit windows for depth
	var rng := RandomNumberGenerator.new()
	rng.seed = 8300
	var frame_mat := _make_ps1_material(Color(0.15, 0.14, 0.13))
	var count := 0
	var max_frames := 160
	for child in get_children():
		if count >= max_frames:
			break
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 10.0:
			continue
		# Check children for window quads
		for sub in mi.get_children():
			if count >= max_frames:
				break
			if not sub is MeshInstance3D:
				continue
			if not sub.mesh is QuadMesh:
				continue
			var qsize: Vector2 = (sub.mesh as QuadMesh).size
			# Must be window-sized (roughly 1.2 x 1.5)
			if qsize.x < 0.8 or qsize.x > 2.0 or qsize.y < 1.0 or qsize.y > 2.0:
				continue
			if rng.randf() > 0.22:
				continue
			count += 1
			# Frame thickness
			var ft := 0.06
			var fh := qsize.y + ft * 2.0
			var fw := qsize.x + ft * 2.0
			# Determine face direction from window position
			# Top frame bar
			var ftop := MeshInstance3D.new()
			var ftop_mesh := BoxMesh.new()
			ftop_mesh.size = Vector3(fw, ft, 0.04)
			ftop.mesh = ftop_mesh
			ftop.position = sub.position + Vector3(0, qsize.y * 0.5 + ft * 0.5, 0)
			ftop.rotation = sub.rotation
			ftop.set_surface_override_material(0, frame_mat)
			ftop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.add_child(ftop)
			# Bottom frame bar
			var fbot := MeshInstance3D.new()
			fbot.mesh = ftop_mesh
			fbot.position = sub.position + Vector3(0, -qsize.y * 0.5 - ft * 0.5, 0)
			fbot.rotation = sub.rotation
			fbot.set_surface_override_material(0, frame_mat)
			fbot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.add_child(fbot)
			# Left side bar
			var fleft := MeshInstance3D.new()
			var fside_mesh := BoxMesh.new()
			fside_mesh.size = Vector3(ft, fh, 0.04)
			fleft.mesh = fside_mesh
			fleft.position = sub.position + Vector3(-qsize.x * 0.5 - ft * 0.5, 0, 0)
			fleft.rotation = sub.rotation
			fleft.set_surface_override_material(0, frame_mat)
			fleft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.add_child(fleft)
			# Right side bar
			var fright := MeshInstance3D.new()
			fright.mesh = fside_mesh
			fright.position = sub.position + Vector3(qsize.x * 0.5 + ft * 0.5, 0, 0)
			fright.rotation = sub.rotation
			fright.set_surface_override_material(0, frame_mat)
			fright.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.add_child(fright)

func _generate_building_stoops() -> void:
	# Small concrete steps at building ground level
	var rng := RandomNumberGenerator.new()
	rng.seed = 8400
	var step_mat := _make_ps1_material(Color(0.3, 0.28, 0.26))
	var count := 0
	for child in get_children():
		if count >= 40:
			break
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 10.0:
			continue
		if rng.randf() > 0.18:
			continue
		count += 1
		var face_sign := 1.0 if rng.randf() < 0.5 else -1.0
		var stoop_x := mi.position.x + rng.randf_range(-bsize.x * 0.25, bsize.x * 0.25)
		var stoop_z := mi.position.z + face_sign * (bsize.z * 0.5)
		var base_y := mi.position.y - bsize.y * 0.5
		# 2-3 steps
		var num_steps := rng.randi_range(2, 3)
		for si in range(num_steps):
			var step := MeshInstance3D.new()
			var step_mesh := BoxMesh.new()
			var step_w := 1.8 - si * 0.15
			step_mesh.size = Vector3(step_w, 0.18, 0.4)
			step.mesh = step_mesh
			step.position = Vector3(stoop_x, base_y + si * 0.18 + 0.09, stoop_z + face_sign * (si * 0.35 + 0.2))
			step.set_surface_override_material(0, step_mat)
			step.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(step)

func _generate_exit_signs() -> void:
	# Green "非常口" / "EXIT" signs on building walls near ground level
	var rng := RandomNumberGenerator.new()
	rng.seed = 8500
	var exit_color := Color(0.0, 0.9, 0.3)
	var count := 0
	for child in get_children():
		if count >= 40:
			break
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 10.0:
			continue
		if rng.randf() > 0.25:
			continue
		count += 1
		var sign_y := mi.position.y - bsize.y * 0.5 + rng.randf_range(2.5, 4.0)
		var face_side := rng.randi_range(0, 1)
		var face_sign := 1.0 if face_side == 0 else -1.0
		var sign_x := mi.position.x + rng.randf_range(-bsize.x * 0.3, bsize.x * 0.3)
		var sign_z := mi.position.z + face_sign * (bsize.z * 0.51 + 0.01)
		# Sign backing (small dark green quad)
		var backing := MeshInstance3D.new()
		var back_mesh := BoxMesh.new()
		back_mesh.size = Vector3(0.6, 0.25, 0.03)
		backing.mesh = back_mesh
		backing.position = Vector3(sign_x, sign_y, sign_z)
		backing.set_surface_override_material(0, _make_ps1_material(Color(0.02, 0.08, 0.02), true, exit_color, 2.0))
		backing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(backing)
		# Text label
		if neon_font:
			var label := Label3D.new()
			var use_kanji := rng.randf() < 0.6
			if use_kanji:
				label.text = "非常口"
			else:
				label.text = "EXIT"
			label.font = neon_font
			label.font_size = 24
			label.pixel_size = 0.008
			label.modulate = exit_color
			label.outline_modulate = exit_color * 0.3
			label.outline_size = 2
			label.no_depth_test = false
			label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			label.position = Vector3(sign_x, sign_y, sign_z + face_sign * 0.02)
			if face_sign < 0:
				label.rotation.y = PI
			add_child(label)
		# Small green glow
		var glow := OmniLight3D.new()
		glow.light_color = exit_color
		glow.light_energy = 0.5
		glow.omni_range = 2.5
		glow.omni_attenuation = 2.0
		glow.shadow_enabled = false
		glow.position = Vector3(sign_x, sign_y, sign_z + face_sign * 0.1)
		add_child(glow)

func _generate_puddle_splash_rings() -> void:
	# Rain impact particles at puddle locations
	var rng := RandomNumberGenerator.new()
	rng.seed = 8600
	var count := 0
	for child in get_children():
		if count >= 12:
			break
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is QuadMesh:
			continue
		# Only ground-level quads (puddles are at y=0.02)
		if absf(mi.position.y - 0.02) > 0.05:
			continue
		if rng.randf() > 0.15:
			continue
		count += 1
		var qsize: Vector2 = (mi.mesh as QuadMesh).size
		var splash := GPUParticles3D.new()
		splash.position = mi.position + Vector3(0, 0.03, 0)
		splash.amount = 4
		splash.lifetime = 0.6
		splash.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 2, 6))
		var smat := ParticleProcessMaterial.new()
		smat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		smat.emission_box_extents = Vector3(qsize.x * 0.4, 0, qsize.y * 0.4)
		smat.direction = Vector3(0, 1, 0)
		smat.spread = 10.0
		smat.initial_velocity_min = 0.3
		smat.initial_velocity_max = 0.8
		smat.gravity = Vector3(0, -3.0, 0)
		smat.scale_min = 0.03
		smat.scale_max = 0.08
		smat.color = Color(0.4, 0.45, 0.55, 0.15)
		splash.process_material = smat
		var smesh := SphereMesh.new()
		smesh.radius = 0.04
		smesh.height = 0.02
		splash.draw_pass_1 = smesh
		add_child(splash)

func _generate_lobby_lights() -> void:
	# Warm interior light spilling from building ground level
	var rng := RandomNumberGenerator.new()
	rng.seed = 8700
	var count := 0
	for child in get_children():
		if count >= 30:
			break
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 10.0:
			continue
		if rng.randf() > 0.20:
			continue
		count += 1
		var base_y := mi.position.y - bsize.y * 0.5 + 1.5
		var face_sign := 1.0 if rng.randf() < 0.5 else -1.0
		var lobby_x := mi.position.x + rng.randf_range(-bsize.x * 0.2, bsize.x * 0.2)
		var lobby_z := mi.position.z + face_sign * (bsize.z * 0.5 + 0.5)
		var lobby_light := OmniLight3D.new()
		var warm_idx := rng.randi_range(0, 2)
		var warm_col := Color(1.0, 0.8, 0.4)
		if warm_idx == 1: warm_col = Color(1.0, 0.7, 0.3)
		elif warm_idx == 2: warm_col = Color(0.9, 0.85, 0.6)
		lobby_light.light_color = warm_col
		lobby_light.light_energy = rng.randf_range(3.0, 5.0)
		lobby_light.omni_range = rng.randf_range(8.0, 14.0)
		lobby_light.omni_attenuation = 1.5
		lobby_light.shadow_enabled = false
		lobby_light.position = Vector3(lobby_x, base_y, lobby_z)
		add_child(lobby_light)

func _generate_height_fog_layers() -> void:
	# Subtle colored fog planes at different heights for depth
	var fog_mat_low := StandardMaterial3D.new()
	fog_mat_low.albedo_color = Color(0.08, 0.03, 0.12, 0.03)
	fog_mat_low.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog_mat_low.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog_mat_low.cull_mode = BaseMaterial3D.CULL_DISABLED
	fog_mat_low.no_depth_test = true

	var fog_mat_mid := StandardMaterial3D.new()
	fog_mat_mid.albedo_color = Color(0.05, 0.06, 0.1, 0.02)
	fog_mat_mid.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog_mat_mid.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog_mat_mid.cull_mode = BaseMaterial3D.CULL_DISABLED
	fog_mat_mid.no_depth_test = true

	var fog_mat_high := StandardMaterial3D.new()
	fog_mat_high.albedo_color = Color(0.02, 0.02, 0.04, 0.015)
	fog_mat_high.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fog_mat_high.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fog_mat_high.cull_mode = BaseMaterial3D.CULL_DISABLED
	fog_mat_high.no_depth_test = true

	var heights := [5.0, 15.0, 25.0]
	var mats := [fog_mat_low, fog_mat_mid, fog_mat_high]
	for i in range(3):
		var fog_plane := MeshInstance3D.new()
		var fog_mesh := PlaneMesh.new()
		fog_mesh.size = Vector2(300, 300)
		fog_plane.mesh = fog_mesh
		fog_plane.position = Vector3(0, heights[i], 0)
		fog_plane.set_surface_override_material(0, mats[i])
		fog_plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(fog_plane)

func _generate_barricade_tape() -> void:
	# Yellow-black emergency tape strips across alley entrances
	var rng := RandomNumberGenerator.new()
	rng.seed = 8800
	var tape_color := Color(0.9, 0.8, 0.0)
	var count := 0
	for child in get_children():
		if count >= 8:
			break
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 8.0 or bsize.x < 5.0:
			continue
		if rng.randf() > 0.04:
			continue
		count += 1
		var tape_y := mi.position.y - bsize.y * 0.5 + rng.randf_range(0.8, 1.2)
		var face_sign := 1.0 if rng.randf() < 0.5 else -1.0
		var tape_z := mi.position.z + face_sign * (bsize.z * 0.5 + 1.0)
		# Tape strip (thin emissive yellow box)
		var tape := MeshInstance3D.new()
		var tape_mesh := BoxMesh.new()
		tape_mesh.size = Vector3(bsize.x * 0.6, 0.04, 0.01)
		tape.mesh = tape_mesh
		tape.position = Vector3(mi.position.x, tape_y, tape_z)
		tape.set_surface_override_material(0,
			_make_ps1_material(tape_color * 0.4, true, tape_color, 1.5))
		tape.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(tape)
		# Second tape at different height
		if rng.randf() < 0.6:
			var tape2 := MeshInstance3D.new()
			tape2.mesh = tape_mesh
			tape2.position = Vector3(mi.position.x, tape_y + 0.3, tape_z)
			tape2.set_surface_override_material(0, tape.get_surface_override_material(0))
			tape2.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(tape2)

func _generate_cardboard_boxes() -> void:
	# Soggy cardboard boxes near buildings and dumpsters
	var rng := RandomNumberGenerator.new()
	rng.seed = 8900
	var box_mat := _make_ps1_material(Color(0.22, 0.15, 0.08))
	var box_mat_dark := _make_ps1_material(Color(0.15, 0.1, 0.05))
	for _i in range(15):
		var gx := rng.randi_range(-grid_size + 1, grid_size - 1)
		var gz := rng.randi_range(-grid_size + 1, grid_size - 1)
		var stride := block_size + street_width
		var bx := gx * stride + rng.randf_range(-block_size * 0.4, block_size * 0.4)
		var bz := gz * stride + rng.randf_range(-block_size * 0.4, block_size * 0.4)
		var box := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		var bw := rng.randf_range(0.25, 0.5)
		var bh := rng.randf_range(0.15, 0.35)
		var bd := rng.randf_range(0.2, 0.4)
		box_mesh.size = Vector3(bw, bh, bd)
		box.mesh = box_mesh
		box.position = Vector3(bx, bh * 0.5, bz)
		box.rotation.y = rng.randf_range(0, TAU)
		# Slight tilt (collapsed/crushed look)
		box.rotation.x = rng.randf_range(-0.1, 0.1)
		box.rotation.z = rng.randf_range(-0.1, 0.1)
		var use_dark := rng.randf() < 0.4
		box.set_surface_override_material(0, box_mat_dark if use_dark else box_mat)
		box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(box)

func _generate_puddle_mist() -> void:
	# Subtle ground-hugging mist near some puddle areas
	var rng := RandomNumberGenerator.new()
	rng.seed = 9200
	var stride := block_size + street_width
	var count := 0
	for _i in range(30):
		if count >= 8:
			break
		var gx := rng.randi_range(-grid_size + 1, grid_size - 1)
		var gz := rng.randi_range(-grid_size + 1, grid_size - 1)
		if rng.randf() > 0.3:
			continue
		count += 1
		var mx := gx * stride + rng.randf_range(-2.0, block_size * 0.4)
		var mz := gz * stride + rng.randf_range(-2.0, block_size * 0.4)
		var mist := GPUParticles3D.new()
		mist.amount = 5
		mist.lifetime = 3.0
		mist.visibility_aabb = AABB(Vector3(-4, -0.5, -4), Vector3(8, 2, 8))
		var mist_mat := ParticleProcessMaterial.new()
		mist_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		mist_mat.emission_box_extents = Vector3(2.0, 0.05, 2.0)
		mist_mat.direction = Vector3(0.3, 0.2, 0)
		mist_mat.spread = 45.0
		mist_mat.initial_velocity_min = 0.1
		mist_mat.initial_velocity_max = 0.3
		mist_mat.gravity = Vector3(0, 0.02, 0)
		mist_mat.damping_min = 0.5
		mist_mat.damping_max = 1.0
		mist_mat.scale_min = 0.3
		mist_mat.scale_max = 0.8
		mist_mat.color = Color(0.4, 0.4, 0.5, 0.03)
		mist.process_material = mist_mat
		var mist_mesh := SphereMesh.new()
		mist_mesh.radius = 0.15
		mist_mesh.height = 0.1
		mist.draw_pass_1 = mist_mesh
		mist.position = Vector3(mx, 0.1, mz)
		add_child(mist)

func _setup_fly_buzz_audio() -> void:
	fly_rng.seed = 9100
	# Collect dumpster/trash bag positions as fly sources
	var stride := block_size + street_width
	for _i in range(6):
		var gx := fly_rng.randi_range(-grid_size + 1, grid_size - 1)
		var gz := fly_rng.randi_range(-grid_size + 1, grid_size - 1)
		var fx := gx * stride + fly_rng.randf_range(2.0, block_size - 2.0)
		var fz := gz * stride + fly_rng.randf_range(2.0, block_size - 2.0)
		fly_positions.append(Vector3(fx, 0.5, fz))
	# Create audio pool
	for _i in range(FLY_POOL_SIZE):
		var player := AudioStreamPlayer3D.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.1
		player.stream = gen
		player.volume_db = -24.0
		player.max_distance = FLY_RANGE
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 3.0
		add_child(player)
		player.play()
		fly_pool.append({
			"player": player,
			"generator": gen,
			"playback": player.get_stream_playback(),
			"phase": 0.0,
		})

func _generate_chimney_smoke() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9300
	var stride := block_size + street_width
	var count := 0
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if count >= 10:
				break
			if rng.randf() > 0.08:
				continue
			var bx := gx * stride + rng.randf_range(3.0, block_size - 3.0)
			var bz := gz * stride + rng.randf_range(3.0, block_size - 3.0)
			var roof_y := rng.randf_range(15.0, 35.0)
			# Chimney stack (dark box on rooftop)
			var chimney := MeshInstance3D.new()
			var ch_mesh := BoxMesh.new()
			ch_mesh.size = Vector3(0.6, 1.8, 0.6)
			chimney.mesh = ch_mesh
			chimney.position = Vector3(bx, roof_y + 0.9, bz)
			chimney.material_override = _make_ps1_material(Color(0.12, 0.1, 0.1))
			add_child(chimney)
			# Smoke particles rising from chimney top
			var smoke := GPUParticles3D.new()
			smoke.position = Vector3(bx, roof_y + 1.8, bz)
			smoke.amount = 6
			smoke.lifetime = 3.0
			smoke.visibility_aabb = AABB(Vector3(-3, -1, -3), Vector3(6, 8, 6))
			var sm_mat := ParticleProcessMaterial.new()
			sm_mat.direction = Vector3(0.3, 1, 0)
			sm_mat.spread = 15.0
			sm_mat.initial_velocity_min = 0.4
			sm_mat.initial_velocity_max = 0.9
			sm_mat.gravity = Vector3(0.2, 0.05, 0)
			sm_mat.damping_min = 0.3
			sm_mat.damping_max = 0.7
			sm_mat.scale_min = 0.15
			sm_mat.scale_max = 0.5
			sm_mat.color = Color(0.45, 0.42, 0.4, 0.06)
			smoke.process_material = sm_mat
			var sm_mesh := BoxMesh.new()
			sm_mesh.size = Vector3(0.2, 0.2, 0.2)
			smoke.draw_pass_1 = sm_mesh
			add_child(smoke)
			count += 1

func _generate_fluorescent_tubes() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9400
	var stride := block_size + street_width
	var tube_count := 0
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if tube_count >= 30:
				break
			if rng.randf() > 0.18:
				continue
			var bx := gx * stride + rng.randf_range(2.0, block_size - 2.0)
			var bz := gz * stride + rng.randf_range(-1.0, 1.0)  # near building edge/street
			var tube_y := rng.randf_range(3.0, 5.5)
			# Tube mesh (long thin box)
			var tube := MeshInstance3D.new()
			var tube_mesh := BoxMesh.new()
			tube_mesh.size = Vector3(1.8, 0.06, 0.06)
			tube.mesh = tube_mesh
			tube.position = Vector3(bx, tube_y, bz)
			var tube_col := Color(0.85, 0.9, 1.0) if rng.randf() < 0.7 else Color(1.0, 0.95, 0.8)
			tube.material_override = _make_ps1_material(tube_col * 0.5, true, tube_col, 3.0)
			add_child(tube)
			# Light underneath
			var tube_light := OmniLight3D.new()
			tube_light.position = Vector3(bx, tube_y - 0.1, bz)
			tube_light.light_color = tube_col
			tube_light.light_energy = 2.5
			tube_light.omni_range = 6.0
			tube_light.shadow_enabled = false
			add_child(tube_light)
			# Register for flickering (50% flicker, 50% steady)
			if rng.randf() < 0.5:
				flickering_lights.append({
					"node": tube_light,
					"base_energy": 2.5,
					"phase": rng.randf() * TAU,
					"speed": rng.randf_range(8.0, 20.0),
					"style": "buzz",
					"mesh": tube,
				})
			tube_count += 1

func _generate_fire_barrels() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9500
	var stride := block_size + street_width
	for _i in range(8):
		var gx := rng.randi_range(-grid_size + 1, grid_size - 1)
		var gz := rng.randi_range(-grid_size + 1, grid_size - 1)
		var bx := gx * stride + rng.randf_range(1.0, 3.0)  # near building edge
		var bz := gz * stride + rng.randf_range(1.0, 3.0)
		# Barrel (cylinder mesh)
		var barrel := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		cyl.top_radius = 0.35
		cyl.bottom_radius = 0.3
		cyl.height = 0.9
		barrel.mesh = cyl
		barrel.position = Vector3(bx, 0.45, bz)
		barrel.material_override = _make_ps1_material(Color(0.15, 0.1, 0.08))
		add_child(barrel)
		# Fire light (warm orange glow)
		var fire_light := OmniLight3D.new()
		fire_light.position = Vector3(bx, 1.2, bz)
		fire_light.light_color = Color(1.0, 0.6, 0.2)
		fire_light.light_energy = 3.5
		fire_light.omni_range = 8.0
		fire_light.shadow_enabled = false
		add_child(fire_light)
		# Flicker the fire light
		flickering_lights.append({
			"node": fire_light,
			"base_energy": 3.5,
			"phase": rng.randf() * TAU,
			"speed": rng.randf_range(5.0, 10.0),
			"style": "default",
			"mesh": null,
		})
		# Flame particles
		var flames := GPUParticles3D.new()
		flames.position = Vector3(bx, 0.9, bz)
		flames.amount = 8
		flames.lifetime = 0.8
		flames.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 3, 2))
		var fl_mat := ParticleProcessMaterial.new()
		fl_mat.direction = Vector3(0, 1, 0)
		fl_mat.spread = 15.0
		fl_mat.initial_velocity_min = 0.5
		fl_mat.initial_velocity_max = 1.2
		fl_mat.gravity = Vector3(0, 0.5, 0)
		fl_mat.damping_min = 0.3
		fl_mat.damping_max = 0.8
		fl_mat.scale_min = 0.04
		fl_mat.scale_max = 0.12
		fl_mat.color = Color(1.0, 0.5, 0.15, 0.3)
		flames.process_material = fl_mat
		var fl_mesh := BoxMesh.new()
		fl_mesh.size = Vector3(0.06, 0.1, 0.06)
		flames.draw_pass_1 = fl_mesh
		add_child(flames)

func _generate_security_spotlights() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9600
	var stride := block_size + street_width
	var count := 0
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if count >= 15:
				break
			if rng.randf() > 0.12:
				continue
			var bx := gx * stride + rng.randf_range(2.0, block_size - 2.0)
			var bz := gz * stride + rng.randf_range(-0.5, 0.5)
			var spot_y := rng.randf_range(3.5, 5.5)
			var spot := SpotLight3D.new()
			spot.position = Vector3(bx, spot_y, bz)
			spot.rotation_degrees = Vector3(-70, rng.randf_range(-30, 30), 0)
			spot.light_color = Color(1.0, 0.95, 0.85)
			spot.light_energy = rng.randf_range(3.0, 5.0)
			spot.spot_range = 12.0
			spot.spot_angle = rng.randf_range(30.0, 45.0)
			spot.shadow_enabled = false
			add_child(spot)
			count += 1

func _generate_wall_drips() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9700
	var stride := block_size + street_width
	var drip_count := 0
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if drip_count >= 8:
				break
			if rng.randf() > 0.06:
				continue
			var bx := gx * stride + rng.randf_range(1.0, block_size - 1.0)
			var bz := gz * stride + rng.randf_range(-0.5, 0.5)
			var drip_y := rng.randf_range(3.0, 8.0)
			var drip := GPUParticles3D.new()
			drip.position = Vector3(bx, drip_y, bz)
			drip.amount = 2
			drip.lifetime = 0.8
			drip.visibility_aabb = AABB(Vector3(-0.5, -4, -0.5), Vector3(1, 5, 1))
			var d_mat := ParticleProcessMaterial.new()
			d_mat.direction = Vector3(0, -1, 0)
			d_mat.spread = 5.0
			d_mat.initial_velocity_min = 0.1
			d_mat.initial_velocity_max = 0.3
			d_mat.gravity = Vector3(0, -4.0, 0)
			d_mat.scale_min = 0.02
			d_mat.scale_max = 0.04
			d_mat.color = Color(0.4, 0.45, 0.6, 0.12)
			drip.process_material = d_mat
			var d_mesh := SphereMesh.new()
			d_mesh.radius = 0.02
			d_mesh.height = 0.06
			drip.draw_pass_1 = d_mesh
			add_child(drip)
			drip_count += 1

func _generate_gutter_overflow() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9800
	var stride := block_size + street_width
	var overflow_count := 0
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if overflow_count >= 6:
				break
			if rng.randf() > 0.04:
				continue
			# Find a building edge position
			var bx := gx * stride + rng.randf_range(2.0, block_size - 2.0)
			var bz := gz * stride + rng.randf_range(-0.5, 0.5)
			var roof_y := rng.randf_range(12.0, 30.0)
			# Vertical water stream from roof to ground
			var stream := GPUParticles3D.new()
			stream.position = Vector3(bx, roof_y, bz)
			stream.amount = 8
			stream.lifetime = roof_y / 12.0  # time to fall to ground
			stream.visibility_aabb = AABB(Vector3(-1, -roof_y, -1), Vector3(2, roof_y + 2, 2))
			var s_mat := ParticleProcessMaterial.new()
			s_mat.direction = Vector3(0, -1, 0)
			s_mat.spread = 3.0
			s_mat.initial_velocity_min = 1.0
			s_mat.initial_velocity_max = 2.0
			s_mat.gravity = Vector3(0, -9.8, 0)
			s_mat.scale_min = 0.015
			s_mat.scale_max = 0.03
			s_mat.color = Color(0.5, 0.55, 0.7, 0.15)
			stream.process_material = s_mat
			var s_mesh := BoxMesh.new()
			s_mesh.size = Vector3(0.03, 0.3, 0.03)
			stream.draw_pass_1 = s_mesh
			add_child(stream)
			overflow_count += 1

func _generate_street_name_signs() -> void:
	# Japanese-style blue street name signs at intersections
	if not neon_font:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 9900
	var stride := block_size + street_width
	var sign_color := Color(0.15, 0.3, 0.7)  # blue sign background
	var text_color := Color(0.9, 0.95, 1.0)  # white text

	# Japanese street name components
	var name_parts := ["新体", "北", "中央", "東", "西", "南", "一", "二", "三",
		"本", "大", "上", "下", "桜", "松", "竹", "梅", "光", "明", "青"]
	var suffixes := ["通り", "街", "路", "坂", "丁目"]

	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.35:  # 35% of intersections get a sign
				continue
			var cell_x := gx * stride + block_size * 0.5 + street_width * 0.5
			var cell_z := gz * stride + block_size * 0.5 + street_width * 0.5
			# Sign pole at corner of intersection
			var pole_offset_x := rng.randf_range(-1.5, 1.5)
			var pole_offset_z := rng.randf_range(-1.5, 1.5)
			var sign_node := Node3D.new()
			sign_node.position = Vector3(cell_x + pole_offset_x, 0, cell_z + pole_offset_z)
			# Thin pole
			var pole := MeshInstance3D.new()
			var pole_mesh := CylinderMesh.new()
			pole_mesh.top_radius = 0.04
			pole_mesh.bottom_radius = 0.04
			pole_mesh.height = 3.5
			pole.mesh = pole_mesh
			pole.position = Vector3(0, 1.75, 0)
			pole.set_surface_override_material(0, _make_ps1_material(Color(0.25, 0.25, 0.28)))
			sign_node.add_child(pole)
			# Blue sign plate
			var plate := MeshInstance3D.new()
			var plate_mesh := BoxMesh.new()
			plate_mesh.size = Vector3(1.2, 0.35, 0.04)
			plate.mesh = plate_mesh
			plate.position = Vector3(0, 3.3, 0)
			plate.set_surface_override_material(0,
				_make_ps1_material(sign_color * 0.4, true, sign_color, 1.5))
			sign_node.add_child(plate)
			# Street name text
			var street_name: String = name_parts[rng.randi_range(0, name_parts.size() - 1)] + suffixes[rng.randi_range(0, suffixes.size() - 1)]
			var label := Label3D.new()
			label.text = street_name
			label.font = neon_font
			label.font_size = 24
			label.pixel_size = 0.006
			label.modulate = text_color
			label.outline_size = 2
			label.outline_modulate = Color(0.1, 0.15, 0.3)
			label.position = Vector3(0, 3.3, 0.025)
			label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			sign_node.add_child(label)
			# Back side text (same name, facing other direction)
			var label_back := Label3D.new()
			label_back.text = street_name
			label_back.font = neon_font
			label_back.font_size = 24
			label_back.pixel_size = 0.006
			label_back.modulate = text_color
			label_back.outline_size = 2
			label_back.outline_modulate = Color(0.1, 0.15, 0.3)
			label_back.position = Vector3(0, 3.3, -0.025)
			label_back.rotation.y = PI
			sign_node.add_child(label_back)
			add_child(sign_node)

func _generate_wall_screens() -> void:
	## Small mounted display screens on building walls — adds light and cyberpunk feel.
	var rng := RandomNumberGenerator.new()
	rng.seed = 8001
	var stride := block_size + street_width
	var screen_colors := [
		Color(0.2, 0.6, 1.0),   # blue info screen
		Color(0.1, 1.0, 0.5),   # green terminal
		Color(1.0, 0.3, 0.5),   # red warning
		Color(0.8, 0.5, 1.0),   # purple ad
		Color(1.0, 0.8, 0.2),   # yellow status
		Color(0.0, 0.9, 0.9),   # cyan data feed
	]
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.4:  # 40% of buildings get wall screens
				continue
			var bx := gx * stride + block_size * 0.5
			var bz := gz * stride + block_size * 0.5
			var num_screens := rng.randi_range(1, 3)
			for _s in range(num_screens):
				var face := rng.randi_range(0, 3)
				var screen_h := rng.randf_range(2.5, 6.0)
				var lateral := rng.randf_range(-block_size * 0.35, block_size * 0.35)
				var sx := bx
				var sz := bz
				var ry := 0.0
				var nx := 0.0
				var nz := 0.0
				match face:
					0: sz -= block_size * 0.5 - 0.06; nx = 0.0; nz = -1.0  # front
					1: sz += block_size * 0.5 - 0.06; nx = 0.0; nz = 1.0; ry = PI  # back
					2: sx -= block_size * 0.5 - 0.06; nx = -1.0; nz = 0.0; ry = PI * 0.5  # left
					3: sx += block_size * 0.5 - 0.06; nx = 1.0; nz = 0.0; ry = -PI * 0.5  # right
				sx += lateral * absf(nz) if nz != 0.0 else 0.0
				sz += lateral * absf(nx) if nx != 0.0 else 0.0
				var screen_w := rng.randf_range(0.4, 0.9)
				var screen_ht := rng.randf_range(0.3, 0.6)
				var screen_color: Color = screen_colors[rng.randi_range(0, screen_colors.size() - 1)]
				# Screen mesh (thin emissive box)
				var screen := MeshInstance3D.new()
				var sm := BoxMesh.new()
				sm.size = Vector3(screen_w, screen_ht, 0.04)
				screen.mesh = sm
				screen.position = Vector3(sx, screen_h, sz)
				screen.rotation.y = ry
				screen.set_surface_override_material(0,
					_make_ps1_material(screen_color * 0.3, true, screen_color, 2.0))
				screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(screen)
				# Frame around screen (dark border)
				var frame := MeshInstance3D.new()
				var fm := BoxMesh.new()
				fm.size = Vector3(screen_w + 0.08, screen_ht + 0.08, 0.02)
				frame.mesh = fm
				frame.position = Vector3(sx, screen_h, sz)
				frame.rotation.y = ry
				frame.set_surface_override_material(0, _make_ps1_material(Color(0.05, 0.05, 0.07)))
				frame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(frame)
				# Small omni light to illuminate surrounding wall
				var sl := OmniLight3D.new()
				sl.light_color = screen_color
				sl.light_energy = 1.5
				sl.omni_range = 4.0
				sl.omni_attenuation = 1.5
				sl.shadow_enabled = false
				sl.position = Vector3(sx + nx * 0.3, screen_h, sz + nz * 0.3)
				add_child(sl)
				# Register for animation
				wall_screen_anims.append({
					"node": screen, "light": sl,
					"phase": rng.randf() * TAU,
					"colors": screen_colors.duplicate(),
					"mat_cache": {}
				})

func _generate_overhead_intersection_lights() -> void:
	## Hanging lantern-style lights over intersections (Japanese shotengai feel).
	var rng := RandomNumberGenerator.new()
	rng.seed = 8002
	var stride := block_size + street_width
	var lantern_colors := [
		Color(1.0, 0.85, 0.5),  # warm yellow
		Color(1.0, 0.6, 0.3),   # amber
		Color(0.9, 0.9, 0.8),   # neutral white
	]
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			if rng.randf() > 0.5:  # 50% of intersections
				continue
			var ix := gx * stride + block_size + street_width * 0.5
			var iz := gz * stride + block_size + street_width * 0.5
			var lc: Color = lantern_colors[rng.randi_range(0, lantern_colors.size() - 1)]
			# Lantern housing (small cylinder)
			var housing := MeshInstance3D.new()
			var hm := CylinderMesh.new()
			hm.top_radius = 0.15
			hm.bottom_radius = 0.2
			hm.height = 0.3
			housing.mesh = hm
			housing.position = Vector3(ix, 5.5, iz)
			housing.set_surface_override_material(0,
				_make_ps1_material(Color(0.15, 0.15, 0.18)))
			housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(housing)
			# Glowing bulb underneath
			var bulb := MeshInstance3D.new()
			var bm := SphereMesh.new()
			bm.radius = 0.1
			bm.height = 0.2
			bulb.mesh = bm
			bulb.position = Vector3(ix, 5.3, iz)
			bulb.set_surface_override_material(0,
				_make_ps1_material(lc * 0.5, true, lc, 3.0))
			bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(bulb)
			# Wire to nearest building edge (thin line)
			var wire := MeshInstance3D.new()
			var wm := BoxMesh.new()
			wm.size = Vector3(street_width * 0.7, 0.015, 0.015)
			wire.mesh = wm
			wire.position = Vector3(ix, 5.6, iz)
			wire.set_surface_override_material(0, _make_ps1_material(Color(0.08, 0.08, 0.1)))
			wire.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(wire)
			# OmniLight casting warm pool below
			var ol := OmniLight3D.new()
			ol.light_color = lc
			ol.light_energy = 5.0
			ol.omni_range = 14.0
			ol.omni_attenuation = 1.3
			ol.shadow_enabled = false
			ol.position = Vector3(ix, 5.2, iz)
			add_child(ol)

func _create_walkway_segment(data: Dictionary) -> void:
	## Creates a single walkway platform segment with floor, railings, columns, underglow.
	var pos: Vector3 = data["position"]
	var level: int = data["level"]
	var seg_axis: String = data["axis"]  # "x" or "z" — direction the walkway runs along
	var seg_length: float = data.get("length", 20.0)
	var seg_width: float = 2.5
	var height: float = pos.y

	var platform_mat := _make_ps1_material(Color(0.18, 0.17, 0.2))
	var railing_mat := _make_ps1_material(Color(0.25, 0.25, 0.28))
	var column_mat := _make_ps1_material(Color(0.15, 0.15, 0.18))

	var seg_node := Node3D.new()
	seg_node.position = pos

	# Platform floor
	var floor_mi := MeshInstance3D.new()
	var floor_bm := BoxMesh.new()
	if seg_axis == "z":
		floor_bm.size = Vector3(seg_width, 0.2, seg_length)
	else:
		floor_bm.size = Vector3(seg_length, 0.2, seg_width)
	floor_mi.mesh = floor_bm
	floor_mi.set_surface_override_material(0, platform_mat)
	seg_node.add_child(floor_mi)

	# Floor collision
	var floor_sb := StaticBody3D.new()
	var floor_cs := CollisionShape3D.new()
	var floor_sh := BoxShape3D.new()
	floor_sh.size = floor_bm.size
	floor_cs.shape = floor_sh
	floor_sb.add_child(floor_cs)
	seg_node.add_child(floor_sb)

	# Railings (both sides)
	for side in [-1.0, 1.0]:
		var rail_mi := MeshInstance3D.new()
		var rail_bm := BoxMesh.new()
		if seg_axis == "z":
			rail_bm.size = Vector3(0.06, 1.1, seg_length)
			rail_mi.position = Vector3(side * seg_width * 0.5, 0.65, 0)
		else:
			rail_bm.size = Vector3(seg_length, 1.1, 0.06)
			rail_mi.position = Vector3(0, 0.65, side * seg_width * 0.5)
		rail_mi.mesh = rail_bm
		rail_mi.set_surface_override_material(0, railing_mat)
		seg_node.add_child(rail_mi)

	# Support columns (every 5m along walkway length)
	var num_cols := int(seg_length / 5.0) + 1
	for ci in range(num_cols):
		var t := (float(ci) / float(max(num_cols - 1, 1))) - 0.5
		var col_offset := t * seg_length

		var col_mi := MeshInstance3D.new()
		var col_bm := BoxMesh.new()
		col_bm.size = Vector3(0.4, height, 0.4)
		col_mi.mesh = col_bm
		if seg_axis == "z":
			col_mi.position = Vector3(0, -height * 0.5 + 0.1, col_offset)
		else:
			col_mi.position = Vector3(col_offset, -height * 0.5 + 0.1, 0)
		col_mi.set_surface_override_material(0, column_mat)
		seg_node.add_child(col_mi)

		# Column collision
		var col_sb := StaticBody3D.new()
		var col_cs := CollisionShape3D.new()
		var col_sh := BoxShape3D.new()
		col_sh.size = Vector3(0.4, height, 0.4)
		col_cs.shape = col_sh
		col_sb.add_child(col_cs)
		col_mi.add_child(col_sb)

		# Neon accent at column base
		var accent_mi := MeshInstance3D.new()
		var accent_bm := BoxMesh.new()
		accent_bm.size = Vector3(0.5, 0.1, 0.5)
		accent_mi.mesh = accent_bm
		accent_mi.position = col_mi.position + Vector3(0, -height * 0.5 + 0.05, 0)
		var accent_col := neon_colors[data.get("color_idx", 0) % neon_colors.size()]
		accent_mi.set_surface_override_material(0, _make_ps1_material(accent_col * 0.3, true, accent_col, 3.0))
		accent_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		seg_node.add_child(accent_mi)

	# Neon underglow strip
	var ug_col := neon_colors[data.get("color_idx", 0) % neon_colors.size()]
	var ug_mi := MeshInstance3D.new()
	var ug_bm := BoxMesh.new()
	if seg_axis == "z":
		ug_bm.size = Vector3(0.06, 0.06, seg_length * 0.9)
	else:
		ug_bm.size = Vector3(seg_length * 0.9, 0.06, 0.06)
	ug_mi.mesh = ug_bm
	ug_mi.position = Vector3(0, -0.15, 0)
	ug_mi.set_surface_override_material(0, _make_ps1_material(ug_col * 0.4, true, ug_col, 4.0))
	ug_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seg_node.add_child(ug_mi)

	# Neon top strips along railing tops (both sides)
	var top_col2 := neon_colors[(data.get("color_idx", 0) + 3) % neon_colors.size()]
	for side in [-1.0, 1.0]:
		var top_mi := MeshInstance3D.new()
		var top_bm := BoxMesh.new()
		if seg_axis == "z":
			top_bm.size = Vector3(0.08, 0.04, seg_length * 0.95)
			top_mi.position = Vector3(side * seg_width * 0.5, 1.22, 0)
		else:
			top_bm.size = Vector3(seg_length * 0.95, 0.04, 0.08)
			top_mi.position = Vector3(0, 1.22, side * seg_width * 0.5)
		top_mi.mesh = top_bm
		top_mi.set_surface_override_material(0, _make_ps1_material(top_col2 * 0.3, true, top_col2, 3.0))
		top_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		seg_node.add_child(top_mi)

	# Underglow OmniLight
	var ug_light := OmniLight3D.new()
	ug_light.light_color = ug_col
	ug_light.light_energy = 1.5
	ug_light.omni_range = 5.0
	ug_light.omni_attenuation = 1.5
	ug_light.shadow_enabled = false
	ug_light.position = Vector3(0, -0.3, 0)
	seg_node.add_child(ug_light)

	add_child(seg_node)

func _generate_elevated_walkways() -> void:
	## Places elevated walkway platforms along street edges.
	## Level 1 at y=8, Level 2 at y=18. Populates walkway_map for ramps/NPCs.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9100
	walkway_map.clear()
	var cs := block_size + street_width  # 28.0

	# Iterate all street segments — each block has a +X edge street and a +Z edge street
	for gx in range(-grid_size, grid_size):
		for gz in range(-grid_size, grid_size):
			# +Z running street (east side of block gx)
			# Walkway sits 2m into the 8m street, hugging the building face
			var street_z_x := float(gx) * cs + block_size * 0.5 + 2.0
			var street_z_center_z := float(gz) * cs
			var key_z := "%d,%d,z,1" % [gx, gz]
			if rng.randf() < 0.45:
				var wpos := Vector3(street_z_x, 8.0, street_z_center_z)
				var col_idx := rng.randi_range(0, neon_colors.size() - 1)
				walkway_map[key_z] = {
					"position": wpos,
					"axis": "z",
					"level": 1,
					"gx": gx, "gz": gz,
					"color_idx": col_idx,
					"length": block_size,
				}
				_create_walkway_segment(walkway_map[key_z])

			# +X running street (south side of block gz)
			var street_x_z := float(gz) * cs + block_size * 0.5 + 2.0
			var street_x_center_x := float(gx) * cs
			var key_x := "%d,%d,x,1" % [gx, gz]
			if rng.randf() < 0.45:
				var wpos := Vector3(street_x_center_x, 8.0, street_x_z)
				var col_idx := rng.randi_range(0, neon_colors.size() - 1)
				walkway_map[key_x] = {
					"position": wpos,
					"axis": "x",
					"level": 1,
					"gx": gx, "gz": gz,
					"color_idx": col_idx,
					"length": block_size,
				}
				_create_walkway_segment(walkway_map[key_x])

	# Level 2: 25% of existing Level 1 segments get a Level 2 at y=18
	var l1_keys := walkway_map.keys().duplicate()
	for key in l1_keys:
		if rng.randf() < 0.25:
			var l1: Dictionary = walkway_map[key]
			var key2: String = key.replace(",1", ",2")
			var l1_pos: Vector3 = l1["position"]
			var wpos2 := Vector3(l1_pos.x + 3.0, 18.0, l1_pos.z)
			# Offset L2 slightly so columns don't overlap
			if l1["axis"] == "z":
				wpos2.x = l1_pos.x + 3.0
			else:
				wpos2.z = l1_pos.z + 3.0
			var col_idx2 := rng.randi_range(0, neon_colors.size() - 1)
			walkway_map[key2] = {
				"position": wpos2,
				"axis": l1["axis"],
				"level": 2,
				"gx": l1["gx"], "gz": l1["gz"],
				"color_idx": col_idx2,
				"length": block_size,
			}
			_create_walkway_segment(walkway_map[key2])

	print("CityGenerator: elevated walkways placed, segments=", walkway_map.size())

func _generate_walkway_ramps() -> void:
	## Places ramps connecting walkway levels to ground (and L1→L2).
	## Ramps look like stairs (visual treads) but have smooth collision for move_and_slide.
	## Corner platforms bridge perpendicular walkway connections.
	## All geometry overlaps slightly for seamless transitions.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9101
	var stair_mat := _make_ps1_material(Color(0.22, 0.22, 0.25))
	var rail_mat := _make_ps1_material(Color(0.3, 0.3, 0.35))
	var platform_mat := _make_ps1_material(Color(0.18, 0.17, 0.2))
	var ramp_count := 0
	var corner_count := 0
	var seg_width := 2.5

	# Collect all ramp landing zones to prevent overlaps
	var ramp_zones: Array[Vector3] = []

	# Collect building footprints for collision avoidance
	var building_rects: Array[Dictionary] = []
	for child in get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
			var bs: Vector3 = ((child as MeshInstance3D).mesh as BoxMesh).size
			if bs.y > 8.0:
				building_rects.append({
					"xmin": child.position.x - bs.x * 0.5 - 0.5,
					"xmax": child.position.x + bs.x * 0.5 + 0.5,
					"zmin": child.position.z - bs.z * 0.5 - 0.5,
					"zmax": child.position.z + bs.z * 0.5 + 0.5,
				})

	for key in walkway_map:
		var seg: Dictionary = walkway_map[key]
		var seg_pos: Vector3 = seg["position"]
		var seg_axis: String = seg["axis"]
		var seg_level: int = seg["level"]
		var seg_length: float = seg.get("length", block_size)

		for end_sign in [-1.0, 1.0]:
			# Endpoint of this walkway segment
			var ep: Vector3
			if seg_axis == "z":
				ep = seg_pos + Vector3(0, 0, end_sign * seg_length * 0.5)
			else:
				ep = seg_pos + Vector3(end_sign * seg_length * 0.5, 0, 0)

			# Find the nearest perpendicular walkway at this endpoint
			var best_perp_key := ""
			var best_perp_dist := 999.0
			for other_key in walkway_map:
				if other_key == key:
					continue
				var other: Dictionary = walkway_map[other_key]
				if other["level"] != seg_level or other["axis"] == seg_axis:
					continue
				var other_pos: Vector3 = other["position"]
				var d := Vector3(ep.x, 0, ep.z).distance_to(Vector3(other_pos.x, 0, other_pos.z))
				if d < best_perp_dist and d < 18.0:
					best_perp_dist = d
					best_perp_key = other_key

			# Check if a same-axis walkway continues (adjacent cell)
			var has_continuation := false
			for other_key in walkway_map:
				if other_key == key:
					continue
				var other: Dictionary = walkway_map[other_key]
				if other["level"] != seg_level or other["axis"] != seg_axis:
					continue
				var other_pos: Vector3 = other["position"]
				if seg_axis == "z":
					if absf(other_pos.x - seg_pos.x) < 3.0 and absf(other_pos.z - ep.z) < seg_length * 0.6:
						has_continuation = true
						break
				else:
					if absf(other_pos.z - seg_pos.z) < 3.0 and absf(other_pos.x - ep.x) < seg_length * 0.6:
						has_continuation = true
						break

			if best_perp_key != "":
				# Place a corner platform connecting this endpoint to the perpendicular walkway.
				# Size it to fill the gap between the two walkway endpoints.
				var perp: Dictionary = walkway_map[best_perp_key]
				var perp_pos: Vector3 = perp["position"]

				# Corner center is at the intersection of the two walkway lines
				var corner_pos := Vector3(0, ep.y, 0)
				if seg_axis == "z":
					corner_pos.x = (ep.x + perp_pos.x) * 0.5
					corner_pos.z = ep.z
				else:
					corner_pos.x = ep.x
					corner_pos.z = (ep.z + perp_pos.z) * 0.5

				# Size to bridge the gap + overlap both walkways by 0.5m
				var gap_x := absf(ep.x - perp_pos.x)
				var gap_z := absf(ep.z - perp_pos.z)
				var corn_sx := maxf(seg_width + 0.5, gap_x + 1.0)
				var corn_sz := maxf(seg_width + 0.5, gap_z + 1.0)
				# Cap to reasonable size
				corn_sx = minf(corn_sx, 8.0)
				corn_sz = minf(corn_sz, 8.0)

				var corner := Node3D.new()
				corner.position = corner_pos

				var corn_mi := MeshInstance3D.new()
				var corn_bm := BoxMesh.new()
				corn_bm.size = Vector3(corn_sx, 0.2, corn_sz)
				corn_mi.mesh = corn_bm
				corn_mi.set_surface_override_material(0, platform_mat)
				corner.add_child(corn_mi)

				var corn_sb := StaticBody3D.new()
				var corn_cs := CollisionShape3D.new()
				var corn_sh := BoxShape3D.new()
				corn_sh.size = Vector3(corn_sx, 0.2, corn_sz)
				corn_cs.shape = corn_sh
				corn_sb.add_child(corn_cs)
				corner.add_child(corn_sb)

				# Corner neon accent
				var corn_col := neon_colors[seg.get("color_idx", 0) % neon_colors.size()]
				var corn_neon := MeshInstance3D.new()
				var corn_neon_bm := BoxMesh.new()
				corn_neon_bm.size = Vector3(corn_sx * 0.8, 0.04, corn_sz * 0.8)
				corn_neon.mesh = corn_neon_bm
				corn_neon.position = Vector3(0, -0.15, 0)
				corn_neon.set_surface_override_material(0, _make_ps1_material(corn_col * 0.3, true, corn_col, 3.0))
				corn_neon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				corner.add_child(corn_neon)

				add_child(corner)
				corner_count += 1
				continue

			if has_continuation:
				# Walkway continues to next cell — add a small bridge pad for seamless connection
				var bridge_pad := Node3D.new()
				bridge_pad.position = ep
				var pad_mi := MeshInstance3D.new()
				var pad_bm := BoxMesh.new()
				# Pad extends 4m in the walkway direction to bridge the intersection gap
				if seg_axis == "z":
					pad_bm.size = Vector3(seg_width, 0.2, 8.0)
					bridge_pad.position.z += end_sign * 4.0
				else:
					pad_bm.size = Vector3(8.0, 0.2, seg_width)
					bridge_pad.position.x += end_sign * 4.0
				pad_mi.mesh = pad_bm
				pad_mi.set_surface_override_material(0, platform_mat)
				bridge_pad.add_child(pad_mi)

				var pad_sb := StaticBody3D.new()
				var pad_cs := CollisionShape3D.new()
				var pad_sh := BoxShape3D.new()
				pad_sh.size = pad_bm.size
				pad_cs.shape = pad_sh
				pad_sb.add_child(pad_cs)
				bridge_pad.add_child(pad_sb)

				# Continuation railings
				for side in [-1.0, 1.0]:
					var r_mi := MeshInstance3D.new()
					var r_bm := BoxMesh.new()
					if seg_axis == "z":
						r_bm.size = Vector3(0.06, 1.1, 8.0)
						r_mi.position = Vector3(side * seg_width * 0.5, 0.65, 0)
					else:
						r_bm.size = Vector3(8.0, 1.1, 0.06)
						r_mi.position = Vector3(0, 0.65, side * seg_width * 0.5)
					r_mi.mesh = r_bm
					r_mi.set_surface_override_material(0, _make_ps1_material(Color(0.25, 0.25, 0.28)))
					bridge_pad.add_child(r_mi)

				add_child(bridge_pad)
				continue

			# === RAMP to ground or lower level ===
			var ramp_rise: float = 8.0 if seg_level == 1 else 10.0
			var ramp_run: float = ramp_rise * 2.0

			# Ramp starts 0.5m back INTO the walkway (overlap) for seamless join
			var ramp_start: Vector3
			if seg_axis == "z":
				ramp_start = ep + Vector3(0, 0, -end_sign * 0.5)
			else:
				ramp_start = ep + Vector3(-end_sign * 0.5, 0, 0)

			var ramp_end_pos: Vector3
			if seg_axis == "z":
				ramp_end_pos = ep + Vector3(0, -ramp_rise, end_sign * ramp_run)
			else:
				ramp_end_pos = ep + Vector3(end_sign * ramp_run, -ramp_rise, 0)
			var ramp_center := (ramp_start + ramp_end_pos) * 0.5

			# Check building collision — skip if ramp would land inside a building
			var hits_building := false
			for br in building_rects:
				if ramp_end_pos.x > br["xmin"] and ramp_end_pos.x < br["xmax"] \
				   and ramp_end_pos.z > br["zmin"] and ramp_end_pos.z < br["zmax"]:
					hits_building = true
					break
			if hits_building:
				continue

			# Check ramp overlap with existing ramps
			var too_close := false
			for existing in ramp_zones:
				if ramp_center.distance_to(existing) < 10.0:
					too_close = true
					break
			if too_close:
				continue

			var ramp_actual_len := ramp_start.distance_to(ramp_end_pos)
			var ramp_angle := atan2(ramp_rise, ramp_run + 0.5)

			var ramp_node := Node3D.new()
			ramp_node.position = ramp_center

			# Invisible ramp collision (smooth surface)
			var ramp_body := StaticBody3D.new()
			var ramp_col := CollisionShape3D.new()
			var ramp_shape := BoxShape3D.new()
			if seg_axis == "z":
				ramp_shape.size = Vector3(seg_width, 0.15, ramp_actual_len)
				ramp_body.rotation.x = end_sign * ramp_angle
			else:
				ramp_shape.size = Vector3(ramp_actual_len, 0.15, seg_width)
				ramp_body.rotation.z = -end_sign * ramp_angle
			ramp_col.shape = ramp_shape
			ramp_body.add_child(ramp_col)
			ramp_node.add_child(ramp_body)

			# Visual ramp surface
			var ramp_mi := MeshInstance3D.new()
			var ramp_bm := BoxMesh.new()
			ramp_bm.size = ramp_shape.size
			ramp_mi.mesh = ramp_bm
			ramp_mi.set_surface_override_material(0, stair_mat)
			ramp_mi.rotation = ramp_body.rotation
			ramp_node.add_child(ramp_mi)

			# Decorative stair treads (every ~0.8m)
			var num_treads := int(ramp_actual_len / 0.8)
			for ti in range(num_treads):
				var t := (float(ti) + 0.5) / float(num_treads)
				var tread_pos := ramp_start.lerp(ramp_end_pos, t) - ramp_center
				var tread_mi := MeshInstance3D.new()
				var tread_bm := BoxMesh.new()
				if seg_axis == "z":
					tread_bm.size = Vector3(seg_width, 0.03, 0.05)
				else:
					tread_bm.size = Vector3(0.05, 0.03, seg_width)
				tread_mi.mesh = tread_bm
				tread_mi.position = tread_pos + Vector3(0, 0.12, 0)
				tread_mi.set_surface_override_material(0, rail_mat)
				tread_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				ramp_node.add_child(tread_mi)

			# Side railings
			for side in [-1.0, 1.0]:
				var rail_mi := MeshInstance3D.new()
				var rail_bm := BoxMesh.new()
				if seg_axis == "z":
					rail_bm.size = Vector3(0.06, 1.0, ramp_actual_len)
					rail_mi.position = Vector3(side * seg_width * 0.5, 0.6, 0)
					rail_mi.rotation.x = end_sign * ramp_angle
				else:
					rail_bm.size = Vector3(ramp_actual_len, 1.0, 0.06)
					rail_mi.position = Vector3(0, 0.6, side * seg_width * 0.5)
					rail_mi.rotation.z = -end_sign * ramp_angle
				rail_mi.mesh = rail_bm
				rail_mi.set_surface_override_material(0, rail_mat)
				rail_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				ramp_node.add_child(rail_mi)

			# Neon edge strip along ramp underside
			var neon_col := neon_colors[seg.get("color_idx", 0) % neon_colors.size()]
			var neon_mi := MeshInstance3D.new()
			var neon_bm := BoxMesh.new()
			if seg_axis == "z":
				neon_bm.size = Vector3(seg_width * 0.8, 0.04, ramp_actual_len * 0.6)
				neon_mi.rotation.x = end_sign * ramp_angle
			else:
				neon_bm.size = Vector3(ramp_actual_len * 0.6, 0.04, seg_width * 0.8)
				neon_mi.rotation.z = -end_sign * ramp_angle
			neon_mi.mesh = neon_bm
			neon_mi.position = Vector3(0, -0.1, 0)
			neon_mi.set_surface_override_material(0, _make_ps1_material(neon_col * 0.4, true, neon_col, 3.0))
			neon_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			ramp_node.add_child(neon_mi)

			# Landing platform at bottom — larger for smooth ground transition
			var landing := MeshInstance3D.new()
			var landing_bm := BoxMesh.new()
			landing_bm.size = Vector3(3.0, 0.2, 3.0)
			landing.mesh = landing_bm
			landing.position = ramp_end_pos - ramp_center
			landing.set_surface_override_material(0, platform_mat)
			ramp_node.add_child(landing)

			var land_sb := StaticBody3D.new()
			var land_cs := CollisionShape3D.new()
			var land_sh := BoxShape3D.new()
			land_sh.size = Vector3(3.0, 0.2, 3.0)
			land_cs.shape = land_sh
			land_sb.add_child(land_cs)
			landing.add_child(land_sb)

			add_child(ramp_node)
			ramp_zones.append(ramp_center)
			ramp_count += 1

	print("CityGenerator: walkway ramps=", ramp_count, " corners=", corner_count)

func _generate_walkway_bridges() -> void:
	## For street segments with walkways on BOTH sides, 30% chance of a cross-street bridge.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9102
	var bridge_count := 0

	# Find pairs: walkways on opposite sides of the same street at the same level
	for key in walkway_map:
		var seg: Dictionary = walkway_map[key]
		var seg_axis: String = seg["axis"]
		var level: int = seg["level"]
		var gx: int = seg["gx"]
		var gz: int = seg["gz"]

		# Only check one direction to avoid duplicate bridges
		# For Z-axis walkways, check if there's one on the opposite side (gx-1 or gx+1)
		var seg_p: Vector3 = seg["position"]
		if seg_axis == "z":
			var opp_key := "%d,%d,z,%d" % [gx - 1, gz, level]
			if walkway_map.has(opp_key) and rng.randf() < 0.30:
				var opp: Dictionary = walkway_map[opp_key]
				var opp_p: Vector3 = opp["position"]
				var bridge_x: float = (seg_p.x + opp_p.x) * 0.5
				var bridge_z: float = seg_p.z
				var bridge_span: float = absf(seg_p.x - opp_p.x)
				_create_bridge(Vector3(bridge_x, seg_p.y, bridge_z), bridge_span, "x", rng)
				bridge_count += 1
		elif seg_axis == "x":
			var opp_key := "%d,%d,x,%d" % [gx, gz - 1, level]
			if walkway_map.has(opp_key) and rng.randf() < 0.30:
				var opp: Dictionary = walkway_map[opp_key]
				var opp_p: Vector3 = opp["position"]
				var bridge_z: float = (seg_p.z + opp_p.z) * 0.5
				var bridge_x: float = seg_p.x
				var bridge_span: float = absf(seg_p.z - opp_p.z)
				_create_bridge(Vector3(bridge_x, seg_p.y, bridge_z), bridge_span, "z", rng)
				bridge_count += 1

	print("CityGenerator: walkway bridges placed=", bridge_count)

func _create_bridge(pos: Vector3, span: float, span_axis: String, rng: RandomNumberGenerator) -> void:
	## Creates a cross-street bridge connecting two walkways.
	var bridge := Node3D.new()
	bridge.position = pos
	var bridge_width := 2.0

	# Floor
	var floor_mi := MeshInstance3D.new()
	var floor_bm := BoxMesh.new()
	if span_axis == "x":
		floor_bm.size = Vector3(span, 0.2, bridge_width)
	else:
		floor_bm.size = Vector3(bridge_width, 0.2, span)
	floor_mi.mesh = floor_bm
	floor_mi.set_surface_override_material(0, _make_ps1_material(Color(0.2, 0.19, 0.22)))
	bridge.add_child(floor_mi)

	var floor_sb := StaticBody3D.new()
	var floor_cs := CollisionShape3D.new()
	var floor_sh := BoxShape3D.new()
	floor_sh.size = floor_bm.size
	floor_cs.shape = floor_sh
	floor_sb.add_child(floor_cs)
	bridge.add_child(floor_sb)

	# Side railings
	for side in [-1.0, 1.0]:
		var rail_mi := MeshInstance3D.new()
		var rail_bm := BoxMesh.new()
		if span_axis == "x":
			rail_bm.size = Vector3(span, 1.1, 0.06)
			rail_mi.position = Vector3(0, 0.65, side * bridge_width * 0.5)
		else:
			rail_bm.size = Vector3(0.06, 1.1, span)
			rail_mi.position = Vector3(side * bridge_width * 0.5, 0.65, 0)
		rail_mi.mesh = rail_bm
		rail_mi.set_surface_override_material(0, _make_ps1_material(Color(0.25, 0.25, 0.28)))
		bridge.add_child(rail_mi)

		# Translucent glass panel
		var glass_mi := MeshInstance3D.new()
		var glass_qm := QuadMesh.new()
		if span_axis == "x":
			glass_qm.size = Vector2(span, 0.8)
			glass_mi.position = Vector3(0, 0.5, side * (bridge_width * 0.5 + 0.01))
			glass_mi.rotation.y = 0.0 if side > 0 else PI
		else:
			glass_qm.size = Vector2(span, 0.8)
			glass_mi.position = Vector3(side * (bridge_width * 0.5 + 0.01), 0.5, 0)
			glass_mi.rotation.y = PI * 0.5 if side > 0 else -PI * 0.5
		glass_mi.mesh = glass_qm
		var gc := Color(0.1, 0.3, 0.5)
		glass_mi.set_surface_override_material(0, _make_ps1_material(gc * 0.3, true, gc, 0.8))
		glass_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		bridge.add_child(glass_mi)

	# Underglow
	var ug_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
	var ug_mi := MeshInstance3D.new()
	var ug_bm := BoxMesh.new()
	if span_axis == "x":
		ug_bm.size = Vector3(span * 0.8, 0.06, 0.06)
	else:
		ug_bm.size = Vector3(0.06, 0.06, span * 0.8)
	ug_mi.mesh = ug_bm
	ug_mi.position = Vector3(0, -0.15, 0)
	ug_mi.set_surface_override_material(0, _make_ps1_material(ug_col * 0.4, true, ug_col, 4.0))
	ug_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bridge.add_child(ug_mi)

	var ug_light := OmniLight3D.new()
	ug_light.light_color = ug_col
	ug_light.light_energy = 1.5
	ug_light.omni_range = 5.0
	ug_light.omni_attenuation = 1.5
	ug_light.shadow_enabled = false
	ug_light.position = Vector3(0, -0.3, 0)
	bridge.add_child(ug_light)

	add_child(bridge)

func _generate_walkway_building_doors() -> void:
	## Adds doors at walkway height (y=8) on buildings adjacent to Level 1 walkways.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9103
	var door_count := 0

	for key in walkway_map:
		var seg: Dictionary = walkway_map[key]
		if seg["level"] != 1:
			continue
		if rng.randf() > 0.40:
			continue

		var seg_pos: Vector3 = seg["position"]
		var seg_axis: String = seg["axis"]

		# Find the nearest building on the building side of the walkway
		var best_building: Node3D = null
		var best_dist := 999.0
		var children_snapshot := get_children()
		for raw_child in children_snapshot:
			if not (raw_child is MeshInstance3D or raw_child is Node3D):
				continue
			var child := raw_child as Node3D
			var bsize := Vector3.ZERO
			if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
				bsize = ((child as MeshInstance3D).mesh as BoxMesh).size
			else:
				# Check first MeshInstance3D child for modular buildings
				for gc in child.get_children():
					if gc is MeshInstance3D and (gc as MeshInstance3D).mesh is BoxMesh:
						var ps: Vector3 = ((gc as MeshInstance3D).mesh as BoxMesh).size
						bsize.y = maxf(bsize.y, ps.y)
						bsize.x = maxf(bsize.x, ps.x)
						bsize.z = maxf(bsize.z, ps.z)
			if bsize.y < 12.0:  # building not tall enough
				continue
			var d := child.position.distance_to(seg_pos)
			if d < best_dist and d < 20.0:
				best_dist = d
				best_building = child

		if best_building == null:
			continue

		# Place door on the face closest to the walkway
		var door_node := Node3D.new()
		var door_y := 8.0
		if seg_axis == "z":
			door_node.position = Vector3(seg_pos.x - 1.25, door_y, seg_pos.z)
		else:
			door_node.position = Vector3(seg_pos.x, door_y, seg_pos.z - 1.25)

		# Dark recessed door frame
		var frame_mi := MeshInstance3D.new()
		var frame_bm := BoxMesh.new()
		frame_bm.size = Vector3(1.8, 3.0, 0.15)
		frame_mi.mesh = frame_bm
		frame_mi.set_surface_override_material(0, _make_ps1_material(Color(0.08, 0.07, 0.06)))
		if seg_axis == "x":
			frame_mi.rotation.y = PI * 0.5
		door_node.add_child(frame_mi)

		# Connecting platform (bridge from walkway to building face)
		var plat_mi := MeshInstance3D.new()
		var plat_bm := BoxMesh.new()
		if seg_axis == "z":
			plat_bm.size = Vector3(1.0, 0.2, 2.0)
			plat_mi.position = Vector3(-0.5, 0, 0)
		else:
			plat_bm.size = Vector3(2.0, 0.2, 1.0)
			plat_mi.position = Vector3(0, 0, -0.5)
		plat_mi.mesh = plat_bm
		plat_mi.set_surface_override_material(0, _make_ps1_material(Color(0.18, 0.17, 0.2)))
		door_node.add_child(plat_mi)

		var plat_sb := StaticBody3D.new()
		var plat_cs := CollisionShape3D.new()
		var plat_sh := BoxShape3D.new()
		plat_sh.size = plat_bm.size
		plat_cs.shape = plat_sh
		plat_sb.add_child(plat_cs)
		plat_mi.add_child(plat_sb)

		# Warm overhead light
		var door_light := OmniLight3D.new()
		door_light.light_color = Color(1.0, 0.8, 0.5)
		door_light.light_energy = 3.0
		door_light.omni_range = 5.0
		door_light.omni_attenuation = 1.5
		door_light.shadow_enabled = false
		door_light.position = Vector3(0, 1.8, 0)
		door_node.add_child(door_light)

		add_child(door_node)
		door_count += 1

	print("CityGenerator: walkway building doors placed=", door_count)

func _generate_walkway_passthroughs() -> void:
	## Detects where walkway segments pass near buildings and creates covered atrium
	## passthrough sections — ceiling, side walls, interior lights, exit signs.
	## This gives the feeling of walkways threading through buildings.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9104
	var passthrough_count := 0
	var seg_width := 2.5

	# Collect building positions and sizes for intersection testing
	var buildings: Array[Dictionary] = []
	for child in get_children():
		var bsize := Vector3.ZERO
		var bpos := Vector3.ZERO
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			if mi.mesh is BoxMesh:
				bsize = (mi.mesh as BoxMesh).size
				bpos = mi.position
		elif child is Node3D and child.get_child_count() > 2:
			# Modular building — estimate from children
			var has_mesh := false
			for gc in child.get_children():
				if gc is MeshInstance3D and (gc as MeshInstance3D).mesh is BoxMesh:
					has_mesh = true
					var piece := gc as MeshInstance3D
					var ps: Vector3 = (piece.mesh as BoxMesh).size
					var top: float = piece.position.y + ps.y * 0.5
					bsize.y = maxf(bsize.y, top)
					bsize.x = maxf(bsize.x, absf(piece.position.x) * 2.0 + ps.x)
					bsize.z = maxf(bsize.z, absf(piece.position.z) * 2.0 + ps.z)
			if has_mesh:
				bpos = child.position
		if bsize.y > 10.0 and bsize.x > 4.0:
			buildings.append({"pos": bpos, "size": bsize})

	for key in walkway_map:
		var seg: Dictionary = walkway_map[key]
		if seg["level"] != 1:
			continue  # Only L1 passthroughs for now
		var seg_pos: Vector3 = seg["position"]
		var seg_axis: String = seg["axis"]
		var seg_length: float = seg.get("length", block_size)
		var walkway_y: float = seg_pos.y

		# Check each building for intersection with this walkway segment
		for bdata in buildings:
			var bp: Vector3 = bdata["pos"]
			var bs: Vector3 = bdata["size"]
			var bh: float = bp.y + bs.y * 0.5  # building top
			var b_bottom: float = bp.y - bs.y * 0.5

			# Building must be tall enough to enclose the walkway (top > walkway + 3m)
			if bh < walkway_y + 3.0:
				continue
			# Building ground floor must be below walkway
			if b_bottom > walkway_y - 1.0:
				continue

			# Check lateral overlap
			var overlap := false
			var passthrough_center := Vector3.ZERO
			var passthrough_len := 0.0

			if seg_axis == "z":
				# Walkway runs along Z, check X proximity (3m tolerance for near-misses)
				var bx_min := bp.x - bs.x * 0.5
				var bx_max := bp.x + bs.x * 0.5
				var wx := seg_pos.x
				if wx > bx_min - 3.0 and wx < bx_max + 3.0:
					var wz_min := seg_pos.z - seg_length * 0.5
					var wz_max := seg_pos.z + seg_length * 0.5
					var bz_min := bp.z - bs.z * 0.5
					var bz_max := bp.z + bs.z * 0.5
					var oz_min := maxf(wz_min, bz_min)
					var oz_max := minf(wz_max, bz_max)
					if oz_max - oz_min > 2.0:  # At least 2m overlap
						overlap = true
						passthrough_len = oz_max - oz_min
						passthrough_center = Vector3(wx, walkway_y, (oz_min + oz_max) * 0.5)
			else:
				# Walkway runs along X, check Z proximity
				var bz_min := bp.z - bs.z * 0.5
				var bz_max := bp.z + bs.z * 0.5
				var wz := seg_pos.z
				if wz > bz_min - 3.0 and wz < bz_max + 3.0:
					var wx_min := seg_pos.x - seg_length * 0.5
					var wx_max := seg_pos.x + seg_length * 0.5
					var bx_min := bp.x - bs.x * 0.5
					var bx_max := bp.x + bs.x * 0.5
					var ox_min := maxf(wx_min, bx_min)
					var ox_max := minf(wx_max, bx_max)
					if ox_max - ox_min > 2.0:
						overlap = true
						passthrough_len = ox_max - ox_min
						passthrough_center = Vector3((ox_min + ox_max) * 0.5, walkway_y, wz)

			if not overlap:
				continue

			# Create the passthrough atrium
			var pt := Node3D.new()
			pt.position = passthrough_center

			# Ceiling
			var ceil_mi := MeshInstance3D.new()
			var ceil_bm := BoxMesh.new()
			if seg_axis == "z":
				ceil_bm.size = Vector3(seg_width + 0.4, 0.15, passthrough_len)
			else:
				ceil_bm.size = Vector3(passthrough_len, 0.15, seg_width + 0.4)
			ceil_mi.mesh = ceil_bm
			ceil_mi.position = Vector3(0, 3.0, 0)
			ceil_mi.set_surface_override_material(0, _make_ps1_material(Color(0.12, 0.11, 0.14)))
			pt.add_child(ceil_mi)

			# Ceiling collision
			var ceil_sb := StaticBody3D.new()
			var ceil_cs := CollisionShape3D.new()
			var ceil_sh := BoxShape3D.new()
			ceil_sh.size = ceil_bm.size
			ceil_sb.add_child(ceil_cs)
			ceil_cs.shape = ceil_sh
			pt.add_child(ceil_sb)
			ceil_sb.position = Vector3(0, 3.0, 0)

			# Side walls (replace railings in this section with solid walls)
			for side in [-1.0, 1.0]:
				var wall_mi := MeshInstance3D.new()
				var wall_bm := BoxMesh.new()
				if seg_axis == "z":
					wall_bm.size = Vector3(0.15, 3.0, passthrough_len)
					wall_mi.position = Vector3(side * (seg_width * 0.5 + 0.1), 1.5, 0)
				else:
					wall_bm.size = Vector3(passthrough_len, 3.0, 0.15)
					wall_mi.position = Vector3(0, 1.5, side * (seg_width * 0.5 + 0.1))
				wall_mi.mesh = wall_bm
				wall_mi.set_surface_override_material(0, _make_ps1_material(Color(0.14, 0.13, 0.16)))
				pt.add_child(wall_mi)

			# Interior fluorescent lights (warm or cool)
			var num_lights := int(passthrough_len / 4.0) + 1
			for li in range(num_lights):
				var t := (float(li) + 0.5) / float(num_lights) - 0.5
				var light_offset := t * passthrough_len
				var int_light := OmniLight3D.new()
				var is_warm := rng.randf() < 0.4
				int_light.light_color = Color(1.0, 0.85, 0.6) if is_warm else Color(0.7, 0.85, 1.0)
				int_light.light_energy = 2.5
				int_light.omni_range = 5.0
				int_light.omni_attenuation = 1.3
				int_light.shadow_enabled = false
				if seg_axis == "z":
					int_light.position = Vector3(0, 2.7, light_offset)
				else:
					int_light.position = Vector3(light_offset, 2.7, 0)
				pt.add_child(int_light)

				# Light fixture mesh (small flat box)
				var fix_mi := MeshInstance3D.new()
				var fix_bm := BoxMesh.new()
				fix_bm.size = Vector3(0.6, 0.05, 0.15) if seg_axis == "z" else Vector3(0.15, 0.05, 0.6)
				fix_mi.mesh = fix_bm
				fix_mi.position = int_light.position + Vector3(0, 0.15, 0)
				var fix_col := Color(0.9, 0.9, 0.95) if is_warm else Color(0.7, 0.85, 1.0)
				fix_mi.set_surface_override_material(0, _make_ps1_material(fix_col * 0.5, true, fix_col, 2.0))
				fix_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				pt.add_child(fix_mi)

			# Neon entrance strip at both ends of the passthrough
			var neon_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
			for end_s in [-1.0, 1.0]:
				var strip_mi := MeshInstance3D.new()
				var strip_bm := BoxMesh.new()
				if seg_axis == "z":
					strip_bm.size = Vector3(seg_width + 0.6, 0.06, 0.06)
					strip_mi.position = Vector3(0, 3.05, end_s * passthrough_len * 0.5)
				else:
					strip_bm.size = Vector3(0.06, 0.06, seg_width + 0.6)
					strip_mi.position = Vector3(end_s * passthrough_len * 0.5, 3.05, 0)
				strip_mi.mesh = strip_bm
				strip_mi.set_surface_override_material(0, _make_ps1_material(neon_col * 0.4, true, neon_col, 4.0))
				strip_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				pt.add_child(strip_mi)

			add_child(pt)
			passthrough_count += 1

	print("CityGenerator: walkway passthroughs=", passthrough_count)

func _generate_walkway_elevated_details() -> void:
	## Adds neon signs, kanji labels, small lights, and decorative elements
	## on walkway columns and undersides — making the elevated level feel alive.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9105
	var detail_count := 0

	var sign_texts: Array[String] = [
		"出口", "通路", "2F", "3F", "歩道橋", "注意",
		"↑", "→", "←", "LEVEL 2", "SKY WALK",
		"展望", "空中", "連絡", "渡り廊下",
	]

	for key in walkway_map:
		var seg: Dictionary = walkway_map[key]
		var seg_pos: Vector3 = seg["position"]
		var seg_axis: String = seg["axis"]
		var seg_length: float = seg.get("length", block_size)
		var _seg_level: int = seg["level"]
		var _col_idx: int = seg.get("color_idx", 0)

		# Hanging sign under walkway (40% chance)
		if rng.randf() < 0.40:
			var sign_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
			var sign_offset := rng.randf_range(-seg_length * 0.3, seg_length * 0.3)

			# Sign backing plate
			var sign_node := Node3D.new()
			if seg_axis == "z":
				sign_node.position = seg_pos + Vector3(0, -0.5, sign_offset)
			else:
				sign_node.position = seg_pos + Vector3(sign_offset, -0.5, 0)

			var backing_mi := MeshInstance3D.new()
			var backing_bm := BoxMesh.new()
			backing_bm.size = Vector3(1.2, 0.6, 0.05)
			backing_mi.mesh = backing_bm
			if seg_axis == "x":
				backing_mi.rotation.y = PI * 0.5
			backing_mi.set_surface_override_material(0, _make_ps1_material(sign_col * 0.2, true, sign_col, 2.0))
			backing_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sign_node.add_child(backing_mi)

			# Kanji text label if font available
			if neon_font:
				var label := Label3D.new()
				label.text = sign_texts[rng.randi_range(0, sign_texts.size() - 1)]
				label.font = neon_font
				label.font_size = 42
				label.modulate = sign_col * 1.5
				label.no_depth_test = true
				label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
				if seg_axis == "x":
					label.rotation.y = PI * 0.5
				label.position = Vector3(0, 0, 0.03) if seg_axis == "z" else Vector3(0.03, 0, 0)
				sign_node.add_child(label)

			add_child(sign_node)
			detail_count += 1

		# Column-mounted neon accent signs (30% per segment)
		if rng.randf() < 0.30:
			var accent_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
			# Pick a column position (roughly at the midpoint)
			var col_z_offset := rng.randf_range(-seg_length * 0.2, seg_length * 0.2)
			var sign_h := rng.randf_range(3.0, seg_pos.y - 1.0)

			var csign := MeshInstance3D.new()
			var csign_bm := BoxMesh.new()
			csign_bm.size = Vector3(0.8, 0.4, 0.04)
			csign.mesh = csign_bm
			if seg_axis == "z":
				csign.position = seg_pos + Vector3(0.3, -seg_pos.y + sign_h, col_z_offset)
			else:
				csign.position = seg_pos + Vector3(col_z_offset, -seg_pos.y + sign_h, 0.3)
				csign.rotation.y = PI * 0.5
			csign.set_surface_override_material(0, _make_ps1_material(accent_col * 0.3, true, accent_col, 3.0))
			csign.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(csign)
			detail_count += 1

		# Protruding neon sign from walkway edge (25% chance, like HK signs but at elevation)
		if rng.randf() < 0.25 and neon_font:
			var proto_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
			var proto_offset := rng.randf_range(-seg_length * 0.3, seg_length * 0.3)

			var proto_node := Node3D.new()
			if seg_axis == "z":
				proto_node.position = seg_pos + Vector3(1.5, 0.8, proto_offset)
			else:
				proto_node.position = seg_pos + Vector3(proto_offset, 0.8, 1.5)

			# Vertical sign plate
			var plate_mi := MeshInstance3D.new()
			var plate_bm := BoxMesh.new()
			plate_bm.size = Vector3(0.08, 1.5, 0.6)
			plate_mi.mesh = plate_bm
			if seg_axis == "x":
				plate_mi.rotation.y = PI * 0.5
			plate_mi.set_surface_override_material(0, _make_ps1_material(proto_col * 0.15, true, proto_col, 2.5))
			plate_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			proto_node.add_child(plate_mi)

			# Text
			var proto_label := Label3D.new()
			proto_label.text = sign_texts[rng.randi_range(0, sign_texts.size() - 1)]
			proto_label.font = neon_font
			proto_label.font_size = 36
			proto_label.modulate = proto_col * 1.5
			proto_label.no_depth_test = true
			if seg_axis == "z":
				proto_label.position = Vector3(0.05, 0, 0)
				proto_label.rotation.z = PI * 0.5
			else:
				proto_label.position = Vector3(0, 0, 0.05)
				proto_label.rotation.y = PI * 0.5
				proto_label.rotation.z = PI * 0.5
			proto_node.add_child(proto_label)

			# Small light
			var proto_light := OmniLight3D.new()
			proto_light.light_color = proto_col
			proto_light.light_energy = 1.5
			proto_light.omni_range = 4.0
			proto_light.omni_attenuation = 1.5
			proto_light.shadow_enabled = false
			proto_node.add_child(proto_light)

			add_child(proto_node)
			detail_count += 1

		# Underside pipe/conduit detail (20% chance)
		if rng.randf() < 0.20:
			var pipe_offset := rng.randf_range(-seg_length * 0.35, seg_length * 0.35)
			var pipe_mi := MeshInstance3D.new()
			var pipe_bm := BoxMesh.new()
			var pipe_len := rng.randf_range(3.0, 8.0)
			if seg_axis == "z":
				pipe_bm.size = Vector3(0.08, 0.08, pipe_len)
				pipe_mi.position = seg_pos + Vector3(rng.randf_range(-0.8, 0.8), -0.3, pipe_offset)
			else:
				pipe_bm.size = Vector3(pipe_len, 0.08, 0.08)
				pipe_mi.position = seg_pos + Vector3(pipe_offset, -0.3, rng.randf_range(-0.8, 0.8))
			pipe_mi.mesh = pipe_bm
			pipe_mi.set_surface_override_material(0, _make_ps1_material(Color(0.2, 0.2, 0.22)))
			pipe_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(pipe_mi)
			detail_count += 1

	print("CityGenerator: walkway elevated details=", detail_count)

func _generate_walkway_furniture() -> void:
	## Places vending machines, benches, waste bins, and payphones on walkway platforms.
	## Makes the elevated level feel lived-in like the ground level.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9106
	var furniture_count := 0

	var vending_colors: Array[Color] = [
		Color(1.0, 0.05, 0.4), Color(0.0, 0.9, 1.0),
		Color(1.0, 0.4, 0.0), Color(0.0, 1.0, 0.5),
	]

	for key in walkway_map:
		var seg: Dictionary = walkway_map[key]
		var seg_pos: Vector3 = seg["position"]
		var seg_axis: String = seg["axis"]
		var seg_length: float = seg.get("length", block_size)

		# Vending machine (30% chance per segment)
		if rng.randf() < 0.30:
			var vc := vending_colors[rng.randi_range(0, vending_colors.size() - 1)]
			var offset := rng.randf_range(-seg_length * 0.3, seg_length * 0.3)
			var vm := Node3D.new()
			if seg_axis == "z":
				vm.position = seg_pos + Vector3(0.8, 0, offset)
			else:
				vm.position = seg_pos + Vector3(offset, 0, 0.8)

			# Body
			var body := MeshInstance3D.new()
			var body_bm := BoxMesh.new()
			body_bm.size = Vector3(0.6, 1.6, 0.5)
			body.mesh = body_bm
			body.position = Vector3(0, 0.9, 0)
			body.set_surface_override_material(0, _make_ps1_material(Color(0.15, 0.15, 0.18)))
			vm.add_child(body)

			# Glowing panel
			var panel := MeshInstance3D.new()
			var panel_qm := QuadMesh.new()
			panel_qm.size = Vector2(0.5, 1.0)
			panel.mesh = panel_qm
			panel.position = Vector3(0, 1.0, 0.26)
			if seg_axis == "x":
				panel.rotation.y = PI * 0.5
				panel.position = Vector3(0.26, 1.0, 0)
			panel.set_surface_override_material(0, _make_ps1_material(vc * 0.3, true, vc, 3.0))
			panel.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			vm.add_child(panel)

			# Small light
			var vl := OmniLight3D.new()
			vl.light_color = vc
			vl.light_energy = 1.0
			vl.omni_range = 3.0
			vl.omni_attenuation = 1.5
			vl.shadow_enabled = false
			vl.position = Vector3(0, 1.2, 0.4) if seg_axis == "z" else Vector3(0.4, 1.2, 0)
			vm.add_child(vl)

			add_child(vm)
			furniture_count += 1

		# Bench (25% chance)
		if rng.randf() < 0.25:
			var offset := rng.randf_range(-seg_length * 0.25, seg_length * 0.25)
			var bench := Node3D.new()
			if seg_axis == "z":
				bench.position = seg_pos + Vector3(-0.7, 0, offset)
			else:
				bench.position = seg_pos + Vector3(offset, 0, -0.7)

			# Seat
			var seat := MeshInstance3D.new()
			var seat_bm := BoxMesh.new()
			seat_bm.size = Vector3(1.2, 0.08, 0.4) if seg_axis == "z" else Vector3(0.4, 0.08, 1.2)
			seat.mesh = seat_bm
			seat.position = Vector3(0, 0.45, 0)
			seat.set_surface_override_material(0, _make_ps1_material(Color(0.2, 0.15, 0.1)))
			bench.add_child(seat)

			# Legs
			for leg_s in [-0.4, 0.4]:
				var leg := MeshInstance3D.new()
				var leg_bm := BoxMesh.new()
				leg_bm.size = Vector3(0.06, 0.45, 0.06)
				leg.mesh = leg_bm
				if seg_axis == "z":
					leg.position = Vector3(leg_s, 0.225, 0)
				else:
					leg.position = Vector3(0, 0.225, leg_s)
				leg.set_surface_override_material(0, _make_ps1_material(Color(0.2, 0.2, 0.22)))
				bench.add_child(leg)

			# Backrest
			var back := MeshInstance3D.new()
			var back_bm := BoxMesh.new()
			back_bm.size = Vector3(1.2, 0.5, 0.06) if seg_axis == "z" else Vector3(0.06, 0.5, 1.2)
			back.mesh = back_bm
			if seg_axis == "z":
				back.position = Vector3(0, 0.7, -0.17)
			else:
				back.position = Vector3(-0.17, 0.7, 0)
			back.set_surface_override_material(0, _make_ps1_material(Color(0.2, 0.15, 0.1)))
			bench.add_child(back)

			add_child(bench)
			furniture_count += 1

		# Waste bin (20% chance)
		if rng.randf() < 0.20:
			var offset := rng.randf_range(-seg_length * 0.35, seg_length * 0.35)
			var bin_mi := MeshInstance3D.new()
			var bin_bm := BoxMesh.new()
			bin_bm.size = Vector3(0.35, 0.7, 0.35)
			bin_mi.mesh = bin_bm
			if seg_axis == "z":
				bin_mi.position = seg_pos + Vector3(0.9, 0.35, offset)
			else:
				bin_mi.position = seg_pos + Vector3(offset, 0.35, 0.9)
			bin_mi.set_surface_override_material(0, _make_ps1_material(Color(0.12, 0.12, 0.14)))
			add_child(bin_mi)
			furniture_count += 1

		# Payphone (15% chance)
		if rng.randf() < 0.15:
			var offset := rng.randf_range(-seg_length * 0.3, seg_length * 0.3)
			var phone := Node3D.new()
			if seg_axis == "z":
				phone.position = seg_pos + Vector3(0.9, 0, offset)
			else:
				phone.position = seg_pos + Vector3(offset, 0, 0.9)

			# Post
			var post := MeshInstance3D.new()
			var post_bm := BoxMesh.new()
			post_bm.size = Vector3(0.12, 1.5, 0.12)
			post.mesh = post_bm
			post.position = Vector3(0, 0.75, 0)
			post.set_surface_override_material(0, _make_ps1_material(Color(0.2, 0.2, 0.22)))
			phone.add_child(post)

			# Phone box
			var box := MeshInstance3D.new()
			var box_bm := BoxMesh.new()
			box_bm.size = Vector3(0.3, 0.4, 0.2)
			box.mesh = box_bm
			box.position = Vector3(0, 1.3, 0)
			var phone_col := neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
			box.set_surface_override_material(0, _make_ps1_material(phone_col * 0.2, true, phone_col, 1.5))
			phone.add_child(box)

			add_child(phone)
			furniture_count += 1

		# Overhead walkway light (40% — fluorescent tube)
		if rng.randf() < 0.40:
			var offset := rng.randf_range(-seg_length * 0.3, seg_length * 0.3)
			var light_pos: Vector3
			if seg_axis == "z":
				light_pos = seg_pos + Vector3(0, 2.8, offset)
			else:
				light_pos = seg_pos + Vector3(offset, 2.8, 0)

			# Fixture
			var fix := MeshInstance3D.new()
			var fix_bm := BoxMesh.new()
			if seg_axis == "z":
				fix_bm.size = Vector3(1.5, 0.06, 0.12)
			else:
				fix_bm.size = Vector3(0.12, 0.06, 1.5)
			fix.mesh = fix_bm
			fix.position = light_pos
			var is_warm := rng.randf() < 0.3
			var light_col := Color(1.0, 0.85, 0.6) if is_warm else Color(0.7, 0.85, 1.0)
			fix.set_surface_override_material(0, _make_ps1_material(light_col * 0.5, true, light_col, 2.0))
			fix.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(fix)

			var ol := OmniLight3D.new()
			ol.light_color = light_col
			ol.light_energy = 2.0
			ol.omni_range = 5.0
			ol.omni_attenuation = 1.3
			ol.shadow_enabled = false
			ol.position = light_pos - Vector3(0, 0.1, 0)
			add_child(ol)
			furniture_count += 1

	print("CityGenerator: walkway furniture=", furniture_count)

func _generate_walkway_window_glow() -> void:
	## Adds glowing windows and interior glimpses on buildings at walkway height.
	## Creates the feeling of walking past lit apartments on elevated walkways.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9107
	var glow_count := 0

	var neon_colors_local: Array[Color] = [
		Color(1.0, 0.1, 0.4), Color(0.1, 0.9, 1.0), Color(0.8, 0.2, 1.0),
		Color(1.0, 0.5, 0.0), Color(0.0, 1.0, 0.5), Color(1.0, 0.9, 0.1),
	]

	# Collect buildings with their positions and sizes
	var buildings: Array[Dictionary] = []
	for child in get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).mesh is BoxMesh:
			var mi := child as MeshInstance3D
			var bsize: Vector3 = (mi.mesh as BoxMesh).size
			if bsize.y >= 10.0:
				buildings.append({"node": mi, "pos": mi.position, "size": bsize})

	for key in walkway_map:
		var seg: Dictionary = walkway_map[key]
		var seg_pos: Vector3 = seg["position"]
		var seg_axis: String = seg["axis"]
		var seg_level: int = seg["level"]
		var seg_length: float = seg.get("length", block_size)
		var walkway_y: float = seg_pos.y  # 8.0 or 18.0

		# Find buildings close to this walkway segment (building side)
		for bdata in buildings:
			var bpos: Vector3 = bdata["pos"]
			var bsize: Vector3 = bdata["size"]
			var building_top: float = bpos.y + bsize.y * 0.5

			# Building must be tall enough to have windows at walkway height
			if building_top < walkway_y + 1.0:
				continue

			# Check proximity — building must be near the walkway and on the building side
			var dist: float
			var face_dir: float  # which face of the building faces the walkway
			var along_axis_match := false

			if seg_axis == "z":
				dist = absf(bpos.x - seg_pos.x)
				# Building center should be on the building side (negative X from walkway)
				if bpos.x > seg_pos.x:
					continue  # building is on street side, not building side
				face_dir = 1.0  # building's +X face faces the walkway
				# Check if building overlaps along Z with walkway segment
				if absf(bpos.z - seg_pos.z) < (bsize.z * 0.5 + seg_length * 0.5):
					along_axis_match = true
			else:
				dist = absf(bpos.z - seg_pos.z)
				if bpos.z > seg_pos.z:
					continue
				face_dir = 1.0
				if absf(bpos.x - seg_pos.x) < (bsize.x * 0.5 + seg_length * 0.5):
					along_axis_match = true

			if not along_axis_match or dist > 15.0 or dist < 1.0:
				continue

			# Place a row of glowing windows at walkway height on the building face
			var window_y_base: float = walkway_y - bpos.y  # local Y in building coords
			var num_windows := rng.randi_range(2, 5)
			var face_width: float = bsize.z if seg_axis == "z" else bsize.x

			for wi in range(num_windows):
				if rng.randf() > 0.65:  # 65% of slots get a window
					continue

				var wc := _pick_window_color(rng)
				var lateral := rng.randf_range(-face_width * 0.35, face_width * 0.35)
				var wy := window_y_base + rng.randf_range(-0.5, 1.5)

				# Window quad on building face
				var win := MeshInstance3D.new()
				var quad := QuadMesh.new()
				quad.size = Vector2(1.3, 1.6)
				win.mesh = quad
				win.set_surface_override_material(0,
					_make_ps1_material(wc * 0.3, true, wc, rng.randf_range(3.0, 6.0)))
				win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

				if seg_axis == "z":
					win.position = Vector3(bsize.x * 0.51 * face_dir, wy, lateral)
				else:
					win.position = Vector3(lateral, wy, bsize.z * 0.51 * face_dir)
					win.rotation.y = PI * 0.5

				(bdata["node"] as Node3D).add_child(win)
				glow_count += 1

				# 30% get horizontal blinds
				if rng.randf() < 0.30:
					for blind_row in range(4):
						var blind := MeshInstance3D.new()
						var blind_mesh := QuadMesh.new()
						blind_mesh.size = Vector2(1.2, 0.07)
						blind.mesh = blind_mesh
						var blind_y := wy - 0.5 + blind_row * 0.35
						if seg_axis == "z":
							blind.position = Vector3(bsize.x * 0.51 * face_dir + 0.005, blind_y, lateral)
						else:
							blind.position = Vector3(lateral, blind_y, bsize.z * 0.51 * face_dir + 0.005)
							blind.rotation.y = PI * 0.5
						blind.set_surface_override_material(0,
							_make_ps1_material(Color(0.05, 0.04, 0.03)))
						blind.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
						(bdata["node"] as Node3D).add_child(blind)

				# 20% get a person silhouette
				elif rng.randf() < 0.20:
					var sil := MeshInstance3D.new()
					var sil_mesh := QuadMesh.new()
					sil_mesh.size = Vector2(0.4, 0.9)
					sil.mesh = sil_mesh
					var sil_lat := lateral + rng.randf_range(-0.15, 0.15)
					if seg_axis == "z":
						sil.position = Vector3(bsize.x * 0.51 * face_dir + 0.01, wy + 0.1, sil_lat)
					else:
						sil.position = Vector3(sil_lat, wy + 0.1, bsize.z * 0.51 * face_dir + 0.01)
						sil.rotation.y = PI * 0.5
					sil.set_surface_override_material(0,
						_make_ps1_material(Color(0.02, 0.02, 0.03)))
					sil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					(bdata["node"] as Node3D).add_child(sil)

				# 15% get a warm light spill (OmniLight casting onto walkway)
				if rng.randf() < 0.15:
					var spill := OmniLight3D.new()
					spill.light_color = wc
					spill.light_energy = 0.8
					spill.omni_range = 4.0
					spill.omni_attenuation = 1.5
					spill.shadow_enabled = false
					if seg_axis == "z":
						spill.position = Vector3(bsize.x * 0.5 * face_dir + 0.5, wy, lateral)
					else:
						spill.position = Vector3(lateral, wy, bsize.z * 0.5 * face_dir + 0.5)
					(bdata["node"] as Node3D).add_child(spill)

				# 10% get a neon window frame (colored border around window)
				if rng.randf() < 0.10:
					var neon_col: Color = neon_colors_local[rng.randi_range(0, neon_colors_local.size() - 1)]
					# Top bar
					var top_bar := MeshInstance3D.new()
					var top_bm := BoxMesh.new()
					top_bm.size = Vector3(1.4, 0.06, 0.06)
					top_bar.mesh = top_bm
					top_bar.set_surface_override_material(0,
						_make_ps1_material(neon_col * 0.4, true, neon_col, 4.0))
					top_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					if seg_axis == "z":
						top_bar.position = Vector3(bsize.x * 0.51 * face_dir + 0.02, wy + 0.8, lateral)
					else:
						top_bar.position = Vector3(lateral, wy + 0.8, bsize.z * 0.51 * face_dir + 0.02)
						top_bar.rotation.y = PI * 0.5
					(bdata["node"] as Node3D).add_child(top_bar)
					# Bottom bar
					var bot_bar := MeshInstance3D.new()
					var bot_bm := BoxMesh.new()
					bot_bm.size = Vector3(1.4, 0.06, 0.06)
					bot_bar.mesh = bot_bm
					bot_bar.set_surface_override_material(0,
						_make_ps1_material(neon_col * 0.4, true, neon_col, 4.0))
					bot_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
					if seg_axis == "z":
						bot_bar.position = Vector3(bsize.x * 0.51 * face_dir + 0.02, wy - 0.8, lateral)
					else:
						bot_bar.position = Vector3(lateral, wy - 0.8, bsize.z * 0.51 * face_dir + 0.02)
						bot_bar.rotation.y = PI * 0.5
					(bdata["node"] as Node3D).add_child(bot_bar)

	print("CityGenerator: walkway window glow=", glow_count)

func _generate_walkway_underside_lights() -> void:
	## Adds flickering fluorescent tube lights on the underside of walkway platforms.
	## Some working, some flickering, some dead — classic dystopian corridor lighting.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9108
	var light_count := 0

	for key in walkway_map:
		var seg: Dictionary = walkway_map[key]
		var seg_pos: Vector3 = seg["position"]
		var seg_axis: String = seg["axis"]
		var seg_length: float = seg.get("length", block_size)

		# Place 3-5 tube lights per walkway segment on the underside
		var num_tubes := rng.randi_range(3, 5)
		for ti in range(num_tubes):
			var roll := rng.randf()
			if roll > 0.75:  # 25% of slots are empty (dead/missing)
				continue

			var tube_offset := -seg_length * 0.4 + ti * (seg_length * 0.8 / float(num_tubes))
			var tube_pos := Vector3.ZERO
			var tube_rot := 0.0

			if seg_axis == "z":
				tube_pos = Vector3(seg_pos.x, seg_pos.y - 0.3, seg_pos.z + tube_offset)
				tube_rot = 0.0  # tube runs along X (perpendicular to walkway)
			else:
				tube_pos = Vector3(seg_pos.x + tube_offset, seg_pos.y - 0.3, seg_pos.z)
				tube_rot = PI * 0.5  # tube runs along Z

			# Tube mesh (long thin glowing box)
			var tube := MeshInstance3D.new()
			var tube_mesh := BoxMesh.new()
			tube_mesh.size = Vector3(2.0, 0.05, 0.05)
			tube.mesh = tube_mesh
			tube.position = tube_pos
			tube.rotation.y = tube_rot

			# Color: mostly cool white, some warm
			var is_warm := rng.randf() < 0.25
			var tube_col := Color(1.0, 0.95, 0.85) if is_warm else Color(0.85, 0.92, 1.0)

			# Status: 60% working, 30% flickering, 10% dead (dim)
			var status_roll := rng.randf()
			var is_dead := status_roll > 0.9
			var is_flickering := status_roll > 0.6 and not is_dead

			if is_dead:
				# Dead tube — very dim, no light
				tube.set_surface_override_material(0,
					_make_ps1_material(tube_col * 0.05, true, tube_col * 0.1, 0.3))
				add_child(tube)
				light_count += 1
				continue

			# Working or flickering tube
			var energy := 2.0 if not is_flickering else rng.randf_range(1.5, 2.5)
			tube.set_surface_override_material(0,
				_make_ps1_material(tube_col * 0.4, true, tube_col, 2.5))
			add_child(tube)

			# OmniLight beneath tube
			var tube_light := OmniLight3D.new()
			tube_light.position = tube_pos - Vector3(0, 0.15, 0)
			tube_light.light_color = tube_col
			tube_light.light_energy = energy
			tube_light.omni_range = 5.0
			tube_light.omni_attenuation = 1.4
			tube_light.shadow_enabled = false
			add_child(tube_light)

			# Flickering tubes get registered for buzz animation
			if is_flickering:
				flickering_lights.append({
					"node": tube_light,
					"base_energy": energy,
					"phase": rng.randf() * TAU,
					"speed": rng.randf_range(10.0, 25.0),
					"style": "buzz",
					"mesh": tube,
				})

			# Mounting bracket (small dark box connecting tube to walkway underside)
			var bracket := MeshInstance3D.new()
			var bracket_mesh := BoxMesh.new()
			bracket_mesh.size = Vector3(0.15, 0.25, 0.08)
			bracket.mesh = bracket_mesh
			bracket.position = tube_pos + Vector3(0, 0.12, 0)
			bracket.set_surface_override_material(0,
				_make_ps1_material(Color(0.12, 0.12, 0.14)))
			bracket.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(bracket)

			light_count += 1

	print("CityGenerator: walkway underside lights=", light_count)

func _generate_walkway_drip_puddles() -> void:
	## Places puddles at the base of walkway support columns where rain drips down.
	## Each puddle reflects the neon color from the walkway above, creating
	## glowing pools at ground level under the elevated platforms.
	if not puddle_shader:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 9109
	var puddle_count := 0

	for key in walkway_map:
		var seg: Dictionary = walkway_map[key]
		var seg_pos: Vector3 = seg["position"]
		var seg_axis: String = seg["axis"]
		var seg_length: float = seg.get("length", block_size)
		var col_idx: int = seg.get("color_idx", 0)
		var neon_col: Color = neon_colors[col_idx % neon_colors.size()]

		# Place puddles at column base positions (every 5m along the walkway)
		var num_columns := int(seg_length / 5.0)
		for ci in range(num_columns):
			if rng.randf() > 0.55:  # 55% of column bases get a puddle
				continue

			var col_offset := -seg_length * 0.5 + (ci + 0.5) * (seg_length / float(num_columns))
			var puddle_pos := Vector3.ZERO
			if seg_axis == "z":
				puddle_pos = Vector3(seg_pos.x, 0.02, seg_pos.z + col_offset)
			else:
				puddle_pos = Vector3(seg_pos.x + col_offset, 0.02, seg_pos.z)

			# Puddle (larger than regular puddles — water pools here)
			var puddle_w := rng.randf_range(2.0, 4.5)
			var puddle_d := rng.randf_range(1.5, 3.5)
			# Slight random offset so they don't look perfectly centered
			puddle_pos.x += rng.randf_range(-0.5, 0.5)
			puddle_pos.z += rng.randf_range(-0.5, 0.5)

			var puddle := MeshInstance3D.new()
			var quad := QuadMesh.new()
			quad.size = Vector2(puddle_w, puddle_d)
			puddle.mesh = quad
			puddle.position = puddle_pos
			puddle.rotation.x = -PI * 0.5
			var puddle_mat := ShaderMaterial.new()
			puddle_mat.shader = puddle_shader
			puddle_mat.set_shader_parameter("puddle_tint", neon_col * 0.06)
			puddle_mat.set_shader_parameter("neon_tint", neon_col)
			puddle_mat.set_shader_parameter("neon_strength", rng.randf_range(0.6, 1.4))
			puddle_mat.set_shader_parameter("reflection_strength", rng.randf_range(0.3, 0.5))
			puddle_mat.set_shader_parameter("ripple_speed", rng.randf_range(2.0, 3.5))
			puddle_mat.set_shader_parameter("ripple_scale", rng.randf_range(8.0, 14.0))
			puddle.set_surface_override_material(0, puddle_mat)
			add_child(puddle)

			# Neon glow light from puddle (matching walkway underglow color)
			if rng.randf() < 0.45:
				var glow := OmniLight3D.new()
				glow.light_color = neon_col
				glow.light_energy = rng.randf_range(0.4, 0.9)
				glow.omni_range = maxf(puddle_w, puddle_d) * 1.0
				glow.omni_attenuation = 2.0
				glow.shadow_enabled = false
				glow.position = Vector3(puddle_pos.x, 0.1, puddle_pos.z)
				add_child(glow)

			puddle_count += 1

	# Also add wet sheen strips along walkway edges (rain drip line)
	var sheen_count := 0
	for key in walkway_map:
		var seg: Dictionary = walkway_map[key]
		if seg["level"] != 1:
			continue  # only ground-adjacent walkways create drip lines
		if rng.randf() > 0.40:
			continue

		var seg_pos: Vector3 = seg["position"]
		var seg_axis: String = seg["axis"]
		var seg_length: float = seg.get("length", block_size)

		# Wet sheen strip under the walkway edge (where rain drips off)
		var sheen := MeshInstance3D.new()
		var sheen_quad := QuadMesh.new()
		if seg_axis == "z":
			sheen_quad.size = Vector2(0.8, seg_length * 0.8)
		else:
			sheen_quad.size = Vector2(seg_length * 0.8, 0.8)
		sheen.mesh = sheen_quad
		sheen.position = Vector3(seg_pos.x, 0.015, seg_pos.z)
		sheen.rotation.x = -PI * 0.5
		# Subtle dark reflective strip
		var sheen_mat := ShaderMaterial.new()
		sheen_mat.shader = puddle_shader
		sheen_mat.set_shader_parameter("puddle_tint", Color(0.02, 0.02, 0.03))
		sheen_mat.set_shader_parameter("neon_tint", Color(0.3, 0.35, 0.4))
		sheen_mat.set_shader_parameter("neon_strength", 0.3)
		sheen_mat.set_shader_parameter("reflection_strength", 0.2)
		sheen_mat.set_shader_parameter("ripple_speed", 2.5)
		sheen_mat.set_shader_parameter("ripple_scale", 15.0)
		sheen.set_surface_override_material(0, sheen_mat)
		add_child(sheen)
		sheen_count += 1

	print("CityGenerator: walkway drip puddles=", puddle_count, " wet sheens=", sheen_count)

func _generate_walkway_rain_drips() -> void:
	## Adds water drip particle effects along walkway edges where rain runs off.
	## Creates visible water droplets falling from elevated platforms to the ground.
	var rng := RandomNumberGenerator.new()
	rng.seed = 9110
	var drip_count := 0

	# Pre-create a shared particle mesh (tiny elongated drop)
	var drop_mesh := BoxMesh.new()
	drop_mesh.size = Vector3(0.02, 0.12, 0.02)

	for key in walkway_map:
		var seg: Dictionary = walkway_map[key]
		if seg["level"] != 1:
			continue  # only Level 1 drips to ground visibly
		if rng.randf() > 0.50:
			continue  # 50% of segments get drip effects

		var seg_pos: Vector3 = seg["position"]
		var seg_axis: String = seg["axis"]
		var seg_length: float = seg.get("length", block_size)

		# Place 2-3 drip emitters along the street-side edge of the walkway
		var num_drips := rng.randi_range(2, 3)
		for di in range(num_drips):
			var drip_offset := rng.randf_range(-seg_length * 0.4, seg_length * 0.4)
			var drip_pos := Vector3.ZERO

			if seg_axis == "z":
				# Street-side edge is +X from walkway center (1.25m from center of 2.5m platform)
				drip_pos = Vector3(seg_pos.x + 1.2, seg_pos.y - 0.1, seg_pos.z + drip_offset)
			else:
				drip_pos = Vector3(seg_pos.x + drip_offset, seg_pos.y - 0.1, seg_pos.z + 1.2)

			var drip := GPUParticles3D.new()
			drip.position = drip_pos
			drip.amount = 4
			drip.lifetime = 1.2
			drip.visibility_aabb = AABB(Vector3(-1, -9, -1), Vector3(2, 10, 2))

			var mat := ParticleProcessMaterial.new()
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(0.3, 0.0, 0.3)
			mat.direction = Vector3(0, -1, 0)
			mat.spread = 5.0
			mat.initial_velocity_min = 0.5
			mat.initial_velocity_max = 1.5
			mat.gravity = Vector3(0, -9.8, 0)
			mat.scale_min = 0.8
			mat.scale_max = 1.2
			mat.color = Color(0.5, 0.55, 0.65, 0.25)
			drip.process_material = mat
			drip.draw_pass_1 = drop_mesh

			add_child(drip)
			drip_count += 1

	print("CityGenerator: walkway rain drips=", drip_count)

func _generate_hk_neon_signs() -> void:
	## HK-style protruding neon signs distributed across city buildings.
	## Each sign protrudes perpendicular from the building face like a flag,
	## with border frame, colored backing, glowing kanji/English text, and light.
	if not neon_font:
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = 9500

	var _wk_min_height := 4.5  # minimum 1.5 stories above ground

	for child in get_children():
		if not child is MeshInstance3D:
			continue
		var mi := child as MeshInstance3D
		if not mi.mesh is BoxMesh:
			continue
		var bsize: Vector3 = (mi.mesh as BoxMesh).size
		if bsize.y < 8.0:  # skip short buildings
			continue
		if rng.randf() > 0.5:  # 50% of buildings get signs
			continue

		var gy := -bsize.y * 0.5  # ground in local coords
		var num_signs := rng.randi_range(1, 3)

		for _si in range(num_signs):
			var s_text: String = HK_SIGN_TEXTS[rng.randi_range(0, HK_SIGN_TEXTS.size() - 1)]
			var s_col: Color = neon_colors[rng.randi_range(0, neon_colors.size() - 1)]
			var face := rng.randi_range(0, 3)  # 0=front, 1=back, 2=right, 3=left

			# Height: between 1.5 stories and 80% of building height
			var max_h := bsize.y * 0.8
			var sign_y := gy + rng.randf_range(min_height, max(min_height + 1.0, max_h))

			# Lateral offset along the face
			var face_width: float = bsize.x if face < 2 else bsize.z
			var lateral := rng.randf_range(-face_width * 0.35, face_width * 0.35)

			# Sign dimensions — capped at 3.5m to avoid protruding into the street
			var char_count := s_text.length()
			var is_english := s_text[0].unicode_at(0) < 128
			var char_w := 0.55 if is_english else 1.1
			var sign_w: float = min(char_count * char_w + 0.5, 3.5)
			var sign_h := 1.6

			# Anchor on building wall
			var anchor := Node3D.new()
			match face:
				0:  # front (+Z)
					anchor.position = Vector3(lateral, sign_y, bsize.z * 0.5)
					anchor.rotation.y = 0.0
				1:  # back (-Z)
					anchor.position = Vector3(lateral, sign_y, -bsize.z * 0.5)
					anchor.rotation.y = PI
				2:  # right (+X)
					anchor.position = Vector3(bsize.x * 0.5, sign_y, lateral)
					anchor.rotation.y = -PI * 0.5
				3:  # left (-X)
					anchor.position = Vector3(-bsize.x * 0.5, sign_y, lateral)
					anchor.rotation.y = PI * 0.5

			# Sign protrudes perpendicular from wall
			var sign_root := Node3D.new()
			sign_root.rotation.y = PI * 0.5
			sign_root.position = Vector3(0, 0, sign_w * 0.5 + 0.2)
			anchor.add_child(sign_root)

			# Border frame (dark)
			var border := MeshInstance3D.new()
			var border_mesh := BoxMesh.new()
			border_mesh.size = Vector3(sign_w + 0.25, sign_h + 0.25, 0.14)
			border.mesh = border_mesh
			border.set_surface_override_material(0, _make_ps1_material(Color(0.06, 0.06, 0.08)))
			border.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sign_root.add_child(border)

			# Backing panel (dim sign color)
			var backing := MeshInstance3D.new()
			var backing_mesh := BoxMesh.new()
			backing_mesh.size = Vector3(sign_w, sign_h, 0.15)
			backing.mesh = backing_mesh
			backing.set_surface_override_material(0,
				_make_ps1_material(s_col * 0.1, true, s_col * 0.25, 1.0))
			backing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			sign_root.add_child(backing)

			# Bloom/glow layer — large soft outline behind the main text
			var glow := Label3D.new()
			glow.text = s_text
			glow.font = neon_font
			glow.font_size = 96
			glow.pixel_size = 0.01
			glow.modulate = Color(s_col.r, s_col.g, s_col.b, 0.4)
			glow.outline_modulate = Color(s_col.r, s_col.g, s_col.b, 0.25)
			glow.outline_size = 32  # very large = soft glow halo
			glow.position = Vector3(0, 0, 0.07)
			glow.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			glow.render_priority = 0
			sign_root.add_child(glow)

			# Main text — bright, sharp
			var label := Label3D.new()
			label.text = s_text
			label.font = neon_font
			label.font_size = 96
			label.pixel_size = 0.01
			label.modulate = Color(min(s_col.r + 0.3, 1.0), min(s_col.g + 0.3, 1.0), min(s_col.b + 0.3, 1.0))
			label.outline_modulate = s_col
			label.outline_size = 12
			label.position = Vector3(0, 0, 0.09)
			label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			label.render_priority = 1
			sign_root.add_child(label)

			# Back side text
			var glow_b := Label3D.new()
			glow_b.text = s_text
			glow_b.font = neon_font
			glow_b.font_size = 96
			glow_b.pixel_size = 0.01
			glow_b.modulate = Color(s_col.r, s_col.g, s_col.b, 0.4)
			glow_b.outline_modulate = Color(s_col.r, s_col.g, s_col.b, 0.25)
			glow_b.outline_size = 32
			glow_b.position = Vector3(0, 0, -0.07)
			glow_b.rotation.y = PI
			glow_b.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			sign_root.add_child(glow_b)

			var label_b := Label3D.new()
			label_b.text = s_text
			label_b.font = neon_font
			label_b.font_size = 96
			label_b.pixel_size = 0.01
			label_b.modulate = Color(min(s_col.r + 0.3, 1.0), min(s_col.g + 0.3, 1.0), min(s_col.b + 0.3, 1.0))
			label_b.outline_modulate = s_col
			label_b.outline_size = 12
			label_b.position = Vector3(0, 0, -0.09)
			label_b.rotation.y = PI
			label_b.billboard = BaseMaterial3D.BILLBOARD_DISABLED
			sign_root.add_child(label_b)

			# OmniLight
			var light := OmniLight3D.new()
			light.light_color = s_col
			light.light_energy = 5.0
			light.omni_range = 12.0
			light.omni_attenuation = 1.5
			light.shadow_enabled = false
			light.position = Vector3(0, -0.5, 0.5)
			sign_root.add_child(light)

			# 25% chance of flicker
			if rng.randf() < 0.25:
				flickering_lights.append({
					"node": light,
					"base_energy": light.light_energy,
					"phase": rng.randf() * 20.0,
					"speed": rng.randf_range(0.8, 1.5),
					"style": "pop_on",
					"mesh": null,
					"label": label,
				})

			mi.add_child(anchor)

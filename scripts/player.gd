extends CharacterBody3D

## Player controller with third-person camera and WASD movement.

const SPEED = 5.0
const SPRINT_SPEED = 8.0
const ROTATION_SPEED = 0.003
const GRAVITY = 20.0
const JUMP_VELOCITY = 7.0
const BASE_FOV = 70.0
const SPRINT_FOV = 80.0
const FOV_LERP_SPEED = 6.0
const BOB_FREQUENCY = 10.0
const BOB_AMPLITUDE = 0.03
const BOB_SPRINT_MULT = 1.4
const CROUCH_SPEED_MULT = 0.6
const CROUCH_HEIGHT = 0.6  # collision shape Y scale when crouched
const STAND_HEIGHT = 1.0

@onready var camera_pivot: Node3D = $CameraPivot
@onready var camera: Camera3D = $CameraPivot/Camera3D

var camera_rotation_x: float = -0.3  # slight downward angle
var ps1_shader: Shader
var anim: HumanoidAnimation
var bob_timer: float = 0.0
var camera_base_y: float = 0.0
var step_player: AudioStreamPlayer
var step_generator: AudioStreamGenerator
var step_playback: AudioStreamGeneratorPlayback
var step_rng := RandomNumberGenerator.new()
var last_step_sign: float = 1.0  # tracks bob_timer sin sign for step triggers
var flashlight: SpotLight3D
var foot_splash: GPUParticles3D
var sprint_streaks: GPUParticles3D
var was_on_floor: bool = true
var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var breath_fog: GPUParticles3D
var breath_timer: float = 0.0
var compass_label: Label
var crt_material: ShaderMaterial
var is_crouching: bool = false
var crouch_lerp: float = 1.0  # 1.0 = standing, CROUCH_HEIGHT = crouched
var model_node: Node3D = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ps1_shader = load("res://shaders/ps1.gdshader")
	camera.fov = BASE_FOV
	camera_base_y = camera.position.y
	_build_humanoid_model()
	_setup_crt_overlay()
	_setup_footstep_audio()
	_setup_flashlight()
	_setup_foot_splash()
	_setup_sprint_streaks()
	_setup_breath_fog()
	_setup_compass_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Horizontal rotation on player body
		rotate_y(-event.relative.x * ROTATION_SPEED)
		# Vertical rotation on camera pivot
		camera_rotation_x -= event.relative.y * ROTATION_SPEED
		camera_rotation_x = clamp(camera_rotation_x, -1.2, 0.5)
		camera_pivot.rotation.x = camera_rotation_x

	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventKey and event.pressed and not event.echo:
		if (event as InputEventKey).keycode == KEY_F:
			if flashlight:
				flashlight.visible = not flashlight.visible

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Landing screen shake
	var fall_speed := absf(velocity.y)
	if is_on_floor() and not was_on_floor and fall_speed > 3.0:
		shake_intensity = clampf(fall_speed * 0.008, 0.01, 0.06)
		shake_timer = 0.25
	was_on_floor = is_on_floor()

	# Apply shake decay
	if shake_timer > 0.0:
		shake_timer -= delta
		var shake_amount := shake_intensity * (shake_timer / 0.25)
		camera_pivot.rotation.z = sin(shake_timer * 40.0) * shake_amount
	else:
		camera_pivot.rotation.z = lerpf(camera_pivot.rotation.z, 0.0, 10.0 * delta)

	# Crouch
	is_crouching = Input.is_key_pressed(KEY_CTRL) and is_on_floor()
	var crouch_target := CROUCH_HEIGHT if is_crouching else STAND_HEIGHT
	crouch_lerp = lerpf(crouch_lerp, crouch_target, 8.0 * delta)
	# Scale model and adjust camera
	if model_node:
		model_node.scale.y = crouch_lerp
	camera_pivot.position.y = lerpf(1.6, 1.0, 1.0 - crouch_lerp)

	# Jump (can't jump while crouching)
	if is_on_floor() and Input.is_action_just_pressed("jump") and not is_crouching:
		velocity.y = JUMP_VELOCITY

	# Get input direction
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var speed_mult := CROUCH_SPEED_MULT if is_crouching else 1.0
	var current_speed := (SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else SPEED) * speed_mult

	if direction:
		velocity.x = direction.x * current_speed
		velocity.z = direction.z * current_speed
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed * 5.0 * delta)
		velocity.z = move_toward(velocity.z, 0, current_speed * 5.0 * delta)

	move_and_slide()

	# Drive walk animation
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if anim:
		anim.update(delta, horiz_speed)

	var is_sprinting := Input.is_key_pressed(KEY_SHIFT) and horiz_speed > 1.0

	# Sprint FOV effect
	var target_fov := SPRINT_FOV if is_sprinting else BASE_FOV
	camera.fov = lerpf(camera.fov, target_fov, FOV_LERP_SPEED * delta)

	# Sprint rain streaks + speed blur
	if sprint_streaks:
		sprint_streaks.emitting = is_sprinting
	if crt_material:
		var blur_target := clampf(horiz_speed / SPRINT_SPEED, 0.0, 1.0) * 0.6 if is_sprinting else 0.0
		var current_blur_val = crt_material.get_shader_parameter("speed_blur")
		var current_blur: float = current_blur_val if current_blur_val != null else 0.0
		crt_material.set_shader_parameter("speed_blur", lerpf(current_blur, blur_target, 8.0 * delta))

	# Breath fog puffs (every 2.5-3.5 seconds)
	breath_timer -= delta
	if breath_timer <= 0.0:
		breath_timer = 2.5 + fmod(bob_timer * 0.1, 1.0)
		if breath_fog:
			breath_fog.restart()
			breath_fog.emitting = true

	# Update compass + time
	if compass_label:
		var heading := fmod(-rotation.y * 180.0 / PI + 360.0, 360.0)
		var directions := ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
		var idx := int(roundf(heading / 45.0)) % 8
		var time_str := ""
		var dnc := get_node_or_null("../DayNightCycle")
		if dnc and "time_of_day" in dnc:
			var tod: float = dnc.time_of_day
			var hours := int(tod) % 24
			var minutes := int((tod - float(hours)) * 60.0)
			time_str = "  %02d:%02d" % [hours, minutes]
		compass_label.text = "SHINTAIHOKU  [ %s %d° ]%s" % [directions[idx], int(heading), time_str]

	# Head bob
	if is_on_floor() and horiz_speed > 0.5:
		var bob_mult := BOB_SPRINT_MULT if is_sprinting else 1.0
		bob_timer += delta * BOB_FREQUENCY * (horiz_speed / SPEED)
		var bob_offset := sin(bob_timer) * BOB_AMPLITUDE * bob_mult
		camera.position.y = camera_base_y + bob_offset
		# Subtle horizontal sway
		camera.position.x = sin(bob_timer * 0.5) * BOB_AMPLITUDE * 0.5 * bob_mult
		# Trigger footstep on bob cycle zero-crossing (each half-cycle = one step)
		var current_sign := signf(sin(bob_timer))
		if current_sign != last_step_sign and current_sign != 0.0:
			last_step_sign = current_sign
			_trigger_footstep(is_sprinting)
		# Foot splash particles while walking on wet ground
		if foot_splash:
			foot_splash.emitting = true
	else:
		if foot_splash:
			foot_splash.emitting = false
		# Idle breathing sway
		bob_timer += delta * 1.2  # slow breathing rate
		var breathe_y := sin(bob_timer * 0.8) * 0.005
		var breathe_x := sin(bob_timer * 0.5) * 0.002
		camera.position.y = lerpf(camera.position.y, camera_base_y + breathe_y, 5.0 * delta)
		camera.position.x = lerpf(camera.position.x, breathe_x, 5.0 * delta)

func _build_humanoid_model() -> void:
	# Remove the old capsule mesh from the scene
	var old_mesh := get_node_or_null("MeshInstance3D")
	if old_mesh:
		old_mesh.queue_free()

	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	model_node = model

	var skin_color := Color(0.85, 0.72, 0.6)
	var jacket_color := Color(0.12, 0.12, 0.15)
	var pants_color := Color(0.1, 0.1, 0.12)
	var accent_cyan := Color(0.0, 0.9, 1.0)

	# Head
	_add_body_part(model, "Head", SphereMesh.new(), Vector3(0, 1.55, 0), skin_color)
	(model.get_node("Head").mesh as SphereMesh).radius = 0.18
	(model.get_node("Head").mesh as SphereMesh).height = 0.36

	# Torso
	_add_body_part(model, "Torso", BoxMesh.new(), Vector3(0, 1.1, 0), jacket_color,
		Vector3(0.5, 0.55, 0.28))

	# Accent stripe on chest (thin emissive cyan strip)
	_add_body_part(model, "AccentStripe", BoxMesh.new(), Vector3(0, 1.05, 0.141), accent_cyan,
		Vector3(0.3, 0.06, 0.01), true, accent_cyan, 3.0)

	# Hips
	_add_body_part(model, "Hips", BoxMesh.new(), Vector3(0, 0.75, 0), pants_color,
		Vector3(0.45, 0.2, 0.25))

	# === PIVOT-BASED ARMS ===
	# Left arm
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

	# === PIVOT-BASED LEGS ===
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

	# Setup animation controller
	anim = HumanoidAnimation.new()
	anim.setup(model)

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

func _setup_footstep_audio() -> void:
	step_rng.seed = 7777
	step_player = AudioStreamPlayer.new()
	step_generator = AudioStreamGenerator.new()
	step_generator.mix_rate = 22050.0
	step_generator.buffer_length = 0.1
	step_player.stream = step_generator
	step_player.volume_db = -8.0
	step_player.bus = "Master"
	add_child(step_player)
	step_player.play()
	step_playback = step_player.get_stream_playback()

func _trigger_footstep(sprinting: bool) -> void:
	if not step_playback:
		return
	# Randomly vary between dry and wet footstep sounds
	var is_wet := step_rng.randf() < 0.35  # 35% chance of splashy step
	var num_samples := 800 if sprinting else 600
	if is_wet:
		num_samples = int(num_samples * 1.3)  # wet steps ring longer
	var pitch := step_rng.randf_range(0.7, 1.0) if sprinting else step_rng.randf_range(0.9, 1.3)
	var volume := 0.35 if sprinting else 0.2
	var phase := 0.0
	var filter_state := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		# Envelope: sharp attack, fast decay
		var env := (1.0 - t) * (1.0 - t)
		var noise := step_rng.randf_range(-1.0, 1.0)
		phase += pitch * 0.02
		var sample: float
		if is_wet:
			# Wet: more noise, higher pitch splash, less thump
			var splash := noise * 0.85
			var water_ring := sin(phase * 120.0 * TAU) * 0.15 * (1.0 - t)
			filter_state = filter_state * 0.6 + splash * 0.4
			sample = (filter_state + water_ring) * env * volume * 1.2
		else:
			# Dry: standard thump + noise
			var thump := sin(phase * 80.0 * TAU) * 0.5
			sample = (noise * 0.6 + thump * 0.4) * env * volume
		if step_playback.can_push_buffer(1):
			step_playback.push_frame(Vector2(sample, sample))

func _setup_flashlight() -> void:
	flashlight = SpotLight3D.new()
	flashlight.light_color = Color(0.95, 0.9, 0.8)
	flashlight.light_energy = 3.0
	flashlight.spot_range = 18.0
	flashlight.spot_angle = 25.0
	flashlight.spot_attenuation = 1.2
	flashlight.shadow_enabled = false
	flashlight.position = Vector3(0.3, 0, -0.5)
	flashlight.visible = false  # start off
	camera.add_child(flashlight)

func _setup_foot_splash() -> void:
	foot_splash = GPUParticles3D.new()
	foot_splash.amount = 12
	foot_splash.lifetime = 0.3
	foot_splash.emitting = false
	foot_splash.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 3, 4))
	var splash_mat := ParticleProcessMaterial.new()
	splash_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	splash_mat.emission_box_extents = Vector3(0.2, 0, 0.2)
	splash_mat.direction = Vector3(0, 1, 0)
	splash_mat.spread = 45.0
	splash_mat.initial_velocity_min = 1.0
	splash_mat.initial_velocity_max = 2.5
	splash_mat.gravity = Vector3(0, -10.0, 0)
	splash_mat.scale_min = 0.03
	splash_mat.scale_max = 0.08
	splash_mat.color = Color(0.5, 0.55, 0.7, 0.3)
	foot_splash.process_material = splash_mat
	var splash_mesh := SphereMesh.new()
	splash_mesh.radius = 0.03
	splash_mesh.height = 0.06
	foot_splash.draw_pass_1 = splash_mesh
	foot_splash.position = Vector3(0, 0.05, 0)
	add_child(foot_splash)

func _setup_sprint_streaks() -> void:
	sprint_streaks = GPUParticles3D.new()
	sprint_streaks.amount = 20
	sprint_streaks.lifetime = 0.15
	sprint_streaks.emitting = false
	sprint_streaks.visibility_aabb = AABB(Vector3(-5, -3, -5), Vector3(10, 6, 10))
	var streak_mat := ParticleProcessMaterial.new()
	streak_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	streak_mat.emission_box_extents = Vector3(1.5, 1.0, 0.3)
	streak_mat.direction = Vector3(0, 0, 1)  # fly toward camera
	streak_mat.spread = 10.0
	streak_mat.initial_velocity_min = 15.0
	streak_mat.initial_velocity_max = 25.0
	streak_mat.gravity = Vector3.ZERO
	streak_mat.scale_min = 0.01
	streak_mat.scale_max = 0.03
	streak_mat.color = Color(0.6, 0.65, 0.8, 0.2)
	sprint_streaks.process_material = streak_mat
	# Elongated mesh for streak look
	var streak_mesh := BoxMesh.new()
	streak_mesh.size = Vector3(0.01, 0.01, 0.15)
	sprint_streaks.draw_pass_1 = streak_mesh
	sprint_streaks.position = Vector3(0, 0, -2.0)
	camera.add_child(sprint_streaks)

func _setup_compass_hud() -> void:
	var hud_layer := CanvasLayer.new()
	hud_layer.layer = 5
	add_child(hud_layer)
	compass_label = Label.new()
	compass_label.text = "[ N  0° ]"
	compass_label.add_theme_font_size_override("font_size", 14)
	compass_label.add_theme_color_override("font_color", Color(0.0, 0.9, 1.0, 0.5))
	compass_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	compass_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	compass_label.position.y = 10
	hud_layer.add_child(compass_label)

func _setup_breath_fog() -> void:
	breath_fog = GPUParticles3D.new()
	breath_fog.amount = 6
	breath_fog.lifetime = 1.2
	breath_fog.one_shot = true
	breath_fog.emitting = false
	breath_fog.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	var fog_mat := ParticleProcessMaterial.new()
	fog_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fog_mat.emission_sphere_radius = 0.03
	fog_mat.direction = Vector3(0, 0.3, -1)  # forward and slightly up
	fog_mat.spread = 20.0
	fog_mat.initial_velocity_min = 0.3
	fog_mat.initial_velocity_max = 0.6
	fog_mat.gravity = Vector3(0, 0.15, 0)
	fog_mat.damping_min = 1.0
	fog_mat.damping_max = 2.0
	fog_mat.scale_min = 0.02
	fog_mat.scale_max = 0.06
	fog_mat.color = Color(0.7, 0.7, 0.8, 0.1)
	breath_fog.process_material = fog_mat
	var fog_mesh := SphereMesh.new()
	fog_mesh.radius = 0.03
	fog_mesh.height = 0.06
	breath_fog.draw_pass_1 = fog_mesh
	breath_fog.position = Vector3(0, -0.2, -0.5)
	camera.add_child(breath_fog)

func _setup_crt_overlay() -> void:
	var crt_shader_path := "res://shaders/crt.gdshader"
	if not ResourceLoader.exists(crt_shader_path):
		return
	var crt_shader: Shader = load(crt_shader_path)
	var canvas_layer := CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)

	var rect := ColorRect.new()
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = crt_shader
	rect.material = mat
	crt_material = mat
	canvas_layer.add_child(rect)

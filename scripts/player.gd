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

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	ps1_shader = load("res://shaders/ps1.gdshader")
	camera.fov = BASE_FOV
	camera_base_y = camera.position.y
	_build_humanoid_model()
	_setup_crt_overlay()
	_setup_footstep_audio()

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

func _physics_process(delta: float) -> void:
	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	# Jump
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	# Get input direction
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_backward")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()

	var current_speed := SPRINT_SPEED if Input.is_key_pressed(KEY_SHIFT) else SPEED

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
	else:
		# Smoothly return to center
		camera.position.y = lerpf(camera.position.y, camera_base_y, 10.0 * delta)
		camera.position.x = lerpf(camera.position.x, 0.0, 10.0 * delta)

func _build_humanoid_model() -> void:
	# Remove the old capsule mesh from the scene
	var old_mesh := get_node_or_null("MeshInstance3D")
	if old_mesh:
		old_mesh.queue_free()

	var model := Node3D.new()
	model.name = "Model"
	add_child(model)

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
	# Generate a short percussive noise burst (footstep on wet concrete)
	var num_samples := 800 if sprinting else 600
	var pitch := step_rng.randf_range(0.7, 1.0) if sprinting else step_rng.randf_range(0.9, 1.3)
	var volume := 0.35 if sprinting else 0.2
	var phase := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		# Envelope: sharp attack, fast decay
		var env := (1.0 - t) * (1.0 - t)
		# Noise + low thump
		var noise := step_rng.randf_range(-1.0, 1.0)
		phase += pitch * 0.02
		var thump := sin(phase * 80.0 * TAU) * 0.5
		var sample := (noise * 0.6 + thump * 0.4) * env * volume
		if step_playback.can_push_buffer(1):
			step_playback.push_frame(Vector2(sample, sample))

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
	canvas_layer.add_child(rect)

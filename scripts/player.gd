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
var echo_delay: float = 0.0  # countdown to play echo footstep
var echo_pending: bool = false
var echo_sprinting: bool = false
var flashlight: SpotLight3D
var foot_splash: GPUParticles3D
var sprint_streaks: GPUParticles3D
var was_on_floor: bool = true
var shake_intensity: float = 0.0
var shake_timer: float = 0.0
var bob_amplitude_current: float = 0.0  # smooth transition for head bob
var breath_fog: GPUParticles3D
var land_dust: GPUParticles3D
var breath_timer: float = 0.0
var compass_label: Label
var crt_material: ShaderMaterial
var interact_label: Label
var is_crouching: bool = false
var crouch_lerp: float = 1.0  # 1.0 = standing, CROUCH_HEIGHT = crouched
var model_node: Node3D = null
var shadow_blob: MeshInstance3D = null
var coat_tail: MeshInstance3D = null
var head_rain_splash: GPUParticles3D = null
var sprint_breath_toggle: bool = false  # alternates per footstep when sprinting
var sprint_time: float = 0.0  # how long we've been sprinting
var impact_aberration: float = 0.0  # chromatic aberration from hard landing
var accent_stripe_mat: ShaderMaterial = null  # for glow pulse
var accent_pulse_time: float = 0.0
var turn_lean: float = 0.0  # camera lean from turning
var head_node: Node3D = null  # for head look direction
var lean_direction: float = 0.0  # -1=left, 0=center, 1=right
var lean_amount: float = 0.0  # current interpolated lean
const LEAN_OFFSET: float = 0.5
const LEAN_TILT: float = 0.08
var footprints: Array[Dictionary] = []  # [{mesh, timer}]
var footprint_pool_idx: int = 0
const FOOTPRINT_POOL_SIZE: int = 8
const FOOTPRINT_LIFETIME: float = 4.0
var limp_timer: float = 0.0  # recovery limp after hard landing
var catch_breath_timer: float = 0.0  # heavier breathing after sustained sprint
var rain_drip_timer: float = 0.0  # rain droplet on camera lens
var rain_drip_flash: float = 0.0  # current drip noise intensity

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
	_setup_land_dust()
	_setup_compass_hud()
	_setup_interaction_prompt()
	_setup_shadow_blob()
	_setup_head_rain_splash()
	_setup_footprint_pool()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		# Horizontal rotation on player body
		rotate_y(-event.relative.x * ROTATION_SPEED)
		# Turn momentum lean (cinematic camera dutch angle)
		turn_lean += event.relative.x * 0.0003
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

	# Landing screen shake + chromatic aberration
	var fall_speed := absf(velocity.y)
	if is_on_floor() and not was_on_floor and fall_speed > 3.0:
		shake_intensity = clampf(fall_speed * 0.008, 0.01, 0.06)
		shake_timer = 0.25
		if fall_speed > 6.0:
			impact_aberration = clampf((fall_speed - 6.0) * 0.15, 0.0, 1.0)
		_play_landing_thud(fall_speed)
		if fall_speed > 6.0:
			limp_timer = 3.0  # recovery limp for 3 seconds
		if fall_speed > 4.0 and land_dust:
			land_dust.restart()
			land_dust.emitting = true
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
		_play_jump_grunt()

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

	# Shadow blob follows player on ground
	if shadow_blob and is_instance_valid(shadow_blob) and shadow_blob.is_inside_tree():
		shadow_blob.global_position = Vector3(global_position.x, 0.03, global_position.z)

	# Drive walk animation
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if anim:
		anim.update(delta, horiz_speed)

	# Head follows camera pitch + lean direction
	if head_node:
		head_node.rotation.x = lerpf(head_node.rotation.x, camera_rotation_x * 0.3, 8.0 * delta)
		head_node.rotation.z = lerpf(head_node.rotation.z, lean_amount * 0.15, 6.0 * delta)

	# Coat tail sway based on speed
	if coat_tail:
		var tail_target := 0.0
		if horiz_speed > 0.5:
			tail_target = horiz_speed * 0.04 + sin(bob_timer * 2.0) * 0.05
		coat_tail.rotation.x = lerpf(coat_tail.rotation.x, tail_target, 6.0 * delta)

	var is_sprinting := Input.is_key_pressed(KEY_SHIFT) and horiz_speed > 1.0

	# Sprint model lean (body leans forward when running)
	if model_node:
		var model_lean_target := 0.1 if is_sprinting else 0.0
		model_node.rotation.x = lerpf(model_node.rotation.x, model_lean_target, 6.0 * delta)

	# Sprint + jump FOV effect
	var target_fov := SPRINT_FOV if is_sprinting else BASE_FOV
	if not is_on_floor():
		if velocity.y > 0.5:
			target_fov += 3.0  # ascent: slight widen
		elif velocity.y < -1.0:
			target_fov -= 2.0  # descent: slight narrow
	camera.fov = lerpf(camera.fov, target_fov, FOV_LERP_SPEED * delta)

	# Sprint strafe camera roll + forward lean
	if is_sprinting and is_on_floor():
		var strafe_roll := -input_dir.x * 0.025  # tilt into the turn
		camera.rotation.z = lerpf(camera.rotation.z, strafe_roll, 6.0 * delta)
		camera.rotation.x = lerpf(camera.rotation.x, 0.03, 4.0 * delta)  # lean forward
	elif not (shake_timer > 0.0):
		camera.rotation.z = lerpf(camera.rotation.z, 0.0, 8.0 * delta)
		camera.rotation.x = lerpf(camera.rotation.x, 0.0, 6.0 * delta)

	# Track sprint duration for breathing
	if is_sprinting:
		sprint_time += delta
	else:
		# Trigger catch-breath when stopping after sustained sprint
		if sprint_time > 5.0 and horiz_speed < 1.0:
			catch_breath_timer = 3.0
		sprint_time = maxf(sprint_time - delta * 2.0, 0.0)

	# Catch-breath effect (heavier breathing after sprint, camera jitter)
	if catch_breath_timer > 0.0:
		catch_breath_timer -= delta
		var cb_intensity := clampf(catch_breath_timer / 3.0, 0.0, 1.0)
		# Camera jitter
		camera_pivot.rotation.z += sin(bob_timer * 15.0) * 0.003 * cb_intensity
		camera.rotation.x += sin(bob_timer * 12.0) * 0.002 * cb_intensity

	# Landing recovery limp decay
	if limp_timer > 0.0:
		limp_timer -= delta

	# Impact chromatic aberration decay
	if impact_aberration > 0.0:
		impact_aberration = maxf(0.0, impact_aberration - delta * 4.0)
		if crt_material:
			var base_aberration_val = crt_material.get_shader_parameter("aberration_amount")
			var base_aberration: float = 1.0
			if base_aberration_val != null:
				base_aberration = float(base_aberration_val)
			crt_material.set_shader_parameter("aberration_amount", base_aberration + impact_aberration * 3.0)

	# Fade out wet footprints
	_update_footprints(delta)

	# Accent stripe glow pulse (slow cyberpunk heartbeat)
	accent_pulse_time += delta
	if accent_stripe_mat:
		var pulse := 2.5 + 1.0 * sin(accent_pulse_time * 1.5)
		accent_stripe_mat.set_shader_parameter("emission_strength", pulse)

	# Sprint rain streaks + speed blur
	if sprint_streaks:
		sprint_streaks.emitting = is_sprinting
	if crt_material:
		var blur_target := clampf(horiz_speed / SPRINT_SPEED, 0.0, 1.0) * 0.6 if is_sprinting else 0.0
		var current_blur_val = crt_material.get_shader_parameter("speed_blur")
		var current_blur: float = current_blur_val if current_blur_val != null else 0.0
		crt_material.set_shader_parameter("speed_blur", lerpf(current_blur, blur_target, 8.0 * delta))

	# Turn momentum lean (decay toward 0)
	turn_lean = clampf(turn_lean, -0.04, 0.04)
	turn_lean = lerpf(turn_lean, 0.0, 6.0 * delta)
	camera_pivot.rotation.z += turn_lean

	# Corner lean/peek (Q/E)
	lean_direction = 0.0
	if Input.is_key_pressed(KEY_Q):
		lean_direction = -1.0
	elif Input.is_key_pressed(KEY_E):
		lean_direction = 1.0
	lean_amount = lerpf(lean_amount, lean_direction, 8.0 * delta)
	camera_pivot.position.x = lean_amount * LEAN_OFFSET
	camera_pivot.rotation.z += lean_amount * LEAN_TILT

	# Camera wind sway (subtle drift from rain wind)
	var rain_node := get_node_or_null("../Rain")
	var wind_strength := 0.0
	if rain_node and "wind_x" in rain_node:
		wind_strength = rain_node.wind_x
	var wind_sway := wind_strength * 0.0008
	camera.rotation.z = lerpf(camera.rotation.z, camera.rotation.z + wind_sway, 2.0 * delta)

	# Standing wind buffet (subtle body sway when idle in heavy wind)
	if horiz_speed < 0.5 and absf(wind_strength) > 0.3:
		var buffet := sin(bob_timer * 1.8) * absf(wind_strength) * 0.003
		camera_pivot.rotation.z += buffet

	# Breath fog puffs (faster when catching breath after sprint)
	breath_timer -= delta
	if breath_timer <= 0.0:
		if catch_breath_timer > 0.0:
			breath_timer = 0.8  # rapid panting
		else:
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

	# Night vignette: stronger vignette during nighttime hours
	if crt_material:
		var dnc_node := get_node_or_null("../DayNightCycle")
		var target_vignette := 0.3  # default daytime
		if dnc_node and "time_of_day" in dnc_node:
			var tod_val: float = dnc_node.time_of_day
			if tod_val > 21.0 or tod_val < 5.0:
				target_vignette = 0.5  # night: stronger vignette
			elif tod_val > 17.0:
				target_vignette = lerpf(0.3, 0.5, (tod_val - 17.0) / 4.0)  # dusk transition
			elif tod_val < 7.0:
				target_vignette = lerpf(0.5, 0.3, (tod_val - 5.0) / 2.0)  # dawn transition
		var cur_vig = crt_material.get_shader_parameter("vignette_intensity")
		var cur_vig_f: float = cur_vig if cur_vig != null else 0.3
		crt_material.set_shader_parameter("vignette_intensity", lerpf(cur_vig_f, target_vignette, 2.0 * delta))

	# Wet lens effect: more noise grain when looking down at puddle level
	# Rain drip: random noise spike when looking up (rain hits camera lens)
	if crt_material:
		var down_factor := clampf(-camera_rotation_x - 0.3, 0.0, 0.5) * 2.0
		var wet_noise := lerpf(0.02, 0.05, down_factor)
		# Rain drip pulse when looking up
		if camera_rotation_x > 0.3:
			rain_drip_timer -= delta
			if rain_drip_timer <= 0.0:
				rain_drip_timer = randf_range(2.0, 5.0)
				rain_drip_flash = 0.06
		else:
			rain_drip_timer = randf_range(1.0, 3.0)
		rain_drip_flash = lerpf(rain_drip_flash, 0.0, 4.0 * delta)
		var final_noise := maxf(wet_noise, rain_drip_flash)
		crt_material.set_shader_parameter("noise_intensity", lerpf(0.02, final_noise, 3.0 * delta))

	# Interaction prompt (proximity + look direction NPC detection)
	if interact_label:
		var npc_mgr := get_node_or_null("../NpcManager")
		var show_prompt := false
		if npc_mgr:
			var cam_forward := -camera.global_transform.basis.z
			var cam_pos := camera.global_position
			for npc_child in npc_mgr.get_children():
				if not npc_child is Node3D:
					continue
				var npc_pos := (npc_child as Node3D).global_position + Vector3(0, 1.0, 0)
				var to_npc := npc_pos - cam_pos
				var dist_to := to_npc.length()
				if dist_to > 5.0 or dist_to < 0.5:
					continue
				var dot := cam_forward.dot(to_npc.normalized())
				if dot > 0.85:  # within ~30 degree cone
					show_prompt = true
					break
		interact_label.visible = show_prompt

	# Head bob (smooth amplitude transition)
	var target_bob_amp := 0.0
	if is_on_floor() and horiz_speed > 0.5:
		var speed_ratio := clampf(horiz_speed / SPRINT_SPEED, 0.3, 1.0)
		target_bob_amp = BOB_AMPLITUDE * lerpf(0.6, BOB_SPRINT_MULT, speed_ratio)
	bob_amplitude_current = lerpf(bob_amplitude_current, target_bob_amp, 8.0 * delta)

	if bob_amplitude_current > 0.001:
		bob_timer += delta * BOB_FREQUENCY * maxf(horiz_speed / SPEED, 0.3)
		var bob_offset := sin(bob_timer) * bob_amplitude_current
		# Landing recovery limp: asymmetric bob + tilt
		if limp_timer > 0.0:
			var limp_strength := clampf(limp_timer / 3.0, 0.0, 1.0)
			var limp_asym := 0.3 * limp_strength  # one side bobs more
			if sin(bob_timer) > 0.0:
				bob_offset *= (1.0 + limp_asym)
			else:
				bob_offset *= (1.0 - limp_asym)
			camera_pivot.rotation.z += sin(bob_timer) * 0.01 * limp_strength
		camera.position.y = camera_base_y + bob_offset
		camera.position.x = sin(bob_timer * 0.5) * bob_amplitude_current * 0.5
		# Trigger footstep on bob cycle zero-crossing
		var current_sign := signf(sin(bob_timer))
		if current_sign != last_step_sign and current_sign != 0.0:
			last_step_sign = current_sign
			if horiz_speed > 0.5:
				_trigger_footstep(is_sprinting)
		if foot_splash:
			foot_splash.emitting = horiz_speed > 0.5
	else:
		if foot_splash:
			foot_splash.emitting = false
		# Idle breathing sway
		bob_timer += delta * 1.2
		var breathe_y := sin(bob_timer * 0.8) * 0.005
		var breathe_x := sin(bob_timer * 0.5) * 0.002
		camera.position.y = lerpf(camera.position.y, camera_base_y + breathe_y, 5.0 * delta)
		camera.position.x = lerpf(camera.position.x, breathe_x, 5.0 * delta)
		# Micro-rotation drift (handheld camera feel)
		var drift_z := sin(bob_timer * 0.3) * 0.0015 + sin(bob_timer * 0.7) * 0.001
		var drift_x := sin(bob_timer * 0.4) * 0.001
		camera.rotation.z = lerpf(camera.rotation.z, drift_z, 3.0 * delta)
		camera.rotation.x = lerpf(camera.rotation.x, drift_x, 3.0 * delta)

	# Footstep echo delay processing
	if echo_pending:
		echo_delay -= delta
		if echo_delay <= 0.0:
			echo_pending = false
			_play_echo_step()

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
	head_node = model.get_node_or_null("Head")

	# Torso
	_add_body_part(model, "Torso", BoxMesh.new(), Vector3(0, 1.1, 0), jacket_color,
		Vector3(0.5, 0.55, 0.28))

	# Accent stripe on chest (thin emissive cyan strip)
	_add_body_part(model, "AccentStripe", BoxMesh.new(), Vector3(0, 1.05, 0.141), accent_cyan,
		Vector3(0.3, 0.06, 0.01), true, accent_cyan, 3.0)
	var stripe_node := model.get_node_or_null("AccentStripe")
	if stripe_node:
		accent_stripe_mat = stripe_node.get_surface_override_material(0) as ShaderMaterial

	# Collar (turned-up jacket collar at back of neck)
	_add_body_part(model, "Collar", BoxMesh.new(), Vector3(0, 1.42, -0.12),
		jacket_color * 1.1, Vector3(0.35, 0.1, 0.08))

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

	# Coat tail flap (back of jacket)
	coat_tail = MeshInstance3D.new()
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(0.35, 0.25, 0.04)
	coat_tail.mesh = tail_mesh
	coat_tail.position = Vector3(0, 0.85, -0.16)
	var tail_mat := ShaderMaterial.new()
	tail_mat.shader = ps1_shader
	tail_mat.set_shader_parameter("albedo_color", jacket_color)
	tail_mat.set_shader_parameter("vertex_snap_intensity", 4.0)
	tail_mat.set_shader_parameter("color_depth", 12.0)
	tail_mat.set_shader_parameter("fog_color", Color(0.05, 0.03, 0.1, 1.0))
	tail_mat.set_shader_parameter("fog_distance", 100.0)
	tail_mat.set_shader_parameter("fog_density", 0.3)
	coat_tail.set_surface_override_material(0, tail_mat)
	coat_tail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(coat_tail)

	# Breath vapor (cold air puffs from face)
	var breath := GPUParticles3D.new()
	breath.amount = 2
	breath.lifetime = 0.8
	breath.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 2, 2))
	var br_mat := ParticleProcessMaterial.new()
	br_mat.direction = Vector3(0, 0.3, 1)
	br_mat.spread = 12.0
	br_mat.initial_velocity_min = 0.3
	br_mat.initial_velocity_max = 0.6
	br_mat.gravity = Vector3(0, 0.2, 0)
	br_mat.damping_min = 0.5
	br_mat.damping_max = 1.0
	br_mat.scale_min = 0.02
	br_mat.scale_max = 0.06
	br_mat.color = Color(0.7, 0.7, 0.8, 0.06)
	breath.process_material = br_mat
	var br_mesh := BoxMesh.new()
	br_mesh.size = Vector3(0.04, 0.04, 0.04)
	breath.draw_pass_1 = br_mesh
	breath.position = Vector3(0, 1.6, 0.15)
	model.add_child(breath)

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
	if not is_crouching:
		_place_footprint()
	if not step_playback:
		return
	# Surface detection: near storefront grid cells = tile/metal, otherwise concrete
	var cell_stride := 28.0  # block_size(20) + street_width(8)
	var gx := fmod(absf(global_position.x), cell_stride)
	var gz := fmod(absf(global_position.z), cell_stride)
	var near_storefront := gx < 3.0 or gx > cell_stride - 3.0 or gz < 3.0 or gz > cell_stride - 3.0
	# Randomly vary between dry and wet footstep sounds
	var is_wet := step_rng.randf() < 0.35  # 35% chance of splashy step
	var num_samples := 800 if sprinting else 600
	if is_crouching:
		num_samples = 350  # shorter, lighter
	if is_wet:
		num_samples = int(num_samples * 1.3)  # wet steps ring longer
	if near_storefront:
		num_samples = int(num_samples * 1.4)  # tile/metal rings longer
	var pitch := step_rng.randf_range(0.7, 1.0) if sprinting else step_rng.randf_range(0.9, 1.3)
	if is_crouching:
		pitch = step_rng.randf_range(1.2, 1.6)  # higher pitch = lighter taps
	if near_storefront:
		pitch *= 1.3  # higher pitch on tile
	var volume := 0.35 if sprinting else 0.2
	if is_crouching:
		volume = 0.08  # very quiet sneaky steps
	var phase := 0.0
	var filter_state := 0.0
	for i in range(num_samples):
		var t := float(i) / float(num_samples)
		# Envelope: sharp attack, fast decay
		var env := (1.0 - t) * (1.0 - t)
		var noise := step_rng.randf_range(-1.0, 1.0)
		phase += pitch * 0.02
		var sample: float
		if near_storefront and not is_wet:
			# Tile/metal: resonant ring with less noise
			var ring := sin(phase * 140.0 * TAU) * 0.4
			ring += sin(phase * 280.0 * TAU) * 0.15
			sample = (noise * 0.3 + ring * 0.7) * env * volume * 0.9
		elif is_wet:
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
	# Sprint breathing: every other footstep when sprinting for >2s
	if sprinting and sprint_time > 2.0:
		sprint_breath_toggle = not sprint_breath_toggle
		if sprint_breath_toggle:
			_trigger_breath_sound()

	# Queue echo if between buildings (alley/narrow street)
	if near_storefront and not echo_pending:
		echo_pending = true
		echo_delay = 0.12
		echo_sprinting = sprinting

func _play_echo_step() -> void:
	if not step_playback:
		return
	var num := 400
	var pitch := step_rng.randf_range(1.1, 1.4)  # higher pitch echo
	var vol := 0.08  # much quieter
	for i in range(num):
		var t := float(i) / float(num)
		var env := (1.0 - t) * (1.0 - t)
		var noise := step_rng.randf_range(-1.0, 1.0)
		var ring := sin(t * pitch * 180.0 * TAU * 0.01) * 0.3
		var sample := (noise * 0.4 + ring * 0.6) * env * vol
		if step_playback.can_push_buffer(1):
			step_playback.push_frame(Vector2(sample, sample))

func _play_jump_grunt() -> void:
	if not step_playback:
		return
	# Short "huh" grunt — low formant burst with noise
	var num := 500
	var grunt_filter := 0.0
	for i in range(num):
		var t := float(i) / float(num)
		# Sharp attack (first 10%), fast decay
		var env := 0.0
		if t < 0.1:
			env = t / 0.1
		else:
			env = (1.0 - t) * (1.0 - t)
		var noise := step_rng.randf_range(-1.0, 1.0)
		grunt_filter = grunt_filter * 0.7 + noise * 0.3
		var formant := sin(t * 220.0 * TAU * 0.01) * grunt_filter * 0.5
		formant += sin(t * 110.0 * TAU * 0.01) * 0.2  # sub harmonic
		var sample := formant * env * 0.06
		if step_playback.can_push_buffer(1):
			step_playback.push_frame(Vector2(sample, sample))

func _play_landing_thud(fall_speed: float) -> void:
	if not step_playback:
		return
	var intensity := clampf((fall_speed - 3.0) / 7.0, 0.2, 1.0)
	var num := int(lerpf(600.0, 1200.0, intensity))
	var base_freq := lerpf(60.0, 35.0, intensity)  # deeper for harder hits
	var vol := lerpf(0.25, 0.6, intensity)
	for i in range(num):
		var t := float(i) / float(num)
		var env := (1.0 - t) * (1.0 - t) * (1.0 - t)  # cubic decay
		var thump := sin(t * base_freq * TAU) * 0.6
		var sub := sin(t * base_freq * 0.5 * TAU) * 0.3
		var noise := step_rng.randf_range(-1.0, 1.0) * 0.4
		var sample := (thump + sub + noise) * env * vol
		if step_playback.can_push_buffer(1):
			step_playback.push_frame(Vector2(sample, sample))

func _setup_land_dust() -> void:
	land_dust = GPUParticles3D.new()
	land_dust.amount = 10
	land_dust.lifetime = 0.5
	land_dust.one_shot = true
	land_dust.emitting = false
	land_dust.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 2, 4))
	var dust_mat := ParticleProcessMaterial.new()
	dust_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_mat.emission_box_extents = Vector3(0.3, 0, 0.3)
	dust_mat.direction = Vector3(0, 0.3, 0)
	dust_mat.spread = 80.0
	dust_mat.initial_velocity_min = 1.0
	dust_mat.initial_velocity_max = 2.5
	dust_mat.gravity = Vector3(0, -2.0, 0)
	dust_mat.damping_min = 2.0
	dust_mat.damping_max = 4.0
	dust_mat.scale_min = 0.03
	dust_mat.scale_max = 0.08
	dust_mat.color = Color(0.4, 0.35, 0.3, 0.2)
	land_dust.process_material = dust_mat
	var dust_mesh := SphereMesh.new()
	dust_mesh.radius = 0.04
	dust_mesh.height = 0.08
	land_dust.draw_pass_1 = dust_mesh
	land_dust.position = Vector3(0, 0.05, 0)
	add_child(land_dust)

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

func _setup_interaction_prompt() -> void:
	# HUD label for NPC interaction
	var hud := CanvasLayer.new()
	hud.layer = 5
	add_child(hud)
	interact_label = Label.new()
	interact_label.text = "[ E ] TALK"
	interact_label.add_theme_font_size_override("font_size", 16)
	interact_label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.4, 0.8))
	interact_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	interact_label.set_anchors_preset(Control.PRESET_CENTER)
	interact_label.position.y = 30
	interact_label.visible = false
	hud.add_child(interact_label)

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

func _setup_shadow_blob() -> void:
	shadow_blob = MeshInstance3D.new()
	var blob_mesh := QuadMesh.new()
	blob_mesh.size = Vector2(0.8, 0.8)
	shadow_blob.mesh = blob_mesh
	shadow_blob.rotation.x = -PI * 0.5  # flat on ground
	# Dark semi-transparent circle approximation
	var blob_mat := StandardMaterial3D.new()
	blob_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.35)
	blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	blob_mat.no_depth_test = false
	shadow_blob.set_surface_override_material(0, blob_mat)
	shadow_blob.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().call_deferred("add_child", shadow_blob)

var breath_variant: int = 0  # alternates between exhale types

func _trigger_breath_sound() -> void:
	if not step_playback:
		return
	breath_variant = (breath_variant + 1) % 2
	var breath_samples := 1200 if breath_variant == 0 else 1500
	var breath_filter := 0.0
	for i in range(breath_samples):
		var t := float(i) / float(breath_samples)
		var env := sin(t * PI) * 0.8
		var noise := step_rng.randf_range(-1.0, 1.0)
		var sample: float
		if breath_variant == 0:
			# Light exhale: higher formant, shorter
			breath_filter = breath_filter * 0.65 + noise * 0.35
			var formant := sin(t * 800.0 * TAU * 0.01) * breath_filter * 0.4
			sample = formant * env * 0.08
		else:
			# Deep exhale: lower formant, longer, more airy
			breath_filter = breath_filter * 0.75 + noise * 0.25
			var formant := sin(t * 500.0 * TAU * 0.01) * breath_filter * 0.3
			formant += sin(t * 300.0 * TAU * 0.01) * breath_filter * 0.15
			sample = formant * env * 0.06
		if step_playback.can_push_buffer(1):
			step_playback.push_frame(Vector2(sample, sample))

func _setup_head_rain_splash() -> void:
	head_rain_splash = GPUParticles3D.new()
	head_rain_splash.amount = 3
	head_rain_splash.lifetime = 0.2
	head_rain_splash.visibility_aabb = AABB(Vector3(-0.5, -0.3, -0.5), Vector3(1, 0.6, 1))
	var hmat := ParticleProcessMaterial.new()
	hmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	hmat.emission_sphere_radius = 0.15
	hmat.direction = Vector3(0, 1, 0)
	hmat.spread = 45.0
	hmat.initial_velocity_min = 0.3
	hmat.initial_velocity_max = 0.6
	hmat.gravity = Vector3(0, -4.0, 0)
	hmat.scale_min = 0.02
	hmat.scale_max = 0.04
	hmat.color = Color(0.5, 0.55, 0.65, 0.2)
	head_rain_splash.process_material = hmat
	var hmesh := SphereMesh.new()
	hmesh.radius = 0.02
	hmesh.height = 0.01
	head_rain_splash.draw_pass_1 = hmesh
	head_rain_splash.position = Vector3(0, 1.65, 0)
	add_child(head_rain_splash)

func _setup_footprint_pool() -> void:
	var fp_mat := StandardMaterial3D.new()
	fp_mat.albedo_color = Color(0.02, 0.02, 0.03, 0.5)
	fp_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fp_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for _i in range(FOOTPRINT_POOL_SIZE):
		var fp := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(0.25, 0.4)
		fp.mesh = q
		fp.set_surface_override_material(0, fp_mat.duplicate())
		fp.rotation.x = -PI * 0.5  # lay flat on ground
		fp.visible = false
		get_tree().root.call_deferred("add_child", fp)
		footprints.append({"mesh": fp, "timer": 0.0})

func _place_footprint() -> void:
	if footprints.is_empty():
		return
	var data: Dictionary = footprints[footprint_pool_idx]
	var fp: MeshInstance3D = data["mesh"]
	if not is_instance_valid(fp):
		return
	fp.global_position = global_position + Vector3(0, 0.01, 0)
	fp.rotation.y = rotation.y
	fp.visible = true
	var mat := fp.get_surface_override_material(0) as StandardMaterial3D
	if mat:
		mat.albedo_color.a = 0.5
	data["timer"] = FOOTPRINT_LIFETIME
	footprint_pool_idx = (footprint_pool_idx + 1) % FOOTPRINT_POOL_SIZE

func _update_footprints(delta: float) -> void:
	for data in footprints:
		if data["timer"] > 0.0:
			data["timer"] -= delta
			var fp: MeshInstance3D = data["mesh"]
			if is_instance_valid(fp):
				var alpha := clampf(data["timer"] / FOOTPRINT_LIFETIME, 0.0, 1.0)
				var mat := fp.get_surface_override_material(0) as StandardMaterial3D
				if mat:
					mat.albedo_color.a = alpha * 0.5
				if data["timer"] <= 0.0:
					fp.visible = false

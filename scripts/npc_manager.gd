extends Node3D

## Spawns NPC pedestrians that walk along streets.

@export var num_npcs: int = 20
@export var grid_size: int = 6
@export var block_size: float = 20.0
@export var street_width: float = 8.0

var ps1_shader: Shader
var npcs: Array[Dictionary] = []
var cell_stride: float
var grid_extent: float
var stop_rng := RandomNumberGenerator.new()

# Umbrella rain patter audio pool
const UMBRELLA_AUDIO_POOL_SIZE: int = 2
const UMBRELLA_AUDIO_RANGE: float = 12.0
var umbrella_pool: Array[Dictionary] = []
var umbrella_rng := RandomNumberGenerator.new()

# NPC footstep audio pool
const NPC_STEP_POOL_SIZE: int = 2
const NPC_STEP_RANGE: float = 12.0
var npc_step_pool: Array[Dictionary] = []
var step_audio_rng := RandomNumberGenerator.new()

# NPC outfit color palettes
var jacket_colors: Array[Color] = [
	Color(0.12, 0.12, 0.15),  # dark charcoal
	Color(0.15, 0.08, 0.2),   # dark purple
	Color(0.2, 0.1, 0.1),     # dark red
	Color(0.08, 0.12, 0.18),  # dark navy
	Color(0.18, 0.15, 0.08),  # dark olive
	Color(0.1, 0.1, 0.1),     # black
]

var accent_colors: Array[Color] = [
	Color(1.0, 0.05, 0.4),   # hot magenta
	Color(0.0, 0.9, 1.0),    # cyan
	Color(0.6, 0.0, 1.0),    # purple
	Color(1.0, 0.4, 0.0),    # orange
	Color(0.0, 1.0, 0.5),    # green
	Color(1.0, 1.0, 0.0),    # yellow
]

var skin_colors: Array[Color] = [
	Color(0.85, 0.72, 0.6),
	Color(0.72, 0.55, 0.42),
	Color(0.55, 0.38, 0.28),
	Color(0.92, 0.8, 0.7),
]

func _ready() -> void:
	ps1_shader = load("res://shaders/ps1.gdshader")
	cell_stride = block_size + street_width
	grid_extent = grid_size * cell_stride

	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	stop_rng.seed = 9999

	for i in range(num_npcs):
		_spawn_npc(rng, i)

	_spawn_conversation_groups(rng)
	_setup_umbrella_audio()
	_setup_npc_step_audio()

func _setup_umbrella_audio() -> void:
	umbrella_rng.seed = 7890
	for _i in range(UMBRELLA_AUDIO_POOL_SIZE):
		var player := AudioStreamPlayer3D.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.1
		player.stream = gen
		player.volume_db = -16.0
		player.max_distance = UMBRELLA_AUDIO_RANGE
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 5.0
		add_child(player)
		player.play()
		umbrella_pool.append({
			"player": player,
			"generator": gen,
			"playback": player.get_stream_playback(),
			"assigned_npc": null,
			"filter": 0.0,
		})

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	var cam_pos := cam.global_position if cam else Vector3.ZERO
	for npc_data in npcs:
		var node: Node3D = npc_data["node"]
		var speed: float = npc_data["speed"]
		var axis: String = npc_data["axis"]
		var direction: float = npc_data["direction"]
		var anim: HumanoidAnimation = npc_data["anim"]

		# Stop-and-look behavior
		var is_stopped: bool = npc_data["is_stopped"]
		if is_stopped:
			npc_data["stop_duration"] -= delta
			if npc_data["stop_duration"] <= 0.0:
				npc_data["is_stopped"] = false
				npc_data["stop_timer"] = stop_rng.randf_range(10.0, 30.0)
		else:
			npc_data["stop_timer"] -= delta
			if npc_data["stop_timer"] <= 0.0:
				npc_data["is_stopped"] = true
				npc_data["stop_duration"] = stop_rng.randf_range(2.0, 5.0)

		var current_speed := 0.0 if is_stopped else speed

		# Always move (even if culled, to keep positions consistent)
		if not is_stopped:
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

		# Distance-based culling
		var dist := node.global_position.distance_to(cam_pos)
		if dist > 80.0:
			node.visible = false
			continue
		else:
			node.visible = true

		# Update walk animation (only for visible NPCs)
		anim.update(delta, current_speed)

		# Track footstep triggers via walk cycle zero-crossing
		if current_speed > 0.5:
			var cur_sign := signf(sin(anim.walk_cycle))
			var prev_sign: float = npc_data.get("step_sign", 1.0)
			if cur_sign != prev_sign and cur_sign != 0.0:
				npc_data["step_triggered"] = true
			else:
				npc_data["step_triggered"] = false
			npc_data["step_sign"] = cur_sign
		else:
			npc_data["step_triggered"] = false

		# Foot splash when walking
		var splash: GPUParticles3D = npc_data.get("splash")
		if splash and is_instance_valid(splash):
			splash.emitting = not is_stopped

		# Toggle cigarette smoke + smoking arm animation
		var smoke: GPUParticles3D = npc_data["smoke"]
		if smoke:
			smoke.emitting = is_stopped
			if is_stopped:
				# Animate right arm raising to mouth (drag cycle ~4s)
				npc_data["smoke_timer"] = npc_data.get("smoke_timer", 0.0) + delta
				var st: float = npc_data["smoke_timer"]
				var cycle := fmod(st, 4.0)
				var rs := node.get_node_or_null("Model/RightShoulder")
				if rs:
					var target_rot := 0.0
					if cycle < 1.0:
						target_rot = -cycle * 0.8  # raise
					elif cycle < 1.5:
						target_rot = -0.8  # hold at mouth
					elif cycle < 2.5:
						target_rot = -0.8 + (cycle - 1.5) * 0.8  # lower
					rs.rotation.x = lerpf(rs.rotation.x, target_rot, 5.0 * delta)

		# Phone glow: only visible when stopped
		if npc_data["has_phone"]:
			var pl: OmniLight3D = npc_data["phone_light"]
			if pl and is_instance_valid(pl):
				pl.light_energy = 0.8 if is_stopped else 0.0
			var phone_mesh := node.get_node_or_null("Model/Phone")
			if phone_mesh:
				phone_mesh.visible = is_stopped

		# Head tracking: stopped NPCs look at player when nearby
		var head_node := node.get_node_or_null("Model/Head")
		if head_node and is_instance_valid(head_node) and head_node.is_inside_tree():
			if is_stopped and dist < 8.0:
				var to_player := cam_pos - node.global_position
				to_player.y = 0.0
				if to_player.length_squared() > 0.01:
					# Get angle relative to NPC facing direction
					var local_dir := node.global_transform.basis.inverse() * to_player.normalized()
					var target_yaw := atan2(local_dir.x, -local_dir.z)
					target_yaw = clampf(target_yaw, -1.0, 1.0)  # ~57 degree max
					head_node.rotation.y = lerpf(head_node.rotation.y, target_yaw, 3.0 * delta)
					# Slight downward tilt when looking
					head_node.rotation.x = lerpf(head_node.rotation.x, -0.15, 3.0 * delta)
			else:
				# Return to neutral
				head_node.rotation.y = lerpf(head_node.rotation.y, 0.0, 2.0 * delta)
				head_node.rotation.x = lerpf(head_node.rotation.x, 0.0, 2.0 * delta)

		# Conversation gestures: active speaker raises arm emphatically
		if npc_data.get("is_conversation", false):
			npc_data["gesture_timer"] = npc_data.get("gesture_timer", 0.0) + delta
			var gt: float = npc_data["gesture_timer"]
			var is_gesturing: bool = npc_data.get("gesture_active", false)
			# Switch who's talking every 3-5 seconds
			if gt > 4.0:
				npc_data["gesture_timer"] = 0.0
				npc_data["gesture_active"] = not is_gesturing
				is_gesturing = not is_gesturing
			if is_gesturing and dist < 80.0:
				var rs2 := node.get_node_or_null("Model/RightShoulder")
				if rs2:
					# Emphatic arm wave: forward + slight oscillation
					var wave := sin(gt * 3.5) * 0.2
					rs2.rotation.x = lerpf(rs2.rotation.x, -0.6 + wave, 4.0 * delta)
					rs2.rotation.z = lerpf(rs2.rotation.z, -0.3, 3.0 * delta)
				# Slight head nod while talking
				if head_node and is_instance_valid(head_node) and head_node.is_inside_tree():
					var nod := sin(gt * 2.5) * 0.08
					head_node.rotation.x = lerpf(head_node.rotation.x, nod, 3.0 * delta)
			elif not is_gesturing and dist < 80.0:
				# Listener: slight head movement (occasional nod)
				if head_node and is_instance_valid(head_node) and head_node.is_inside_tree():
					var listen_nod := sin(gt * 1.5) * 0.05
					head_node.rotation.x = lerpf(head_node.rotation.x, listen_nod - 0.05, 2.0 * delta)
				var rs3 := node.get_node_or_null("Model/RightShoulder")
				if rs3:
					rs3.rotation.x = lerpf(rs3.rotation.x, 0.0, 3.0 * delta)
					rs3.rotation.z = lerpf(rs3.rotation.z, 0.0, 3.0 * delta)

	# Update umbrella rain patter audio
	_update_umbrella_audio(cam_pos)

	# Update NPC footstep positional audio
	_update_npc_step_audio(cam_pos)

func _update_umbrella_audio(cam_pos: Vector3) -> void:
	# Find nearest umbrella NPCs to camera
	var umbrella_npcs: Array[Dictionary] = []
	for npc_data in npcs:
		if not npc_data["has_umbrella"]:
			continue
		var npc_node: Node3D = npc_data["node"]
		var d := npc_node.global_position.distance_to(cam_pos)
		if d < UMBRELLA_AUDIO_RANGE:
			umbrella_npcs.append({"npc": npc_data, "dist": d})
	# Sort by distance
	umbrella_npcs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["dist"] < b["dist"])
	# Assign pool slots to nearest umbrella NPCs
	for i in range(UMBRELLA_AUDIO_POOL_SIZE):
		var slot: Dictionary = umbrella_pool[i]
		var player: AudioStreamPlayer3D = slot["player"]
		var playback: AudioStreamGeneratorPlayback = slot["playback"]
		if i < umbrella_npcs.size():
			var npc_node: Node3D = umbrella_npcs[i]["npc"]["node"]
			player.global_position = npc_node.global_position + Vector3(0, 1.9, 0)
			# Fill buffer with metallic rain patter (high-pass noise)
			if playback:
				var frames := playback.get_frames_available()
				var filt: float = slot["filter"]
				for _f in range(frames):
					var noise := umbrella_rng.randf_range(-1.0, 1.0)
					# High-pass filter for metallic plink
					var hp := noise - filt
					filt = noise
					# Sparse patter: mostly quiet, occasional taps
					var tap := 0.0
					if absf(hp) > 0.8:
						tap = hp * 0.5
					var sample := tap * 0.25
					playback.push_frame(Vector2(sample, sample))
				slot["filter"] = filt
		else:
			# No umbrella NPC for this slot - silence
			if playback:
				var frames := playback.get_frames_available()
				for _f in range(frames):
					playback.push_frame(Vector2.ZERO)

func _setup_npc_step_audio() -> void:
	step_audio_rng.seed = 4567
	for _i in range(NPC_STEP_POOL_SIZE):
		var player := AudioStreamPlayer3D.new()
		var gen := AudioStreamGenerator.new()
		gen.mix_rate = 22050.0
		gen.buffer_length = 0.1
		player.stream = gen
		player.volume_db = -22.0
		player.max_distance = NPC_STEP_RANGE
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		player.unit_size = 4.0
		add_child(player)
		player.play()
		npc_step_pool.append({
			"player": player,
			"generator": gen,
			"playback": player.get_stream_playback(),
			"burst_remaining": 0,
			"burst_pitch": 1.0,
			"burst_wet": false,
			"filter": 0.0,
		})

func _update_npc_step_audio(cam_pos: Vector3) -> void:
	# Find nearest walking visible NPCs
	var walking_npcs: Array[Dictionary] = []
	for npc_data in npcs:
		if npc_data["is_stopped"]:
			continue
		var npc_node: Node3D = npc_data["node"]
		if not npc_node.visible:
			continue
		var d := npc_node.global_position.distance_to(cam_pos)
		if d < NPC_STEP_RANGE:
			walking_npcs.append({"npc": npc_data, "dist": d})
	walking_npcs.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["dist"] < b["dist"])

	for i in range(NPC_STEP_POOL_SIZE):
		var slot: Dictionary = npc_step_pool[i]
		var player: AudioStreamPlayer3D = slot["player"]
		var playback: AudioStreamGeneratorPlayback = slot["playback"]
		if i < walking_npcs.size():
			var npc_data: Dictionary = walking_npcs[i]["npc"]
			var npc_node: Node3D = npc_data["node"]
			player.global_position = npc_node.global_position + Vector3(0, 0.05, 0)
			# Trigger footstep burst on walk cycle crossing
			if npc_data.get("step_triggered", false):
				slot["burst_remaining"] = 600
				slot["burst_pitch"] = step_audio_rng.randf_range(0.8, 1.2)
				slot["burst_wet"] = step_audio_rng.randf() < 0.4
			# Fill buffer
			if playback:
				var frames := playback.get_frames_available()
				var filt: float = slot["filter"]
				for _f in range(frames):
					var sample := 0.0
					if slot["burst_remaining"] > 0:
						var prog := 1.0 - float(slot["burst_remaining"]) / 600.0
						var env := (1.0 - prog) * (1.0 - prog)
						var noise := step_audio_rng.randf_range(-1.0, 1.0)
						if slot["burst_wet"]:
							var splash := noise * 0.8
							filt = filt * 0.55 + splash * 0.45
							sample = filt * env * 0.15
						else:
							var thump := sin(prog * 80.0 * slot["burst_pitch"] * TAU) * 0.5
							sample = (noise * 0.5 + thump * 0.5) * env * 0.12
						slot["burst_remaining"] -= 1
					playback.push_frame(Vector2(sample, sample))
				slot["filter"] = filt
		else:
			# No walking NPC for this slot - silence
			if playback:
				var frames := playback.get_frames_available()
				for _f in range(frames):
					playback.push_frame(Vector2.ZERO)

func _spawn_npc(rng: RandomNumberGenerator, _index: int) -> void:
	var npc := Node3D.new()

	# Pick a street to walk on
	var axis := "x" if rng.randf() < 0.5 else "z"
	var lane_index := rng.randi_range(-grid_size, grid_size - 1)
	var lane_pos := lane_index * cell_stride + block_size * 0.5 + street_width * 0.3
	# Offset to sidewalk side
	var sidewalk_offset := rng.randf_range(-1.5, 1.5)
	var along_pos := rng.randf_range(-grid_extent, grid_extent)
	var direction := 1.0 if rng.randf() < 0.5 else -1.0
	var speed := rng.randf_range(1.5, 3.5)

	if axis == "x":
		npc.position = Vector3(along_pos, 0, lane_pos + sidewalk_offset)
		npc.rotation.y = 0.0 if direction > 0 else PI
	else:
		npc.position = Vector3(lane_pos + sidewalk_offset, 0, along_pos)
		npc.rotation.y = PI * 0.5 if direction > 0 else -PI * 0.5

	# Build humanoid model with height/build variety
	var model := Node3D.new()
	model.name = "Model"
	var height_scale := rng.randf_range(0.85, 1.15)
	model.scale = Vector3(height_scale, height_scale, height_scale)
	npc.add_child(model)

	var skin_color := skin_colors[rng.randi_range(0, skin_colors.size() - 1)]
	var jacket_color := jacket_colors[rng.randi_range(0, jacket_colors.size() - 1)]
	var pants_color := Color(jacket_color.r * 0.8, jacket_color.g * 0.8, jacket_color.b * 0.8)
	var accent := accent_colors[rng.randi_range(0, accent_colors.size() - 1)]

	# Head
	_add_body_part(model, "Head", SphereMesh.new(), Vector3(0, 1.55, 0), skin_color)
	(model.get_node("Head").mesh as SphereMesh).radius = 0.18
	(model.get_node("Head").mesh as SphereMesh).height = 0.36

	# Torso
	_add_body_part(model, "Torso", BoxMesh.new(), Vector3(0, 1.1, 0), jacket_color,
		Vector3(0.5, 0.55, 0.28))

	# Accent stripe
	_add_body_part(model, "AccentStripe", BoxMesh.new(), Vector3(0, 1.05, 0.141), accent,
		Vector3(0.3, 0.06, 0.01), true, accent, 2.0)

	# Hips
	_add_body_part(model, "Hips", BoxMesh.new(), Vector3(0, 0.75, 0), pants_color,
		Vector3(0.45, 0.2, 0.25))

	# Left arm (pivot-based)
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

	# Setup animation
	var anim := HumanoidAnimation.new()
	anim.setup(model)

	# Umbrella (25% of NPCs carry one)
	var has_umbrella := false
	if rng.randf() < 0.25:
		has_umbrella = true
		var umbrella := Node3D.new()
		umbrella.name = "Umbrella"
		umbrella.position = Vector3(0.15, 1.85, 0)
		# Handle (thin cylinder)
		var handle := MeshInstance3D.new()
		var handle_mesh := CylinderMesh.new()
		handle_mesh.top_radius = 0.02
		handle_mesh.bottom_radius = 0.02
		handle_mesh.height = 0.5
		handle.mesh = handle_mesh
		handle.position = Vector3(0, -0.15, 0)
		var handle_color := Color(0.15, 0.1, 0.08)
		var handle_mat := ShaderMaterial.new()
		handle_mat.shader = ps1_shader
		handle_mat.set_shader_parameter("albedo_color", handle_color)
		handle_mat.set_shader_parameter("vertex_snap_intensity", 4.0)
		handle_mat.set_shader_parameter("color_depth", 12.0)
		handle_mat.set_shader_parameter("fog_color", Color(0.05, 0.03, 0.1, 1.0))
		handle_mat.set_shader_parameter("fog_distance", 100.0)
		handle_mat.set_shader_parameter("fog_density", 0.3)
		handle.set_surface_override_material(0, handle_mat)
		umbrella.add_child(handle)
		# Canopy (flattened cone)
		var canopy := MeshInstance3D.new()
		var canopy_mesh := CylinderMesh.new()
		canopy_mesh.top_radius = 0.0
		canopy_mesh.bottom_radius = 0.45
		canopy_mesh.height = 0.12
		canopy.mesh = canopy_mesh
		canopy.position = Vector3(0, 0.1, 0)
		var canopy_tint := jacket_color * 1.2
		var canopy_mat := ShaderMaterial.new()
		canopy_mat.shader = ps1_shader
		canopy_mat.set_shader_parameter("albedo_color", canopy_tint)
		canopy_mat.set_shader_parameter("vertex_snap_intensity", 4.0)
		canopy_mat.set_shader_parameter("color_depth", 12.0)
		canopy_mat.set_shader_parameter("fog_color", Color(0.05, 0.03, 0.1, 1.0))
		canopy_mat.set_shader_parameter("fog_distance", 100.0)
		canopy_mat.set_shader_parameter("fog_density", 0.3)
		canopy.set_surface_override_material(0, canopy_mat)
		umbrella.add_child(canopy)
		model.add_child(umbrella)

	# Phone (20% of non-umbrella NPCs hold a glowing phone)
	var has_phone := false
	var phone_light: OmniLight3D = null
	if not has_umbrella and rng.randf() < 0.20:
		has_phone = true
		# Small emissive rectangle in right hand area
		var phone := MeshInstance3D.new()
		var phone_mesh := BoxMesh.new()
		phone_mesh.size = Vector3(0.06, 0.1, 0.02)
		phone.mesh = phone_mesh
		phone.position = Vector3(0.18, 0.95, 0.15)
		var phone_color := Color(0.6, 0.7, 1.0)
		var phone_mat := ShaderMaterial.new()
		phone_mat.shader = ps1_shader
		phone_mat.set_shader_parameter("albedo_color", phone_color * 0.3)
		phone_mat.set_shader_parameter("vertex_snap_intensity", 4.0)
		phone_mat.set_shader_parameter("color_depth", 12.0)
		phone_mat.set_shader_parameter("fog_color", Color(0.05, 0.03, 0.1, 1.0))
		phone_mat.set_shader_parameter("fog_distance", 100.0)
		phone_mat.set_shader_parameter("fog_density", 0.3)
		phone_mat.set_shader_parameter("emissive", true)
		phone_mat.set_shader_parameter("emission_color", phone_color)
		phone_mat.set_shader_parameter("emission_strength", 3.0)
		phone.set_surface_override_material(0, phone_mat)
		phone.name = "Phone"
		model.add_child(phone)
		# Face glow light
		phone_light = OmniLight3D.new()
		phone_light.light_color = Color(0.5, 0.6, 1.0)
		phone_light.light_energy = 0.8
		phone_light.omni_range = 1.5
		phone_light.omni_attenuation = 1.5
		phone_light.shadow_enabled = false
		phone_light.position = Vector3(0.18, 0.95, 0.15)
		phone_light.name = "PhoneLight"
		model.add_child(phone_light)

	# Cigarette smoke (30% of NPCs are smokers, but not umbrella holders or phone users)
	var smoke_particles: GPUParticles3D = null
	if not has_umbrella and not has_phone and rng.randf() < 0.30:
		smoke_particles = GPUParticles3D.new()
		smoke_particles.position = Vector3(0.1, 1.6, 0.15)
		smoke_particles.amount = 8
		smoke_particles.lifetime = 2.0
		smoke_particles.emitting = false
		smoke_particles.visibility_aabb = AABB(Vector3(-1, -1, -1), Vector3(2, 3, 2))
		var smoke_mat := ParticleProcessMaterial.new()
		smoke_mat.direction = Vector3(0.2, 1, 0)
		smoke_mat.spread = 15.0
		smoke_mat.initial_velocity_min = 0.3
		smoke_mat.initial_velocity_max = 0.6
		smoke_mat.gravity = Vector3(0, 0.2, 0)
		smoke_mat.damping_min = 0.5
		smoke_mat.damping_max = 1.0
		smoke_mat.scale_min = 0.02
		smoke_mat.scale_max = 0.08
		smoke_mat.color = Color(0.6, 0.6, 0.7, 0.15)
		smoke_particles.process_material = smoke_mat
		var smoke_mesh := SphereMesh.new()
		smoke_mesh.radius = 0.04
		smoke_mesh.height = 0.08
		smoke_particles.draw_pass_1 = smoke_mesh
		model.add_child(smoke_particles)

	# Hat/beanie (15% of NPCs)
	if rng.randf() < 0.15:
		var hat_type := rng.randi_range(0, 1)
		if hat_type == 0:
			# Beanie - slightly wider than head, sits on top
			_add_body_part(model, "Hat", BoxMesh.new(), Vector3(0, 1.72, 0),
				jacket_color * 1.3, Vector3(0.34, 0.12, 0.34))
		else:
			# Flat cap - wider brim, flatter
			_add_body_part(model, "Hat", BoxMesh.new(), Vector3(0, 1.7, 0.05),
				jacket_color * 0.8, Vector3(0.38, 0.06, 0.4))

	# Backpack/messenger bag (10% of non-umbrella NPCs)
	if not has_umbrella and rng.randf() < 0.10:
		var bag_type := rng.randi_range(0, 1)
		if bag_type == 0:
			# Backpack on back
			_add_body_part(model, "Backpack", BoxMesh.new(), Vector3(0, 1.05, -0.22),
				Color(jacket_color.r * 0.7, jacket_color.g * 0.7, jacket_color.b * 0.7),
				Vector3(0.3, 0.35, 0.15))
		else:
			# Messenger bag on side
			_add_body_part(model, "Bag", BoxMesh.new(), Vector3(-0.28, 0.85, 0.05),
				Color(0.15, 0.12, 0.08), Vector3(0.08, 0.25, 0.2))

	# Glowing wristwatch (8% of NPCs)
	if rng.randf() < 0.08:
		var watch_col_idx := rng.randi_range(0, 1)
		var watch_col := Color(0.0, 0.8, 0.4) if watch_col_idx == 0 else Color(0.3, 0.6, 1.0)
		var left_lower := left_elbow.get_node_or_null("LeftLowerArm")
		if left_lower:
			_add_body_part(left_lower, "Watch", BoxMesh.new(), Vector3(0.05, -0.08, 0.06),
				watch_col * 0.3, Vector3(0.04, 0.03, 0.06), true, watch_col, 2.0)

	# Boots (20% of NPCs, adds ground-level detail)
	if rng.randf() < 0.20:
		var boot_color := Color(0.08, 0.06, 0.05)
		for boot_side in [-0.08, 0.08]:
			_add_body_part(model, "Boot", BoxMesh.new(),
				Vector3(boot_side, 0.04, 0.02), boot_color, Vector3(0.14, 0.08, 0.2))

	# Scarf/neck wrap (12% of NPCs, adds color pop)
	if rng.randf() < 0.12:
		_add_body_part(model, "Scarf", BoxMesh.new(), Vector3(0, 1.38, 0.08),
			accent, Vector3(0.42, 0.06, 0.18), true, accent, 1.5)

	# Hoodie (8% of NPCs without hats)
	var has_hat := model.get_node_or_null("Hat") != null
	if not has_hat and rng.randf() < 0.08:
		# Hood draped behind/over head
		_add_body_part(model, "Hood", BoxMesh.new(), Vector3(0, 1.6, -0.12),
			jacket_color * 1.1, Vector3(0.4, 0.25, 0.22))

	# Earbuds (5% of NPCs - tiny white dots on ears)
	if rng.randf() < 0.05:
		var bud_col := Color(0.9, 0.9, 0.95)
		_add_body_part(model, "EarbudL", BoxMesh.new(), Vector3(-0.18, 1.55, 0),
			bud_col * 0.5, Vector3(0.04, 0.04, 0.04), true, bud_col, 1.5)
		_add_body_part(model, "EarbudR", BoxMesh.new(), Vector3(0.18, 1.55, 0),
			bud_col * 0.5, Vector3(0.04, 0.04, 0.04), true, bud_col, 1.5)

	# Cigarette glow (6% of NPCs - orange dot near mouth)
	if rng.randf() < 0.06:
		var cig_col := Color(1.0, 0.5, 0.1)
		var right_lower := right_elbow.get_node_or_null("RightLowerArm")
		if right_lower:
			_add_body_part(right_lower, "Cigarette", BoxMesh.new(), Vector3(-0.04, -0.12, 0.08),
				cig_col * 0.3, Vector3(0.02, 0.02, 0.06), true, cig_col, 2.5)

	# Foot splash particles (wet ground)
	var npc_splash := GPUParticles3D.new()
	npc_splash.amount = 6
	npc_splash.lifetime = 0.25
	npc_splash.emitting = false
	npc_splash.visibility_aabb = AABB(Vector3(-1, -0.5, -1), Vector3(2, 2, 2))
	var sp_mat := ParticleProcessMaterial.new()
	sp_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sp_mat.emission_box_extents = Vector3(0.15, 0, 0.15)
	sp_mat.direction = Vector3(0, 1, 0)
	sp_mat.spread = 40.0
	sp_mat.initial_velocity_min = 0.5
	sp_mat.initial_velocity_max = 1.5
	sp_mat.gravity = Vector3(0, -8.0, 0)
	sp_mat.scale_min = 0.015
	sp_mat.scale_max = 0.04
	sp_mat.color = Color(0.4, 0.45, 0.6, 0.2)
	npc_splash.process_material = sp_mat
	var sp_mesh := SphereMesh.new()
	sp_mesh.radius = 0.02
	sp_mesh.height = 0.04
	npc_splash.draw_pass_1 = sp_mesh
	npc_splash.position = Vector3(0, 0.03, 0)
	npc.add_child(npc_splash)

	add_child(npc)

	npcs.append({
		"node": npc,
		"speed": speed,
		"base_speed": speed,
		"axis": axis,
		"direction": direction,
		"anim": anim,
		"stop_timer": rng.randf_range(8.0, 25.0),
		"stop_duration": 0.0,
		"is_stopped": false,
		"smoke": smoke_particles,
		"has_umbrella": has_umbrella,
		"has_phone": has_phone,
		"phone_light": phone_light,
		"splash": npc_splash,
	})

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

func _spawn_conversation_groups(_rng: RandomNumberGenerator) -> void:
	# Spawn 3 groups of 2-3 NPCs standing together chatting
	var group_rng := RandomNumberGenerator.new()
	group_rng.seed = 8888
	for _g in range(3):
		var group_size := group_rng.randi_range(2, 3)
		# Pick a random street intersection for the group
		var gx := group_rng.randi_range(-grid_size + 1, grid_size - 2)
		var gz := group_rng.randi_range(-grid_size + 1, grid_size - 2)
		var center_x := gx * cell_stride + block_size * 0.5 + street_width * 0.3
		var center_z := gz * cell_stride + block_size * 0.5 + street_width * 0.3
		var center := Vector3(center_x, 0, center_z)

		for gi in range(group_size):
			var angle := (float(gi) / float(group_size)) * TAU
			var offset := Vector3(cos(angle) * 0.8, 0, sin(angle) * 0.8)
			var npc_pos := center + offset
			# Face toward center
			var face_angle := atan2(center.x - npc_pos.x, center.z - npc_pos.z)

			var npc := Node3D.new()
			npc.position = npc_pos
			npc.rotation.y = face_angle

			var model := Node3D.new()
			model.name = "Model"
			var height_scale := group_rng.randf_range(0.9, 1.1)
			model.scale = Vector3(height_scale, height_scale, height_scale)
			npc.add_child(model)

			var skin_color := skin_colors[group_rng.randi_range(0, skin_colors.size() - 1)]
			var jacket_color := jacket_colors[group_rng.randi_range(0, jacket_colors.size() - 1)]
			var pants_color := Color(jacket_color.r * 0.8, jacket_color.g * 0.8, jacket_color.b * 0.8)
			var accent := accent_colors[group_rng.randi_range(0, accent_colors.size() - 1)]

			_add_body_part(model, "Head", SphereMesh.new(), Vector3(0, 1.55, 0), skin_color)
			(model.get_node("Head").mesh as SphereMesh).radius = 0.18
			(model.get_node("Head").mesh as SphereMesh).height = 0.36
			_add_body_part(model, "Torso", BoxMesh.new(), Vector3(0, 1.1, 0), jacket_color,
				Vector3(0.5, 0.55, 0.28))
			_add_body_part(model, "AccentStripe", BoxMesh.new(), Vector3(0, 1.05, 0.141), accent,
				Vector3(0.3, 0.06, 0.01), true, accent, 2.0)
			_add_body_part(model, "Hips", BoxMesh.new(), Vector3(0, 0.75, 0), pants_color,
				Vector3(0.45, 0.2, 0.25))

			var ls := _add_pivot(model, "LeftShoulder", Vector3(-0.32, 1.3, 0))
			_add_body_part(ls, "LeftUpperArm", BoxMesh.new(), Vector3(0, -0.15, 0),
				jacket_color, Vector3(0.13, 0.3, 0.13))
			var le := _add_pivot(ls, "LeftElbow", Vector3(0, -0.3, 0))
			_add_body_part(le, "LeftLowerArm", BoxMesh.new(), Vector3(0, -0.15, 0),
				skin_color, Vector3(0.12, 0.3, 0.12))
			var rs := _add_pivot(model, "RightShoulder", Vector3(0.32, 1.3, 0))
			_add_body_part(rs, "RightUpperArm", BoxMesh.new(), Vector3(0, -0.15, 0),
				jacket_color, Vector3(0.13, 0.3, 0.13))
			var re := _add_pivot(rs, "RightElbow", Vector3(0, -0.3, 0))
			_add_body_part(re, "RightLowerArm", BoxMesh.new(), Vector3(0, -0.15, 0),
				skin_color, Vector3(0.12, 0.3, 0.12))
			var lh := _add_pivot(model, "LeftHip", Vector3(-0.12, 0.65, 0))
			_add_body_part(lh, "LeftUpperLeg", BoxMesh.new(), Vector3(0, -0.17, 0),
				pants_color, Vector3(0.15, 0.33, 0.15))
			var lk := _add_pivot(lh, "LeftKnee", Vector3(0, -0.33, 0))
			_add_body_part(lk, "LeftLowerLeg", BoxMesh.new(), Vector3(0, -0.17, 0),
				pants_color, Vector3(0.14, 0.33, 0.14))
			var rh := _add_pivot(model, "RightHip", Vector3(0.12, 0.65, 0))
			_add_body_part(rh, "RightUpperLeg", BoxMesh.new(), Vector3(0, -0.17, 0),
				pants_color, Vector3(0.15, 0.33, 0.15))
			var rk := _add_pivot(rh, "RightKnee", Vector3(0, -0.33, 0))
			_add_body_part(rk, "RightLowerLeg", BoxMesh.new(), Vector3(0, -0.17, 0),
				pants_color, Vector3(0.14, 0.33, 0.14))

			var anim := HumanoidAnimation.new()
			anim.setup(model)
			add_child(npc)

			# Add to npcs array as permanently stopped
			npcs.append({
				"node": npc,
				"speed": 0.0,
				"base_speed": 0.0,
				"axis": "x",
				"direction": 0.0,
				"anim": anim,
				"stop_timer": 99999.0,
				"stop_duration": 99999.0,
				"is_stopped": true,
				"smoke": null,
				"has_umbrella": false,
				"has_phone": false,
				"phone_light": null,
				"is_conversation": true,
				"gesture_timer": group_rng.randf_range(0.0, 3.0),
				"gesture_active": gi == 0,  # first NPC starts gesturing
			})

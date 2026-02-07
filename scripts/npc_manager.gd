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

		# Weather speed modifier: umbrella holders are slower, others hurry
		var weather_mult := 1.0
		if npc_data.get("has_umbrella", false):
			weather_mult = 0.8
		elif not npc_data.get("is_jogger", false):
			weather_mult = 1.15  # hurrying through rain
		var current_speed := 0.0 if is_stopped else speed * weather_mult

		# Always move (even if culled, to keep positions consistent)
		if not is_stopped:
			if axis == "x":
				node.position.x += current_speed * direction * delta
				if node.position.x > grid_extent:
					node.position.x = -grid_extent
				elif node.position.x < -grid_extent:
					node.position.x = grid_extent
			else:
				node.position.z += current_speed * direction * delta
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

		# Idle weight shifting (subtle lateral sway when stopped)
		if is_stopped:
			npc_data["idle_sway_t"] = npc_data.get("idle_sway_t", 0.0) + delta
			var sway_x := sin(npc_data["idle_sway_t"] * 0.5) * 0.03
			var mdl_ws := node.get_node_or_null("Model")
			if mdl_ws:
				mdl_ws.position.x = lerpf(mdl_ws.position.x, sway_x, 3.0 * delta)
		else:
			var mdl_ws := node.get_node_or_null("Model")
			if mdl_ws and absf(mdl_ws.position.x) > 0.001:
				mdl_ws.position.x = lerpf(mdl_ws.position.x, 0.0, 5.0 * delta)

		# Breathing animation (subtle torso scale pulse when stopped)
		if is_stopped:
			npc_data["breath_t"] = npc_data.get("breath_t", 0.0) + delta
			var torso := node.get_node_or_null("Model/Torso")
			if torso:
				var breath := sin(npc_data["breath_t"] * 2.1) * 0.02
				torso.scale.y = lerpf(torso.scale.y, 1.0 + breath, 4.0 * delta)

		# Hand in pocket override
		if npc_data.get("pocket_hand", false):
			var ls := node.get_node_or_null("Model/LeftShoulder")
			var le := node.get_node_or_null("Model/LeftShoulder/LeftElbow")
			if not is_stopped:
				# Dampens left arm swing while walking
				if ls:
					ls.rotation.x = lerpf(ls.rotation.x, 0.1, 8.0 * delta)
				if le:
					le.rotation.x = lerpf(le.rotation.x, -0.3, 8.0 * delta)
			else:
				# Idle: arm hangs at side, elbow bent into hip
				if ls:
					ls.rotation.x = lerpf(ls.rotation.x, 0.15, 4.0 * delta)
					ls.rotation.z = lerpf(ls.rotation.z, 0.1, 4.0 * delta)
				if le:
					le.rotation.x = lerpf(le.rotation.x, -0.5, 4.0 * delta)

		# Limp override (right leg shorter stride, slight body bob)
		if npc_data.get("has_limp", false) and not is_stopped:
			var rh := node.get_node_or_null("Model/RightHip")
			if rh:
				rh.rotation.x *= 0.4  # reduced right leg swing
			var rk := node.get_node_or_null("Model/RightHip/RightKnee")
			if rk:
				rk.rotation.x *= 0.5
			# Bob up/down on the bad leg
			var mdl := node.get_node_or_null("Model")
			if mdl:
				var limp_bob := sin(anim.walk_cycle) * 0.04
				mdl.position.y = lerpf(mdl.position.y, limp_bob, 10.0 * delta)

		# Jogger forward lean
		if npc_data.get("is_jogger", false) and not is_stopped:
			var mdl2 := node.get_node_or_null("Model")
			if mdl2:
				mdl2.rotation.x = lerpf(mdl2.rotation.x, 0.12, 8.0 * delta)
		elif npc_data.get("is_jogger", false) and is_stopped:
			var mdl2 := node.get_node_or_null("Model")
			if mdl2:
				mdl2.rotation.x = lerpf(mdl2.rotation.x, 0.0, 8.0 * delta)

		# Walk body lean (forward lean + side sway when moving)
		if not npc_data.get("is_jogger", false):
			var mdl_lean := node.get_node_or_null("Model")
			if mdl_lean:
				if not is_stopped:
					var fwd_lean := clampf(current_speed * 0.012, 0.02, 0.08)
					var side_sway := sin(anim.walk_cycle) * 0.025
					mdl_lean.rotation.x = lerpf(mdl_lean.rotation.x, fwd_lean, 6.0 * delta)
					mdl_lean.rotation.z = lerpf(mdl_lean.rotation.z, side_sway, 8.0 * delta)
				elif not npc_data.get("has_limp", false):
					mdl_lean.rotation.x = lerpf(mdl_lean.rotation.x, 0.0, 4.0 * delta)
					mdl_lean.rotation.z = lerpf(mdl_lean.rotation.z, 0.0, 4.0 * delta)

		# Arm swing amplitude variation (per-NPC personality)
		if not is_stopped:
			var sm: float = npc_data.get("swing_mult", 1.0)
			if sm != 1.0:
				var ls_swing := node.get_node_or_null("Model/LeftShoulder")
				var rs_swing := node.get_node_or_null("Model/RightShoulder")
				if ls_swing and not npc_data.get("pocket_hand", false):
					ls_swing.rotation.x *= sm
				if rs_swing and not npc_data.get("smoke") and not npc_data.get("has_phone", false):
					rs_swing.rotation.x *= sm

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

		# Phone glow: only visible when stopped, arm raises to check
		if npc_data["has_phone"]:
			var pl: OmniLight3D = npc_data["phone_light"]
			if pl and is_instance_valid(pl):
				pl.light_energy = 0.8 if is_stopped else 0.0
			var phone_mesh := node.get_node_or_null("Model/Phone")
			if phone_mesh:
				phone_mesh.visible = is_stopped
			# Raise right arm when stopped (checking phone pose)
			if is_stopped and not smoke:
				var phone_rs := node.get_node_or_null("Model/RightShoulder")
				if phone_rs:
					var phone_target := -0.6  # arm raised to face level
					phone_rs.rotation.x = lerpf(phone_rs.rotation.x, phone_target, 3.0 * delta)

		# Newspaper reading pose (both arms forward, paper visible)
		if npc_data.get("has_newspaper", false):
			var paper := node.get_node_or_null("Model/Newspaper")
			if paper:
				paper.visible = is_stopped
			if is_stopped:
				var nls := node.get_node_or_null("Model/LeftShoulder")
				var nrs := node.get_node_or_null("Model/RightShoulder")
				if nls:
					nls.rotation.x = lerpf(nls.rotation.x, -0.5, 4.0 * delta)
				if nrs:
					nrs.rotation.x = lerpf(nrs.rotation.x, -0.5, 4.0 * delta)
				var nle := node.get_node_or_null("Model/LeftShoulder/LeftElbow")
				var nre := node.get_node_or_null("Model/RightShoulder/RightElbow")
				if nle:
					nle.rotation.x = lerpf(nle.rotation.x, -0.7, 4.0 * delta)
				if nre:
					nre.rotation.x = lerpf(nre.rotation.x, -0.7, 4.0 * delta)

		# Shoulder shrug idle gesture (15% of NPCs, periodic when stopped)
		if npc_data.get("does_shrug", false) and is_stopped:
			npc_data["shrug_clock"] = npc_data.get("shrug_clock", 0.0) + delta
			var sclock: float = npc_data["shrug_clock"]
			var shrug_cycle := fmod(sclock, 6.0)  # shrug every 6s
			var shrug_y := 0.0
			if shrug_cycle < 0.4:
				shrug_y = shrug_cycle / 0.4 * 0.06  # raise
			elif shrug_cycle < 0.8:
				shrug_y = 0.06  # hold
			elif shrug_cycle < 1.2:
				shrug_y = (1.2 - shrug_cycle) / 0.4 * 0.06  # lower
			var sls := node.get_node_or_null("Model/LeftShoulder")
			var srs := node.get_node_or_null("Model/RightShoulder")
			if sls:
				sls.position.y = lerpf(sls.position.y, 1.3 + shrug_y, 8.0 * delta)
			if srs:
				srs.position.y = lerpf(srs.position.y, 1.3 + shrug_y, 8.0 * delta)

		# Head scratch idle gesture (10% of NPCs, periodic when stopped)
		if npc_data.get("does_scratch", false) and is_stopped and not npc_data["has_phone"] and not npc_data.get("has_newspaper", false) and not npc_data["smoke"]:
			npc_data["scratch_clock"] = npc_data.get("scratch_clock", 0.0) + delta
			var scratch_cycle := fmod(npc_data["scratch_clock"], 8.0)
			if scratch_cycle < 2.0:
				var scratch_rs := node.get_node_or_null("Model/RightShoulder")
				var scratch_re := node.get_node_or_null("Model/RightShoulder/RightElbow")
				if scratch_rs:
					var target_sh := -0.9
					if scratch_cycle < 0.4:
						target_sh = -0.9 * (scratch_cycle / 0.4)
					elif scratch_cycle > 1.6:
						target_sh = -0.9 * ((2.0 - scratch_cycle) / 0.4)
					# Slight oscillation for scratching motion
					target_sh += sin(scratch_cycle * 12.0) * 0.05
					scratch_rs.rotation.x = lerpf(scratch_rs.rotation.x, target_sh, 6.0 * delta)
				if scratch_re:
					var target_el := -1.0
					if scratch_cycle < 0.4:
						target_el = -1.0 * (scratch_cycle / 0.4)
					elif scratch_cycle > 1.6:
						target_el = -1.0 * ((2.0 - scratch_cycle) / 0.4)
					scratch_re.rotation.x = lerpf(scratch_re.rotation.x, target_el, 6.0 * delta)

		# Arms crossed idle pose (12% of NPCs without accessories)
		if npc_data.get("arms_crossed", false) and is_stopped and not npc_data["has_phone"] and not npc_data.get("has_newspaper", false) and not npc_data["smoke"] and not npc_data["has_umbrella"]:
			var acls := node.get_node_or_null("Model/LeftShoulder")
			var acrs := node.get_node_or_null("Model/RightShoulder")
			var acle := node.get_node_or_null("Model/LeftShoulder/LeftElbow")
			var acre := node.get_node_or_null("Model/RightShoulder/RightElbow")
			if acls:
				acls.rotation.x = lerpf(acls.rotation.x, -0.3, 4.0 * delta)
			if acrs:
				acrs.rotation.x = lerpf(acrs.rotation.x, -0.3, 4.0 * delta)
			if acle:
				acle.rotation.x = lerpf(acle.rotation.x, -1.2, 4.0 * delta)
			if acre:
				acre.rotation.x = lerpf(acre.rotation.x, -1.2, 4.0 * delta)

		# Looking up at rain (5% of NPCs without umbrella, periodic when stopped)
		if npc_data.get("looks_at_rain", false) and is_stopped and not npc_data["has_umbrella"]:
			npc_data["rain_look_clock"] = npc_data.get("rain_look_clock", 0.0) + delta
			var rlc: float = npc_data["rain_look_clock"]
			var rain_look_cycle := fmod(rlc, 10.0)
			if rain_look_cycle > 7.0 and rain_look_cycle < 9.5:
				# Tilt head up to look at sky
				var head := node.get_node_or_null("Model/Head")
				if head:
					var look_progress := (rain_look_cycle - 7.0) / 2.5
					var look_up := 0.4
					if look_progress < 0.2:
						look_up = 0.4 * (look_progress / 0.2)
					elif look_progress > 0.8:
						look_up = 0.4 * ((1.0 - look_progress) / 0.2)
					head.rotation.x = lerpf(head.rotation.x, look_up, 3.0 * delta)

		# Check watch gesture (NPCs with wristwatch, periodic when stopped)
		var has_watch := node.get_node_or_null("Model/LeftShoulder/LeftElbow/LeftLowerArm/Watch") != null
		if has_watch and is_stopped and not npc_data["has_phone"] and not npc_data.get("has_newspaper", false):
			npc_data["watch_clock"] = npc_data.get("watch_clock", 0.0) + delta
			var watch_cycle := fmod(npc_data["watch_clock"], 12.0)
			if watch_cycle < 2.0:
				var wls := node.get_node_or_null("Model/LeftShoulder")
				var wle := node.get_node_or_null("Model/LeftShoulder/LeftElbow")
				if wls and wle:
					var raise := 0.0
					var bend := 0.0
					if watch_cycle < 0.5:
						raise = (watch_cycle / 0.5) * -0.7
						bend = (watch_cycle / 0.5) * -1.3
					elif watch_cycle < 1.5:
						raise = -0.7
						bend = -1.3
					else:
						raise = -0.7 * ((2.0 - watch_cycle) / 0.5)
						bend = -1.3 * ((2.0 - watch_cycle) / 0.5)
					wls.rotation.x = lerpf(wls.rotation.x, raise, 6.0 * delta)
					wle.rotation.x = lerpf(wle.rotation.x, bend, 6.0 * delta)

		# Yawn gesture (5% of idle NPCs, periodic)
		if npc_data.get("does_yawn", false) and is_stopped and not npc_data["has_phone"] and not npc_data.get("has_newspaper", false) and not npc_data["smoke"]:
			npc_data["yawn_clock"] = npc_data.get("yawn_clock", 0.0) + delta
			var yawn_cycle := fmod(npc_data["yawn_clock"], 15.0)
			if yawn_cycle < 2.0:
				var yhead := node.get_node_or_null("Model/Head")
				if yhead:
					var yaw_tilt := 0.0
					var yaw_scale := 1.0
					if yawn_cycle < 0.4:
						yaw_tilt = (yawn_cycle / 0.4) * 0.3
						yaw_scale = 1.0 + (yawn_cycle / 0.4) * 0.1
					elif yawn_cycle < 1.4:
						yaw_tilt = 0.3
						yaw_scale = 1.1
					elif yawn_cycle < 2.0:
						yaw_tilt = 0.3 * ((2.0 - yawn_cycle) / 0.6)
						yaw_scale = 1.1 - 0.1 * ((yawn_cycle - 1.4) / 0.6)
					yhead.rotation.x = lerpf(yhead.rotation.x, yaw_tilt, 5.0 * delta)
					yhead.scale.y = lerpf(yhead.scale.y, yaw_scale, 5.0 * delta)
			else:
				var yhead := node.get_node_or_null("Model/Head")
				if yhead and absf(yhead.scale.y - 1.0) > 0.001:
					yhead.scale.y = lerpf(yhead.scale.y, 1.0, 5.0 * delta)

		# Head tracking: stopped NPCs look at player when nearby
		# Also react to sprinting player passing by
		var head_node := node.get_node_or_null("Model/Head")
		var player_node := get_node_or_null("../Player")
		var player_sprinting := false
		if player_node and player_node is CharacterBody3D:
			var pvel := (player_node as CharacterBody3D).velocity
			player_sprinting = Vector2(pvel.x, pvel.z).length() > 6.0
		if head_node and is_instance_valid(head_node) and head_node.is_inside_tree():
			var should_look := (is_stopped and dist < 8.0) or (player_sprinting and dist < 4.0)
			if should_look:
				var to_player := cam_pos - node.global_position
				to_player.y = 0.0
				if to_player.length_squared() > 0.01:
					var local_dir := node.global_transform.basis.inverse() * to_player.normalized()
					var target_yaw := atan2(local_dir.x, -local_dir.z)
					target_yaw = clampf(target_yaw, -1.0, 1.0)
					var look_speed := 5.0 if player_sprinting else 3.0
					head_node.rotation.y = lerpf(head_node.rotation.y, target_yaw, look_speed * delta)
					head_node.rotation.x = lerpf(head_node.rotation.x, -0.15, 3.0 * delta)
			else:
				head_node.rotation.y = lerpf(head_node.rotation.y, 0.0, 2.0 * delta)
				head_node.rotation.x = lerpf(head_node.rotation.x, 0.0, 2.0 * delta)

		# Greeting nod (10% of NPCs, brief head dip when player passes within 3m)
		if npc_data.get("does_greet", false) and is_stopped and dist < 3.0:
			if not npc_data.get("greet_done", false):
				npc_data["greet_done"] = true
				npc_data["greet_t"] = 0.0
		if npc_data.get("greet_done", false) and npc_data.get("greet_t", -1.0) >= 0.0:
			npc_data["greet_t"] = npc_data.get("greet_t", 0.0) + delta
			var gt2: float = npc_data["greet_t"]
			if head_node and is_instance_valid(head_node) and head_node.is_inside_tree():
				var nod_pitch := 0.0
				if gt2 < 0.2:
					nod_pitch = (gt2 / 0.2) * 0.25  # dip down
				elif gt2 < 0.5:
					nod_pitch = 0.25 * (1.0 - (gt2 - 0.2) / 0.3)  # rise back
				else:
					npc_data["greet_t"] = -1.0  # done, won't nod again (greet_done stays true)
				head_node.rotation.x = lerpf(head_node.rotation.x, head_node.rotation.x + nod_pitch, 8.0 * delta)
		if npc_data.get("does_greet", false) and dist > 10.0:
			npc_data["greet_done"] = false  # reset when player is far away

		# Flinch from sprinting player (lean torso away when player sprints past close)
		if is_stopped and player_sprinting and dist < 2.0:
			if not npc_data.get("flinch_done", false):
				npc_data["flinch_done"] = true
				npc_data["flinch_t"] = 0.0
		if npc_data.get("flinch_done", false) and npc_data.get("flinch_t", -1.0) >= 0.0:
			npc_data["flinch_t"] = npc_data.get("flinch_t", 0.0) + delta
			var ft: float = npc_data["flinch_t"]
			var flinch_model := node.get_node_or_null("Model")
			if flinch_model:
				var lean := 0.0
				if ft < 0.1:
					lean = (ft / 0.1) * -0.15  # lean away
				elif ft < 0.4:
					lean = -0.15 * (1.0 - (ft - 0.1) / 0.3)  # recover
				else:
					npc_data["flinch_t"] = -1.0
				flinch_model.rotation.z = lerpf(flinch_model.rotation.z, lean, 10.0 * delta)
		if dist > 6.0:
			npc_data["flinch_done"] = false  # reset when player leaves

		# Bag bounce (messenger bag/backpack sway when walking)
		if not is_stopped:
			var bag_node := node.get_node_or_null("Model/Bag")
			var bag_base_y := 0.85  # messenger bag base y
			if not bag_node:
				bag_node = node.get_node_or_null("Model/Backpack")
				bag_base_y = 1.05  # backpack base y
			if bag_node:
				var bag_swing := sin(anim.walk_cycle * 2.0) * 0.06
				bag_node.rotation.x = lerpf(bag_node.rotation.x, bag_swing, 6.0 * delta)
				bag_node.position.y = lerpf(bag_node.position.y, bag_base_y + sin(anim.walk_cycle) * 0.02, 4.0 * delta)

		# Coat tail flap (sways while walking, gentle idle sway)
		var coat_tail := node.get_node_or_null("Model/CoatTail")
		if coat_tail:
			var target_rot := 0.0
			if not is_stopped:
				target_rot = sin(anim.walk_cycle * 2.0) * 0.15 + 0.05
			else:
				npc_data["coat_wind_t"] = npc_data.get("coat_wind_t", 0.0) + delta
				target_rot = sin(npc_data["coat_wind_t"] * 1.3) * 0.04
			coat_tail.rotation.x = lerpf(coat_tail.rotation.x, target_rot, 5.0 * delta)

		# Stumble micro-animation (3% of NPCs, rare while walking)
		if npc_data.get("can_stumble", false) and not is_stopped:
			npc_data["stumble_cd"] = npc_data.get("stumble_cd", 0.0) - delta
			if npc_data["stumble_cd"] <= 0.0:
				npc_data["stumble_cd"] = stop_rng.randf_range(30.0, 60.0)
				npc_data["stumble_t"] = 0.0
			if npc_data.get("stumble_t", -1.0) >= 0.0:
				npc_data["stumble_t"] = npc_data["stumble_t"] + delta
				var st: float = npc_data["stumble_t"]
				var stumble_model := node.get_node_or_null("Model")
				if stumble_model:
					var pitch_fwd := 0.0
					if st < 0.15:
						pitch_fwd = (st / 0.15) * 0.15  # lean forward
					elif st < 0.5:
						pitch_fwd = 0.15 * (1.0 - (st - 0.15) / 0.35)  # recover
					else:
						npc_data["stumble_t"] = -1.0  # done
					stumble_model.rotation.x = lerpf(stumble_model.rotation.x, pitch_fwd, 10.0 * delta)

		# Hand rub for warmth (15% of idle NPCs, both arms forward, slight rub oscillation)
		if npc_data.get("does_hand_rub", false) and is_stopped and not npc_data["smoke"] and not npc_data.get("arms_crossed", false):
			npc_data["rub_clock"] = npc_data.get("rub_clock", 0.0) + delta
			var rub_cycle := fmod(npc_data["rub_clock"], 10.0)
			if rub_cycle < 3.0:
				var ls := node.get_node_or_null("Model/LeftShoulder")
				var rs := node.get_node_or_null("Model/RightShoulder")
				var le := node.get_node_or_null("Model/LeftShoulder/LeftElbow")
				var re := node.get_node_or_null("Model/RightShoulder/RightElbow")
				if ls and rs and le and re:
					var rub_osc := sin(npc_data["rub_clock"] * 8.0) * 0.05
					ls.rotation.x = lerpf(ls.rotation.x, -0.4 + rub_osc, 5.0 * delta)
					rs.rotation.x = lerpf(rs.rotation.x, -0.4 - rub_osc, 5.0 * delta)
					ls.rotation.z = lerpf(ls.rotation.z, 0.2, 4.0 * delta)
					rs.rotation.z = lerpf(rs.rotation.z, -0.2, 4.0 * delta)
					le.rotation.x = lerpf(le.rotation.x, -0.9, 5.0 * delta)
					re.rotation.x = lerpf(re.rotation.x, -0.9, 5.0 * delta)

		# Stretch gesture (8% of idle NPCs, arms raise up then lower)
		if npc_data.get("does_stretch", false) and is_stopped and not npc_data["smoke"] and not npc_data.get("arms_crossed", false):
			npc_data["stretch_clock"] = npc_data.get("stretch_clock", 0.0) + delta
			var stretch_cycle := fmod(npc_data["stretch_clock"], 20.0)
			if stretch_cycle < 2.5:
				var ls := node.get_node_or_null("Model/LeftShoulder")
				var rs := node.get_node_or_null("Model/RightShoulder")
				var le := node.get_node_or_null("Model/LeftShoulder/LeftElbow")
				var re := node.get_node_or_null("Model/RightShoulder/RightElbow")
				if ls and rs and le and re:
					var raise := 0.0
					if stretch_cycle < 0.5:
						raise = (stretch_cycle / 0.5) * -2.5  # arms up
					elif stretch_cycle < 1.8:
						raise = -2.5  # hold
					else:
						raise = -2.5 * ((2.5 - stretch_cycle) / 0.7)  # arms down
					ls.rotation.x = lerpf(ls.rotation.x, raise, 5.0 * delta)
					rs.rotation.x = lerpf(rs.rotation.x, raise, 5.0 * delta)
					le.rotation.x = lerpf(le.rotation.x, 0.0, 4.0 * delta)
					re.rotation.x = lerpf(re.rotation.x, 0.0, 4.0 * delta)
					# Slight back arch
					var mdl := node.get_node_or_null("Model")
					if mdl and stretch_cycle > 0.3 and stretch_cycle < 2.0:
						mdl.rotation.x = lerpf(mdl.rotation.x, -0.08, 3.0 * delta)

		# Impatient toe tap (8% of idle NPCs, right foot taps rhythmically)
		if npc_data.get("does_toe_tap", false) and is_stopped and not npc_data.get("has_limp", false):
			npc_data["tap_clock"] = npc_data.get("tap_clock", 0.0) + delta
			var tap_cycle := fmod(npc_data["tap_clock"], 8.0)
			if tap_cycle < 2.0:
				var rh := node.get_node_or_null("Model/RightHip")
				if rh:
					var tap := absf(sin(tap_cycle * 3.0 * TAU)) * 0.12
					rh.rotation.x = lerpf(rh.rotation.x, -tap, 12.0 * delta)

		# Phone thumb scroll (subtle elbow micro-oscillation while looking at phone)
		if npc_data["has_phone"] and is_stopped:
			var phone_re := node.get_node_or_null("Model/RightShoulder/RightElbow")
			if phone_re:
				npc_data["scroll_t"] = npc_data.get("scroll_t", 0.0) + delta
				var scroll := sin(npc_data["scroll_t"] * 2.0 * TAU) * 0.05
				phone_re.rotation.x = lerpf(phone_re.rotation.x, -0.7 + scroll, 6.0 * delta)

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
	var is_jogger := rng.randf() < 0.05
	if is_jogger:
		speed = rng.randf_range(5.5, 7.0)

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

	# Newspaper (8% of NPCs without phone/umbrella - read when stopped)
	var has_newspaper := false
	if not has_umbrella and not has_phone and rng.randf() < 0.08:
		has_newspaper = true
		var paper := MeshInstance3D.new()
		var paper_mesh := QuadMesh.new()
		paper_mesh.size = Vector2(0.3, 0.4)
		paper.mesh = paper_mesh
		paper.name = "Newspaper"
		paper.position = Vector3(0, 1.2, 0.35)
		var paper_mat := ShaderMaterial.new()
		paper_mat.shader = ps1_shader
		paper_mat.set_shader_parameter("albedo_color", Color(0.85, 0.82, 0.75))
		paper_mat.set_shader_parameter("vertex_snap_intensity", 4.0)
		paper_mat.set_shader_parameter("color_depth", 12.0)
		paper_mat.set_shader_parameter("fog_color", Color(0.05, 0.03, 0.1, 1.0))
		paper_mat.set_shader_parameter("fog_distance", 100.0)
		paper_mat.set_shader_parameter("fog_density", 0.3)
		paper.set_surface_override_material(0, paper_mat)
		paper.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		paper.visible = false  # only visible when stopped
		model.add_child(paper)

	# Cigarette smoke (30% of NPCs are smokers, but not umbrella holders or phone users)
	var smoke_particles: GPUParticles3D = null
	if not has_umbrella and not has_phone and not has_newspaper and rng.randf() < 0.30:
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
		var bag_color: Color
		if bag_type == 0:
			# Backpack on back
			bag_color = Color(jacket_color.r * 0.7, jacket_color.g * 0.7, jacket_color.b * 0.7)
			_add_body_part(model, "Backpack", BoxMesh.new(), Vector3(0, 1.05, -0.22),
				bag_color, Vector3(0.3, 0.35, 0.15))
			# Backpack straps across chest
			_add_body_part(model, "StrapL", BoxMesh.new(), Vector3(-0.1, 1.15, 0.05),
				bag_color * 0.9, Vector3(0.04, 0.35, 0.04))
			_add_body_part(model, "StrapR", BoxMesh.new(), Vector3(0.1, 1.15, 0.05),
				bag_color * 0.9, Vector3(0.04, 0.35, 0.04))
		else:
			# Messenger bag on side
			bag_color = Color(0.15, 0.12, 0.08)
			_add_body_part(model, "Bag", BoxMesh.new(), Vector3(-0.28, 0.85, 0.05),
				bag_color, Vector3(0.08, 0.25, 0.2))
			# Diagonal strap across chest (shoulder to opposite hip)
			_add_body_part(model, "Strap", BoxMesh.new(), Vector3(0.05, 1.1, 0.1),
				bag_color * 0.8, Vector3(0.04, 0.5, 0.03))

	# Glowing wristwatch (8% of NPCs)
	if rng.randf() < 0.08:
		var watch_col_idx := rng.randi_range(0, 1)
		var watch_col := Color(0.0, 0.8, 0.4) if watch_col_idx == 0 else Color(0.3, 0.6, 1.0)
		var left_lower := left_elbow.get_node_or_null("LeftLowerArm")
		if left_lower:
			_add_body_part(left_lower, "Watch", BoxMesh.new(), Vector3(0.05, -0.08, 0.06),
				watch_col * 0.3, Vector3(0.04, 0.03, 0.06), true, watch_col, 2.0)

	# Coat tail (30% of NPCs without backpacks - flaps when moving)
	var has_backpack := model.get_node_or_null("Backpack") != null
	if not has_backpack and rng.randf() < 0.30:
		_add_body_part(model, "CoatTail", BoxMesh.new(), Vector3(0, 0.78, -0.12),
			jacket_color * 0.9, Vector3(0.44, 0.15, 0.04))

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

	# Popped collar (8% of NPCs without scarf)
	var has_scarf := model.get_node_or_null("Scarf") != null
	if not has_scarf and rng.randf() < 0.08:
		# Left collar flap
		_add_body_part(model, "CollarL", BoxMesh.new(), Vector3(-0.18, 1.4, -0.08),
			jacket_color * 1.1, Vector3(0.16, 0.12, 0.04))
		# Right collar flap
		_add_body_part(model, "CollarR", BoxMesh.new(), Vector3(0.18, 1.4, -0.08),
			jacket_color * 1.1, Vector3(0.16, 0.12, 0.04))

	# Hoodie (8% of NPCs without hats)
	var has_hat := model.get_node_or_null("Hat") != null
	if not has_hat and rng.randf() < 0.08:
		if rng.randf() < 0.5:
			# Hood UP - pulled over head, shadowing face
			_add_body_part(model, "Hood", BoxMesh.new(), Vector3(0, 1.68, 0.0),
				jacket_color * 0.9, Vector3(0.42, 0.2, 0.35))
			# Front brim overhang
			_add_body_part(model, "HoodBrim", BoxMesh.new(), Vector3(0, 1.62, 0.14),
				jacket_color * 0.85, Vector3(0.36, 0.06, 0.1))
		else:
			# Hood draped behind/over head (down)
			_add_body_part(model, "Hood", BoxMesh.new(), Vector3(0, 1.6, -0.12),
				jacket_color * 1.1, Vector3(0.4, 0.25, 0.22))

	# Cybernetic glowing eyes (3% of NPCs)
	if rng.randf() < 0.03:
		var eye_col := Color(0.0, 0.9, 1.0) if rng.randf() < 0.6 else Color(1.0, 0.1, 0.1)
		_add_body_part(model, "EyeL", BoxMesh.new(), Vector3(-0.07, 1.58, 0.13),
			eye_col * 0.3, Vector3(0.03, 0.03, 0.03), true, eye_col, 3.0)
		_add_body_part(model, "EyeR", BoxMesh.new(), Vector3(0.07, 1.58, 0.13),
			eye_col * 0.3, Vector3(0.03, 0.03, 0.03), true, eye_col, 3.0)

	# Face mask (10% of NPCs - covers lower face)
	if rng.randf() < 0.10:
		var mask_col := Color(0.85, 0.85, 0.85) if rng.randf() < 0.6 else Color(0.1, 0.1, 0.1)
		_add_body_part(model, "Mask", BoxMesh.new(), Vector3(0, 1.48, 0.12),
			mask_col, Vector3(0.28, 0.1, 0.08))

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

	# LED shoelaces (3% of NPCs - glowing strips at ankle level)
	if rng.randf() < 0.03:
		var led_cols: Array[Color] = [Color(0.0, 0.9, 1.0), Color(1.0, 0.05, 0.8), Color(0.0, 1.0, 0.4)]
		var led_col: Color = led_cols[rng.randi_range(0, 2)]
		_add_body_part(model, "LedL", BoxMesh.new(), Vector3(-0.08, 0.02, 0.04),
			led_col * 0.3, Vector3(0.12, 0.015, 0.06), true, led_col, 3.0)
		_add_body_part(model, "LedR", BoxMesh.new(), Vector3(0.08, 0.02, 0.04),
			led_col * 0.3, Vector3(0.12, 0.015, 0.06), true, led_col, 3.0)

	# Wrist tattoo (2% of NPCs - emissive circuit line on forearm)
	if rng.randf() < 0.02:
		var tattoo_cols: Array[Color] = [Color(0.0, 0.8, 1.0), Color(1.0, 0.0, 0.6), Color(0.4, 1.0, 0.2)]
		var tattoo_col: Color = tattoo_cols[rng.randi_range(0, 2)]
		var tattoo_arm := left_elbow.get_node_or_null("LeftLowerArm") if rng.randf() < 0.5 else right_elbow.get_node_or_null("RightLowerArm")
		if tattoo_arm:
			# Main line along forearm
			_add_body_part(tattoo_arm, "Tattoo", BoxMesh.new(), Vector3(0.05, -0.1, 0.05),
				tattoo_col * 0.3, Vector3(0.01, 0.18, 0.01), true, tattoo_col, 2.5)
			# Short perpendicular branch
			_add_body_part(tattoo_arm, "TattooBranch", BoxMesh.new(), Vector3(0.07, -0.06, 0.05),
				tattoo_col * 0.3, Vector3(0.04, 0.01, 0.01), true, tattoo_col, 2.5)

	# Rain drip particles (non-umbrella NPCs - water dripping off clothes)
	var rain_drip: GPUParticles3D = null
	if not has_umbrella:
		rain_drip = GPUParticles3D.new()
		rain_drip.amount = 4
		rain_drip.lifetime = 0.4
		rain_drip.emitting = true
		rain_drip.visibility_aabb = AABB(Vector3(-0.5, -1, -0.5), Vector3(1, 2, 1))
		var rd_mat := ParticleProcessMaterial.new()
		rd_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		rd_mat.emission_box_extents = Vector3(0.2, 0.3, 0.1)
		rd_mat.direction = Vector3(0, -1, 0)
		rd_mat.spread = 10.0
		rd_mat.initial_velocity_min = 0.8
		rd_mat.initial_velocity_max = 1.5
		rd_mat.gravity = Vector3(0, -6.0, 0)
		rd_mat.scale_min = 0.01
		rd_mat.scale_max = 0.02
		rd_mat.color = Color(0.5, 0.55, 0.7, 0.15)
		rain_drip.process_material = rd_mat
		var rd_mesh := SphereMesh.new()
		rd_mesh.radius = 0.015
		rd_mesh.height = 0.03
		rain_drip.draw_pass_1 = rd_mesh
		rain_drip.position = Vector3(0, 1.1, 0)
		model.add_child(rain_drip)

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
		"pocket_hand": not has_umbrella and rng.randf() < 0.30,
		"has_limp": rng.randf() < 0.05,
		"is_jogger": is_jogger,
		"has_newspaper": has_newspaper,
		"does_shrug": rng.randf() < 0.15,
		"does_scratch": rng.randf() < 0.10,
		"arms_crossed": rng.randf() < 0.12,
		"looks_at_rain": rng.randf() < 0.05,
		"can_stumble": rng.randf() < 0.03,
		"does_yawn": rng.randf() < 0.05,
		"does_greet": rng.randf() < 0.10,
		"does_hand_rub": not has_umbrella and not has_phone and not has_newspaper and rng.randf() < 0.15,
		"does_stretch": not has_umbrella and not has_phone and not has_newspaper and rng.randf() < 0.08,
		"does_toe_tap": not is_jogger and rng.randf() < 0.08,
		"swing_mult": rng.randf_range(0.7, 1.3),
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

extends Node3D

## Procedural ambient audio: rain, city hum, distant sirens.
## Uses AudioStreamGenerator for real-time noise synthesis.

var rain_player: AudioStreamPlayer
var hum_player: AudioStreamPlayer
var rain_generator: AudioStreamGenerator
var hum_generator: AudioStreamGenerator
var rain_playback: AudioStreamGeneratorPlayback
var hum_playback: AudioStreamGeneratorPlayback

var rain_phase: float = 0.0
var hum_phase: float = 0.0
var siren_timer: float = 0.0
var siren_phase: float = 0.0
var siren_active: bool = false
var siren_type: int = 0  # 0 = American wail, 1 = European two-tone
var thunder_timer: float = 0.0
var thunder_phase: float = 0.0
var thunder_active: bool = false
var thunder_filter: float = 0.0
var lightning_light: DirectionalLight3D = null
var lightning_flash_timer: float = 0.0
var bark_timer: float = 0.0
var bark_phase: float = 0.0
var bark_active: bool = false
var bark_count: int = 0
var bark_max: int = 0
var bark_gap_timer: float = 0.0
var bark_pitch: float = 1.0
var murmur_filter1: float = 0.0
var murmur_filter2: float = 0.0
var crow_timer: float = 0.0
var crow_phase: float = 0.0
var crow_active: bool = false
var crow_count: int = 0
var crow_max: int = 0
var crow_gap_timer: float = 0.0
var crow_pitch: float = 1.0
var train_timer: float = 0.0
var train_phase: float = 0.0
var train_active: bool = false
var train_pitch: float = 1.0
var glass_timer: float = 0.0
var glass_phase: float = 0.0
var glass_active: bool = false
var horn_timer: float = 0.0
var horn_phase: float = 0.0
var horn_active: bool = false
var horn_duration: float = 0.3
var horn_pitch: float = 1.0
var horn_double: bool = false
var horn_gap_done: bool = false
var radio_timer: float = 0.0
var radio_phase: float = 0.0
var radio_active: bool = false
var radio_duration: float = 0.8
var radio_filter: float = 0.0
var bass_timer: float = 0.0
var bass_phase: float = 0.0
var bass_active: bool = false
var bass_duration: float = 10.0
var bass_bpm: float = 120.0
var spark_timer: float = 0.0
var spark_phase: float = 0.0
var spark_active: bool = false
var explosion_timer: float = 0.0
var explosion_phase: float = 0.0
var explosion_active: bool = false
var explosion_duration: float = 2.0
var explosion_filter: float = 0.0
var door_timer: float = 0.0
var door_phase: float = 0.0
var door_active: bool = false
var melody_timer: float = 0.0
var melody_phase: float = 0.0
var melody_active: bool = false
var melody_duration: float = 4.0
var melody_note_idx: int = 0
var melody_notes: Array[float] = []
var phone_timer: float = 0.0
var phone_phase: float = 0.0
var phone_active: bool = false
var phone_duration: float = 2.5
var drip_timer: float = 0.0
var drip_phase: float = 0.0
var drip_active: bool = false
var pa_timer: float = 0.0
var pa_phase: float = 0.0
var pa_active: bool = false
var pa_duration: float = 3.0
var pa_filter: float = 0.0
var alarm_timer: float = 0.0
var alarm_phase: float = 0.0
var alarm_active: bool = false
var alarm_duration: float = 4.0
var whistle_timer: float = 0.0
var whistle_phase: float = 0.0
var whistle_active: bool = false
var whistle_duration: float = 2.0
var whistle_pitch: float = 1.0
var subway_timer: float = 0.0
var subway_phase: float = 0.0
var subway_active: bool = false
var subway_duration: float = 6.0
var subway_filter: float = 0.0
var pigeon_timer: float = 0.0
var pigeon_phase: float = 0.0
var pigeon_active: bool = false
var pigeon_count: int = 0
var pigeon_max: int = 0
var pigeon_gap_timer: float = 0.0
var pigeon_pitch: float = 1.0
var heli_timer: float = 0.0
var heli_phase: float = 0.0
var heli_active: bool = false
var heli_duration: float = 8.0
var construction_timer: float = 0.0
var construction_phase: float = 0.0
var construction_active: bool = false
var construction_duration: float = 4.0
var construction_bpm: float = 3.0
var cheer_timer: float = 0.0
var cheer_phase: float = 0.0
var cheer_active: bool = false
var cheer_duration: float = 2.0
var cheer_filter: float = 0.0
var baby_timer: float = 0.0
var baby_phase: float = 0.0
var baby_active: bool = false
var baby_duration: float = 3.0
var chime_timer: float = 0.0
var chime_phase: float = 0.0
var chime_active: bool = false
var chime_duration: float = 2.0
var chime_notes: Array[float] = []
var chime_note_idx: int = 0
var gunshot_timer: float = 0.0
var gunshot_phase: float = 0.0
var gunshot_active: bool = false
var gunshot_count: int = 0
var gunshot_max: int = 0
var gunshot_gap_timer: float = 0.0
var gunshot_reverb: float = 0.0
var bell_timer: float = 0.0
var bell_phase: float = 0.0
var bell_active: bool = false
var bell_count: int = 0
var bell_max: int = 0
var bell_gap_timer: float = 0.0
var moto_timer: float = 0.0
var moto_phase: float = 0.0
var moto_active: bool = false
var moto_duration: float = 2.0
var crossing_timer: float = 0.0
var crossing_phase: float = 0.0
var crossing_active: bool = false
var crossing_duration: float = 4.0
var cat_screech_timer: float = 0.0
var cat_screech_phase: float = 0.0
var cat_screech_active: bool = false
var cat_screech_duration: float = 1.0
var clink_timer: float = 0.0
var clink_phase: float = 0.0
var clink_active: bool = false
var clink_count: int = 0
var clink_max: int = 0
var clink_gap_timer: float = 0.0
var dumpster_timer: float = 0.0
var dumpster_phase: float = 0.0
var dumpster_active: bool = false
var dumpster_duration: float = 0.5
var firework_timer: float = 0.0
var firework_phase: float = 0.0
var firework_active: bool = false
var firework_flash_light: OmniLight3D = null
var foghorn_timer: float = 0.0
var foghorn_phase: float = 0.0
var foghorn_active: bool = false
var foghorn_duration: float = 3.0
var laughter_timer: float = 0.0
var laughter_phase: float = 0.0
var laughter_active: bool = false
var laughter_duration: float = 1.0
var laughter_filter: float = 0.0
var brake_timer: float = 0.0
var brake_phase: float = 0.0
var brake_active: bool = false
var brake_duration: float = 1.0
var gate_timer: float = 0.0
var gate_phase: float = 0.0
var gate_active: bool = false
var crash_timer: float = 0.0
var crash_phase: float = 0.0
var crash_active: bool = false
var crash_duration: float = 1.5
var rat_timer: float = 0.0
var rat_phase: float = 0.0
var rat_active: bool = false
var rat_count: int = 0
var rat_max: int = 0
var rat_gap_timer: float = 0.0
var organ_timer: float = 0.0
var organ_phase: float = 0.0
var organ_active: bool = false
var organ_duration: float = 6.0
var tune_timer: float = 0.0
var tune_phase: float = 0.0
var tune_active: bool = false
var tune_duration: float = 0.4
var tune_freq: float = 1000.0
var ship_timer: float = 0.0
var ship_phase: float = 0.0
var ship_active: bool = false
var ship_duration: float = 4.0
var tvstatic_timer: float = 0.0
var tvstatic_phase: float = 0.0
var tvstatic_active: bool = false
var tvstatic_duration: float = 0.5
var tvstatic_filter: float = 0.0
var clang_timer: float = 0.0
var clang_phase: float = 0.0
var clang_active: bool = false
var clang_pitch: float = 1.0
var hour_chime_phase: float = 0.0
var hour_chime_active: bool = false
var hour_chime_note_idx: int = 0
var last_hour: int = -1
var neonbuzz_timer: float = 0.0
var neonbuzz_phase: float = 0.0
var neonbuzz_active: bool = false
var neonbuzz_duration: float = 2.0
var jet_timer: float = 0.0
var jet_phase: float = 0.0
var jet_active: bool = false
var jet_duration: float = 4.0
var cart_timer: float = 0.0
var cart_phase: float = 0.0
var cart_active: bool = false
var cart_duration: float = 2.0
var gust_timer: float = 0.0
var gust_phase: float = 0.0
var gust_active: bool = false
var gust_duration: float = 3.0
var gust_filter: float = 0.0
var car_alarm_timer: float = 0.0
var car_alarm_phase: float = 0.0
var car_alarm_active: bool = false
var car_alarm_duration: float = 4.0
var fence_timer: float = 0.0
var fence_phase: float = 0.0
var fence_active: bool = false
var fence_duration: float = 2.0
var fence_filter: float = 0.0
var club_timer: float = 0.0
var club_phase: float = 0.0
var club_active: bool = false
var club_duration: float = 10.0
var steam_timer: float = 0.0
var steam_phase: float = 0.0
var steam_active: bool = false
var steam_duration: float = 2.0
var steam_filter: float = 0.0
var pipe_timer: float = 0.0
var pipe_phase: float = 0.0
var pipe_active: bool = false
var pipe_duration: float = 2.5
var pipe_pitch: float = 1.0
var xformer_timer: float = 0.0
var xformer_phase: float = 0.0
var xformer_active: bool = false
var xformer_duration: float = 4.0
var buzzer_timer: float = 0.0
var buzzer_phase: float = 0.0
var buzzer_active: bool = false
var vend_timer: float = 0.0
var vend_phase: float = 0.0
var vend_active: bool = false
var vend_duration: float = 5.0
var trash_timer: float = 0.0
var trash_phase: float = 0.0
var trash_active: bool = false
var trash_count: int = 0
var trash_max: int = 0
var trash_gap: float = 0.0
var fluor_timer: float = 0.0
var fluor_phase: float = 0.0
var fluor_active: bool = false
var fluor_duration: float = 3.0
var fluor_dropout: float = 0.0
var gate_timer: float = 0.0
var gate_phase: float = 0.0
var gate_active: bool = false
var engine_timer: float = 0.0
var engine_phase: float = 0.0
var engine_active: bool = false
var engine_duration: float = 5.0
var engine_rpm: float = 1.0
var ac_timer: float = 0.0
var ac_phase: float = 0.0
var ac_active: bool = false
var ac_duration: float = 8.0
var elev_timer: float = 0.0
var elev_phase: float = 0.0
var elev_active: bool = false
var world_env: WorldEnvironment = null
var base_ambient_energy: float = 4.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 1234

	# Grab WorldEnvironment for lightning ambient boost
	world_env = get_node_or_null("../WorldEnvironment")
	if world_env and world_env.environment:
		base_ambient_energy = world_env.environment.ambient_light_energy

	# Rain noise player
	rain_player = AudioStreamPlayer.new()
	rain_generator = AudioStreamGenerator.new()
	rain_generator.mix_rate = 22050.0
	rain_generator.buffer_length = 0.1
	rain_player.stream = rain_generator
	rain_player.volume_db = -12.0
	rain_player.bus = "Master"
	add_child(rain_player)
	rain_player.play()
	rain_playback = rain_player.get_stream_playback()

	# City hum player (low frequency drone)
	hum_player = AudioStreamPlayer.new()
	hum_generator = AudioStreamGenerator.new()
	hum_generator.mix_rate = 22050.0
	hum_generator.buffer_length = 0.1
	hum_player.stream = hum_generator
	hum_player.volume_db = -18.0
	hum_player.bus = "Master"
	add_child(hum_player)
	hum_player.play()
	hum_playback = hum_player.get_stream_playback()

	# Lightning flash light (normally off)
	lightning_light = DirectionalLight3D.new()
	lightning_light.light_color = Color(0.8, 0.85, 1.0)
	lightning_light.light_energy = 0.0
	lightning_light.rotation_degrees = Vector3(-45, 30, 0)
	lightning_light.shadow_enabled = false
	add_child(lightning_light)

	# Firework flash light (sky-level burst)
	firework_flash_light = OmniLight3D.new()
	firework_flash_light.light_energy = 0.0
	firework_flash_light.omni_range = 80.0
	firework_flash_light.shadow_enabled = false
	firework_flash_light.position = Vector3(0, 80, 0)
	add_child(firework_flash_light)

var rain_intensity_time: float = 0.0

func _process(delta: float) -> void:
	_fill_rain_buffer()
	_fill_hum_buffer()

	# Sync rain audio volume with intensity cycle (~60s period, matching rain.gd)
	rain_intensity_time += delta
	var rain_intensity := 0.5 + 0.5 * sin(rain_intensity_time * 0.1)
	if rain_player:
		rain_player.volume_db = -18.0 + rain_intensity * 8.0  # -18dB to -10dB

	# Occasional siren
	siren_timer -= delta
	if siren_timer <= 0.0:
		siren_timer = rng.randf_range(30.0, 90.0)
		siren_active = true
		siren_type = rng.randi_range(0, 2)  # 0=American, 1=European, 2=Ambulance

	if siren_active:
		siren_phase += delta
		if siren_phase > 4.0:
			siren_active = false
			siren_phase = 0.0

	# Occasional distant thunder
	thunder_timer -= delta
	if thunder_timer <= 0.0:
		thunder_timer = rng.randf_range(45.0, 120.0)
		thunder_active = true
		thunder_phase = 0.0
		# Trigger lightning flash
		lightning_flash_timer = 0.2

	if thunder_active:
		thunder_phase += delta
		if thunder_phase > 3.5:
			thunder_active = false

	# Lightning flash decay
	if lightning_light and lightning_flash_timer > 0.0:
		lightning_flash_timer -= delta
		# Rapid double-flash pattern
		var flash_val := 0.0
		var ft := 0.2 - lightning_flash_timer
		if ft < 0.04:
			flash_val = 5.0
		elif ft < 0.08:
			flash_val = 0.5
		elif ft < 0.12:
			flash_val = 3.0
		else:
			flash_val = maxf(0.0, (0.2 - ft) * 10.0)
		lightning_light.light_energy = flash_val
		# Boost ambient light during flash
		if world_env and world_env.environment:
			world_env.environment.ambient_light_energy = base_ambient_energy + flash_val * 0.4
	elif lightning_light:
		lightning_light.light_energy = 0.0
		# Restore ambient light
		if world_env and world_env.environment:
			world_env.environment.ambient_light_energy = lerpf(
				world_env.environment.ambient_light_energy, base_ambient_energy, 8.0 * delta)

	# Electrical sparking crackle
	spark_timer -= delta
	if spark_timer <= 0.0 and not spark_active:
		spark_timer = rng.randf_range(40.0, 90.0)
		spark_active = true
		spark_phase = 0.0

	if spark_active:
		spark_phase += delta
		if spark_phase > 0.15:
			spark_active = false

	# Distant explosion rumble (very rare)
	explosion_timer -= delta
	if explosion_timer <= 0.0 and not explosion_active:
		explosion_timer = rng.randf_range(120.0, 300.0)
		explosion_active = true
		explosion_phase = 0.0
		explosion_duration = rng.randf_range(1.5, 2.5)
		explosion_filter = 0.0

	if explosion_active:
		explosion_phase += delta
		if explosion_phase > explosion_duration:
			explosion_active = false

	# Distant phone ringtone
	phone_timer -= delta
	if phone_timer <= 0.0 and not phone_active:
		phone_timer = rng.randf_range(60.0, 120.0)
		phone_active = true
		phone_phase = 0.0
		phone_duration = rng.randf_range(2.0, 3.0)

	if phone_active:
		phone_phase += delta
		if phone_phase > phone_duration:
			phone_active = false

	# Distant door slam
	door_timer -= delta
	if door_timer <= 0.0 and not door_active:
		door_timer = rng.randf_range(45.0, 90.0)
		door_active = true
		door_phase = 0.0

	if door_active:
		door_phase += delta
		if door_phase > 0.15:
			door_active = false

	# Distant melody fragment
	melody_timer -= delta
	if melody_timer <= 0.0 and not melody_active:
		melody_timer = rng.randf_range(80.0, 150.0)
		melody_active = true
		melody_phase = 0.0
		melody_duration = rng.randf_range(3.0, 5.0)
		melody_note_idx = 0
		# Generate pentatonic melody (C, D, E, G, A in various octaves)
		var penta := [261.6, 293.7, 329.6, 392.0, 440.0]
		melody_notes.clear()
		for _n in range(rng.randi_range(3, 5)):
			var ni := rng.randi_range(0, 4)
			var octave := 1.0 if rng.randf() < 0.7 else 2.0
			melody_notes.append(penta[ni] * octave)

	if melody_active:
		melody_phase += delta
		if melody_phase > melody_duration:
			melody_active = false

	# Distant dog barking
	bark_timer -= delta
	if bark_timer <= 0.0 and not bark_active:
		bark_timer = rng.randf_range(25.0, 70.0)
		bark_active = true
		bark_count = 0
		bark_max = rng.randi_range(2, 5)
		bark_gap_timer = 0.0
		bark_pitch = rng.randf_range(0.8, 1.3)

	if bark_active:
		bark_gap_timer -= delta
		if bark_gap_timer <= 0.0 and bark_count < bark_max:
			bark_phase = 0.0
			bark_count += 1
			bark_gap_timer = rng.randf_range(0.2, 0.5)
		if bark_count >= bark_max and bark_phase > 0.15:
			bark_active = false

	if bark_active:
		bark_phase += delta

	# Distant crow cawing
	crow_timer -= delta
	if crow_timer <= 0.0 and not crow_active:
		crow_timer = rng.randf_range(20.0, 55.0)
		crow_active = true
		crow_count = 0
		crow_max = rng.randi_range(2, 4)
		crow_gap_timer = 0.0
		crow_pitch = rng.randf_range(0.85, 1.2)

	if crow_active:
		crow_gap_timer -= delta
		if crow_gap_timer <= 0.0 and crow_count < crow_max:
			crow_phase = 0.0
			crow_count += 1
			crow_gap_timer = rng.randf_range(0.3, 0.7)
		if crow_count >= crow_max and crow_phase > 0.2:
			crow_active = false

	if crow_active:
		crow_phase += delta

	# Distant train/monorail horn
	train_timer -= delta
	if train_timer <= 0.0 and not train_active:
		train_timer = rng.randf_range(40.0, 80.0)
		train_active = true
		train_phase = 0.0
		train_pitch = rng.randf_range(0.9, 1.1)

	if train_active:
		train_phase += delta
		if train_phase > 3.0:
			train_active = false

	# Distant glass breaking/shattering
	glass_timer -= delta
	if glass_timer <= 0.0 and not glass_active:
		glass_timer = rng.randf_range(50.0, 100.0)
		glass_active = true
		glass_phase = 0.0

	if glass_active:
		glass_phase += delta
		if glass_phase > 0.4:
			glass_active = false

	# Distant car horn beeps
	horn_timer -= delta
	if horn_timer <= 0.0 and not horn_active:
		horn_timer = rng.randf_range(15.0, 35.0)
		horn_active = true
		horn_phase = 0.0
		horn_pitch = rng.randf_range(0.85, 1.15)
		horn_duration = rng.randf_range(0.2, 0.5)
		horn_double = rng.randf() < 0.4
		horn_gap_done = false

	if horn_active:
		horn_phase += delta
		var total_dur := horn_duration
		if horn_double:
			total_dur = horn_duration * 2.0 + 0.1
		if horn_phase > total_dur:
			horn_active = false

	# Radio chatter bursts (walkie-talkie crackle)
	radio_timer -= delta
	if radio_timer <= 0.0 and not radio_active:
		radio_timer = rng.randf_range(35.0, 65.0)
		radio_active = true
		radio_phase = 0.0
		radio_duration = rng.randf_range(0.5, 1.5)
		radio_filter = 0.0

	if radio_active:
		radio_phase += delta
		if radio_phase > radio_duration:
			radio_active = false

	# Distant club bass thump
	bass_timer -= delta
	if bass_timer <= 0.0 and not bass_active:
		bass_timer = rng.randf_range(30.0, 80.0)
		bass_active = true
		bass_phase = 0.0
		bass_duration = rng.randf_range(8.0, 15.0)
		bass_bpm = rng.randf_range(115.0, 130.0)

	if bass_active:
		bass_phase += delta
		if bass_phase > bass_duration:
			bass_active = false

	# Water drip from awnings
	drip_timer -= delta
	if drip_timer <= 0.0 and not drip_active:
		drip_timer = rng.randf_range(8.0, 20.0)
		drip_active = true
		drip_phase = 0.0

	if drip_active:
		drip_phase += delta
		if drip_phase > 0.08:
			drip_active = false

	# Distant PA/megaphone announcement
	pa_timer -= delta
	if pa_timer <= 0.0 and not pa_active:
		pa_timer = rng.randf_range(100.0, 180.0)
		pa_active = true
		pa_phase = 0.0
		pa_duration = rng.randf_range(2.0, 4.0)
		pa_filter = 0.0

	if pa_active:
		pa_phase += delta
		if pa_phase > pa_duration:
			pa_active = false

	# Distant car alarm
	alarm_timer -= delta
	if alarm_timer <= 0.0 and not alarm_active:
		alarm_timer = rng.randf_range(60.0, 150.0)
		alarm_active = true
		alarm_phase = 0.0
		alarm_duration = rng.randf_range(3.0, 6.0)

	if alarm_active:
		alarm_phase += delta
		if alarm_phase > alarm_duration:
			alarm_active = false

	# Wind whistle through buildings
	whistle_timer -= delta
	if whistle_timer <= 0.0 and not whistle_active:
		whistle_timer = rng.randf_range(20.0, 40.0)
		whistle_active = true
		whistle_phase = 0.0
		whistle_duration = rng.randf_range(1.0, 3.0)
		whistle_pitch = rng.randf_range(0.8, 1.3)

	if whistle_active:
		whistle_phase += delta
		if whistle_phase > whistle_duration:
			whistle_active = false

	# Distant subway rumble
	subway_timer -= delta
	if subway_timer <= 0.0 and not subway_active:
		subway_timer = rng.randf_range(60.0, 120.0)
		subway_active = true
		subway_phase = 0.0
		subway_duration = rng.randf_range(4.0, 8.0)
		subway_filter = 0.0

	if subway_active:
		subway_phase += delta
		if subway_phase > subway_duration:
			subway_active = false

	# Pigeon cooing
	pigeon_timer -= delta
	if pigeon_timer <= 0.0 and not pigeon_active:
		pigeon_timer = rng.randf_range(30.0, 60.0)
		pigeon_active = true
		pigeon_count = 0
		pigeon_max = rng.randi_range(2, 3)
		pigeon_gap_timer = 0.0
		pigeon_pitch = rng.randf_range(0.85, 1.15)

	if pigeon_active:
		pigeon_gap_timer -= delta
		if pigeon_gap_timer <= 0.0 and pigeon_count < pigeon_max:
			pigeon_phase = 0.0
			pigeon_count += 1
			pigeon_gap_timer = rng.randf_range(0.3, 0.6)
		if pigeon_count >= pigeon_max and pigeon_phase > 0.25:
			pigeon_active = false

	if pigeon_active:
		pigeon_phase += delta

	# Distant helicopter blade chop
	heli_timer -= delta
	if heli_timer <= 0.0 and not heli_active:
		heli_timer = rng.randf_range(90.0, 200.0)
		heli_active = true
		heli_phase = 0.0
		heli_duration = rng.randf_range(6.0, 12.0)

	if heli_active:
		heli_phase += delta
		if heli_phase > heli_duration:
			heli_active = false

	# Distant construction hammering/drilling
	construction_timer -= delta
	if construction_timer <= 0.0 and not construction_active:
		construction_timer = rng.randf_range(70.0, 140.0)
		construction_active = true
		construction_phase = 0.0
		construction_duration = rng.randf_range(3.0, 6.0)
		construction_bpm = rng.randf_range(2.5, 5.0)

	if construction_active:
		construction_phase += delta
		if construction_phase > construction_duration:
			construction_active = false

	# Distant crowd cheer/applause
	cheer_timer -= delta
	if cheer_timer <= 0.0 and not cheer_active:
		cheer_timer = rng.randf_range(120.0, 240.0)
		cheer_active = true
		cheer_phase = 0.0
		cheer_duration = rng.randf_range(1.0, 3.0)
		cheer_filter = 0.0

	if cheer_active:
		cheer_phase += delta
		if cheer_phase > cheer_duration:
			cheer_active = false

	# Distant baby crying (very rare)
	baby_timer -= delta
	if baby_timer <= 0.0 and not baby_active:
		baby_timer = rng.randf_range(150.0, 300.0)
		baby_active = true
		baby_phase = 0.0
		baby_duration = rng.randf_range(2.0, 4.0)

	if baby_active:
		baby_phase += delta
		if baby_phase > baby_duration:
			baby_active = false

	# Distant wind chime / music box tinkle
	chime_timer -= delta
	if chime_timer <= 0.0 and not chime_active:
		chime_timer = rng.randf_range(80.0, 160.0)
		chime_active = true
		chime_phase = 0.0
		chime_duration = rng.randf_range(2.0, 3.0)
		chime_note_idx = 0
		chime_notes.clear()
		var chime_freqs: Array[float] = [1200.0, 1500.0, 1800.0, 2000.0, 2400.0]
		for _n in range(rng.randi_range(4, 6)):
			chime_notes.append(chime_freqs[rng.randi_range(0, 4)])

	if chime_active:
		chime_phase += delta
		if chime_phase > chime_duration:
			chime_active = false

	# Distant gunshots (very rare)
	gunshot_timer -= delta
	if gunshot_timer <= 0.0 and not gunshot_active:
		gunshot_timer = rng.randf_range(180.0, 400.0)
		gunshot_active = true
		gunshot_count = 0
		gunshot_max = rng.randi_range(1, 3)
		gunshot_gap_timer = 0.0

	if gunshot_active:
		gunshot_gap_timer -= delta
		if gunshot_gap_timer <= 0.0 and gunshot_count < gunshot_max:
			gunshot_phase = 0.0
			gunshot_count += 1
			gunshot_gap_timer = rng.randf_range(0.3, 0.6)
		if gunshot_count >= gunshot_max and gunshot_phase > 0.5:
			gunshot_active = false

	if gunshot_active:
		gunshot_phase += delta

	# Distant temple/church bell toll (very rare)
	bell_timer -= delta
	if bell_timer <= 0.0 and not bell_active:
		bell_timer = rng.randf_range(200.0, 400.0)
		bell_active = true
		bell_count = 0
		bell_max = rng.randi_range(1, 3)
		bell_gap_timer = 0.0

	if bell_active:
		bell_gap_timer -= delta
		if bell_gap_timer <= 0.0 and bell_count < bell_max:
			bell_phase = 0.0
			bell_count += 1
			bell_gap_timer = rng.randf_range(1.5, 2.5)
		if bell_count >= bell_max and bell_phase > 2.0:
			bell_active = false

	if bell_active:
		bell_phase += delta

	# Distant motorcycle rev
	moto_timer -= delta
	if moto_timer <= 0.0 and not moto_active:
		moto_timer = rng.randf_range(40.0, 80.0)
		moto_active = true
		moto_phase = 0.0
		moto_duration = rng.randf_range(1.0, 3.0)

	if moto_active:
		moto_phase += delta
		if moto_phase > moto_duration:
			moto_active = false

	# Distant train crossing bell
	crossing_timer -= delta
	if crossing_timer <= 0.0 and not crossing_active:
		crossing_timer = rng.randf_range(90.0, 180.0)
		crossing_active = true
		crossing_phase = 0.0
		crossing_duration = rng.randf_range(3.0, 5.0)

	if crossing_active:
		crossing_phase += delta
		if crossing_phase > crossing_duration:
			crossing_active = false

	# Distant cat fight screech (very rare)
	cat_screech_timer -= delta
	if cat_screech_timer <= 0.0 and not cat_screech_active:
		cat_screech_timer = rng.randf_range(120.0, 250.0)
		cat_screech_active = true
		cat_screech_phase = 0.0
		cat_screech_duration = rng.randf_range(0.5, 1.5)

	if cat_screech_active:
		cat_screech_phase += delta
		if cat_screech_phase > cat_screech_duration:
			cat_screech_active = false

	# Glass bottle clink
	clink_timer -= delta
	if clink_timer <= 0.0 and not clink_active:
		clink_timer = rng.randf_range(30.0, 70.0)
		clink_active = true
		clink_count = 0
		clink_max = rng.randi_range(2, 3)
		clink_gap_timer = 0.0

	if clink_active:
		clink_gap_timer -= delta
		if clink_gap_timer <= 0.0 and clink_count < clink_max:
			clink_phase = 0.0
			clink_count += 1
			clink_gap_timer = rng.randf_range(0.1, 0.2)
		if clink_count >= clink_max and clink_phase > 0.05:
			clink_active = false

	if clink_active:
		clink_phase += delta

	# Distant firework (very rare)
	firework_timer -= delta
	if firework_timer <= 0.0 and not firework_active:
		firework_timer = rng.randf_range(300.0, 600.0)
		firework_active = true
		firework_phase = 0.0
		# Random sky position for the flash
		if firework_flash_light:
			firework_flash_light.position = Vector3(
				rng.randf_range(-60.0, 60.0), 80.0, rng.randf_range(-60.0, 60.0))
			# Random color
			var fw_colors := [Color(1.0, 0.3, 0.3), Color(0.3, 1.0, 0.3), Color(0.3, 0.5, 1.0),
				Color(1.0, 0.8, 0.2), Color(1.0, 0.4, 0.8)]
			firework_flash_light.light_color = fw_colors[rng.randi_range(0, 4)]

	if firework_active:
		firework_phase += delta
		# Flash at the burst moment (0.5s whistle, then pop)
		if firework_flash_light:
			if firework_phase > 0.5 and firework_phase < 0.7:
				firework_flash_light.light_energy = maxf(0.0, (0.7 - firework_phase) * 15.0)
			else:
				firework_flash_light.light_energy = 0.0
		if firework_phase > 1.5:
			firework_active = false
			if firework_flash_light:
				firework_flash_light.light_energy = 0.0

	# Distant squealing brakes
	brake_timer -= delta
	if brake_timer <= 0.0 and not brake_active:
		brake_timer = rng.randf_range(50.0, 100.0)
		brake_active = true
		brake_phase = 0.0
		brake_duration = rng.randf_range(0.5, 1.5)

	if brake_active:
		brake_phase += delta
		if brake_phase > brake_duration:
			brake_active = false

	# Distant metal gate slam
	gate_timer -= delta
	if gate_timer <= 0.0 and not gate_active:
		gate_timer = rng.randf_range(60.0, 120.0)
		gate_active = true
		gate_phase = 0.0

	if gate_active:
		gate_phase += delta
		if gate_phase > 0.15:
			gate_active = false

	# Distant foghorn
	foghorn_timer -= delta
	if foghorn_timer <= 0.0 and not foghorn_active:
		foghorn_timer = rng.randf_range(120.0, 250.0)
		foghorn_active = true
		foghorn_phase = 0.0
		foghorn_duration = rng.randf_range(2.0, 4.0)

	if foghorn_active:
		foghorn_phase += delta
		if foghorn_phase > foghorn_duration:
			foghorn_active = false

	# Distant crowd laughter burst
	laughter_timer -= delta
	if laughter_timer <= 0.0 and not laughter_active:
		laughter_timer = rng.randf_range(80.0, 160.0)
		laughter_active = true
		laughter_phase = 0.0
		laughter_duration = rng.randf_range(0.5, 1.5)
		laughter_filter = 0.0

	if laughter_active:
		laughter_phase += delta
		if laughter_phase > laughter_duration:
			laughter_active = false

	# Dumpster lid rattle
	dumpster_timer -= delta
	if dumpster_timer <= 0.0 and not dumpster_active:
		dumpster_timer = rng.randf_range(45.0, 90.0)
		dumpster_active = true
		dumpster_phase = 0.0
		dumpster_duration = rng.randf_range(0.3, 0.8)

	if dumpster_active:
		dumpster_phase += delta
		if dumpster_phase > dumpster_duration:
			dumpster_active = false

	# Distant car crash (rare)
	crash_timer -= delta
	if crash_timer <= 0.0 and not crash_active:
		crash_timer = rng.randf_range(200.0, 400.0)
		crash_active = true
		crash_phase = 0.0
		crash_duration = rng.randf_range(1.2, 2.0)

	if crash_active:
		crash_phase += delta
		if crash_phase > crash_duration:
			crash_active = false

	# Rat squeaking
	rat_timer -= delta
	if rat_timer <= 0.0 and not rat_active:
		rat_timer = rng.randf_range(40.0, 80.0)
		rat_active = true
		rat_phase = 0.0
		rat_count = 0
		rat_max = rng.randi_range(2, 4)
		rat_gap_timer = 0.0

	if rat_active:
		rat_gap_timer -= delta
		if rat_gap_timer <= 0.0 and rat_count < rat_max:
			rat_phase = 0.0
			rat_count += 1
			rat_gap_timer = rng.randf_range(0.08, 0.15)
		if rat_count >= rat_max and rat_phase > 0.06:
			rat_active = false

	if rat_active:
		rat_phase += delta

	# Distant person whistling (brief melodic tone)
	tune_timer -= delta
	if tune_timer <= 0.0 and not tune_active:
		tune_timer = rng.randf_range(25.0, 60.0)
		tune_active = true
		tune_phase = 0.0
		tune_duration = rng.randf_range(0.2, 0.5)
		# Pentatonic scale: C5, D5, E5, G5, A5
		var penta := [1046.5, 1174.7, 1318.5, 1568.0, 1760.0]
		tune_freq = penta[rng.randi_range(0, 4)]

	if tune_active:
		tune_phase += delta
		if tune_phase > tune_duration:
			tune_active = false

	# Distant church organ drone (very rare, eerie)
	organ_timer -= delta
	if organ_timer <= 0.0 and not organ_active:
		organ_timer = rng.randf_range(400.0, 700.0)
		organ_active = true
		organ_phase = 0.0
		organ_duration = rng.randf_range(5.0, 8.0)

	if organ_active:
		organ_phase += delta
		if organ_phase > organ_duration:
			organ_active = false

	# Distant ship/container horn (very deep blast, rare)
	ship_timer -= delta
	if ship_timer <= 0.0 and not ship_active:
		ship_timer = rng.randf_range(300.0, 500.0)
		ship_active = true
		ship_phase = 0.0
		ship_duration = rng.randf_range(3.0, 5.0)

	if ship_active:
		ship_phase += delta
		if ship_phase > ship_duration:
			ship_active = false

	# Distant TV static burst (channel change)
	tvstatic_timer -= delta
	if tvstatic_timer <= 0.0 and not tvstatic_active:
		tvstatic_timer = rng.randf_range(60.0, 120.0)
		tvstatic_active = true
		tvstatic_phase = 0.0
		tvstatic_duration = rng.randf_range(0.3, 0.8)
		tvstatic_filter = 0.0

	if tvstatic_active:
		tvstatic_phase += delta
		if tvstatic_phase > tvstatic_duration:
			tvstatic_active = false

	# Hour chime (Westminster melody on hour change)
	var dnc := get_node_or_null("../DayNightCycle")
	if dnc and "time_of_day" in dnc:
		var current_hour := int(dnc.time_of_day) % 24
		if last_hour == -1:
			last_hour = current_hour
		elif current_hour != last_hour:
			last_hour = current_hour
			hour_chime_active = true
			hour_chime_phase = 0.0
			hour_chime_note_idx = 0

	if hour_chime_active:
		hour_chime_phase += delta
		if hour_chime_phase > 4.0:
			hour_chime_active = false

	# Distant industrial metal clang
	clang_timer -= delta
	if clang_timer <= 0.0 and not clang_active:
		clang_timer = rng.randf_range(80.0, 150.0)
		clang_active = true
		clang_phase = 0.0
		clang_pitch = rng.randf_range(0.8, 1.2)

	if clang_active:
		clang_phase += delta
		if clang_phase > 0.3:
			clang_active = false

	# Neon sign electrical buzz
	neonbuzz_timer -= delta
	if neonbuzz_timer <= 0.0 and not neonbuzz_active:
		neonbuzz_timer = rng.randf_range(40.0, 80.0)
		neonbuzz_active = true
		neonbuzz_phase = 0.0
		neonbuzz_duration = rng.randf_range(1.0, 3.0)

	if neonbuzz_active:
		neonbuzz_phase += delta
		if neonbuzz_phase > neonbuzz_duration:
			neonbuzz_active = false

	# Distant jet flyover
	jet_timer -= delta
	if jet_timer <= 0.0 and not jet_active:
		jet_timer = rng.randf_range(120.0, 240.0)
		jet_active = true
		jet_phase = 0.0
		jet_duration = rng.randf_range(3.5, 5.0)

	if jet_active:
		jet_phase += delta
		if jet_phase > jet_duration:
			jet_active = false

	# Shopping cart rattle
	cart_timer -= delta
	if cart_timer <= 0.0 and not cart_active:
		cart_timer = rng.randf_range(80.0, 160.0)
		cart_active = true
		cart_phase = 0.0
		cart_duration = rng.randf_range(1.5, 3.0)

	if cart_active:
		cart_phase += delta
		if cart_phase > cart_duration:
			cart_active = false

	# Wind gust whoosh
	gust_timer -= delta
	if gust_timer <= 0.0 and not gust_active:
		gust_timer = rng.randf_range(30.0, 60.0)
		gust_active = true
		gust_phase = 0.0
		gust_duration = rng.randf_range(2.0, 4.0)

	if gust_active:
		gust_phase += delta
		if gust_phase > gust_duration:
			gust_active = false

	# Distant car alarm (alternating two-tone)
	car_alarm_timer -= delta
	if car_alarm_timer <= 0.0 and not car_alarm_active:
		car_alarm_timer = rng.randf_range(90.0, 180.0)
		car_alarm_active = true
		car_alarm_phase = 0.0
		car_alarm_duration = rng.randf_range(3.0, 5.0)

	if car_alarm_active:
		car_alarm_phase += delta
		if car_alarm_phase > car_alarm_duration:
			car_alarm_active = false

	# Chain link fence rattle (wind-driven metallic vibration)
	fence_timer -= delta
	if fence_timer <= 0.0 and not fence_active:
		fence_timer = rng.randf_range(45.0, 120.0)
		fence_active = true
		fence_phase = 0.0
		fence_duration = rng.randf_range(1.5, 3.0)

	if fence_active:
		fence_phase += delta
		if fence_phase > fence_duration:
			fence_active = false

	# Distant nightclub bass pulse (rhythmic kick)
	club_timer -= delta
	if club_timer <= 0.0 and not club_active:
		club_timer = rng.randf_range(60.0, 150.0)
		club_active = true
		club_phase = 0.0
		club_duration = rng.randf_range(8.0, 15.0)

	if club_active:
		club_phase += delta
		if club_phase > club_duration:
			club_active = false

	# Steam vent hiss (high-frequency noise burst)
	steam_timer -= delta
	if steam_timer <= 0.0 and not steam_active:
		steam_timer = rng.randf_range(40.0, 100.0)
		steam_active = true
		steam_phase = 0.0
		steam_duration = rng.randf_range(1.0, 3.0)

	if steam_active:
		steam_phase += delta
		if steam_phase > steam_duration:
			steam_active = false

	# Water pipe groan (deep metallic groan from underground)
	pipe_timer -= delta
	if pipe_timer <= 0.0 and not pipe_active:
		pipe_timer = rng.randf_range(60.0, 150.0)
		pipe_active = true
		pipe_phase = 0.0
		pipe_duration = rng.randf_range(2.0, 3.5)
		pipe_pitch = rng.randf_range(0.8, 1.2)

	if pipe_active:
		pipe_phase += delta
		if pipe_phase > pipe_duration:
			pipe_active = false

	# Electrical transformer hum (buzzing transformer box)
	xformer_timer -= delta
	if xformer_timer <= 0.0 and not xformer_active:
		xformer_timer = rng.randf_range(50.0, 120.0)
		xformer_active = true
		xformer_phase = 0.0
		xformer_duration = rng.randf_range(3.0, 5.0)

	if xformer_active:
		xformer_phase += delta
		if xformer_phase > xformer_duration:
			xformer_active = false

	# Door buzzer (harsh apartment intercom buzz)
	buzzer_timer -= delta
	if buzzer_timer <= 0.0 and not buzzer_active:
		buzzer_timer = rng.randf_range(80.0, 160.0)
		buzzer_active = true
		buzzer_phase = 0.0

	if buzzer_active:
		buzzer_phase += delta
		if buzzer_phase > 0.8:
			buzzer_active = false

	# Vending machine hum (compressor drone with periodic click)
	vend_timer -= delta
	if vend_timer <= 0.0 and not vend_active:
		vend_timer = rng.randf_range(70.0, 130.0)
		vend_active = true
		vend_phase = 0.0
		vend_duration = rng.randf_range(4.0, 6.0)

	if vend_active:
		vend_phase += delta
		if vend_phase > vend_duration:
			vend_active = false

	# Garbage can rattle (wind-triggered metallic clanking)
	var trash_rain := get_node_or_null("../Rain")
	var trash_wind: float = 0.0
	if trash_rain and "wind_x" in trash_rain:
		trash_wind = absf(trash_rain.wind_x)
	trash_timer -= delta
	if trash_timer <= 0.0 and not trash_active and trash_wind > 1.0:
		trash_timer = rng.randf_range(50.0, 100.0)
		trash_active = true
		trash_phase = 0.0
		trash_count = 0
		trash_max = rng.randi_range(2, 4)
		trash_gap = 0.0

	if trash_active:
		trash_gap -= delta
		if trash_gap <= 0.0 and trash_count < trash_max:
			trash_count += 1
			trash_phase = 0.0
			trash_gap = rng.randf_range(0.08, 0.15)
		trash_phase += delta
		if trash_count >= trash_max and trash_phase > 0.3:
			trash_active = false

	# Fluorescent light flicker buzz (dying tube stutter)
	fluor_timer -= delta
	if fluor_timer <= 0.0 and not fluor_active:
		fluor_timer = rng.randf_range(90.0, 180.0)
		fluor_active = true
		fluor_phase = 0.0
		fluor_duration = rng.randf_range(2.0, 4.0)

	if fluor_active:
		fluor_phase += delta
		# Random dropout gaps
		fluor_dropout -= delta
		if fluor_dropout <= 0.0:
			fluor_dropout = rng.randf_range(0.02, 0.08)
		if fluor_phase > fluor_duration:
			fluor_active = false

	# Metal gate creak (rusty hinge sweep)
	gate_timer -= delta
	if gate_timer <= 0.0 and not gate_active:
		gate_timer = rng.randf_range(70.0, 140.0)
		gate_active = true
		gate_phase = 0.0

	if gate_active:
		gate_phase += delta
		if gate_phase > 0.6:
			gate_active = false

	# Distant car engine idle (low rumble with irregular RPM wobble)
	engine_timer -= delta
	if engine_timer <= 0.0 and not engine_active:
		engine_timer = rng.randf_range(40.0, 90.0)
		engine_active = true
		engine_phase = 0.0
		engine_duration = rng.randf_range(4.0, 8.0)
		engine_rpm = rng.randf_range(0.8, 1.2)

	if engine_active:
		engine_phase += delta
		if engine_phase > engine_duration:
			engine_active = false

	# Elevator ding (bright bell tone, brief)
	elev_timer -= delta
	if elev_timer <= 0.0 and not elev_active:
		elev_timer = rng.randf_range(60.0, 150.0)
		elev_active = true
		elev_phase = 0.0

	if elev_active:
		elev_phase += delta
		if elev_phase > 0.8:
			elev_active = false

	# AC unit compressor cycling (building HVAC motor drone)
	ac_timer -= delta
	if ac_timer <= 0.0 and not ac_active:
		ac_timer = rng.randf_range(80.0, 120.0)
		ac_active = true
		ac_phase = 0.0
		ac_duration = rng.randf_range(6.0, 10.0)

	if ac_active:
		ac_phase += delta
		if ac_phase > ac_duration:
			ac_active = false

func _fill_rain_buffer() -> void:
	if not rain_playback:
		return
	var frames := rain_playback.get_frames_available()
	for _i in range(frames):
		# White noise filtered to sound like rain
		var noise := rng.randf_range(-1.0, 1.0)
		# Simple low-pass: mix with previous value
		rain_phase = rain_phase * 0.7 + noise * 0.3
		var sample := rain_phase * 0.4
		rain_playback.push_frame(Vector2(sample, sample))

func _fill_hum_buffer() -> void:
	if not hum_playback:
		return
	var frames := hum_playback.get_frames_available()
	var mix_rate := hum_generator.mix_rate
	for _i in range(frames):
		# Low frequency drone (60Hz fundamental + harmonics)
		hum_phase += 1.0 / mix_rate
		var t := hum_phase
		var sample := sin(t * 60.0 * TAU) * 0.3
		sample += sin(t * 120.0 * TAU) * 0.15
		sample += sin(t * 180.0 * TAU) * 0.05
		# Add siren if active (two variants)
		if siren_active:
			var siren_env := 0.08 * (1.0 - siren_phase / 4.0)
			if siren_type == 0:
				# American wail: smooth rising/falling
				var siren_freq := 600.0 + sin(siren_phase * 1.5) * 200.0
				sample += sin(t * siren_freq * TAU) * siren_env
			elif siren_type == 1:
				# European two-tone: alternating 600/800Hz
				var euro_toggle := sin(siren_phase * 1.5 * TAU)
				var euro_freq := 600.0 if euro_toggle > 0.0 else 800.0
				sample += sin(t * euro_freq * TAU) * siren_env
			else:
				# Ambulance: faster oscillation, higher pitch 800-1200Hz
				var ambu_freq := 1000.0 + sin(siren_phase * 3.0) * 200.0
				sample += sin(t * ambu_freq * TAU) * siren_env * 0.9
		# Add distant dog bark (short noise burst with resonance)
		if bark_active and bark_phase < 0.12:
			var bark_env := (1.0 - bark_phase / 0.12) * (1.0 - bark_phase / 0.12)
			var bark_noise := rng.randf_range(-1.0, 1.0)
			var bark_tone := sin(t * 350.0 * bark_pitch * TAU) * 0.4
			bark_tone += sin(t * 700.0 * bark_pitch * TAU) * 0.2
			sample += (bark_noise * 0.3 + bark_tone) * bark_env * 0.06
		# Add distant crow caw (harsh nasal tone burst)
		if crow_active and crow_phase < 0.18:
			var crow_env := (1.0 - crow_phase / 0.18) * (1.0 - crow_phase / 0.18)
			# Harsh nasal tone: square-ish wave with overtones
			var crow_fund := sin(t * 520.0 * crow_pitch * TAU)
			var crow_harm := sin(t * 1040.0 * crow_pitch * TAU) * 0.4
			var crow_harm2 := sin(t * 1560.0 * crow_pitch * TAU) * 0.15
			# Add noise for raspy texture
			var crow_noise := rng.randf_range(-1.0, 1.0) * 0.25
			var crow_raw := (crow_fund + crow_harm + crow_harm2 + crow_noise) * crow_env * 0.04
			# Downward pitch bend at end of caw
			if crow_phase > 0.1:
				crow_raw *= 0.7
			sample += crow_raw
		# Add distant train horn (low mournful two-tone)
		if train_active:
			var train_env := 1.0
			# Fade in over 0.3s, sustain, fade out over 0.5s
			if train_phase < 0.3:
				train_env = train_phase / 0.3
			elif train_phase > 2.5:
				train_env = (3.0 - train_phase) / 0.5
			# Two-tone chord (minor second, mournful)
			var horn1 := sin(t * 180.0 * train_pitch * TAU) * 0.3
			var horn2 := sin(t * 190.0 * train_pitch * TAU) * 0.25
			var horn3 := sin(t * 360.0 * train_pitch * TAU) * 0.08  # octave overtone
			# Doppler-like pitch bend at tail end
			var pitch_bend := 1.0
			if train_phase > 2.0:
				pitch_bend = 1.0 - (train_phase - 2.0) * 0.03
			var horn_sample := (horn1 + horn2 + horn3) * train_env * pitch_bend * 0.06
			sample += horn_sample
		# Add distant thunder rumble (low-pass filtered noise burst)
		if thunder_active:
			var thunder_env := (1.0 - thunder_phase / 3.5) * (1.0 - thunder_phase / 3.5)
			# Initial crack at the start
			var crack := 0.0
			if thunder_phase < 0.15:
				crack = rng.randf_range(-1.0, 1.0) * (1.0 - thunder_phase / 0.15) * 0.4
			# Low rumble body
			var rumble_noise := rng.randf_range(-1.0, 1.0)
			thunder_filter = thunder_filter * 0.92 + rumble_noise * 0.08
			var rumble := thunder_filter * 0.3 + sin(t * 30.0 * TAU) * 0.15
			sample += (crack + rumble) * thunder_env * 0.5
		# Distant car horn (short mid-frequency beep)
		if horn_active:
			var in_beep := false
			if horn_double:
				# Double honk: beep, gap, beep
				if horn_phase < horn_duration:
					in_beep = true
				elif horn_phase > horn_duration + 0.1 and horn_phase < horn_duration * 2.0 + 0.1:
					in_beep = true
			else:
				if horn_phase < horn_duration:
					in_beep = true
			if in_beep:
				var local_t := fmod(horn_phase, horn_duration + 0.1)
				var horn_env := 1.0
				if local_t < 0.02:
					horn_env = local_t / 0.02
				elif local_t > horn_duration - 0.03:
					horn_env = maxf(0.0, (horn_duration - local_t) / 0.03)
				var h1 := sin(t * 340.0 * horn_pitch * TAU) * 0.3
				var h2 := sin(t * 510.0 * horn_pitch * TAU) * 0.15
				sample += (h1 + h2) * horn_env * 0.05
		# Distant glass breaking (high-freq noise burst with tinkling resonance)
		if glass_active and glass_phase < 0.35:
			var glass_env := (1.0 - glass_phase / 0.35)
			# Initial impact (0-0.05s): sharp crack
			var glass_sample := 0.0
			if glass_phase < 0.05:
				glass_sample = rng.randf_range(-1.0, 1.0) * (1.0 - glass_phase / 0.05) * 0.6
			# Tinkling shards (0.03-0.35s): high-frequency resonant bursts
			if glass_phase > 0.03:
				var tinkle1 := sin(t * 2800.0 * TAU) * 0.15
				var tinkle2 := sin(t * 4200.0 * TAU) * 0.1
				var tinkle3 := sin(t * 6100.0 * TAU) * 0.05
				var tinkle_noise := rng.randf_range(-1.0, 1.0) * 0.2
				glass_sample += (tinkle1 + tinkle2 + tinkle3 + tinkle_noise) * glass_env * glass_env
			sample += glass_sample * 0.04
		# Distant door slam (percussive thud)
		if door_active and door_phase < 0.12:
			var door_env := (1.0 - door_phase / 0.12)
			door_env = door_env * door_env * door_env  # cubic decay
			var door_thud := sin(t * 120.0 * TAU) * 0.5
			door_thud += sin(t * 180.0 * TAU) * 0.2
			var door_noise := rng.randf_range(-1.0, 1.0) * 0.3
			sample += (door_thud + door_noise) * door_env * 0.04
		# Distant melody fragment (pentatonic sine tones)
		if melody_active and melody_notes.size() > 0:
			var note_dur := melody_duration / float(melody_notes.size())
			var current_note_idx := mini(int(melody_phase / note_dur), melody_notes.size() - 1)
			var note_local := fmod(melody_phase, note_dur)
			var mel_env := 1.0
			# Note envelope: fast attack, slow decay
			if note_local < 0.02:
				mel_env = note_local / 0.02
			else:
				mel_env = maxf(0.0, 1.0 - (note_local - 0.02) / (note_dur * 0.8))
			mel_env = mel_env * mel_env
			var freq := melody_notes[current_note_idx]
			var mel_tone := sin(t * freq * TAU) * 0.3
			mel_tone += sin(t * freq * 2.0 * TAU) * 0.08  # gentle octave
			sample += mel_tone * mel_env * 0.02
		# Distant explosion rumble (sub-bass boom)
		if explosion_active:
			var ex_env := 1.0
			if explosion_phase < 0.05:
				ex_env = explosion_phase / 0.05
			elif explosion_phase > explosion_duration * 0.3:
				ex_env = maxf(0.0, (explosion_duration - explosion_phase) / (explosion_duration * 0.7))
			ex_env = ex_env * ex_env
			# Sub-bass sine (25-40Hz)
			var boom := sin(t * 30.0 * TAU) * 0.5
			boom += sin(t * 55.0 * TAU) * 0.2
			# Impact noise
			var ex_noise := rng.randf_range(-1.0, 1.0)
			explosion_filter = explosion_filter * 0.9 + ex_noise * 0.1
			boom += explosion_filter * 0.3
			sample += boom * ex_env * 0.06
		# Distant phone ringtone (two-tone melodic beep)
		if phone_active:
			# Ring pattern: 0.15s on, 0.1s off, repeating
			var ring_pos := fmod(phone_phase, 0.5)
			if ring_pos < 0.15 or (ring_pos > 0.25 and ring_pos < 0.4):
				var ph_env := 0.8
				if ring_pos < 0.02:
					ph_env = ring_pos / 0.02
				var tone_a := sin(t * 800.0 * TAU) * 0.3
				var tone_b := sin(t * 1000.0 * TAU) * 0.2
				# Alternate tones per ring burst
				var use_a := ring_pos < 0.15
				var ph_sample := tone_a if use_a else tone_b
				sample += ph_sample * ph_env * 0.02
		# Electrical spark crackle (short high-freq burst)
		if spark_active and spark_phase < 0.12:
			var sp_env := (1.0 - spark_phase / 0.12)
			sp_env = sp_env * sp_env
			# Rapid random clicks/pops
			var sp_noise := rng.randf_range(-1.0, 1.0)
			var sp_high := sin(t * 5500.0 * TAU) * 0.2 + sin(t * 8200.0 * TAU) * 0.1
			# Gate: only crackle on random peaks
			var sp_gate := 1.0 if absf(sp_noise) > 0.5 else 0.0
			sample += (sp_noise * 0.4 + sp_high) * sp_env * sp_gate * 0.03
		# Distant club bass thump (4-on-the-floor kick)
		if bass_active:
			var beat_period := 60.0 / bass_bpm
			var beat_pos := fmod(bass_phase, beat_period)
			# Short low kick drum (sine wave with pitch decay)
			if beat_pos < 0.08:
				var kick_env := (1.0 - beat_pos / 0.08)
				kick_env = kick_env * kick_env  # squared envelope
				# Pitch drops from 150Hz to 50Hz during kick
				var kick_freq := 150.0 - beat_pos * 1200.0
				var kick := sin(t * kick_freq * TAU) * kick_env * 0.06
				# Fade in/out over duration
				var bass_env := 1.0
				if bass_phase < 1.0:
					bass_env = bass_phase
				elif bass_phase > bass_duration - 2.0:
					bass_env = (bass_duration - bass_phase) / 2.0
				sample += kick * clampf(bass_env, 0.0, 1.0)
		# Radio chatter burst (band-pass filtered noise, walkie-talkie texture)
		if radio_active:
			var radio_env := 1.0
			# Click-on at start, click-off at end
			if radio_phase < 0.03:
				radio_env = radio_phase / 0.03
			elif radio_phase > radio_duration - 0.05:
				radio_env = maxf(0.0, (radio_duration - radio_phase) / 0.05)
			# Band-pass noise (800-2000Hz range) to mimic voice texture
			var radio_noise := rng.randf_range(-1.0, 1.0)
			radio_filter = radio_filter * 0.6 + radio_noise * 0.4
			# Add formant-like resonances to suggest speech
			var formant1 := sin(t * 900.0 * TAU) * radio_filter * 0.3
			var formant2 := sin(t * 1400.0 * TAU) * radio_filter * 0.2
			# Squelch click at start/end
			var squelch := 0.0
			if radio_phase < 0.02 or (radio_phase > radio_duration - 0.02 and radio_phase < radio_duration):
				squelch = rng.randf_range(-1.0, 1.0) * 0.3
			sample += (formant1 + formant2 + squelch) * radio_env * 0.04
		# Water drip (short high-freq ping with decay)
		if drip_active and drip_phase < 0.06:
			var drip_env := (1.0 - drip_phase / 0.06)
			drip_env = drip_env * drip_env * drip_env  # cubic decay
			var drip_tone := sin(t * 3200.0 * TAU) * 0.3
			drip_tone += sin(t * 4800.0 * TAU) * 0.15
			sample += drip_tone * drip_env * 0.025
		# Distant PA/megaphone (filtered speech-like noise with syllable rhythm)
		if pa_active:
			var pa_env := 1.0
			if pa_phase < 0.1:
				pa_env = pa_phase / 0.1
			elif pa_phase > pa_duration - 0.3:
				pa_env = maxf(0.0, (pa_duration - pa_phase) / 0.3)
			var pa_noise := rng.randf_range(-1.0, 1.0)
			pa_filter = pa_filter * 0.5 + pa_noise * 0.5
			# Formant resonances for speech-like quality
			var f1 := sin(t * 500.0 * TAU) * pa_filter * 0.3
			var f2 := sin(t * 1200.0 * TAU) * pa_filter * 0.2
			var f3 := sin(t * 2400.0 * TAU) * pa_filter * 0.1
			# Syllable rhythm (~3 per second)
			var syllable := 0.6 + 0.4 * absf(sin(pa_phase * 3.0 * PI))
			sample += (f1 + f2 + f3) * pa_env * syllable * 0.02
		# Distant car alarm (oscillating two-tone beep)
		if alarm_active:
			var alarm_env := 0.8
			if alarm_phase < 0.1:
				alarm_env = alarm_phase / 0.1 * 0.8
			elif alarm_phase > alarm_duration - 0.3:
				alarm_env = maxf(0.0, (alarm_duration - alarm_phase) / 0.3) * 0.8
			var alarm_toggle := sin(alarm_phase * 4.0 * TAU)
			var alarm_freq := 800.0 if alarm_toggle > 0.0 else 1000.0
			var alarm_tone := sin(t * alarm_freq * TAU) * 0.3
			sample += alarm_tone * alarm_env * 0.02
		# Wind whistle through buildings (high airy tone with wobble)
		if whistle_active:
			var ws_env := 1.0
			if whistle_phase < 0.3:
				ws_env = whistle_phase / 0.3
			elif whistle_phase > whistle_duration - 0.5:
				ws_env = maxf(0.0, (whistle_duration - whistle_phase) / 0.5)
			ws_env = ws_env * ws_env  # smooth fade
			var ws_wobble := 1.0 + sin(whistle_phase * 7.0) * 0.05
			var ws_freq := 900.0 * whistle_pitch * ws_wobble
			var ws_tone := sin(t * ws_freq * TAU) * 0.2
			ws_tone += sin(t * ws_freq * 1.5 * TAU) * 0.08  # harmonic
			# Add breathy noise component
			var ws_noise := rng.randf_range(-1.0, 1.0) * 0.1
			sample += (ws_tone + ws_noise) * ws_env * 0.015
		# Distant subway rumble (sub-bass vibration)
		if subway_active:
			var sub_env := 1.0
			if subway_phase < 0.8:
				sub_env = subway_phase / 0.8
			elif subway_phase > subway_duration - 1.5:
				sub_env = maxf(0.0, (subway_duration - subway_phase) / 1.5)
			sub_env = sub_env * sub_env
			# Very low rumble (20-35Hz)
			var rumble := sin(t * 22.0 * TAU) * 0.4
			rumble += sin(t * 35.0 * TAU) * 0.2
			# Add rattling texture
			var sub_noise := rng.randf_range(-1.0, 1.0)
			subway_filter = subway_filter * 0.88 + sub_noise * 0.12
			rumble += subway_filter * 0.15
			sample += rumble * sub_env * 0.04
		# Pigeon cooing (gentle wobbling tone)
		if pigeon_active and pigeon_phase < 0.22:
			var pg_env := 1.0
			if pigeon_phase < 0.03:
				pg_env = pigeon_phase / 0.03
			elif pigeon_phase > 0.12:
				pg_env = maxf(0.0, (0.22 - pigeon_phase) / 0.1)
			pg_env = pg_env * pg_env
			# Gentle warbling tone (~350Hz with vibrato)
			var pg_vibrato := 1.0 + sin(pigeon_phase * 30.0) * 0.08
			var pg_freq := 340.0 * pigeon_pitch * pg_vibrato
			var pg_tone := sin(t * pg_freq * TAU) * 0.3
			pg_tone += sin(t * pg_freq * 2.0 * TAU) * 0.1  # octave
			sample += pg_tone * pg_env * 0.015
		# Distant construction hammering (rhythmic metallic impacts)
		if construction_active:
			var con_env := 1.0
			if construction_phase < 0.3:
				con_env = construction_phase / 0.3
			elif construction_phase > construction_duration - 0.5:
				con_env = maxf(0.0, (construction_duration - construction_phase) / 0.5)
			var hit_period := 1.0 / construction_bpm
			var hit_pos := fmod(construction_phase, hit_period)
			if hit_pos < 0.025:
				var hit_env := (1.0 - hit_pos / 0.025)
				hit_env = hit_env * hit_env * hit_env
				# Metallic impact: mid-freq ring + noise
				var ring := sin(t * 420.0 * TAU) * 0.3
				ring += sin(t * 680.0 * TAU) * 0.15
				var impact_noise := rng.randf_range(-1.0, 1.0) * 0.4
				sample += (ring + impact_noise) * hit_env * con_env * 0.025
		# Distant helicopter blade chop (rhythmic low-freq thumping)
		if heli_active:
			var heli_env := 1.0
			if heli_phase < 1.5:
				heli_env = heli_phase / 1.5
			elif heli_phase > heli_duration - 2.0:
				heli_env = maxf(0.0, (heli_duration - heli_phase) / 2.0)
			heli_env = heli_env * heli_env
			# Blade chop: ~6Hz rhythmic pulse (360 RPM)
			var chop_cycle := fmod(t * 6.0 * TAU, TAU)
			var chop_pulse := maxf(0.0, sin(chop_cycle))
			chop_pulse = chop_pulse * chop_pulse  # sharpen pulse
			# Low thump + whoosh
			var heli_thump := sin(t * 40.0 * TAU) * chop_pulse * 0.3
			var heli_whoosh := rng.randf_range(-1.0, 1.0) * chop_pulse * 0.15
			sample += (heli_thump + heli_whoosh) * heli_env * 0.03
		# Distant crowd cheer/applause (burst of filtered noise with energy swell)
		if cheer_active:
			var ch_env := 1.0
			if cheer_phase < 0.2:
				ch_env = cheer_phase / 0.2
			elif cheer_phase > cheer_duration - 0.5:
				ch_env = maxf(0.0, (cheer_duration - cheer_phase) / 0.5)
			# Swell envelope: rises then fades
			var swell := sin(cheer_phase / cheer_duration * PI)
			ch_env *= swell
			var ch_noise := rng.randf_range(-1.0, 1.0)
			cheer_filter = cheer_filter * 0.6 + ch_noise * 0.4
			# Band-pass: multiple voices merged into roar
			var ch_tone := cheer_filter * 0.3
			ch_tone += sin(t * 600.0 * TAU) * cheer_filter * 0.15
			ch_tone += sin(t * 1100.0 * TAU) * cheer_filter * 0.1
			sample += ch_tone * ch_env * 0.02
		# Distant baby crying (wavering high-pitched wail)
		if baby_active:
			var by_env := 1.0
			if baby_phase < 0.15:
				by_env = baby_phase / 0.15
			elif baby_phase > baby_duration - 0.3:
				by_env = maxf(0.0, (baby_duration - baby_phase) / 0.3)
			# Cry has rhythmic bursts (~2.5Hz sobbing rhythm)
			var sob := maxf(0.0, sin(baby_phase * 2.5 * TAU))
			by_env *= sob
			# High-pitched wail with vibrato (~650Hz)
			var cry_vib := 1.0 + sin(baby_phase * 18.0) * 0.06
			var cry_freq := 650.0 * cry_vib
			var cry_tone := sin(t * cry_freq * TAU) * 0.3
			cry_tone += sin(t * cry_freq * 1.5 * TAU) * 0.12
			cry_tone += sin(t * cry_freq * 2.0 * TAU) * 0.06
			sample += cry_tone * by_env * 0.012
		# Distant wind chime / music box tinkle (metallic bell tones)
		if chime_active and chime_notes.size() > 0:
			var note_dur := chime_duration / float(chime_notes.size())
			var ci := mini(int(chime_phase / note_dur), chime_notes.size() - 1)
			var note_local := fmod(chime_phase, note_dur)
			var cm_env := 1.0
			# Sharp attack, long decay
			if note_local < 0.005:
				cm_env = note_local / 0.005
			else:
				cm_env = maxf(0.0, 1.0 - (note_local - 0.005) / (note_dur * 0.9))
			cm_env = cm_env * cm_env  # squared for bell-like decay
			var cm_freq := chime_notes[ci]
			# Metallic bell: fundamental + inharmonic overtones
			var bell := sin(t * cm_freq * TAU) * 0.25
			bell += sin(t * cm_freq * 2.76 * TAU) * 0.1  # inharmonic partial
			bell += sin(t * cm_freq * 5.4 * TAU) * 0.04  # high shimmer
			sample += bell * cm_env * 0.015
		# Distant squealing brakes (descending high-pitched screech)
		if brake_active:
			var bk_env := 1.0
			if brake_phase < 0.05:
				bk_env = brake_phase / 0.05
			elif brake_phase > brake_duration - 0.1:
				bk_env = maxf(0.0, (brake_duration - brake_phase) / 0.1)
			# Descending pitch: 1500Hz -> 800Hz
			var bk_progress := clampf(brake_phase / brake_duration, 0.0, 1.0)
			var bk_freq := 1500.0 - bk_progress * 700.0
			var bk_tone := sin(t * bk_freq * TAU) * 0.2
			bk_tone += sin(t * bk_freq * 1.5 * TAU) * 0.08
			var bk_noise := rng.randf_range(-1.0, 1.0) * 0.15
			sample += (bk_tone + bk_noise) * bk_env * 0.02
		# Distant metal gate slam (single resonant clang)
		if gate_active and gate_phase < 0.12:
			var gt_env := (1.0 - gate_phase / 0.12)
			gt_env = gt_env * gt_env * gt_env
			var gt_tone := sin(t * 280.0 * TAU) * 0.3
			gt_tone += sin(t * 560.0 * TAU) * 0.15
			gt_tone += sin(t * 840.0 * TAU) * 0.05
			var gt_noise := rng.randf_range(-1.0, 1.0) * 0.25
			sample += (gt_tone + gt_noise) * gt_env * 0.03
		# Distant foghorn (deep mournful blast)
		if foghorn_active:
			var fh_env := 1.0
			if foghorn_phase < 0.5:
				fh_env = foghorn_phase / 0.5
			elif foghorn_phase > foghorn_duration - 0.5:
				fh_env = maxf(0.0, (foghorn_duration - foghorn_phase) / 0.5)
			fh_env = fh_env * fh_env
			var fh_tone := sin(t * 85.0 * TAU) * 0.35
			fh_tone += sin(t * 170.0 * TAU) * 0.15
			fh_tone += sin(t * 255.0 * TAU) * 0.05
			sample += fh_tone * fh_env * 0.03
		# Distant crowd laughter burst (energetic noise burst)
		if laughter_active:
			var la_env := 1.0
			if laughter_phase < 0.1:
				la_env = laughter_phase / 0.1
			elif laughter_phase > laughter_duration - 0.2:
				la_env = maxf(0.0, (laughter_duration - laughter_phase) / 0.2)
			# Rising then falling energy
			var la_swell := sin(laughter_phase / laughter_duration * PI)
			la_env *= la_swell
			var la_noise := rng.randf_range(-1.0, 1.0)
			laughter_filter = laughter_filter * 0.5 + la_noise * 0.5
			# Formant resonances for voice-like quality
			var la_f1 := sin(t * 700.0 * TAU) * laughter_filter * 0.2
			var la_f2 := sin(t * 1500.0 * TAU) * laughter_filter * 0.12
			# "Ha ha" rhythm (~5Hz syllable pattern)
			var ha_rhythm := maxf(0.0, sin(laughter_phase * 5.0 * TAU))
			sample += (la_f1 + la_f2) * la_env * ha_rhythm * 0.018
		# Distant firework (ascending whistle + pop + crackle)
		if firework_active:
			if firework_phase < 0.5:
				# Ascending whistle
				var fw_env := firework_phase / 0.5
				var fw_freq := 400.0 + firework_phase * 3200.0  # 400 -> 2000Hz
				var fw_whistle := sin(t * fw_freq * TAU) * 0.15
				sample += fw_whistle * fw_env * 0.025
			elif firework_phase < 0.55:
				# Pop (sharp noise burst)
				var pop_env := (0.55 - firework_phase) / 0.05
				pop_env = pop_env * pop_env
				var pop := rng.randf_range(-1.0, 1.0) * 0.5
				pop += sin(t * 200.0 * TAU) * 0.3
				sample += pop * pop_env * 0.05
			elif firework_phase < 1.3:
				# Crackle/sparkle tail
				var cr_env := maxf(0.0, (1.3 - firework_phase) / 0.75)
				cr_env = cr_env * cr_env
				var sparkle := sin(t * 3500.0 * TAU) * 0.1
				sparkle += sin(t * 5200.0 * TAU) * 0.05
				var cr_noise := rng.randf_range(-1.0, 1.0) * 0.2
				# Gate to create sparkle bursts
				var cr_gate := 1.0 if absf(cr_noise) > 0.4 else 0.0
				sample += (sparkle + cr_noise * 0.3) * cr_env * cr_gate * 0.02
		# Dumpster lid rattle (metallic impacts in quick succession)
		if dumpster_active:
			var dm_env := 1.0
			if dumpster_phase > dumpster_duration - 0.1:
				dm_env = maxf(0.0, (dumpster_duration - dumpster_phase) / 0.1)
			# Rapid metallic impacts (~8Hz)
			var rattle_pos := fmod(dumpster_phase, 0.125)
			if rattle_pos < 0.03:
				var rt_env := (1.0 - rattle_pos / 0.03)
				rt_env = rt_env * rt_env * rt_env
				var rt_tone := sin(t * 380.0 * TAU) * 0.2
				rt_tone += sin(t * 550.0 * TAU) * 0.15
				var rt_noise := rng.randf_range(-1.0, 1.0) * 0.3
				sample += (rt_tone + rt_noise) * rt_env * dm_env * 0.02
		# Distant cat fight screech (high warbling screech)
		if cat_screech_active:
			var cs_env := 1.0
			if cat_screech_phase < 0.05:
				cs_env = cat_screech_phase / 0.05
			elif cat_screech_phase > cat_screech_duration - 0.1:
				cs_env = maxf(0.0, (cat_screech_duration - cat_screech_phase) / 0.1)
			# Intermittent screech bursts
			var screech_burst := maxf(0.0, sin(cat_screech_phase * 8.0 * TAU))
			cs_env *= screech_burst
			# High warbling tone with rapid vibrato
			var cs_vib := 1.0 + sin(cat_screech_phase * 35.0) * 0.1
			var cs_freq := 900.0 * cs_vib
			var cs_tone := sin(t * cs_freq * TAU) * 0.25
			cs_tone += sin(t * cs_freq * 2.0 * TAU) * 0.15
			cs_tone += sin(t * cs_freq * 3.0 * TAU) * 0.05
			# Harsh noise
			var cs_noise := rng.randf_range(-1.0, 1.0) * 0.15
			sample += (cs_tone + cs_noise) * cs_env * 0.015
		# Glass bottle clink (short high metallic tink)
		if clink_active and clink_phase < 0.04:
			var cl_env := (1.0 - clink_phase / 0.04)
			cl_env = cl_env * cl_env * cl_env
			var cl_tone := sin(t * 2200.0 * TAU) * 0.2
			cl_tone += sin(t * 3300.0 * TAU) * 0.12
			cl_tone += sin(t * 5500.0 * TAU) * 0.04
			sample += cl_tone * cl_env * 0.02
		# Distant motorcycle rev (low growl with pitch bend)
		if moto_active:
			var mt_env := 1.0
			if moto_phase < 0.15:
				mt_env = moto_phase / 0.15
			elif moto_phase > moto_duration - 0.3:
				mt_env = maxf(0.0, (moto_duration - moto_phase) / 0.3)
			# Rev-up pitch bend: 120Hz -> 200Hz
			var rev_progress := clampf(moto_phase / moto_duration, 0.0, 1.0)
			var moto_freq := 120.0 + rev_progress * 80.0
			var moto_tone := sin(t * moto_freq * TAU) * 0.25
			moto_tone += sin(t * moto_freq * 2.0 * TAU) * 0.12  # harmonic
			moto_tone += sin(t * moto_freq * 3.0 * TAU) * 0.05  # grit
			# Engine noise texture
			var moto_noise := rng.randf_range(-1.0, 1.0) * 0.15
			sample += (moto_tone + moto_noise) * mt_env * 0.02
		# Distant train crossing bell (rhythmic metallic dinging)
		if crossing_active:
			var cr_env := 1.0
			if crossing_phase < 0.2:
				cr_env = crossing_phase / 0.2
			elif crossing_phase > crossing_duration - 0.5:
				cr_env = maxf(0.0, (crossing_duration - crossing_phase) / 0.5)
			# Ding at ~3Hz rhythm
			var ding_period := 1.0 / 3.0
			var ding_pos := fmod(crossing_phase, ding_period)
			if ding_pos < 0.06:
				var ding_env := (1.0 - ding_pos / 0.06)
				ding_env = ding_env * ding_env
				var ding := sin(t * 1800.0 * TAU) * 0.25
				ding += sin(t * 1800.0 * 2.76 * TAU) * 0.08
				sample += ding * ding_env * cr_env * 0.018
		# Distant gunshot (sharp crack + reverb tail)
		if gunshot_active and gunshot_phase < 0.5:
			if gunshot_phase < 0.02:
				# Sharp crack: wideband noise burst
				var gs_env := (1.0 - gunshot_phase / 0.02)
				gs_env = gs_env * gs_env * gs_env
				var gs_crack := rng.randf_range(-1.0, 1.0) * 0.5
				gs_crack += sin(t * 1800.0 * TAU) * 0.2
				sample += gs_crack * gs_env * 0.04
			# Reverb tail: filtered decay
			if gunshot_phase > 0.01 and gunshot_phase < 0.5:
				var rv_env := maxf(0.0, (0.5 - gunshot_phase) / 0.49)
				rv_env = rv_env * rv_env
				var rv_noise := rng.randf_range(-1.0, 1.0)
				gunshot_reverb = gunshot_reverb * 0.92 + rv_noise * 0.08
				sample += gunshot_reverb * rv_env * 0.025
		# Distant temple/church bell toll (deep resonant ring)
		if bell_active and bell_phase < 2.0:
			var bl_env := 1.0
			if bell_phase < 0.01:
				bl_env = bell_phase / 0.01
			else:
				bl_env = maxf(0.0, (2.0 - bell_phase) / 1.99)
			bl_env = bl_env * bl_env  # squared for bell decay
			# Deep bell: fundamental ~220Hz + inharmonic partials
			var bl_tone := sin(t * 220.0 * TAU) * 0.3
			bl_tone += sin(t * 220.0 * 2.76 * TAU) * 0.12  # inharmonic
			bl_tone += sin(t * 220.0 * 5.4 * TAU) * 0.04   # high shimmer
			bl_tone += sin(t * 110.0 * TAU) * 0.15          # sub-octave
			sample += bl_tone * bl_env * 0.02
		# Distant car crash (tire screech + metal crunch + glass)
		if crash_active:
			if crash_phase < 0.4:
				# Tire screech (descending high-pitched squeal)
				var sc_env := 1.0
				if crash_phase < 0.03:
					sc_env = crash_phase / 0.03
				sc_env *= maxf(0.0, 1.0 - crash_phase / 0.4)
				var sc_freq := 2000.0 - crash_phase * 3000.0  # rapid descent
				var sc_tone := sin(t * sc_freq * TAU) * 0.2
				sc_tone += sin(t * sc_freq * 1.3 * TAU) * 0.1
				var sc_noise := rng.randf_range(-1.0, 1.0) * 0.25
				sample += (sc_tone + sc_noise) * sc_env * 0.03
			if crash_phase > 0.35 and crash_phase < 0.55:
				# Metal crunch impact
				var cr_local := crash_phase - 0.35
				var cr_env := maxf(0.0, 1.0 - cr_local / 0.2)
				cr_env = cr_env * cr_env * cr_env
				var cr_tone := sin(t * 150.0 * TAU) * 0.3
				cr_tone += sin(t * 340.0 * TAU) * 0.2
				cr_tone += sin(t * 680.0 * TAU) * 0.1
				var cr_noise := rng.randf_range(-1.0, 1.0) * 0.5
				sample += (cr_tone + cr_noise) * cr_env * 0.04
			if crash_phase > 0.5 and crash_phase < crash_duration:
				# Glass shatter tail
				var gl_local := crash_phase - 0.5
				var gl_dur := crash_duration - 0.5
				var gl_env := maxf(0.0, 1.0 - gl_local / gl_dur)
				gl_env = gl_env * gl_env
				# High tinkling noise
				var gl_noise := rng.randf_range(-1.0, 1.0)
				var gl_tone := sin(t * 4500.0 * TAU) * 0.08
				gl_tone += sin(t * 6200.0 * TAU) * 0.04
				# Gated sparkle effect
				var gl_gate := 1.0 if absf(gl_noise) > 0.5 else 0.0
				sample += (gl_tone + gl_noise * 0.15) * gl_env * gl_gate * 0.02
		# Rat squeaking (rapid high-pitched chirps)
		if rat_active and rat_phase < 0.06:
			var rt_env := 1.0
			if rat_phase < 0.005:
				rt_env = rat_phase / 0.005
			else:
				rt_env = maxf(0.0, 1.0 - (rat_phase - 0.005) / 0.055)
			rt_env = rt_env * rt_env
			# Very high squeaky tones with fast vibrato
			var rt_vib := sin(rat_phase * 45.0 * TAU) * 200.0
			var rt_freq := rng.randf_range(3000.0, 4000.0) + rt_vib
			var rt_tone := sin(t * rt_freq * TAU) * 0.15
			rt_tone += sin(t * rt_freq * 1.6 * TAU) * 0.06
			sample += rt_tone * rt_env * 0.015
		# Distant person whistling (brief pure tone)
		if tune_active:
			var wh_env := 1.0
			if tune_phase < 0.03:
				wh_env = tune_phase / 0.03
			elif tune_phase > tune_duration - 0.05:
				wh_env = maxf(0.0, (tune_duration - tune_phase) / 0.05)
			wh_env = wh_env * wh_env
			# Pure sine tone with slight vibrato
			var wh_vib := sin(tune_phase * 6.0 * TAU) * 8.0
			var wh_tone := sin(t * (tune_freq + wh_vib) * TAU) * 0.2
			sample += wh_tone * wh_env * 0.015
		# Distant church organ drone (eerie sustained chord)
		if organ_active:
			var og_env := 1.0
			if organ_phase < 1.5:
				og_env = organ_phase / 1.5  # slow swell in
			elif organ_phase > organ_duration - 2.0:
				og_env = maxf(0.0, (organ_duration - organ_phase) / 2.0)
			og_env = og_env * og_env  # smooth curve
			# C2 + E3 + G3 chord with organ-like harmonics
			var og_c := sin(t * 130.8 * TAU) * 0.15
			og_c += sin(t * 261.6 * TAU) * 0.08  # octave
			var og_e := sin(t * 164.8 * TAU) * 0.12
			og_e += sin(t * 329.6 * TAU) * 0.06  # octave
			var og_g := sin(t * 196.0 * TAU) * 0.10
			og_g += sin(t * 392.0 * TAU) * 0.05  # octave
			# Slight tremolo for pipe organ vibrato
			var og_trem := 1.0 + sin(t * 5.5 * TAU) * 0.06
			sample += (og_c + og_e + og_g) * og_env * og_trem * 0.012
		# Distant ship/container horn (very deep resonant blast)
		if ship_active:
			var sh_env := 1.0
			if ship_phase < 0.8:
				sh_env = ship_phase / 0.8
			elif ship_phase > ship_duration - 1.0:
				sh_env = maxf(0.0, (ship_duration - ship_phase) / 1.0)
			sh_env = sh_env * sh_env
			# Very low fundamental: 55Hz + sub-harmonics
			var sh_tone := sin(t * 55.0 * TAU) * 0.35
			sh_tone += sin(t * 110.0 * TAU) * 0.15
			sh_tone += sin(t * 27.5 * TAU) * 0.2  # sub-octave rumble
			# Slight beating from detuned partial
			sh_tone += sin(t * 57.0 * TAU) * 0.1
			sample += sh_tone * sh_env * 0.025
		# Distant TV static burst (bandpass noise, channel change)
		if tvstatic_active:
			var tv_env := 1.0
			if tvstatic_phase < 0.03:
				tv_env = tvstatic_phase / 0.03
			elif tvstatic_phase > tvstatic_duration - 0.05:
				tv_env = maxf(0.0, (tvstatic_duration - tvstatic_phase) / 0.05)
			var tv_noise := rng.randf_range(-1.0, 1.0)
			tvstatic_filter = tvstatic_filter * 0.5 + tv_noise * 0.5
			# Bandpass 800-3000Hz: resonant peaks
			var tv_bp := sin(t * 1200.0 * TAU) * tvstatic_filter * 0.2
			tv_bp += sin(t * 2400.0 * TAU) * tvstatic_filter * 0.1
			sample += tv_bp * tv_env * 0.02
		# Hour chime melody (Westminster: E4, C4, D4, G3)
		if hour_chime_active:
			var chime_freqs: Array[float] = [329.6, 261.6, 293.7, 196.0]
			var note_dur := 1.0
			var ci := mini(int(hour_chime_phase / note_dur), 3)
			var note_local := fmod(hour_chime_phase, note_dur)
			var hc_env := 1.0
			if note_local < 0.01:
				hc_env = note_local / 0.01
			else:
				hc_env = maxf(0.0, 1.0 - (note_local - 0.01) / 0.9)
			hc_env = hc_env * hc_env  # bell decay
			var hc_freq := chime_freqs[ci]
			var hc_tone := sin(t * hc_freq * TAU) * 0.25
			hc_tone += sin(t * hc_freq * 2.76 * TAU) * 0.1  # inharmonic
			hc_tone += sin(t * hc_freq * 0.5 * TAU) * 0.1  # sub-octave
			sample += hc_tone * hc_env * 0.025
		# Distant industrial metal clang (resonant low-mid impact)
		if clang_active and clang_phase < 0.3:
			var cl_env := (1.0 - clang_phase / 0.3)
			cl_env = cl_env * cl_env * cl_env
			var cl_ring := sin(t * 250.0 * clang_pitch * TAU) * 0.3
			cl_ring += sin(t * 400.0 * clang_pitch * TAU) * 0.15
			cl_ring += sin(t * 630.0 * clang_pitch * TAU) * 0.08
			var cl_noise := rng.randf_range(-1.0, 1.0) * 0.2
			sample += (cl_ring + cl_noise) * cl_env * 0.03
		# Neon sign electrical buzz (120Hz mains hum + harmonics)
		if neonbuzz_active:
			var nb_env := 1.0
			if neonbuzz_phase < 0.1:
				nb_env = neonbuzz_phase / 0.1
			elif neonbuzz_phase > neonbuzz_duration - 0.2:
				nb_env = maxf(0.0, (neonbuzz_duration - neonbuzz_phase) / 0.2)
			# Amplitude flicker
			var flicker := 0.7 + 0.3 * sin(neonbuzz_phase * 7.3)
			var buzz := sin(t * 120.0 * TAU) * 0.5
			buzz += sin(t * 240.0 * TAU) * 0.3
			buzz += sin(t * 360.0 * TAU) * 0.15
			sample += buzz * nb_env * flicker * 0.012

		# Distant jet flyover (low rumble with slow volume swell)
		if jet_active:
			var jet_env := 0.0
			if jet_phase < jet_duration * 0.4:
				jet_env = jet_phase / (jet_duration * 0.4)  # swell in
			elif jet_phase < jet_duration * 0.6:
				jet_env = 1.0  # peak
			else:
				jet_env = (jet_duration - jet_phase) / (jet_duration * 0.4)  # fade out
			jet_env = maxf(0.0, jet_env)
			var jet_noise := rng.randf_range(-1.0, 1.0)
			var jet_rumble := sin(t * 45.0 * TAU) * 0.3 + sin(t * 90.0 * TAU) * 0.2
			jet_rumble += jet_noise * 0.15
			sample += jet_rumble * jet_env * jet_env * 0.018

		# Shopping cart rattle (metallic jingle + wheel clatter)
		if cart_active:
			var cart_env := 1.0
			if cart_phase < 0.15:
				cart_env = cart_phase / 0.15
			elif cart_phase > cart_duration - 0.3:
				cart_env = maxf(0.0, (cart_duration - cart_phase) / 0.3)
			# Rapid metallic pings at ~12Hz
			var ping_rate := 12.0 + sin(cart_phase * 3.0) * 2.0
			var ping := sin(cart_phase * ping_rate * TAU) * 0.4
			ping += sin(cart_phase * ping_rate * 2.3 * TAU) * 0.25
			# Wheel rumble (low noise)
			var wheel := rng.randf_range(-1.0, 1.0) * 0.2
			sample += (ping + wheel) * cart_env * 0.008

		# Wind gust whoosh (low filtered noise swell)
		if gust_active:
			var gust_env := 0.0
			if gust_phase < gust_duration * 0.3:
				gust_env = gust_phase / (gust_duration * 0.3)
			elif gust_phase < gust_duration * 0.5:
				gust_env = 1.0
			else:
				gust_env = (gust_duration - gust_phase) / (gust_duration * 0.5)
			gust_env = maxf(0.0, gust_env)
			var gust_noise := rng.randf_range(-1.0, 1.0)
			gust_filter = gust_filter * 0.88 + gust_noise * 0.12  # low-pass ~100Hz band
			var whoosh := gust_filter * 0.6
			whoosh += sin(t * 80.0 * TAU) * gust_filter * 0.2  # resonant hum
			sample += whoosh * gust_env * gust_env * 0.02

		# Distant car alarm (alternating 800Hz/600Hz two-tone at 2Hz switch)
		if car_alarm_active:
			var ca_env := 0.0
			if car_alarm_phase < 0.3:
				ca_env = car_alarm_phase / 0.3
			elif car_alarm_phase < car_alarm_duration - 0.5:
				ca_env = 1.0
			else:
				ca_env = (car_alarm_duration - car_alarm_phase) / 0.5
			ca_env = maxf(0.0, ca_env)
			var tone_switch := fmod(car_alarm_phase * 2.0, 1.0)
			var freq := 800.0 if tone_switch < 0.5 else 600.0
			var alarm_tone := sin(t * freq * TAU) * 0.6
			alarm_tone += sin(t * freq * 2.0 * TAU) * 0.2  # harmonic
			sample += alarm_tone * ca_env * 0.006

		# Chain link fence rattle (high-frequency metallic vibration)
		if fence_active:
			var fe_env := 0.0
			if fence_phase < 0.2:
				fe_env = fence_phase / 0.2
			elif fence_phase < fence_duration - 0.4:
				fe_env = 1.0
			else:
				fe_env = (fence_duration - fence_phase) / 0.4
			fe_env = maxf(0.0, fe_env)
			var fe_noise := rng.randf_range(-1.0, 1.0)
			fence_filter = fence_filter * 0.3 + fe_noise * 0.7  # high-pass for metallic
			var rattle := fence_filter * 0.4
			rattle += sin(t * 2000.0 * TAU) * fence_filter * 0.3  # metallic resonance
			rattle += sin(t * 3500.0 * TAU) * fence_filter * 0.15  # harmonic
			sample += rattle * fe_env * 0.005

		# Distant nightclub bass pulse (rhythmic 128BPM kick at 60Hz)
		if club_active:
			var cl_env := 0.0
			if club_phase < 0.5:
				cl_env = club_phase / 0.5
			elif club_phase < club_duration - 1.0:
				cl_env = 1.0
			else:
				cl_env = (club_duration - club_phase) / 1.0
			cl_env = maxf(0.0, cl_env)
			# 128 BPM = 2.133 beats/sec
			var beat_phase := fmod(club_phase * 2.133, 1.0)
			var kick_env := maxf(0.0, 1.0 - beat_phase * 6.0)  # sharp attack, fast decay
			kick_env = kick_env * kick_env
			var kick := sin(t * 60.0 * TAU) * kick_env * 0.7
			kick += sin(t * 30.0 * TAU) * kick_env * 0.3  # sub bass
			sample += kick * cl_env * 0.004

		# Steam vent hiss (high-pass filtered noise with metallic resonance)
		if steam_active:
			var st_env := 0.0
			if steam_phase < 0.1:
				st_env = steam_phase / 0.1  # sharp attack
			elif steam_phase < steam_duration - 0.5:
				st_env = 1.0
			else:
				st_env = (steam_duration - steam_phase) / 0.5
			st_env = maxf(0.0, st_env)
			var st_noise := rng.randf_range(-1.0, 1.0)
			steam_filter = steam_filter * 0.4 + st_noise * 0.6  # high-pass
			var hiss := steam_filter * 0.5
			hiss += sin(t * 4000.0 * TAU) * steam_filter * 0.25  # resonance
			sample += hiss * st_env * 0.008

		# Water pipe groan (deep metallic resonance from underground)
		if pipe_active:
			var pp_env := 0.0
			if pipe_phase < 0.3:
				pp_env = pipe_phase / 0.3
			elif pipe_phase < pipe_duration - 0.8:
				pp_env = 1.0 - (pipe_phase - 0.3) * 0.1  # slow fade
			else:
				pp_env = maxf(0.0, (pipe_duration - pipe_phase) / 0.8)
			pp_env = maxf(0.0, pp_env)
			var pp_base := sin(t * 45.0 * pipe_pitch * TAU) * 0.4
			pp_base += sin(t * 90.0 * pipe_pitch * TAU) * 0.25  # 2nd harmonic
			pp_base += sin(t * 135.0 * pipe_pitch * TAU) * 0.15  # 3rd harmonic
			var pp_bend := sin(pipe_phase * 1.5) * 0.1  # slow pitch wobble
			pp_base += sin(t * (45.0 + pp_bend * 10.0) * pipe_pitch * TAU) * 0.1
			sample += pp_base * pp_env * 0.006

		# Electrical transformer hum (120Hz buzz with amplitude modulation)
		if xformer_active:
			var xf_env := 0.0
			if xformer_phase < 0.2:
				xf_env = xformer_phase / 0.2
			elif xformer_phase < xformer_duration - 0.5:
				xf_env = 1.0
			else:
				xf_env = (xformer_duration - xformer_phase) / 0.5
			xf_env = maxf(0.0, xf_env)
			var am := 0.6 + 0.4 * sin(t * 2.0 * TAU)  # 2Hz amplitude modulation
			var xf_tone := sin(t * 120.0 * TAU) * 0.5
			xf_tone += sin(t * 240.0 * TAU) * 0.25  # 2nd harmonic
			xf_tone += sin(t * 360.0 * TAU) * 0.1  # 3rd harmonic
			sample += xf_tone * xf_env * am * 0.005

		# Door buzzer (harsh apartment intercom, 0.8s duration)
		if buzzer_active:
			var bz_env := 0.0
			if buzzer_phase < 0.03:
				bz_env = buzzer_phase / 0.03  # sharp attack
			elif buzzer_phase < 0.75:
				bz_env = 1.0
			else:
				bz_env = (0.8 - buzzer_phase) / 0.05
			bz_env = maxf(0.0, bz_env)
			# Square-ish wave via odd harmonics
			var bz_tone := sin(t * 400.0 * TAU) * 0.5
			bz_tone += sin(t * 1200.0 * TAU) * 0.15  # 3rd harmonic
			bz_tone += sin(t * 200.0 * TAU) * 0.3  # undertone
			bz_tone = clampf(bz_tone * 1.5, -0.8, 0.8)  # soft clip for distortion
			sample += bz_tone * bz_env * 0.006

		# Vending machine hum (compressor drone + periodic relay click)
		if vend_active:
			var vm_env := 0.0
			if vend_phase < 0.3:
				vm_env = vend_phase / 0.3
			elif vend_phase < vend_duration - 0.5:
				vm_env = 1.0
			else:
				vm_env = (vend_duration - vend_phase) / 0.5
			vm_env = maxf(0.0, vm_env)
			var vm_hum := sin(t * 80.0 * TAU) * 0.5
			vm_hum += sin(t * 160.0 * TAU) * 0.2
			# Periodic relay click every ~0.4s
			var vm_click_phase := fmod(vend_phase, 0.4)
			if vm_click_phase < 0.01:
				vm_hum += rng.randf_range(-1.0, 1.0) * 0.8  # click transient
			sample += vm_hum * vm_env * 0.004

		# Garbage can rattle (metallic clanking in wind)
		if trash_active and trash_phase < 0.15:
			var tr_env := (0.15 - trash_phase) / 0.15
			tr_env *= tr_env
			var tr_ring := sin(trash_phase * 800.0 * TAU) * 0.4
			tr_ring += sin(trash_phase * 1600.0 * TAU) * 0.25
			tr_ring += rng.randf_range(-1.0, 1.0) * 0.3  # metallic noise
			sample += tr_ring * tr_env * 0.007

		# Fluorescent light flicker buzz (stuttering dying tube)
		if fluor_active:
			var fl_env := 0.0
			if fluor_phase < 0.1:
				fl_env = fluor_phase / 0.1
			elif fluor_phase < fluor_duration - 0.3:
				fl_env = 1.0
			else:
				fl_env = (fluor_duration - fluor_phase) / 0.3
			fl_env = maxf(0.0, fl_env)
			# Dropout: silence during gaps
			var fl_gap := maxf(fluor_dropout, 0.01)
			var fl_on := fmod(fluor_phase, fl_gap * 2.0) > fl_gap * 0.3
			if fl_on:
				var fl_buzz := sin(t * 120.0 * TAU) * 0.4
				fl_buzz += sin(t * 240.0 * TAU) * 0.2
				fl_buzz += rng.randf_range(-1.0, 1.0) * 0.15
				sample += fl_buzz * fl_env * 0.004

		# Metal gate creak (descending frequency sweep with resonance)
		if gate_active:
			var gk_env := 0.0
			if gate_phase < 0.05:
				gk_env = gate_phase / 0.05
			elif gate_phase < 0.5:
				gk_env = 1.0 - (gate_phase - 0.05) * 0.8
			else:
				gk_env = maxf(0.0, (0.6 - gate_phase) / 0.1)
			var gk_freq := lerpf(600.0, 200.0, gate_phase / 0.6)  # descending sweep
			var gk_tone := sin(t * gk_freq * TAU) * 0.4
			gk_tone += sin(t * gk_freq * 2.0 * TAU) * 0.15  # metallic overtone
			var gk_noise := rng.randf_range(-1.0, 1.0) * 0.2
			sample += (gk_tone + gk_noise) * gk_env * 0.006

		# Distant car engine idle (low-frequency rumble with RPM wobble)
		if engine_active:
			var en_env := 0.0
			if engine_phase < 0.5:
				en_env = engine_phase / 0.5
			elif engine_phase < engine_duration - 1.0:
				en_env = 1.0
			else:
				en_env = maxf(0.0, (engine_duration - engine_phase) / 1.0)
			var rpm_wobble := 1.0 + sin(engine_phase * 1.7) * 0.05 + sin(engine_phase * 0.6) * 0.08
			var en_base := sin(t * 35.0 * engine_rpm * rpm_wobble * TAU) * 0.35
			en_base += sin(t * 70.0 * engine_rpm * rpm_wobble * TAU) * 0.25
			en_base += sin(t * 105.0 * engine_rpm * rpm_wobble * TAU) * 0.1
			en_base += rng.randf_range(-1.0, 1.0) * 0.15  # combustion noise
			sample += en_base * en_env * 0.005

		# Elevator ding (bright bell with decaying harmonics)
		if elev_active:
			var el_env := exp(-elev_phase * 5.0)  # fast exponential decay
			var el_tone := sin(t * 3520.0 * TAU) * 0.5  # A7 ~3520Hz
			el_tone += sin(t * 5274.0 * TAU) * 0.3  # 5th harmonic-ish
			el_tone += sin(t * 7040.0 * TAU) * 0.1  # octave above
			sample += el_tone * el_env * 0.008

		# AC unit compressor cycling (building HVAC motor hum)
		if ac_active:
			var ac_env := 0.0
			if ac_phase < 1.0:
				ac_env = ac_phase / 1.0
			elif ac_phase < ac_duration - 1.5:
				ac_env = 1.0
			else:
				ac_env = maxf(0.0, (ac_duration - ac_phase) / 1.5)
			var ac_am := 1.0 + sin(ac_phase * 3.5) * 0.15  # amplitude modulation
			var ac_tone := sin(t * 50.0 * TAU) * 0.35 * ac_am
			ac_tone += sin(t * 100.0 * TAU) * 0.2
			ac_tone += sin(t * 150.0 * TAU) * 0.08
			ac_tone += rng.randf_range(-1.0, 1.0) * 0.1  # motor noise
			sample += ac_tone * ac_env * 0.004

		# Distant crowd murmur (band-limited noise, 200-800Hz band)
		var murmur_noise := rng.randf_range(-1.0, 1.0)
		murmur_filter1 = murmur_filter1 * 0.85 + murmur_noise * 0.15
		murmur_filter2 = murmur_filter2 * 0.7 + murmur_filter1 * 0.3
		var murmur := (murmur_filter1 - murmur_filter2) * 0.04
		sample += murmur
		sample *= 0.3
		hum_playback.push_frame(Vector2(sample, sample))

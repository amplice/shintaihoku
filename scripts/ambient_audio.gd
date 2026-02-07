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
		# Add siren if active (rising/falling tone)
		if siren_active:
			var siren_freq := 600.0 + sin(siren_phase * 1.5) * 200.0
			sample += sin(t * siren_freq * TAU) * 0.08 * (1.0 - siren_phase / 4.0)
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
		# Distant crowd murmur (band-limited noise, 200-800Hz band)
		var murmur_noise := rng.randf_range(-1.0, 1.0)
		murmur_filter1 = murmur_filter1 * 0.85 + murmur_noise * 0.15
		murmur_filter2 = murmur_filter2 * 0.7 + murmur_filter1 * 0.3
		var murmur := (murmur_filter1 - murmur_filter2) * 0.04
		sample += murmur
		sample *= 0.3
		hum_playback.push_frame(Vector2(sample, sample))

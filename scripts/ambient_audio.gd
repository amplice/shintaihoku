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
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 1234

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

func _process(delta: float) -> void:
	_fill_rain_buffer()
	_fill_hum_buffer()

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
	elif lightning_light:
		lightning_light.light_energy = 0.0

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
		# Distant crowd murmur (band-limited noise, 200-800Hz band)
		var murmur_noise := rng.randf_range(-1.0, 1.0)
		murmur_filter1 = murmur_filter1 * 0.85 + murmur_noise * 0.15
		murmur_filter2 = murmur_filter2 * 0.7 + murmur_filter1 * 0.3
		var murmur := (murmur_filter1 - murmur_filter2) * 0.04
		sample += murmur
		sample *= 0.3
		hum_playback.push_frame(Vector2(sample, sample))

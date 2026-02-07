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

	if thunder_active:
		thunder_phase += delta
		if thunder_phase > 3.5:
			thunder_active = false

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
		sample *= 0.3
		hum_playback.push_frame(Vector2(sample, sample))

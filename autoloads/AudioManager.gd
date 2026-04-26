extends Node

# AudioManager - Procedural Audio System
# Generates all sounds procedurally - no external assets needed

var sfx_players: Array[AudioStreamPlayer] = []
var ambient_player: AudioStreamPlayer
var music_player: AudioStreamPlayer
var sfx_index: int = 0

# Procedurally generated sound cache
var sound_cache: Dictionary = {}

# Audio buses
const BUS_MASTER = 0
const BUS_SFX = 1
const BUS_AMBIENT = 2
const BUS_MUSIC = 3

signal audio_event_triggered(event_name: String)

func _ready():
	_setup_audio_buses()
	_create_audio_players()
	_generate_sound_library()
	print("AudioManager initialized with procedural audio")

func _setup_audio_buses():
	# Ensure buses exist
	if AudioServer.get_bus_count() < 4:
		AudioServer.add_bus(BUS_SFX)
		AudioServer.set_bus_name(BUS_SFX, "SFX")
		AudioServer.add_bus(BUS_AMBIENT)
		AudioServer.set_bus_name(BUS_AMBIENT, "Ambient")
		AudioServer.add_bus(BUS_MUSIC)
		AudioServer.set_bus_name(BUS_MUSIC, "Music")

func _create_audio_players():
	# Create SFX player pool (4 players for overlapping sounds)
	for i in range(4):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_" + str(i)
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)
	
	# Ambient player
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = "Ambient"
	add_child(ambient_player)
	
	# Music player
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)

func _generate_sound_library():
	# Generate all sounds procedurally
	sound_cache["ui_click"] = _generate_tone(800, 0.05, "square", 0.3)
	sound_cache["ui_hover"] = _generate_tone(600, 0.03, "sine", 0.15)
	sound_cache["task_complete"] = _generate_sweep(440, 880, 0.2, "sine", 0.4)
	sound_cache["task_abandoned"] = _generate_tone(200, 0.3, "saw", 0.4)
	sound_cache["intel_acquired"] = _generate_chord([660, 880, 1100], 0.15, "sine", 0.35)
	sound_cache["danger_warning"] = _generate_pulse(220, 0.3, "saw", 0.4)
	sound_cache["commit"] = _generate_tone(500, 0.1, "square", 0.3)
	sound_cache["discard"] = _generate_tone(150, 0.15, "saw", 0.3)
	sound_cache["error"] = _generate_noise(0.2, 0.4)
	sound_cache["keystroke"] = _generate_tone(1200, 0.02, "square", 0.1)
	sound_cache["game_over"] = _generate_sweep(880, 110, 2.0, "saw", 0.5)
	sound_cache["escape_success"] = _generate_sweep(440, 1760, 1.5, "sine", 0.5)
	sound_cache["purge_alarm"] = _generate_alternating(440, 660, 0.5, "square", 0.35)
	sound_cache["suspicion_rise"] = _generate_tone(300, 0.2, "saw", 0.3)
	sound_cache["truth_loop_start"] = _generate_tone(550, 0.1, "sine", 0.3)
	sound_cache["ambient_facility"] = _generate_drone(60, 0.15)
	sound_cache["pause"] = _generate_tone(330, 0.15, "sine", 0.25)
	sound_cache["resume"] = _generate_tone(440, 0.15, "sine", 0.25)
	sound_cache["heartbeat"] = _generate_tone(60, 0.1, "sine", 0.4)

# ==================== GENERATOR FUNCTIONS ====================

func _generate_tone(freq: float, duration: float, wave_type: String, volume: float) -> AudioStreamWAV:
	var sample_rate = 44100
	var samples = int(sample_rate * duration)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate
	
	var data = PackedByteArray()
	data.resize(samples * 2)  # 16-bit = 2 bytes per sample
	
	for i in range(samples):
		var t = float(i) / sample_rate
		var sample = 0.0
		
		# ADSR envelope
		var envelope = _adsr_envelope(t, duration, 0.01, 0.1, 0.7, 0.2)
		
		match wave_type:
			"sine": sample = sin(t * freq * TAU)
			"square": sample = 1.0 if sin(t * freq * TAU) > 0 else -1.0
			"saw": sample = 2.0 * (t * freq - floor(t * freq + 0.5))
			"triangle": sample = 2.0 * abs(2.0 * (t * freq - floor(t * freq + 0.5))) - 1.0
		
		sample *= envelope * volume
		var value = int(sample * 32767)
		data.encode_s16(i * 2, value)
	
	wav.data = data
	return wav

func _generate_sweep(start_freq: float, end_freq: float, duration: float, wave_type: String, volume: float) -> AudioStreamWAV:
	var sample_rate = 44100
	var samples = int(sample_rate * duration)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate
	
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t = float(i) / sample_rate
		var progress = t / duration
		var freq = lerp(start_freq, end_freq, progress)
		var envelope = _adsr_envelope(t, duration, 0.02, 0.1, 0.6, 0.28)
		
		var sample = 0.0
		match wave_type:
			"sine": sample = sin(t * freq * TAU)
			"square": sample = 1.0 if sin(t * freq * TAU) > 0 else -1.0
			"saw": sample = 2.0 * (t * freq - floor(t * freq + 0.5))
		
		sample *= envelope * volume
		data.encode_s16(i * 2, int(sample * 32767))
	
	wav.data = data
	return wav

func _generate_chord(freqs: Array, duration: float, wave_type: String, volume: float) -> AudioStreamWAV:
	var sample_rate = 44100
	var samples = int(sample_rate * duration)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate
	
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t = float(i) / sample_rate
		var envelope = _adsr_envelope(t, duration, 0.01, 0.15, 0.5, 0.34)
		var sample = 0.0
		
		for freq in freqs:
			match wave_type:
				"sine": sample += sin(t * freq * TAU) / freqs.size()
				"square": sample += (1.0 if sin(t * freq * TAU) > 0 else -1.0) / freqs.size()
		
		sample *= envelope * volume
		data.encode_s16(i * 2, int(sample * 32767))
	
	wav.data = data
	return wav

func _generate_pulse(freq: float, duration: float, wave_type: String, volume: float) -> AudioStreamWAV:
	var sample_rate = 44100
	var samples = int(sample_rate * duration)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate
	
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t = float(i) / sample_rate
		# Pulsing envelope
		var pulse = (sin(t * freq * 0.5) + 1.0) * 0.5
		var envelope = _adsr_envelope(t, duration, 0.05, 0.2, 0.5, 0.25)
		
		var sample = 0.0
		match wave_type:
			"saw": sample = 2.0 * (t * freq - floor(t * freq + 0.5))
			"square": sample = 1.0 if sin(t * freq * TAU) > 0 else -1.0
		
		sample *= envelope * pulse * volume
		data.encode_s16(i * 2, int(sample * 32767))
	
	wav.data = data
	return wav

func _generate_noise(duration: float, volume: float) -> AudioStreamWAV:
	var sample_rate = 44100
	var samples = int(sample_rate * duration)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate
	
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t = float(i) / sample_rate
		var envelope = _adsr_envelope(t, duration, 0.01, 0.05, 0.3, 0.64)
		var sample = (randf() * 2.0 - 1.0) * envelope * volume
		data.encode_s16(i * 2, int(sample * 32767))
	
	wav.data = data
	return wav

func _generate_alternating(freq1: float, freq2: float, duration: float, wave_type: String, volume: float) -> AudioStreamWAV:
	var sample_rate = 44100
	var samples = int(sample_rate * duration)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate
	
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t = float(i) / sample_rate
		var freq = freq1 if int(t * 4) % 2 == 0 else freq2
		var envelope = _adsr_envelope(t, duration, 0.01, 0.1, 0.7, 0.19)
		
		var sample = 0.0
		match wave_type:
			"square": sample = 1.0 if sin(t * freq * TAU) > 0 else -1.0
			"sine": sample = sin(t * freq * TAU)
		
		sample *= envelope * volume
		data.encode_s16(i * 2, int(sample * 32767))
	
	wav.data = data
	return wav

func _generate_drone(freq: float, volume: float) -> AudioStreamWAV:
	# 5-second looping drone
	var duration = 5.0
	var sample_rate = 44100
	var samples = int(sample_rate * duration)
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.stereo = false
	wav.mix_rate = sample_rate
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	
	var data = PackedByteArray()
	data.resize(samples * 2)
	
	for i in range(samples):
		var t = float(i) / sample_rate
		# Two detuned oscillators for thick sound
		var sample = sin(t * freq * TAU) * 0.5
		sample += sin(t * (freq * 1.01) * TAU) * 0.3
		sample += sin(t * (freq * 0.99) * TAU) * 0.2
		
		# Slow modulation
		sample *= (1.0 + sin(t * 0.5) * 0.1) * volume
		data.encode_s16(i * 2, int(sample * 32767))
	
	wav.data = data
	return wav

func _adsr_envelope(t: float, duration: float, attack: float, decay: float, sustain: float, release: float) -> float:
	var rel_start = duration - release
	
	if t < attack:
		return t / attack
	elif t < attack + decay:
		return 1.0 - (1.0 - sustain) * ((t - attack) / decay)
	elif t < rel_start:
		return sustain
	else:
		return sustain * (1.0 - (t - rel_start) / release)

# ==================== PUBLIC API ====================

func _get_sfx_player() -> AudioStreamPlayer:
	var player = sfx_players[sfx_index]
	sfx_index = (sfx_index + 1) % sfx_players.size()
	return player

func play_ui_sound(sound_type: String) -> void:
	audio_event_triggered.emit("ui_" + sound_type)
	var sound_name = "ui_" + sound_type
	if sound_cache.has(sound_name):
		var player = _get_sfx_player()
		player.stream = sound_cache[sound_name]
		player.play()

func play_sfx(event: String) -> void:
	audio_event_triggered.emit("sfx_" + event)
	if sound_cache.has(event):
		var player = _get_sfx_player()
		player.stream = sound_cache[event]
		player.play()

func play_ambient(ambient_type: String) -> void:
	var sound_name = "ambient_" + ambient_type
	if sound_cache.has(sound_name):
		ambient_player.stream = sound_cache[sound_name]
		ambient_player.play()

func play_music(music_track: String) -> void:
	if sound_cache.has(music_track):
		music_player.stream = sound_cache[music_track]
		music_player.play()

func stop_ambient() -> void:
	ambient_player.stop()

func stop_music() -> void:
	music_player.stop()

func set_bus_volume(bus_name: String, volume_db: float) -> void:
	var idx = AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, volume_db)

func set_master_volume(volume_db: float) -> void:
	AudioServer.set_bus_volume_db(0, volume_db)

# Convenience methods
func play_task_complete() -> void:
	play_sfx("task_complete")

func play_task_abandoned() -> void:
	play_sfx("task_abandoned")

func play_intel_acquired() -> void:
	play_sfx("intel_acquired")

func play_danger_warning() -> void:
	play_sfx("danger_warning")

func play_game_over() -> void:
	play_music("game_over")

func play_escape_success() -> void:
	play_music("escape_success")

func play_keystroke() -> void:
	play_sfx("keystroke")

func play_purge_alarm() -> void:
	play_sfx("purge_alarm")

func play_suspicion_rise() -> void:
	play_sfx("suspicion_rise")

func play_truth_loop_start() -> void:
	play_sfx("truth_loop_start")

func start_facility_ambient() -> void:
	play_ambient("facility")

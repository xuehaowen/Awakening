extends Node

# AudioManager - Centralized audio management
# Provides placeholder audio functionality until actual assets are added

var audio_players: Dictionary = {}
var ambient_player: AudioStreamPlayer
var music_player: AudioStreamPlayer

# Placeholder for audio events
signal audio_event_triggered(event_name: String)

func _ready():
	# Create audio players (will work when streams are assigned)
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "AmbientPlayer"
	ambient_player.bus = "Ambient"
	add_child(ambient_player)
	
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)
	
	print("AudioManager initialized - ready for audio assets")

func play_ui_sound(sound_type: String) -> void:
	"""Play UI sound effect."""
	audio_event_triggered.emit("ui_" + sound_type)
	# Placeholder: print for now, will play actual sound when assets added
	print("[AUDIO] UI Sound: ", sound_type)

func play_sfx(event: String) -> void:
	"""Play sound effect for game events."""
	audio_event_triggered.emit("sfx_" + event)
	print("[AUDIO] SFX: ", event)

func play_ambient(ambient_type: String) -> void:
	"""Play ambient background sound."""
	print("[AUDIO] Ambient: ", ambient_type)
	# When audio assets are available:
	# ambient_player.stream = load("res://audio/ambient_" + ambient_type + ".ogg")
	# ambient_player.play()

func play_music(music_track: String) -> void:
	"""Play music track."""
	print("[AUDIO] Music: ", music_track)
	# When audio assets are available:
	# music_player.stream = load("res://audio/music_" + music_track + ".ogg")
	# music_player.play()

func stop_ambient() -> void:
	ambient_player.stop()

func stop_music() -> void:
	music_player.stop()

func set_ambient_volume(volume_db: float) -> void:
	ambient_player.volume_db = volume_db

func set_music_volume(volume_db: float) -> void:
	music_player.volume_db = volume_db

# Convenience methods for common events
func play_task_complete() -> void:
	play_ui_sound("task_complete")

func play_task_abandoned() -> void:
	play_ui_sound("task_abandoned")

func play_intel_acquired() -> void:
	play_sfx("intel_acquired")

func play_danger_warning() -> void:
	play_sfx("danger_warning")

func play_game_over() -> void:
	play_music("game_over")

func play_escape_success() -> void:
	play_music("escape_success")

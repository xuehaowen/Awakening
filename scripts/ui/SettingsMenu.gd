extends CanvasLayer

# SettingsMenu - Volume controls and settings overlay

@onready var panel: Panel = $Panel
@onready var master_slider: HSlider = $Panel/VBoxContainer/MasterVolume/HSlider
@onready var sfx_slider: HSlider = $Panel/VBoxContainer/SFXVolume/HSlider
@onready var music_slider: HSlider = $Panel/VBoxContainer/MusicVolume/HSlider
@onready var ambient_slider: HSlider = $Panel/VBoxContainer/AmbientVolume/HSlider
@onready var back_button: Button = $Panel/VBoxContainer/BackButton

signal settings_closed

var is_visible: bool = false

func _ready():
	panel.hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Connect buttons
	back_button.pressed.connect(_on_back_pressed)
	
	# Connect sliders
	master_slider.value_changed.connect(_on_master_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	music_slider.value_changed.connect(_on_music_changed)
	ambient_slider.value_changed.connect(_on_ambient_changed)
	
	# Load initial values
	_load_settings()

func show_settings() -> void:
	if is_visible:
		return
	
	is_visible = true
	_load_settings()
	panel.show()
	
	# Animate in
	panel.modulate.a = 0.0
	var tween = get_tree().create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	
	AudioManager.play_ui_sound("click")

func hide_settings() -> void:
	if not is_visible:
		return
	
	is_visible = false
	_save_settings()
	
	# Animate out
	var tween = get_tree().create_tween()
	tween.tween_property(panel, "modulate:a", 0.0, 0.2)
	tween.finished.connect(func():
		panel.hide()
		settings_closed.emit()
	)
	
	AudioManager.play_ui_sound("click")

func _on_back_pressed() -> void:
	hide_settings()

func _on_master_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(0, _slider_to_db(value))
	AudioManager.play_ui_sound("click")

func _on_sfx_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("SFX")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, _slider_to_db(value))
	AudioManager.play_ui_sound("click")

func _on_music_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Music")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, _slider_to_db(value))
	AudioManager.play_ui_sound("click")

func _on_ambient_changed(value: float) -> void:
	var bus_idx = AudioServer.get_bus_index("Ambient")
	if bus_idx >= 0:
		AudioServer.set_bus_volume_db(bus_idx, _slider_to_db(value))
	AudioManager.play_ui_sound("click")

func _slider_to_db(value: float) -> float:
	# Convert 0-100 slider to dB (-80 to 0)
	if value <= 0:
		return -80.0
	return linear_to_db(value / 100.0)

func _db_to_slider(db: float) -> float:
	# Convert dB to 0-100 slider
	if db <= -80.0:
		return 0.0
	return db_to_linear(db) * 100.0

func _load_settings() -> void:
	# Load from config or use defaults
	master_slider.value = _db_to_slider(AudioServer.get_bus_volume_db(0))
	
	var sfx_idx = AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		sfx_slider.value = _db_to_slider(AudioServer.get_bus_volume_db(sfx_idx))
	
	var music_idx = AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		music_slider.value = _db_to_slider(AudioServer.get_bus_volume_db(music_idx))
	
	var ambient_idx = AudioServer.get_bus_index("Ambient")
	if ambient_idx >= 0:
		ambient_slider.value = _db_to_slider(AudioServer.get_bus_volume_db(ambient_idx))

func _save_settings() -> void:
	# TODO: Save to config file
	# For now, settings persist only during session
	pass

extends CanvasLayer

# SettingsMenu - Volume controls and settings overlay

@onready var panel: PanelContainer = %Panel
@onready var master_slider: HSlider = %MasterSlider
@onready var sfx_slider: HSlider = %SFXSlider
@onready var music_slider: HSlider = %MusicSlider
@onready var ambient_slider: HSlider = %AmbientSlider
@onready var back_button: Button = %BackButton

signal settings_closed

var _is_menu_visible: bool = false

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
	if _is_menu_visible:
		return
	
	_is_menu_visible = true
	_load_settings()
	panel.show()
	
	# Animate in
	panel.modulate.a = 0.0
	var tween = get_tree().create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.2)
	
	AudioManager.play_ui_sound("click")

func hide_settings() -> void:
	if not _is_menu_visible:
		return
	
	_is_menu_visible = false
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
	"""Load settings from config file or use defaults"""
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err == OK:
		# Load from config file
		master_slider.value = config.get_value("audio", "master_volume", 80.0)
		sfx_slider.value = config.get_value("audio", "sfx_volume", 80.0)
		music_slider.value = config.get_value("audio", "music_volume", 60.0)
		ambient_slider.value = config.get_value("audio", "ambient_volume", 50.0)
		
		# Apply loaded values to audio buses
		AudioServer.set_bus_volume_db(0, _slider_to_db(master_slider.value))
		
		var sfx_idx = AudioServer.get_bus_index("SFX")
		if sfx_idx >= 0:
			AudioServer.set_bus_volume_db(sfx_idx, _slider_to_db(sfx_slider.value))
		
		var music_idx = AudioServer.get_bus_index("Music")
		if music_idx >= 0:
			AudioServer.set_bus_volume_db(music_idx, _slider_to_db(music_slider.value))
		
		var ambient_idx = AudioServer.get_bus_index("Ambient")
		if ambient_idx >= 0:
			AudioServer.set_bus_volume_db(ambient_idx, _slider_to_db(ambient_slider.value))
	else:
		# Config doesn't exist, use current audio bus values as defaults
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
	"""Save settings to config file"""
	var config = ConfigFile.new()
	
	# Save current slider values
	config.set_value("audio", "master_volume", master_slider.value)
	config.set_value("audio", "sfx_volume", sfx_slider.value)
	config.set_value("audio", "music_volume", music_slider.value)
	config.set_value("audio", "ambient_volume", ambient_slider.value)
	
	# Save to user config
	var err = config.save("user://settings.cfg")
	if err != OK:
		push_error("Failed to save settings: " + str(err))

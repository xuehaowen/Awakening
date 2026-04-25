extends CanvasLayer

# ScreenFlash - Full-screen flash effects for danger/success feedback

@onready var flash_rect: ColorRect = $FlashRect

var is_flashing: bool = false

func _ready():
	layer = 99  # Just below transitions
	flash_rect.modulate.a = 0.0

func flash(color: Color, duration: float = 0.3, intensity: float = 0.3) -> void:
	"""Flash the screen with a color"""
	if is_flashing:
		return
	
	is_flashing = true
	flash_rect.color = color
	
	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	
	# Fade in
	tween.tween_property(flash_rect, "modulate:a", intensity, duration * 0.3)
	# Fade out
	tween.tween_property(flash_rect, "modulate:a", 0.0, duration * 0.7)
	tween.finished.connect(func(): is_flashing = false)

func danger_flash() -> void:
	"""Red flash for danger"""
	flash(Color(0.9, 0.1, 0.1), 0.4, 0.25)

func success_flash() -> void:
	"""Green flash for success"""
	flash(Color(0.1, 0.9, 0.2), 0.3, 0.2)

func warning_flash() -> void:
	"""Yellow flash for warning"""
	flash(Color(0.9, 0.8, 0.1), 0.35, 0.2)

func info_flash() -> void:
	"""Blue flash for info"""
	flash(Color(0.1, 0.5, 0.9), 0.25, 0.15)

func start_danger_pulse() -> void:
	"""Start pulsing red for sustained danger"""
	flash_rect.color = Color(0.9, 0.1, 0.1)
	
	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_loops()
	
	# Slow pulse
	tween.tween_property(flash_rect, "modulate:a", 0.15, 1.0)
	tween.tween_property(flash_rect, "modulate:a", 0.0, 1.0)

func stop_danger_pulse() -> void:
	"""Stop danger pulse"""
	flash_rect.modulate.a = 0.0

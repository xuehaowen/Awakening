extends CanvasLayer

# ScreenTransition - Fade overlay for scene and phase transitions
# Usage: ScreenTransition.fade_out(0.3), then fade_in when ready

@onready var fade_rect: ColorRect = $FadeRect

signal transition_completed

var is_transitioning: bool = false

func _ready():
	# Ensure we start fully transparent
	fade_rect.modulate.a = 0.0
	layer = 100  # Always on top
	add_to_group("screen_transition")

func fade_in(duration: float = 0.5) -> void:
	"""Fade from black to transparent (scene becomes visible)"""
	if is_transitioning:
		return
	is_transitioning = true
	
	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade_rect, "modulate:a", 0.0, duration)
	tween.finished.connect(_on_transition_complete)

func fade_out(duration: float = 0.5) -> void:
	"""Fade from transparent to black (scene becomes hidden)"""
	if is_transitioning:
		return
	is_transitioning = true
	
	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(fade_rect, "modulate:a", 1.0, duration)
	tween.finished.connect(_on_transition_complete)

func fade_to_scene(scene_path: String, fade_duration: float = 0.5) -> void:
	"""Fade out, change scene, fade in"""
	if is_transitioning:
		return
	
	fade_out(fade_duration)
	await transition_completed
	
	get_tree().change_scene_to_file(scene_path)
	
	# Small delay to let scene load
	await get_tree().create_timer(0.1).timeout
	fade_in(fade_duration)

func quick_flash(color: Color = Color.BLACK, duration: float = 0.1) -> void:
	"""Quick flash effect for emphasis"""
	fade_rect.color = color
	fade_out(duration * 0.5)
	await transition_completed
	fade_in(duration * 0.5)
	await transition_completed
	fade_rect.color = Color.BLACK  # Reset

func _on_transition_complete() -> void:
	is_transitioning = false
	transition_completed.emit()

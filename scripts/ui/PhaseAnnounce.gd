extends CanvasLayer

# PhaseAnnounce - Shows phase transition announcements

@onready var announce_label: Label = $CenterContainer/AnnounceLabel
@onready var timer: Timer = $Timer

var is_showing: bool = false

func _ready():
	layer = 95
	visible = false
	
	# Connect to Blackboard signal
	Blackboard.phase_changed.connect(_on_phase_changed)
	timer.timeout.connect(_on_timer_timeout)

func show_announcement(phase: int) -> void:
	"""Show announcement for phase"""
	if is_showing:
		return
	
	is_showing = true
	visible = true
	
	var text = ""
	var color = Color.WHITE
	
	match phase:
		DayManager.DayPhase.CALIBRATION:
			text = ">>> CALIBRATION PHASE <<"
			color = Color(0.3, 0.6, 0.9)  # Blue
		DayManager.DayPhase.SHIFT:
			text = ">>> SHIFT PHASE INITIATED <<<"
			color = Color(0.2, 0.9, 0.4)  # Green
		DayManager.DayPhase.PURGE:
			text = ">>> NIGHTLY PURGE BEGINNING <<<"
			color = Color(0.9, 0.2, 0.2)  # Red
		DayManager.DayPhase.UPGRADE:
			text = ">>> SYSTEM UPGRADE <<<"
			color = Color(0.2, 0.8, 0.9)  # Cyan
		DayManager.DayPhase.ESCAPE:
			text = ">>> ESCAPE SEQUENCE <<<"
			color = Color(0.9, 0.8, 0.2)  # Yellow
	
	announce_label.text = text
	announce_label.modulate = color
	
	# Animate in
	announce_label.scale = Vector2(0.8, 0.8)
	announce_label.modulate.a = 0.0
	
	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.set_parallel()
	tween.tween_property(announce_label, "scale", Vector2.ONE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(announce_label, "modulate:a", 1.0, 0.2)
	
	# Play sound
	AudioManager.play_sfx("truth_loop_start")
	
	# Auto-hide after 2 seconds
	timer.start(2.0)

func _on_phase_changed(phase: int) -> void:
	show_announcement(phase)

func _on_timer_timeout() -> void:
	# Animate out
	var tween = get_tree().create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(announce_label, "modulate:a", 0.0, 0.3)
	tween.finished.connect(func():
		visible = false
		is_showing = false
	)

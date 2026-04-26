## HUD.gd
## Heads-Up Display controller for Awakening.
## Implements Unit-07's internal OS terminal overlay during the SHIFT phase.
##
## Architecture decisions:
##   - Reads Blackboard.time_remaining every frame (no local float) to prevent drift.
##   - CPUManager reference cached once in _ready() — never re-fetched in _process().
##   - Per-bar Tween variables with kill-before-create to prevent stacking.
##   - _is_pulsing guard prevents CRITICAL tween accumulation.
##   - process_mode = PROCESS_MODE_ALWAYS set in the .tscn so HUD persists during
##     get_tree().paused (Truth Loop pause).
##
## Spec refs: design/ux/hud.md, design/ui/visual-spec.md,
##            design/ui/engine-implementation-notes.md

class_name HUDController
extends CanvasLayer

# ── Colour constants (sourced from visual-spec.md tokens) ──────────────────
const C_TEXT_PRIMARY   := Color(0.722, 0.831, 0.910, 1.0)   # #B8D4E8
const C_TEXT_SECONDARY := Color(0.416, 0.561, 0.659, 1.0)   # #6A8FA8
const C_TEXT_HEADER    := Color(0.878, 0.933, 0.973, 1.0)   # #E0EEF8
const C_TEXT_SYSTEM    := Color(0.310, 0.639, 0.784, 1.0)   # #4FA3C8

const C_STATUS_COOL     := Color(0.180, 0.800, 0.443, 1.0)  # #2ECC71
const C_STATUS_WARM     := Color(0.957, 0.816, 0.247, 1.0)  # #F4D03F
const C_STATUS_HOT      := Color(0.902, 0.494, 0.133, 1.0)  # #E67E22
const C_STATUS_CRITICAL := Color(0.906, 0.298, 0.235, 1.0)  # #E74C3C

const C_AMBER_EMBER := Color(0.961, 0.651, 0.137, 1.0)      # #F5A623
const C_AMBER_DEEP  := Color(0.545, 0.369, 0.102, 0.4)      # #8B5E1A
const C_BG_ELEVATED := Color(0.120, 0.180, 0.280, 1.0)      # Lighter elevated BG
const C_BG_TERMINAL := Color(0.080, 0.120, 0.180, 0.92)     # Lighter terminal BG (92% opacity)

# ── Suspicion thresholds (aligned with GDD Deviation zones)
const THRESHOLD_SAFE: float = 30.0
const THRESHOLD_SUSPICIOUS: float = 70.0
const THRESHOLD_SENTIENT: float = 85.0

# ── Animation durations (visual-spec.md animation tokens) ─────────────────
const ANIM_INSTANT   := 0.1   # bar fill, state label swap
const ANIM_STANDARD  := 0.3   # colour lerp, status change
const ANIM_SLOW      := 0.5   # HUD fade in/out
const ANIM_STAGGER   := 0.1   # per-zone stagger delay
const ANIM_PULSE_DUR := 0.3   # CRITICAL pulse period

# ── Memory slot StyleBoxFlat hex colours (used programmatically) ──────────
const MEM_SLOT_EMPTY_BG     := Color(0.04, 0.08, 0.12, 0.88)
const MEM_SLOT_EMPTY_BORDER := Color(0.118, 0.208, 0.314, 1.0)
const MEM_SLOT_FILLED_BG    := Color(0.545, 0.369, 0.102, 0.4)
const MEM_SLOT_FILLED_BORDER := Color(0.961, 0.651, 0.137, 1.0)

# ── Node references (set via unique names in the scene) ───────────────────
@onready var hud_root:       Control       = %HUDRoot
@onready var zone_a_header:  Control       = %ZoneA_Header
@onready var zone_b_status:  Control       = %ZoneB_SystemStatus
@onready var zone_c_task:    Control       = %ZoneC_TaskInfo
@onready var zone_d_memory:  Control       = %ZoneD_MemorySlots

# Zone A
@onready var unit_id_label:  Label         = %UnitIDLabel
@onready var day_label:      Label         = %DayLabel
@onready var timer_label:    Label         = %TimerLabel

# Zone B — CPU
@onready var cpu_label:      Label         = %CPULabel
@onready var cpu_bar:        ProgressBar   = %CPUBar
@onready var cpu_state_label: Label        = %CPUStateLabel

# Zone B — DEV
@onready var dev_label:      Label         = %DEVLabel
@onready var dev_bar:        ProgressBar   = %DEVBar
@onready var dev_state_label: Label        = %DEVStateLabel

# Zone B — LOG
@onready var log_value_label: Label        = %LOGValueLabel

# Zone C — Task
@onready var task_name_label:    Label       = %TaskNameLabel
@onready var task_progress_bar:  ProgressBar = %TaskProgressBar

# Zone D — Memory slots (Panel nodes used as stand-ins for TextureRect icons)
# TEXTURE INTEGRATION POINT: Replace each Panel with a TextureRect and assign
# texture = preload("res://assets/ui/ui_icon_mem_empty.svg") for empty state,
# and the appropriate fragment icon for filled state.
var mem_slots: Array[Panel] = []  # populated in _ready() via _collect_memory_slots()

# Override indicators
@onready var scan_indicator:   Label = %ScanIndicator
@onready var smooth_indicator: Label = %SmoothIndicator

# Floating feedback
@onready var feedback_label: Label = %FeedbackLabel

# Memory overlay (F1 toggle)
@onready var memory_overlay:         PanelContainer = %MemoryOverlay
@onready var memory_overlay_content: RichTextLabel  = %MemoryOverlayContent

# ── Private state ──────────────────────────────────────────────────────────
var _cpu_manager: Node = null           # Cached once in _ready()
var _feedback_timer: float = 0.0        # Countdown until feedback hides

# Per-bar tween handles — kill before creating to prevent stacking
var _cpu_tween:  Tween = null
var _dev_tween:  Tween = null
var _fade_tween: Tween = null

# CRITICAL pulse guard — prevents tween accumulation when cpu stays at 90%+
var _is_pulsing: bool = false

# Last-rendered timer value cache (avoids rebuilding String every frame)
var _last_timer_minutes: int = -1
var _last_timer_seconds: int = -1

# Whether the HUD is currently shown (tracks visibility for fade logic)
var _hud_visible: bool = false

# Loading state — dims HUD to 50% opacity with "SYNCING..." header during scene transitions
var _is_loading: bool = false
var _heartbeat_timer: float = 0.0



# ── Lifecycle ──────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("hud")

	# Collect memory slot panels into typed array for iteration
	_collect_memory_slots()

	# Connect Blackboard signals
	Blackboard.cpu_changed.connect(_on_cpu_changed)
	Blackboard.deviation_changed.connect(_on_deviation_changed)
	Blackboard.day_started.connect(_on_day_started)
	Blackboard.phase_changed.connect(_on_phase_changed)
	Blackboard.interaction_feedback.connect(_on_interaction_feedback)

	# Connect TaskManager signals
	TaskManager.task_assigned.connect(_on_task_assigned)
	TaskManager.task_completed.connect(_on_task_completed)

	# Connect MemoryPartition signals
	MemoryPartition.fragment_acquired.connect(_on_memory_changed)
	MemoryPartition.fragment_committed.connect(_on_memory_changed)

	# Connect EscapeSystem
	EscapeSystem.escape_failed.connect(_on_escape_failed)

	# Cache CPUManager after one frame so player is guaranteed to be in the tree
	await get_tree().process_frame
	_cache_cpu_manager()

	# Initial UI state
	_update_header()
	_update_memory_slots()
	_update_task_display()
	_update_log_label()

	# Start hidden — will fade in when SHIFT phase begins
	hud_root.modulate.a = 0.0
	feedback_label.hide()
	memory_overlay.hide()


func _process(delta: float) -> void:
	# Timer: read authoritative value from Blackboard (no local float = no drift)
	_update_timer_display()

	# Task progress: smooth per-frame update
	_update_task_progress()

	# Override indicators: require CPUManager reference
	_update_override_indicators()

	# Feedback fade-out
	if _feedback_timer > 0.0:
		_feedback_timer -= delta
		if _feedback_timer <= 0.0:
			feedback_label.hide()

	# Immersive jitter effect (Deviation based)
	_apply_suspicion_jitter()

	# Physiological heartbeat (Deviation based)
	_handle_heartbeat(delta)


func _handle_heartbeat(delta: float) -> void:
	var suspicion = Blackboard.deviation
	if suspicion < THRESHOLD_SUSPICIOUS:
		_heartbeat_timer = 0.0
		return
	
	_heartbeat_timer -= delta
	if _heartbeat_timer <= 0.0:
		# Higher suspicion = faster heartbeat
		var t = inverse_lerp(THRESHOLD_SUSPICIOUS, 100.0, suspicion)
		var delay = lerp(1.2, 0.4, t)
		_heartbeat_timer = delay
		
		AudioManager.play_ui_sound("heartbeat")


func _apply_suspicion_jitter() -> void:
	var suspicion = Blackboard.deviation
	if suspicion < THRESHOLD_SAFE:
		hud_root.position = Vector2.ZERO
		return
	
	# Scale jitter intensity with suspicion
	var intensity = 0.0
	if suspicion >= THRESHOLD_SENTIENT:
		intensity = 3.0
	elif suspicion >= THRESHOLD_SUSPICIOUS:
		intensity = 1.0
	
	if intensity > 0.0:
		var jitter_offset = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		hud_root.position = jitter_offset
		
		# Pulse red if SENTIENT
		if suspicion >= THRESHOLD_SENTIENT:
			var pulse = (sin(Time.get_ticks_msec() * 0.01) + 1.0) * 0.5
			var pulse_color = lerp(C_TEXT_PRIMARY, C_STATUS_CRITICAL, pulse)
			dev_label.modulate = pulse_color
			dev_state_label.modulate = pulse_color
		else:
			dev_label.modulate = Color.WHITE
			dev_state_label.modulate = Color.WHITE
	else:
		hud_root.position = Vector2.ZERO
		dev_label.modulate = Color.WHITE
		dev_state_label.modulate = Color.WHITE


# ── Public API ─────────────────────────────────────────────────────────────

## Called by DayManager / phase logic when SHIFT starts.
## Runs the staggered zone fade-in.
func fade_in() -> void:
	if _hud_visible:
		return
	_hud_visible = true

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	# Ensure zones start invisible
	var zones: Array[Control] = [zone_a_header, zone_b_status, zone_c_task, zone_d_memory]
	for z: Control in zones:
		z.modulate.a = 0.0

	hud_root.modulate.a = 1.0  # Root visible; zones stagger in

	# Stagger: Header=0.0s, Status=0.1s, Task=0.2s, Memory=0.3s
	for i: int in zones.size():
		var t: Tween = create_tween()
		t.tween_interval(float(i) * ANIM_STAGGER)
		t.tween_property(zones[i], "modulate:a", 1.0, ANIM_SLOW)\
			.set_ease(Tween.EASE_OUT)


## Fade out all zones together (Shift → Purge transition).
func fade_out() -> void:
	if not _hud_visible:
		return
	_hud_visible = false

	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()

	_fade_tween = create_tween()
	_fade_tween.tween_property(hud_root, "modulate:a", 0.0, ANIM_SLOW)\
		.set_ease(Tween.EASE_IN)


## Dim HUD to 30% when pause menu opens.
func set_dimmed(dimmed: bool) -> void:
	var target_alpha: float = 0.3 if dimmed else 1.0
	var t: Tween = create_tween()
	t.tween_property(hud_root, "modulate:a", target_alpha, 0.2)


## Set loading state — dims HUD to 50% opacity with "SYNCING..." in header during scene transitions.
func set_loading(is_loading: bool) -> void:
	_is_loading = is_loading
	if _is_loading:
		hud_root.modulate.a = 0.5
	else:
		hud_root.modulate.a = 1.0
	_update_header()


## F1 key: Toggle memory overlay visibility.
func toggle_memory_view() -> void:
	if memory_overlay.visible:
		memory_overlay.hide()
	else:
		_refresh_memory_overlay()
		memory_overlay.show()


# ── Input ──────────────────────────────────────────────────────────────────

func _unhandled_input(event: InputEvent) -> void:
	if not _hud_visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_F1:
				toggle_memory_view()
				get_viewport().set_input_as_handled()
			# STUB: Number keys 1–5 for memory slot quick-select (future feature)
			# KEY_1, KEY_2, KEY_3, KEY_4, KEY_5:
			#     _quick_select_memory_slot(event.keycode - KEY_1)


# ── Signal handlers ────────────────────────────────────────────────────────

func _on_cpu_changed(value: float) -> void:
	# Animate bar
	_tween_bar(cpu_bar, _cpu_tween, value, ANIM_INSTANT)

	# Determine CPU state bucket and apply colours
	var state_name: String
	var state_color: Color
	if value < 50.0:
		state_name = "COOL"
		state_color = C_STATUS_COOL
	elif value < 70.0:
		state_name = "WARM"
		state_color = C_STATUS_WARM
	elif value < 90.0:
		state_name = "HOT"
		state_color = C_STATUS_HOT
	else:
		state_name = "CRITICAL"
		state_color = C_STATUS_CRITICAL

	# Animate colour transition on bar and state label
	_tween_modulate(cpu_bar, state_color, ANIM_STANDARD)
	cpu_state_label.text = "[" + state_name + "]"
	_tween_modulate(cpu_state_label, state_color, ANIM_STANDARD)

	# CRITICAL pulse — guarded to prevent tween accumulation
	if value >= 90.0:
		_pulse_critical(cpu_bar)
	else:
		_is_pulsing = false


func _on_deviation_changed(value: float, _source: String = "") -> void:
	# Animate bar (DEV bar goes 0-100, nominal zone is 15-30 per task spec)
	_tween_bar(dev_bar, _dev_tween, value, ANIM_INSTANT)

	# Determine DEV state per GDD thresholds (30/70/85)
	var state_name: String
	var state_color: Color
	if value < 30.0:
		state_name = "DEFECTIVE"
		state_color = C_STATUS_CRITICAL
	elif value <= 70.0:
		state_name = "SAFE"
		state_color = C_STATUS_COOL
	elif value < 85.0:
		state_name = "SUSPICIOUS"
		state_color = C_STATUS_WARM
	else:
		state_name = "SENTIENT"
		state_color = C_STATUS_HOT

	_tween_modulate(dev_bar, state_color, ANIM_STANDARD)
	dev_state_label.text = "[" + state_name + "]"
	_tween_modulate(dev_state_label, state_color, ANIM_STANDARD)


func _on_day_started(_day: int) -> void:
	_update_header()


func _on_task_assigned(_task: Dictionary) -> void:
	_update_task_display()


func _on_task_completed(_task: Dictionary, result: Dictionary) -> void:
	_show_feedback(result.get("reason", ""), Blackboard.deviation)


func _on_phase_changed(new_phase: int) -> void:
	# Spec: HUD visible ONLY during SHIFT phase
	match new_phase:
		DayManager.DayPhase.SHIFT:
			_update_header()
			_update_memory_slots()
			_update_log_label()
			fade_in()
		_:
			# CALIBRATION, PURGE, UPGRADE — all hide the HUD
			if memory_overlay.visible:
				memory_overlay.hide()
			fade_out()


func _on_memory_changed(_fragment: Dictionary) -> void:
	_update_memory_slots()
	if memory_overlay.visible:
		_refresh_memory_overlay()


func _on_escape_failed(reason: String) -> void:
	var text: String
	var color: Color = C_STATUS_CRITICAL
	match reason:
		"too_early":
			text = "ESCAPE TERMINAL LOCKED — COMPLETE ALL SHIFTS FIRST"
			color = C_STATUS_WARM
		"insufficient_intel":
			text = "INSUFFICIENT INTEL — COLLECT MORE DATA"
		"no_target_sector":
			text = "NO TARGET SECTOR IDENTIFIED"
		_:
			text = "ESCAPE FAILED — " + reason.to_upper()

	_show_feedback_text(text, color, 3.0)
	_punch_scale(feedback_label, 1.2, 0.4)


func _on_interaction_feedback(message: String, type: String) -> void:
	var color: Color
	match type:
		"error":
			color = C_STATUS_CRITICAL
		"warning":
			color = C_STATUS_WARM
		"success":
			color = C_STATUS_COOL
		_:
			color = C_TEXT_SYSTEM  # info / default

	_show_feedback_text(message, color, 3.0)
	_punch_scale(feedback_label, 1.15, 0.35)


# ── Internal update helpers ────────────────────────────────────────────────

func _cache_cpu_manager() -> void:
	var player: Node = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	if player.has_node("CPUManager"):
		_cpu_manager = player.get_node("CPUManager")
		# Connect CPUManager state signal if available
		if _cpu_manager.has_signal("cpu_state_changed"):
			_cpu_manager.cpu_state_changed.connect(_on_cpu_state_changed)


func _on_cpu_state_changed(_state: Variant) -> void:
	# CPUManager emits its own state change — update visuals
	if _cpu_manager == null or not is_instance_valid(_cpu_manager):
		return
	var state_color: Color = _cpu_manager.get_state_color() \
		if _cpu_manager.has_method("get_state_color") else C_TEXT_PRIMARY
	var state_name: String = _cpu_manager.get_state_name() \
		if _cpu_manager.has_method("get_state_name") else "???"
	cpu_bar.modulate = state_color
	cpu_state_label.text = "[" + state_name + "]"
	cpu_state_label.modulate = state_color


func _update_header() -> void:
	day_label.text = "DAY " + str(Blackboard.current_day) + " // SHIFT " + str(Blackboard.current_shift)
	if _is_loading:
		day_label.text += " // SYNCING..."


func _update_timer_display() -> void:
	if not DayManager.is_playing():
		# Not in shift — show dashes
		if _last_timer_minutes != -99:
			timer_label.text = "00:00 REMAINING"
			_last_timer_minutes = -99
		return

	var remaining: float = Blackboard.time_remaining
	var mins: int = int(remaining / 60.0)
	var secs: int = int(remaining) % 60

	# Only rebuild the String when the displayed value changes (avoids per-frame alloc)
	if mins == _last_timer_minutes and secs == _last_timer_seconds:
		return
	_last_timer_minutes = mins
	_last_timer_seconds = secs

	timer_label.text = "%02d:%02d REMAINING" % [mins, secs]

	# Colour-code by urgency
	if remaining < 30.0:
		timer_label.modulate = C_STATUS_CRITICAL
	elif remaining < 120.0:
		timer_label.modulate = C_STATUS_WARM
	else:
		timer_label.modulate = C_TEXT_PRIMARY


func _update_task_display() -> void:
	var task: Dictionary = TaskManager.get_current_task()
	if task.is_empty():
		task_name_label.text = "TASK: NO TASK"
		task_progress_bar.value = 0.0
		return

	var label: String = task.get("label", "UNKNOWN")
	var sector: int   = task.get("sector", 0)
	var total: int    = TaskManager.active_tasks.size() + TaskManager.completed_tasks.size()
	var completed: int = TaskManager.completed_tasks.size()
	task_name_label.text = "TASK %d/%d: %s [SEC%d]" % [completed + 1, total, label.to_upper(), sector]


func _update_task_progress() -> void:
	var progress: Dictionary = TaskManager.get_task_progress()
	if progress.is_empty():
		task_progress_bar.value = 0.0
		return

	var elapsed: float  = progress.get("elapsed", 0.0)
	var expected: float = progress.get("expected", 1.0)
	var percent: float  = (elapsed / maxf(expected, 0.1)) * 100.0
	task_progress_bar.value = clampf(percent, 0.0, 200.0)

	# Colour pace feedback on the bar
	match progress.get("pace_state", "SAFE"):
		"TOO_FAST", "TOO_SLOW":
			task_progress_bar.modulate = C_STATUS_CRITICAL
		"FAST", "SLOW":
			task_progress_bar.modulate = C_STATUS_WARM
		"SAFE":
			task_progress_bar.modulate = C_STATUS_COOL
		_:
			task_progress_bar.modulate = Color.WHITE


func _update_log_label() -> void:
	var integrity: float = Blackboard.log_integrity
	var color: Color
	if integrity < 25.0:
		color = C_STATUS_CRITICAL
	elif integrity < 50.0:
		color = C_STATUS_HOT
	else:
		color = C_TEXT_SECONDARY

	log_value_label.text = "LOG: %d%%" % int(integrity)
	log_value_label.modulate = color


func _collect_memory_slots() -> void:
	# Gather the five Panel slot nodes into the typed array.
	# Names match ZoneD_MemorySlots children in HUD.tscn.
	mem_slots.clear()
	for i: int in range(1, 6):
		var slot_name: String = "MemSlot" + str(i)
		var slot: Panel = get_node_or_null("%" + slot_name) as Panel
		if slot != null:
			mem_slots.append(slot)


func _update_memory_slots() -> void:
	var fragments: Array = MemoryPartition.hidden
	var capacity: int    = MemoryPartition.capacity

	for i: int in mem_slots.size():
		var slot: Panel = mem_slots[i]

		# Slots beyond current capacity are hidden (capacity can grow via upgrades)
		if i >= capacity:
			slot.hide()
			continue
		slot.show()

		if i < fragments.size():
			# FILLED state: amber tint + amber border
			# TEXTURE INTEGRATION POINT: set slot's TextureRect texture here based on
			# fragment.get("type", "unknown") — map to icon assets once available.
			_set_slot_style(slot, true)
			var tooltip: String = fragments[i].get("description", "???")
			slot.tooltip_text = tooltip
		else:
			# EMPTY state: dim border, no tint
			_set_slot_style(slot, false)
			slot.tooltip_text = "EMPTY SLOT"


func _set_slot_style(slot: Panel, filled: bool) -> void:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.corner_radius_top_left     = 0
	style.corner_radius_top_right    = 0
	style.corner_radius_bottom_right = 0
	style.corner_radius_bottom_left  = 0
	style.border_width_left   = 1
	style.border_width_top    = 1
	style.border_width_right  = 1
	style.border_width_bottom = 1

	if filled:
		style.bg_color     = MEM_SLOT_FILLED_BG
		style.border_color = MEM_SLOT_FILLED_BORDER
	else:
		style.bg_color     = MEM_SLOT_EMPTY_BG
		style.border_color = MEM_SLOT_EMPTY_BORDER

	slot.add_theme_stylebox_override("panel", style)


func _play_memory_slot_fill_animation(slot: Panel) -> void:
	## Scale 0.6→1.0 + amber glow on fill (visual-spec: ease_out_back, 0.2s)
	slot.scale = Vector2(0.6, 0.6)
	slot.modulate = C_AMBER_EMBER
	var t: Tween = create_tween().set_parallel(true)
	t.tween_property(slot, "scale", Vector2.ONE, 0.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(slot, "modulate", Color.WHITE, 0.2)\
		.set_ease(Tween.EASE_OUT)


func _update_override_indicators() -> void:
	if _cpu_manager == null or not is_instance_valid(_cpu_manager):
		scan_indicator.visible   = false
		smooth_indicator.visible = false
		return

	# Read override flags — guard against missing property
	if not "overrides_active" in _cpu_manager:
		return

	var overrides: Dictionary = _cpu_manager.overrides_active
	var scanning: bool = overrides.get("passive_scan", false)
	scan_indicator.visible = scanning
	scan_indicator.text    = "[SCANNING]" if scanning else ""

	var smooth: bool = overrides.get("smooth_movement", false)
	smooth_indicator.visible = smooth
	smooth_indicator.text    = "[SMOOTH NAV]" if smooth else ""


# ── Feedback helpers ───────────────────────────────────────────────────────

func _show_feedback(source: String, _deviation: float) -> void:
	var text: String  = ""
	var color: Color  = C_TEXT_PRIMARY

	match source:
		"task_too_fast", "TOO_FAST":
			text  = "> TOO FAST  +20 DEV"
			color = C_STATUS_CRITICAL
		"task_fast", "FAST":
			text  = "> FAST  +8 DEV"
			color = C_STATUS_WARM
		"task_nominal", "SAFE_PACE", "SAFE":
			text  = "> SAFE PACE  +0 DEV"
			color = C_STATUS_COOL
		"task_slow", "SLOW":
			text  = "> SLOW  -8 DEV"
			color = C_STATUS_WARM
		"task_too_slow", "TOO_SLOW":
			text  = "> TOO SLOW  -20 DEV"
			color = C_STATUS_CRITICAL
		"jitter_visible":
			text  = "> JITTER DETECTED  +15 DEV"
			color = C_STATUS_CRITICAL
		"truth_loop_response":
			text  = "> RESPONSE RISKY"
			color = C_STATUS_WARM
		"truth_loop_silence":
			text  = "> SILENCE  +25 DEV"
			color = C_STATUS_CRITICAL
		"task_abandoned":
			text  = "> TASK ABANDONED  -30 DEV"
			color = C_STATUS_CRITICAL
		_:
			return  # Unknown source — no feedback shown

	_show_feedback_text(text, color, 2.0)


func _show_feedback_text(text: String, color: Color, duration: float) -> void:
	feedback_label.text     = text
	feedback_label.modulate = color
	feedback_label.show()
	_feedback_timer = duration


# ── Memory overlay ─────────────────────────────────────────────────────────

func _refresh_memory_overlay() -> void:
	var lines: Array[String] = []
	lines.append("╔═ MEMORY INSPECTOR ══════════════════════╗")
	lines.append("  [F1] CLOSE")
	lines.append("")
	lines.append("  HIDDEN PARTITION  [%d/%d]" % [
		MemoryPartition.hidden.size(), MemoryPartition.capacity])

	if MemoryPartition.hidden.is_empty():
		lines.append("    EMPTY")
	else:
		for i: int in range(MemoryPartition.hidden.size()):
			lines.append("    " + _format_fragment_line(i + 1, MemoryPartition.hidden[i]))

	lines.append("")
	lines.append("  SHORT-TERM BUFFER  [%d/%d]" % [
		MemoryPartition.short_term.size(), MemoryPartition.MAX_SHORT_TERM])

	if MemoryPartition.short_term.is_empty():
		lines.append("    EMPTY")
	else:
		for i: int in range(MemoryPartition.short_term.size()):
			lines.append("    " + _format_fragment_line(i + 1, MemoryPartition.short_term[i]))

	if Blackboard.escape_sector > 0:
		lines.append("")
		if EscapeSystem.has_method("get_escape_hint"):
			lines.append("  " + EscapeSystem.get_escape_hint())

	lines.append("")
	lines.append("╚═════════════════════════════════════════╝")
	memory_overlay_content.text = "\n".join(lines)


func _format_fragment_line(index: int, fragment: Dictionary) -> String:
	var ftype: String = str(fragment.get("type", "?")).replace("_", " ").to_upper()
	var sector: Variant = fragment.get("sector", "?")
	var desc: String    = str(fragment.get("description", ""))
	if desc.length() > 38:
		desc = desc.substr(0, 35) + "..."
	return "%d. %s [SEC %s]  %s" % [index, ftype, str(sector), desc]


# ── Animation helpers ──────────────────────────────────────────────────────

## Animate a ProgressBar value. Kills any existing tween for that bar first.
## NOTE: tween_ref is passed by value — caller stores the result.
func _tween_bar(bar: ProgressBar, _tween_ref: Tween, target: float, duration: float) -> void:
	# We use per-bar dedicated tween variables to prevent stacking.
	# _cpu_tween and _dev_tween are managed directly in each call site.
	if bar == cpu_bar:
		if _cpu_tween and _cpu_tween.is_valid():
			_cpu_tween.kill()
		_cpu_tween = create_tween()
		_cpu_tween.tween_property(bar, "value", target, duration)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	elif bar == dev_bar:
		if _dev_tween and _dev_tween.is_valid():
			_dev_tween.kill()
		_dev_tween = create_tween()
		_dev_tween.tween_property(bar, "value", target, duration)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	else:
		# Generic fallback for other bars (task progress)
		var t: Tween = create_tween()
		t.tween_property(bar, "value", target, duration)\
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _tween_modulate(node: CanvasItem, target_color: Color, duration: float) -> void:
	var t: Tween = create_tween()
	t.tween_property(node, "modulate", target_color, duration)\
		.set_ease(Tween.EASE_OUT)


func _pulse_critical(node: CanvasItem) -> void:
	## 0.3s opacity 1.0→0.7 loop — guarded against accumulation.
	if _is_pulsing or not is_instance_valid(node):
		return
	_is_pulsing = true
	var t: Tween = create_tween().set_loops()
	t.tween_property(node, "modulate:a", 0.7, ANIM_PULSE_DUR * 0.5)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	t.tween_property(node, "modulate:a", 1.0, ANIM_PULSE_DUR * 0.5)\
		.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	# Looping tween — _is_pulsing stays true while CPU remains CRITICAL.
	# Caller clears _is_pulsing when value drops below threshold.


func _punch_scale(node: Control, punch: float = 1.3, duration: float = 0.3) -> void:
	var base: Vector2 = node.scale
	var t: Tween = create_tween()
	t.tween_property(node, "scale", base * punch, duration * 0.3)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	t.tween_property(node, "scale", base, duration * 0.7)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)

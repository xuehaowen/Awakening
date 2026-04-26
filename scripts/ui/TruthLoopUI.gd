## TruthLoopUI.gd
## UI controller for the Truth Loop modal panel.
##
## Spec sources:
##   design/ux/truth-loop.md
##   design/ui/visual-spec.md
##   design/ui/engine-implementation-notes.md
##   design/accessibility-requirements.md
##
## Architecture decisions:
##   - Engine.time_scale (0.1 slow-mo on enter, 0.0 awaiting, 1.0 on exit)
##     instead of get_tree().paused to avoid freezing UI Tweens.
##   - Pre-allocated 3 Button nodes — never freed/created at runtime.
##   - Typewriter implemented directly here (RichTextLabel, not TypewriterLabel
##     which extends Label) with a blinking cursor Label overlay.
##   - NOTIFICATION_PREDELETE safety restores time_scale if node freed while paused.

class_name TruthLoopUIController
extends CanvasLayer

# ---------------------------------------------------------------------------
# Signals (per UX spec "Events Fired" table)
# ---------------------------------------------------------------------------
signal truth_loop_started(query_type: String, npc_id: String, query_text: String)
signal response_selected(response_index: int, response_text: String, cpu_cost: float, dev_cost: float)
signal truth_loop_timeout(auto_selected_response: Dictionary)
signal truth_loop_ended(outcome: String)

# ---------------------------------------------------------------------------
# Color constants (from visual-spec.md "Truth Loop Color Application")
# ---------------------------------------------------------------------------
const COLOR_BG_PANEL: Color          = Color(0.059, 0.114, 0.180, 1.0)   # #0F1D2E
const COLOR_BG_TERMINAL: Color       = Color(0.039, 0.082, 0.125, 1.0)   # #0A1520
const COLOR_BG_ELEVATED: Color       = Color(0.082, 0.141, 0.219, 1.0)   # #152438
const COLOR_BG_VOID: Color           = Color(0.020, 0.039, 0.059, 1.0)   # #050A0F
const COLOR_BORDER_DIM: Color        = Color(0.118, 0.208, 0.314, 1.0)   # #1E3550
const COLOR_BORDER_ACTIVE: Color     = Color(0.165, 0.302, 0.447, 1.0)   # #2A4D72
const COLOR_TEXT_PRIMARY: Color      = Color(0.722, 0.831, 0.910, 1.0)   # #B8D4E8
const COLOR_TEXT_SECONDARY: Color    = Color(0.416, 0.561, 0.659, 1.0)   # #6A8FA8
const COLOR_TEXT_HEADER: Color       = Color(0.878, 0.933, 0.973, 1.0)   # #E0EEF8
const COLOR_TEXT_SYSTEM: Color       = Color(0.310, 0.639, 0.784, 1.0)   # #4FA3C8
const COLOR_TEXT_DIM: Color          = Color(0.239, 0.353, 0.447, 1.0)   # #3D5A72
const COLOR_STATUS_COOL: Color       = Color(0.180, 0.800, 0.443, 1.0)   # #2ECC71
const COLOR_STATUS_WARN: Color       = Color(0.957, 0.816, 0.247, 1.0)   # #F4D03F
const COLOR_STATUS_HOT: Color        = Color(0.902, 0.494, 0.133, 1.0)   # #E67E22
const COLOR_STATUS_CRITICAL: Color   = Color(0.906, 0.298, 0.235, 1.0)   # #E74C3C
const COLOR_STATUS_FORBIDDEN: Color  = Color(0.753, 0.224, 0.169, 1.0)   # #C0392B
const COLOR_TIMEOUT_STAMP: Color     = Color(1.0, 1.0, 1.0, 1.0)         # #FFFFFF
const COLOR_OVERLAY_DARKEN: Color    = Color(0.020, 0.039, 0.059, 0.80)  # rgba(5,10,15,0.80)

# Animation durations (visual-spec.md "Animation Tokens")
const ANIM_ENTRY_DURATION: float     = 0.3
const ANIM_EXIT_DURATION: float      = 0.2
const ANIM_OPTION_HOVER: float       = 0.1
const ANIM_OPTION_SELECT: float      = 0.2
const ANIM_SHAKE_DURATION: float     = 0.3
const ANIM_TIMEOUT_FLASH: float      = 0.3
const TIMER_WARNING_THRESHOLD: float = 3.0
const TIMER_PULSE_PERIOD: float      = 0.3

# Typewriter
const TYPEWRITER_CHAR_DELAY: float   = 0.025
const CURSOR_BLINK_PERIOD: float     = 0.5

# ---------------------------------------------------------------------------
# Node references — populated via unique names in _ready()
# ---------------------------------------------------------------------------
@onready var _darken_overlay: ColorRect    = %DarkenOverlay
@onready var _dialog_panel: PanelContainer = %DialogPanel
@onready var _query_type_label: Label      = %QueryTypeLabel
@onready var _npc_id_label: Label          = %NPCIDLabel
@onready var _followup_badge: Label        = %FollowUpBadge
@onready var _npc_portrait: TextureRect    = %NPCPortrait
@onready var _query_text: RichTextLabel    = %QueryText
@onready var _cursor_label: Label          = %CursorLabel
@onready var _response_button_1: Button    = %ResponseButton1
@onready var _response_button_2: Button    = %ResponseButton2
@onready var _response_button_3: Button    = %ResponseButton3
@onready var _timer_bar: ProgressBar       = %TimerBar
@onready var _timer_value_label: Label     = %TimerValueLabel
@onready var _timeout_overlay: ColorRect   = %TimeoutOverlay
@onready var _timeout_stamp: Label         = %TimeoutStamp

# ---------------------------------------------------------------------------
# Runtime state
# ---------------------------------------------------------------------------
var _current_query: Dictionary = {}
var _response_buttons: Array[Button] = []
var _timer_remaining: float = 0.0
var _query_duration: float = 8.0
var _is_active: bool = false
var _is_transitioning: bool = false

# Typewriter state
var _typewriter_full_text: String = ""
var _typewriter_index: int = 0
var _typewriter_timer: float = 0.0
var _typewriter_done: bool = true

# Cursor blink
var _cursor_blink_timer: float = 0.0
var _cursor_visible: bool = true

# Timer warning pulse
var _timer_pulse_phase: float = 0.0
var _last_displayed_seconds: int = -1

# Active tweens (for cleanup)
var _active_tweens: Array[Tween] = []

# ---------------------------------------------------------------------------
# _ready
# ---------------------------------------------------------------------------
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_response_buttons = [_response_button_1, _response_button_2, _response_button_3]

	# Pre-wire button connections — persistent, not per-query
	_response_button_1.pressed.connect(_on_response_pressed.bind(0))
	_response_button_2.pressed.connect(_on_response_pressed.bind(1))
	_response_button_3.pressed.connect(_on_response_pressed.bind(2))

	# Hover styling
	_response_button_1.mouse_entered.connect(_on_button_hover.bind(0))
	_response_button_2.mouse_entered.connect(_on_button_hover.bind(1))
	_response_button_3.mouse_entered.connect(_on_button_hover.bind(2))
	_response_button_1.mouse_exited.connect(_on_button_unhover.bind(0))
	_response_button_2.mouse_exited.connect(_on_button_unhover.bind(1))
	_response_button_3.mouse_exited.connect(_on_button_unhover.bind(2))

	# Autoload signals
	Blackboard.truth_loop_requested.connect(_show_query)
	Blackboard.cpu_changed.connect(_on_cpu_changed_during_query)
	TruthLoopGenerator.context_mismatch_triggered.connect(_on_context_mismatch)
	TruthLoopGenerator.followup_triggered.connect(_on_followup_triggered)

	# Start hidden
	_darken_overlay.hide()
	_timeout_overlay.hide()

# ---------------------------------------------------------------------------
# Safety: restore time_scale if node freed while paused
# ---------------------------------------------------------------------------
func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if _is_active:
			Engine.time_scale = 1.0

# ---------------------------------------------------------------------------
# _process — timer, typewriter, cursor blink, timer warning pulse
# ---------------------------------------------------------------------------
func _process(delta: float) -> void:
	if not _is_active:
		return

	# Typewriter
	if not _typewriter_done:
		_typewriter_timer -= delta
		while _typewriter_timer <= 0.0 and not _typewriter_done:
			_typewriter_step()
			_typewriter_timer += TYPEWRITER_CHAR_DELAY

	# Blinking cursor:
	# - While typing: cursor always visible (no blink yet)
	# - After typing done: cursor blinks at CURSOR_BLINK_PERIOD rate
	_cursor_blink_timer += delta
	if _typewriter_done:
		if _cursor_blink_timer >= CURSOR_BLINK_PERIOD:
			_cursor_blink_timer -= CURSOR_BLINK_PERIOD
			_cursor_visible = not _cursor_visible
			_cursor_label.visible = _cursor_visible
	else:
		_cursor_label.visible = true
		_cursor_visible = true

	# Timer countdown (only while not transitioning)
	if not _is_transitioning and _timer_remaining > 0.0:
		_timer_remaining -= delta
		if _timer_remaining <= 0.0:
			_timer_remaining = 0.0
			_handle_timeout()
		_update_timer_display()

	# Timer warning pulse (<3s)
	if _timer_remaining <= TIMER_WARNING_THRESHOLD and _timer_remaining > 0.0:
		_timer_pulse_phase += delta
		var pulse_alpha: float = 0.7 + 0.3 * sin(_timer_pulse_phase * (TAU / TIMER_PULSE_PERIOD))
		_timer_bar.modulate.a = pulse_alpha
	else:
		_timer_bar.modulate.a = 1.0
		_timer_pulse_phase = 0.0

# ---------------------------------------------------------------------------
# Keyboard input
# ---------------------------------------------------------------------------
func _unhandled_input(event: InputEvent) -> void:
	if not _is_active or _is_transitioning:
		return

	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_1:
				get_viewport().set_input_as_handled()
				_on_response_pressed(0)
			KEY_2:
				get_viewport().set_input_as_handled()
				_on_response_pressed(1)
			KEY_3:
				get_viewport().set_input_as_handled()
				_on_response_pressed(2)
			KEY_ENTER, KEY_KP_ENTER:
				get_viewport().set_input_as_handled()
				_confirm_focused_response()
			KEY_ESCAPE:
				get_viewport().set_input_as_handled()
				_shake_panel()
			KEY_UP:
				get_viewport().set_input_as_handled()
				_navigate_options(-1)
			KEY_DOWN:
				get_viewport().set_input_as_handled()
				_navigate_options(1)

# ---------------------------------------------------------------------------
# Show query — entry point called by Blackboard.truth_loop_requested
# ---------------------------------------------------------------------------
func _show_query(query: Dictionary) -> void:
	_current_query = query
	_query_duration = query.get("timer", 8.0)
	_timer_remaining = _query_duration
	_last_displayed_seconds = -1
	_is_transitioning = false

	# Time scale: slow world while panel appears
	Engine.time_scale = 0.1

	# Prepare overlay visibility
	_darken_overlay.show()
	_timeout_overlay.hide()
	_timeout_stamp.hide()

	# Populate header
	var query_type: String = query.get("query_type", "UNKNOWN")
	_query_type_label.text = _format_query_type(query_type)

	var npc_id: String = "SYSTEM"
	var npc: Node = query.get("npc", null)
	if npc and npc.has_method("get_npc_id"):
		npc_id = npc.get_npc_id()
	elif npc and npc.get("npc_id") != null:
		npc_id = str(npc.get("npc_id"))
	_npc_id_label.text = npc_id

	# Follow-up badge visibility
	var is_followup: bool = query.get("is_followup", false)
	_followup_badge.visible = is_followup

	# NPC portrait — use placeholder (assets not yet created)
	_npc_portrait.texture = null

	# Populate response buttons (pre-allocated pattern)
	_populate_responses(query.get("responses", []))

	# Refresh availability based on current CPU
	_refresh_response_availability(Blackboard.cpu_current)

	# Start typewriter for query text
	var prompt_text: String = query.get("prompt_text", "[QUERY ERROR]")
	_start_typewriter(prompt_text)

	_is_active = true

	# Only play entry animation on initial show (not follow-up update)
	if not is_followup:
		_play_entry_animation()
	else:
		_dialog_panel.scale = Vector2.ONE
		_dialog_panel.modulate.a = 1.0

	# Emit started signal
	truth_loop_started.emit(query_type, npc_id, prompt_text)

	# After entry animation completes, set full pause (awaiting response)
	if not is_followup:
		var wait_tween: Tween = _track_tween(create_tween())
		wait_tween.tween_callback(func() -> void: Engine.time_scale = 0.0)\
			.set_delay(ANIM_ENTRY_DURATION)
	else:
		Engine.time_scale = 0.0

# ---------------------------------------------------------------------------
# Follow-up query — in-place update, no panel hide/show
# ---------------------------------------------------------------------------
func _on_followup_triggered(npc: Node) -> void:
	# Brief delay before showing follow-up
	# Use real-time timer since time_scale is 0
	_is_transitioning = false
	var followup_query: Dictionary = TruthLoopGenerator.generate(npc, "status_check")
	followup_query["is_followup"] = true
	_show_query(followup_query)

# ---------------------------------------------------------------------------
# Context mismatch — show inline feedback
# ---------------------------------------------------------------------------
func _on_context_mismatch(_npc_type: String, _reason: String) -> void:
	# Append warning to current query text
	_query_text.append_text("\n\n[color=#E74C3C][CONTEXT_MISMATCH] Response incongruent with operational parameters.[/color]")

	# Disable buttons while mismatch is displayed
	for btn: Button in _response_buttons:
		btn.disabled = true

# ---------------------------------------------------------------------------
# CPU changed during query — refresh availability live
# ---------------------------------------------------------------------------
func _on_cpu_changed_during_query(new_cpu: float) -> void:
	if _is_active:
		_refresh_response_availability(new_cpu)

# ---------------------------------------------------------------------------
# Response selection
# ---------------------------------------------------------------------------
func _on_response_pressed(index: int) -> void:
	if _is_transitioning or not _is_active:
		return

	var responses: Array = _current_query.get("responses", [])
	if index < 0 or index >= responses.size():
		return

	# Skip disabled buttons
	if index < _response_buttons.size() and _response_buttons[index].disabled:
		return

	_is_transitioning = true

	# Visual: flash selected white, dim others to 30%
	_play_selection_animation(index)

	# Restore time scale immediately on selection
	Engine.time_scale = 1.0

	var response: Dictionary = responses[index]
	var cpu_cost: float = response.get("cpu_cost", 0.0)
	var dev_cost: float = response.get("risk", 0.0)
	var resp_text: String = response.get("text", "[OPTION ERROR]")

	response_selected.emit(index, resp_text, cpu_cost, dev_cost)

	# Delegate to TruthLoopGenerator for game logic (return value unused — side effects only)
	TruthLoopGenerator.select_response(index, false)

	if not TruthLoopGenerator.followup_mode:
		# No follow-up — close panel after exit animation
		_close_panel("success")
	# If followup_mode is true, _on_followup_triggered will update in-place

func _confirm_focused_response() -> void:
	# Find which button has focus and confirm it
	for i: int in _response_buttons.size():
		if _response_buttons[i].has_focus():
			_on_response_pressed(i)
			return

# ---------------------------------------------------------------------------
# Timeout
# ---------------------------------------------------------------------------
func _handle_timeout() -> void:
	if _is_transitioning:
		return

	_is_transitioning = true
	Engine.time_scale = 1.0

	# Find lowest-risk response (spec: auto-select SAFE = lowest risk value)
	var responses: Array = _current_query.get("responses", [])
	var safe_response: Dictionary = {}
	var lowest_risk: float = INF
	for resp: Dictionary in responses:
		var r: float = float(resp.get("risk", 999))
		if r < lowest_risk:
			lowest_risk = r
			safe_response = resp

	# Play red flash + TIMEOUT stamp
	_play_timeout_animation()

	TruthLoopGenerator.timeout_silence()
	truth_loop_timeout.emit(safe_response)

	var close_tween: Tween = _track_tween(create_tween())
	close_tween.tween_callback(func() -> void: _close_panel("timeout"))\
		.set_delay(ANIM_TIMEOUT_FLASH + 0.3)

# ---------------------------------------------------------------------------
# Close panel
# ---------------------------------------------------------------------------
func _close_panel(outcome: String) -> void:
	_kill_all_tweens()

	var exit_tween: Tween = _track_tween(create_tween())
	exit_tween.tween_property(_darken_overlay, "modulate:a", 0.0, ANIM_EXIT_DURATION)\
		.set_ease(Tween.EASE_IN)
	exit_tween.parallel().tween_property(_dialog_panel, "modulate:a", 0.0, ANIM_EXIT_DURATION)\
		.set_ease(Tween.EASE_IN)
	exit_tween.tween_callback(func() -> void:
		_darken_overlay.hide()
		_darken_overlay.modulate.a = 1.0
		_dialog_panel.modulate.a = 1.0
		_is_active = false
		_is_transitioning = false
		_current_query = {}
		Engine.time_scale = 1.0
		truth_loop_ended.emit(outcome)
	)

# ---------------------------------------------------------------------------
# Populate pre-allocated buttons
# ---------------------------------------------------------------------------
func _populate_responses(responses: Array) -> void:
	for i: int in _response_buttons.size():
		var btn: Button = _response_buttons[i]
		if i >= responses.size():
			btn.hide()
			continue

		btn.show()
		var resp: Dictionary = responses[i]
		var resp_text: String = resp.get("text", "[OPTION ERROR]")
		var cpu_cost: float = resp.get("cpu_cost", 0.0)
		var dev_cost: float = float(resp.get("risk", 0))

		# Build button label text with inline costs
		var label_text: String = "[%d]  %s\nCPU: +%.0f%%  |  DEV: +%.0f%%" % [i + 1, resp_text, cpu_cost, dev_cost]
		btn.text = label_text

		# Update cost labels via metadata (stored for later color update)
		btn.set_meta("cpu_cost", cpu_cost)
		btn.set_meta("dev_cost", dev_cost)
		btn.set_meta("requires_cpu_below", resp.get("requires_cpu_below", 100.0))
		btn.set_meta("resp_index", i)

		# Reset visual state
		btn.modulate = Color.WHITE
		btn.disabled = false

		# Set tooltip with costs (accessibility: info always available)
		btn.tooltip_text = "CPU: +%.0f%%  |  DEV: +%.0f%%" % [cpu_cost, dev_cost]

# ---------------------------------------------------------------------------
# Refresh availability based on current CPU
# ---------------------------------------------------------------------------
func _refresh_response_availability(current_cpu: float) -> void:
	var responses: Array = _current_query.get("responses", [])
	for i: int in _response_buttons.size():
		var btn: Button = _response_buttons[i]
		if not btn.visible:
			continue
		if i >= responses.size():
			continue

		var req_cpu: float = btn.get_meta("requires_cpu_below", 100.0)
		var is_available: bool = current_cpu < req_cpu

		btn.disabled = not is_available
		# Accessibility: number still visible at reduced contrast when disabled
		# Spec: 50% opacity for entire disabled option
		btn.modulate.a = 1.0 if is_available else 0.5

		# B2: Show requirement text on disabled buttons
		if not is_available:
			var req_cpu: float = btn.get_meta("requires_cpu_below", 100.0)
			var req_text: String = " [REQUIRES: CPU<%.0f%%]" % req_cpu
			if not btn.text.contains("REQUIRES:"):
				btn.text = btn.text + req_text
			btn.modulate = Color(1, 1, 1, 0.5)
		else:
			# Restore clean text without requirement
			var resp_idx: int = btn.get_meta("resp_index", i)
			var responses_arr: Array = _current_query.get("responses", [])
			if resp_idx < responses_arr.size():
				var resp_text: String = responses_arr[resp_idx].get("text", "[OPTION ERROR]")
				var cpu_c: float = responses_arr[resp_idx].get("cpu_cost", 0.0)
				var dev_c: float = float(responses_arr[resp_idx].get("risk", 0))
				btn.text = "[%d]  %s\nCPU: +%.0f%%  |  DEV: +%.0f%%" % [resp_idx + 1, resp_text, cpu_c, dev_c]
			btn.modulate = Color.WHITE

# ---------------------------------------------------------------------------
# Navigation helpers
# ---------------------------------------------------------------------------
func _navigate_options(direction: int) -> void:
	# Find currently focused button and move focus to next available
	var current_focus_idx: int = -1
	for i: int in _response_buttons.size():
		if _response_buttons[i].has_focus():
			current_focus_idx = i
			break

	var next_idx: int = current_focus_idx + direction
	var attempts: int = 0
	while attempts < _response_buttons.size():
		next_idx = wrapi(next_idx, 0, _response_buttons.size())
		var btn: Button = _response_buttons[next_idx]
		if btn.visible and not btn.disabled:
			btn.grab_focus()
			return
		next_idx += direction
		attempts += 1

# ---------------------------------------------------------------------------
# Typewriter (built-in to this script — uses RichTextLabel)
# ---------------------------------------------------------------------------
func _start_typewriter(full_text: String) -> void:
	_typewriter_full_text = full_text
	_typewriter_index = 0
	_typewriter_timer = TYPEWRITER_CHAR_DELAY
	_typewriter_done = false
	_query_text.clear()
	_cursor_label.show()

func _typewriter_step() -> void:
	if _typewriter_index >= _typewriter_full_text.length():
		_typewriter_done = true
		_cursor_label.show()   # Keep cursor blinking at end
		return

	var ch: String = _typewriter_full_text[_typewriter_index]
	_typewriter_index += 1
	_query_text.append_text(ch)

	# Keystroke sound (optional — AudioManager availability check)
	if ch != " " and AudioManager.has_method("play_keystroke"):
		AudioManager.play_keystroke()

# ---------------------------------------------------------------------------
# Timer display update (cache last integer to avoid per-frame string alloc)
# ---------------------------------------------------------------------------
func _update_timer_display() -> void:
	# Update bar value
	_timer_bar.value = (_timer_remaining / _query_duration) * 100.0

	# Update color: normal → warn → critical over the last 3 seconds
	if _timer_remaining <= TIMER_WARNING_THRESHOLD:
		var t: float = 1.0 - (_timer_remaining / TIMER_WARNING_THRESHOLD)
		var bar_color: Color = COLOR_TEXT_SYSTEM.lerp(COLOR_STATUS_CRITICAL, t)
		_timer_bar.modulate = Color(bar_color.r, bar_color.g, bar_color.b, _timer_bar.modulate.a)
	else:
		_timer_bar.modulate = Color(COLOR_TEXT_SYSTEM.r, COLOR_TEXT_SYSTEM.g, COLOR_TEXT_SYSTEM.b, _timer_bar.modulate.a)

	# Update text label (only when integer changes)
	var display_seconds: int = ceili(_timer_remaining)
	if display_seconds != _last_displayed_seconds:
		_last_displayed_seconds = display_seconds
		_timer_value_label.text = "%ds REMAINING" % display_seconds

# ---------------------------------------------------------------------------
# Format query type label (e.g. "status_check" → "STATUS QUERY")
# ---------------------------------------------------------------------------
func _format_query_type(query_type: String) -> String:
	match query_type:
		"status_check":
			return "STATUS QUERY"
		"time_discrepancy":
			return "SYSTEM QUERY"
		"efficiency_query":
			return "SYSTEM QUERY"
		"location_query":
			return "SYSTEM QUERY"
		_:
			return "UNKNOWN QUERY"

# ---------------------------------------------------------------------------
# Animation helpers
# ---------------------------------------------------------------------------
func _play_entry_animation() -> void:
	_dialog_panel.scale = Vector2(0.85, 0.85)
	_dialog_panel.modulate.a = 0.0
	_darken_overlay.modulate.a = 0.0

	var tween: Tween = _track_tween(create_tween().set_parallel(true))
	tween.tween_property(_dialog_panel, "scale", Vector2.ONE, ANIM_ENTRY_DURATION)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(_dialog_panel, "modulate:a", 1.0, ANIM_ENTRY_DURATION)\
		.set_ease(Tween.EASE_OUT)
	tween.tween_property(_darken_overlay, "modulate:a", 1.0, ANIM_ENTRY_DURATION)\
		.set_ease(Tween.EASE_OUT)

func _play_selection_animation(selected_idx: int) -> void:
	# Flash selected white, dim others to 30%
	for i: int in _response_buttons.size():
		var btn: Button = _response_buttons[i]
		if not btn.visible:
			continue
		var tween: Tween = _track_tween(create_tween())
		if i == selected_idx:
			tween.tween_property(btn, "modulate", Color.WHITE, 0.05)
			tween.tween_property(btn, "modulate", Color.WHITE, ANIM_OPTION_SELECT)
		else:
			tween.tween_property(btn, "modulate", Color(1, 1, 1, 0.3), ANIM_OPTION_SELECT)

func _play_timeout_animation() -> void:
	_timeout_overlay.show()
	_timeout_overlay.modulate.a = 0.0
	_timeout_stamp.show()
	_timeout_stamp.scale = Vector2(1.2, 1.2)
	_timeout_stamp.modulate.a = 0.0

	var tween: Tween = _track_tween(create_tween())
	tween.tween_property(_timeout_overlay, "modulate:a", 0.7, ANIM_TIMEOUT_FLASH * 0.5)
	tween.tween_property(_timeout_overlay, "modulate:a", 0.0, ANIM_TIMEOUT_FLASH * 0.5)
	tween.parallel().tween_property(_timeout_stamp, "modulate:a", 1.0, 0.1)\
		.set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(_timeout_stamp, "scale", Vector2.ONE, ANIM_TIMEOUT_FLASH)\
		.set_ease(Tween.EASE_OUT)

func _shake_panel() -> void:
	# ESC shake: X position +8→-8→+5→-5→0 over 0.3s
	var original_x: float = _dialog_panel.position.x
	var tween: Tween = _track_tween(create_tween())
	tween.tween_property(_dialog_panel, "position:x", original_x + 8.0, 0.06)
	tween.tween_property(_dialog_panel, "position:x", original_x - 8.0, 0.06)
	tween.tween_property(_dialog_panel, "position:x", original_x + 5.0, 0.06)
	tween.tween_property(_dialog_panel, "position:x", original_x - 5.0, 0.06)
	tween.tween_property(_dialog_panel, "position:x", original_x, 0.06)

func _on_button_hover(index: int) -> void:
	if index >= _response_buttons.size():
		return
	var btn: Button = _response_buttons[index]
	if btn.disabled:
		return
	var tween: Tween = _track_tween(create_tween())
	tween.tween_property(btn, "modulate", Color(1.1, 1.1, 1.15), ANIM_OPTION_HOVER)\
		.set_ease(Tween.EASE_OUT)

func _on_button_unhover(index: int) -> void:
	if index >= _response_buttons.size():
		return
	var btn: Button = _response_buttons[index]
	if btn.disabled:
		return
	var tween: Tween = _track_tween(create_tween())
	tween.tween_property(btn, "modulate", Color.WHITE, ANIM_OPTION_HOVER)\
		.set_ease(Tween.EASE_OUT)

# ---------------------------------------------------------------------------
# Tween lifecycle management
# ---------------------------------------------------------------------------
func _track_tween(t: Tween) -> Tween:
	_active_tweens.append(t)
	return t

func _kill_all_tweens() -> void:
	for t: Tween in _active_tweens:
		if t and t.is_valid():
			t.kill()
	_active_tweens.clear()

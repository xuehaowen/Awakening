## NightlyPurgeUI.gd
## Full-screen Nightly Purge interface — Day-end memory selection.
## Layer 30, PROCESS_MODE_ALWAYS. Mandatory screen (no ESC exit).
##
## Spec: design/ux/nightly-purge.md, design/ui/visual-spec.md
## Engine notes: design/ui/engine-implementation-notes.md
class_name NightlyPurgeUIController
extends CanvasLayer

# ── Color constants (mirror design/ui/visual-spec.md) ─────────────────────
const COLOR_BG_VOID       := Color(0.020, 0.039, 0.059, 1.0)   # #050A0F
const COLOR_BG_TERMINAL   := Color(0.039, 0.082, 0.125, 1.0)   # #0A1520
const COLOR_BG_PANEL      := Color(0.059, 0.114, 0.176, 1.0)   # #0F1D2E
const COLOR_BG_ELEVATED   := Color(0.082, 0.141, 0.220, 1.0)   # #152438
const COLOR_BORDER_DIM    := Color(0.118, 0.208, 0.314, 1.0)   # #1E3550
const COLOR_BORDER_ACTIVE := Color(0.165, 0.302, 0.447, 1.0)   # #2A4D72

const COLOR_TEXT_PRIMARY  := Color(0.722, 0.831, 0.910, 1.0)   # #B8D4E8
const COLOR_TEXT_SECONDARY:= Color(0.416, 0.561, 0.659, 1.0)   # #6A8FA8
const COLOR_TEXT_HEADER   := Color(0.878, 0.933, 0.973, 1.0)   # #E0EEF8
const COLOR_TEXT_SYSTEM   := Color(0.310, 0.639, 0.784, 1.0)   # #4FA3C8

const COLOR_STATUS_COOL   := Color(0.180, 0.800, 0.443, 1.0)   # #2ECC71
const COLOR_STATUS_WARM   := Color(0.957, 0.816, 0.247, 1.0)   # #F4D03F
const COLOR_STATUS_HOT    := Color(0.902, 0.494, 0.133, 1.0)   # #E67E22
const COLOR_STATUS_CRIT   := Color(0.906, 0.298, 0.235, 1.0)   # #E74C3C
const COLOR_STATUS_FORB   := Color(0.753, 0.224, 0.169, 1.0)   # #C0392B

const COLOR_AMBER_EMBER   := Color(0.961, 0.651, 0.137, 1.0)   # #F5A623
const COLOR_AMBER_GLOW    := Color(0.984, 0.745, 0.329, 1.0)   # #FBBE54
const COLOR_AMBER_DEEP    := Color(0.545, 0.369, 0.102, 1.0)   # #8B5E1A
const COLOR_EMBER_RED     := Color(0.910, 0.278, 0.110, 1.0)   # #E8471C

# ── Risk multipliers ────────────────────────────────────────────────────────
const RISK_LOW  := 0.05
const RISK_MED  := 0.10
const RISK_HIGH := 0.15
const RISK_CRIT := 0.20
const BASE_RISK_PER_DAY := 0.05

# ── Intel type → icon text mapping (Nerd-Font / Unicode fallback) ──────────
const ICON_DOC     := "[D]"  # document type
const ICON_KEY     := "[K]"  # access key type
const ICON_PROFILE := "[P]"  # NPC profile type
const ICON_DEFAULT := "[?]"  # unknown

# ── Node refs (populated by @onready) ──────────────────────────────────────
@onready var purge_root: Control               = %PurgeRoot
@onready var zone_a_header: PanelContainer     = %ZoneAHeader
@onready var purge_title_label: Label          = %PurgeTitleLabel
@onready var day_count_label: Label            = %DayCountLabel
@onready var slot_count_label: Label           = %SlotCountLabel
@onready var countdown_label: Label            = %CountdownLabel

@onready var zone_b_intel: VBoxContainer       = %ZoneBIntel
@onready var intel_scroll: ScrollContainer     = %IntelScroll
@onready var intel_list: VBoxContainer         = %IntelList
@onready var filter_all_btn: Button            = %FilterAllBtn
@onready var filter_new_btn: Button            = %FilterNewBtn
@onready var filter_risk_btn: Button           = %FilterRiskBtn

@onready var zone_c_memory: VBoxContainer      = %ZoneCMemory
@onready var partition_header: Label           = %PartitionHeader
@onready var memory_slot_1: PanelContainer     = %MemorySlot1
@onready var memory_slot_2: PanelContainer     = %MemorySlot2
@onready var memory_slot_3: PanelContainer     = %MemorySlot3
@onready var memory_slot_4: PanelContainer     = %MemorySlot4
@onready var confirm_purge_btn: Button         = %ConfirmPurgeBtn
@onready var auto_optimize_btn: Button         = %AutoOptimizeBtn
@onready var detection_value_label: Label      = %DetectionValueLabel
@onready var detection_meter: ProgressBar      = %DetectionMeter
@onready var high_risk_warning: Label          = %HighRiskWarning

@onready var zone_d_detail: PanelContainer     = %ZoneDDetail
@onready var detail_title: Label               = %DetailTitle
@onready var detail_source: Label              = %DetailSource
@onready var detail_acquired: Label            = %DetailAcquired
@onready var detail_content: RichTextLabel     = %DetailContent
@onready var detail_risk: Label                = %DetailRisk
@onready var detail_use: Label                 = %DetailUse
@onready var detail_placeholder: Label         = %DetailPlaceholder

@onready var modal_darken: ColorRect           = %ModalDarken
@onready var confirm_modal: PanelContainer     = %ConfirmModal
@onready var modal_keep_list: Label            = %ModalKeepList
@onready var modal_purge_list: Label           = %ModalPurgeList
@onready var modal_confirm_btn: Button         = %ModalConfirmBtn
@onready var modal_cancel_btn: Button          = %ModalCancelBtn

@onready var purge_progress_bar: ProgressBar   = %PurgeProgressBar
@onready var purge_status_label: Label         = %PurgeStatusLabel
@onready var game_over_stamp: Label            = %GameOverStamp

# ── Slot control references array (ordered 0–3) ────────────────────────────
var _memory_slots: Array[PanelContainer] = []

# ── State ──────────────────────────────────────────────────────────────────
var _purge_time_remaining: float = 60.0
var _is_visible: bool = false
var _is_confirming: bool = false
var _is_purging: bool = false

## Intel in today's collection (Array[Dictionary])
var _today_intel: Array[Dictionary] = []
## Current filter: "all" | "new" | "risk"
var _active_filter: String = "all"
## Selected intel item (Dictionary, or {} if none)
var _selected_intel: Dictionary = {}
## Which slot each index maps to (-1 = unassigned)
## _slot_contents[slot_index] = Dictionary or {} for empty
var _slot_contents: Array[Dictionary] = [{}, {}, {}, {}]
## Currently focused intel index (keyboard nav)
var _focused_intel_index: int = -1
## Currently focused slot index (keyboard nav)
var _focused_slot_index: int = -1
## Which zone has keyboard focus: "intel" | "slots" | "buttons"
var _focus_zone: String = "intel"

# ── Tween tracking ─────────────────────────────────────────────────────────
var _active_tweens: Array[Tween] = []
var _risk_tween: Tween = null
var _warning_tween: Tween = null
var _auto_opt_pulse_tween: Tween = null
var _is_warning_pulsing: bool = false
var _is_auto_opt_pulsing: bool = false

# ── Signals ────────────────────────────────────────────────────────────────
signal purge_started(day: int, intel_count: int)
signal intel_assigned_to_slot(intel: Dictionary, slot_index: int)
signal intel_removed_from_slot(intel: Dictionary, slot_index: int)
signal auto_optimize_requested(suggested_set: Array)
signal purge_confirmed(kept_intel: Array, purged_intel: Array)
signal purge_completed(detection_roll: float, detected: bool)

# ══════════════════════════════════════════════════════════════════════════
# Lifecycle
# ══════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	# Populate slot array in order
	_memory_slots = [memory_slot_1, memory_slot_2, memory_slot_3, memory_slot_4]

	# Wire autoload signals
	Blackboard.purge_initiated.connect(_show_purge)
	Blackboard.day_started.connect(_on_day_started)

	# Wire button signals (pre-allocated — no dynamic wiring)
	confirm_purge_btn.pressed.connect(_request_confirm_purge)
	auto_optimize_btn.pressed.connect(_auto_optimize)
	filter_all_btn.pressed.connect(_set_filter.bind("all"))
	filter_new_btn.pressed.connect(_set_filter.bind("new"))
	filter_risk_btn.pressed.connect(_set_filter.bind("risk"))
	modal_confirm_btn.pressed.connect(_execute_purge)
	modal_cancel_btn.pressed.connect(_close_confirm_modal)

	# Wire slot signals
	for i: int in _memory_slots.size():
		_memory_slots[i].gui_input.connect(_on_slot_gui_input.bind(i))

	# Start hidden — everything is shown only when _show_purge() is called
	purge_root.modulate.a = 0.0
	purge_root.hide()
	modal_darken.hide()
	confirm_modal.hide()
	game_over_stamp.hide()
	high_risk_warning.hide()
	purge_progress_bar.hide()
	purge_status_label.hide()

	_clear_detail_panel()


func _process(delta: float) -> void:
	if not _is_visible:
		return
	if _is_purging:
		return

	_purge_time_remaining -= delta
	_update_countdown_display()

	if _purge_time_remaining <= 0.0:
		_force_purge()


func _show_purge() -> void:
	_is_visible = true
	_is_confirming = false
	_is_purging = false
	_purge_time_remaining = 60.0
	_today_intel = MemoryPartition.short_term.duplicate(true)
	_slot_contents = [{}, {}, {}, {}]
	# Pre-fill slots from existing hidden partition (intel already saved from prior days)
	for i: int in mini(MemoryPartition.hidden.size(), MemoryPartition.capacity):
		_slot_contents[i] = MemoryPartition.hidden[i].duplicate(true)
	_selected_intel = {}
	_focused_intel_index = -1
	_focused_slot_index = -1
	_focus_zone = "intel"
	_active_filter = "all"

	_update_header()
	_populate_intel_list()
	_update_slot_displays()
	_recalculate_detection_risk()
	_clear_detail_panel()
	modal_darken.hide()
	confirm_modal.hide()
	game_over_stamp.hide()
	high_risk_warning.hide()
	purge_progress_bar.hide()
	purge_status_label.hide()

	purge_root.show()
	_play_entry_animation()

	purge_started.emit(Blackboard.current_day, _today_intel.size())
	AudioManager.play_purge_alarm()


func _on_day_started(_day: int) -> void:
	_is_visible = false
	_kill_all_tweens()
	purge_root.hide()


# ══════════════════════════════════════════════════════════════════════════
# Header
# ══════════════════════════════════════════════════════════════════════════

func _update_header() -> void:
	purge_title_label.text = "NIGHTLY SYSTEM PURGE"
	day_count_label.text = "DAY %d" % Blackboard.current_day
	_update_slot_count_label()


func _update_slot_count_label() -> void:
	var filled: int = 0
	for s: Dictionary in _slot_contents:
		if not s.is_empty():
			filled += 1
	slot_count_label.text = "MEMORY: %d/%d" % [filled, MemoryPartition.capacity]


func _update_countdown_display() -> void:
	var t: float = maxf(0.0, _purge_time_remaining)
	countdown_label.text = "RESET IN: %ds" % int(ceilf(t))
	if t <= 10.0:
		countdown_label.modulate = COLOR_STATUS_CRIT
	elif t <= 30.0:
		countdown_label.modulate = COLOR_STATUS_WARM
	else:
		countdown_label.modulate = COLOR_TEXT_SYSTEM


# ══════════════════════════════════════════════════════════════════════════
# Intel List (Zone B)
# ══════════════════════════════════════════════════════════════════════════

func _populate_intel_list() -> void:
	# Clear old items
	for child: Node in intel_list.get_children():
		child.queue_free()

	var items: Array[Dictionary] = _get_filtered_intel()

	if items.is_empty():
		var empty_label: Label = Label.new()
		empty_label.text = "NO INTEL COLLECTED TODAY"
		empty_label.modulate = COLOR_TEXT_SECONDARY
		empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		intel_list.add_child(empty_label)
		return

	for i: int in items.size():
		var row: Control = _create_intel_row(items[i], i)
		intel_list.add_child(row)


func _get_filtered_intel() -> Array[Dictionary]:
	match _active_filter:
		"new":
			var result: Array[Dictionary] = []
			for item: Dictionary in _today_intel:
				if item.get("day_acquired", 1) == Blackboard.current_day:
					result.append(item)
			return result
		"risk":
			var sorted: Array[Dictionary] = _today_intel.duplicate()
			sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
				return _risk_string_to_value(a.get("detection_risk", "LOW")) > \
				       _risk_string_to_value(b.get("detection_risk", "LOW"))
			)
			return sorted
		_:
			return _today_intel.duplicate()


func _create_intel_row(intel: Dictionary, index: int) -> PanelContainer:
	var row: PanelContainer = PanelContainer.new()
	row.custom_minimum_size = Vector2(0.0, 72.0)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.focus_mode = Control.FOCUS_ALL
	row.set_meta("intel_index", index)
	row.set_meta("intel_data", intel)

	# StyleBox via theme colour
	var style_idle: StyleBoxFlat = StyleBoxFlat.new()
	style_idle.bg_color = COLOR_BG_TERMINAL
	style_idle.border_width_left = 1
	style_idle.border_width_top = 1
	style_idle.border_width_right = 1
	style_idle.border_width_bottom = 1
	style_idle.border_color = COLOR_BORDER_DIM
	style_idle.content_margin_left = 8.0
	style_idle.content_margin_top = 4.0
	style_idle.content_margin_right = 8.0
	style_idle.content_margin_bottom = 4.0
	row.add_theme_stylebox_override("panel", style_idle)

	var hbox: HBoxContainer = HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_child(hbox)

	# 4px left accent bar (drag affordance colour)
	var accent: ColorRect = ColorRect.new()
	accent.custom_minimum_size = Vector2(4.0, 0.0)
	accent.color = _get_icon_color(intel.get("type", ""))
	hbox.add_child(accent)

	# Icon label
	var icon_label: Label = Label.new()
	icon_label.text = " %s " % _get_intel_icon(intel.get("type", ""))
	icon_label.custom_minimum_size = Vector2(32.0, 0.0)
	icon_label.modulate = _get_icon_color(intel.get("type", ""))
	hbox.add_child(icon_label)

	# Name + badges column
	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_label: Label = Label.new()
	name_label.text = intel.get("type", "UNKNOWN").to_upper().replace("_", " ")
	if intel.has("sector"):
		name_label.text += " — SECTOR %s" % str(intel.get("sector", "?"))
	elif intel.has("npc_type"):
		name_label.text += " — %s" % str(intel.get("npc_type", "?")).to_upper()
	name_label.modulate = COLOR_TEXT_PRIMARY
	name_label.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_label)

	var badge_row: HBoxContainer = HBoxContainer.new()
	vbox.add_child(badge_row)

	var risk_str: String = intel.get("detection_risk", "LOW")
	var val_str: String  = intel.get("strategic_value", "MED")

	var risk_label: Label = _make_badge("RISK:" + risk_str, _get_risk_color(risk_str))
	badge_row.add_child(risk_label)

	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(8.0, 0.0)
	badge_row.add_child(spacer)

	var val_label: Label = _make_badge("VAL:" + val_str, _get_value_color(val_str))
	badge_row.add_child(val_label)

	# Wire interactions
	row.gui_input.connect(_on_intel_row_gui_input.bind(index))
	row.focus_entered.connect(_on_intel_row_focused.bind(index))

	return row


func _make_badge(text: String, color: Color) -> Label:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.modulate = color
	lbl.add_theme_font_size_override("font_size", 11)
	return lbl


# ══════════════════════════════════════════════════════════════════════════
# Intel Row interaction
# ══════════════════════════════════════════════════════════════════════════

func _on_intel_row_gui_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.pressed and mbe.button_index == MOUSE_BUTTON_LEFT:
			_select_intel(index)
			get_viewport().set_input_as_handled()


func _on_intel_row_focused(index: int) -> void:
	_focus_zone = "intel"
	_focused_intel_index = index


func _select_intel(index: int) -> void:
	if index < 0 or index >= _today_intel.size():
		return
	_selected_intel = _today_intel[index]
	_focused_intel_index = index
	_focus_zone = "intel"
	_update_intel_row_styles()
	_update_detail_panel(_selected_intel)
	AudioManager.play_ui_sound("click")


func _update_intel_row_styles() -> void:
	var rows: Array[Node] = intel_list.get_children()
	for i: int in rows.size():
		if rows[i] is PanelContainer:
			var row := rows[i] as PanelContainer
			var intel_data: Dictionary = row.get_meta("intel_data", {})
			var is_selected: bool = (intel_data == _selected_intel and not _selected_intel.is_empty())
			var is_assigned: bool = _is_intel_assigned(intel_data)

			var style: StyleBoxFlat = StyleBoxFlat.new()
			style.content_margin_left = 8.0
			style.content_margin_top = 4.0
			style.content_margin_right = 8.0
			style.content_margin_bottom = 4.0
			style.border_width_left = 1
			style.border_width_top = 1
			style.border_width_right = 1
			style.border_width_bottom = 1

			if is_assigned:
				style.bg_color = COLOR_AMBER_DEEP
				style.border_color = COLOR_AMBER_EMBER
			elif is_selected:
				style.bg_color = COLOR_BG_ELEVATED
				style.border_color = COLOR_AMBER_EMBER
			else:
				style.bg_color = COLOR_BG_TERMINAL
				style.border_color = COLOR_BORDER_DIM

			row.add_theme_stylebox_override("panel", style)


func _is_intel_assigned(intel: Dictionary) -> bool:
	if intel.is_empty():
		return false
	for s: Dictionary in _slot_contents:
		if not s.is_empty() and s == intel:
			return true
	return false


# ══════════════════════════════════════════════════════════════════════════
# Memory Slots (Zone C) — fixed pattern, never recreated
# ══════════════════════════════════════════════════════════════════════════

func _update_slot_displays() -> void:
	for i: int in _memory_slots.size():
		_update_single_slot(i)
	_update_slot_count_label()
	_update_partition_header()


func _update_single_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _memory_slots.size():
		return

	var slot: PanelContainer = _memory_slots[slot_index]
	var intel: Dictionary = _slot_contents[slot_index]

	# Remove old children
	for child: Node in slot.get_children():
		child.queue_free()

	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.content_margin_left = 8.0
	style.content_margin_top = 8.0
	style.content_margin_right = 8.0
	style.content_margin_bottom = 8.0

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	slot.add_child(vbox)

	if intel.is_empty():
		style.bg_color = COLOR_BG_TERMINAL
		style.border_color = COLOR_BORDER_DIM
		slot.add_theme_stylebox_override("panel", style)

		var empty_icon: Label = Label.new()
		empty_icon.text = "[ ]"
		empty_icon.modulate = COLOR_TEXT_SECONDARY
		empty_icon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(empty_icon)

		var empty_lbl: Label = Label.new()
		empty_lbl.text = "EMPTY"
		empty_lbl.modulate = COLOR_TEXT_SECONDARY
		empty_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty_lbl.add_theme_font_size_override("font_size", 12)
		vbox.add_child(empty_lbl)
	else:
		style.bg_color = Color(COLOR_AMBER_DEEP.r, COLOR_AMBER_DEEP.g, COLOR_AMBER_DEEP.b, 0.4)
		style.border_color = COLOR_AMBER_EMBER
		slot.add_theme_stylebox_override("panel", style)

		var icon_lbl: Label = Label.new()
		icon_lbl.text = _get_intel_icon(intel.get("type", ""))
		icon_lbl.modulate = COLOR_AMBER_EMBER
		icon_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(icon_lbl)

		var name_lbl: Label = Label.new()
		var type_str: String = intel.get("type", "UNKNOWN").to_upper().replace("_", " ")
		name_lbl.text = type_str
		name_lbl.modulate = COLOR_TEXT_HEADER
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 12)
		name_lbl.clip_contents = true
		vbox.add_child(name_lbl)


func _update_partition_header() -> void:
	var filled: int = 0
	for s: Dictionary in _slot_contents:
		if not s.is_empty():
			filled += 1
	partition_header.text = "HIDDEN PARTITION (%d/%d SLOTS):" % [filled, MemoryPartition.capacity]


func _on_slot_gui_input(event: InputEvent, slot_index: int) -> void:
	if event is InputEventMouseButton:
		var mbe := event as InputEventMouseButton
		if mbe.pressed:
			if mbe.button_index == MOUSE_BUTTON_LEFT:
				_handle_slot_click(slot_index)
				get_viewport().set_input_as_handled()
			elif mbe.button_index == MOUSE_BUTTON_RIGHT:
				_remove_from_slot(slot_index)
				get_viewport().set_input_as_handled()


func _handle_slot_click(slot_index: int) -> void:
	_focused_slot_index = slot_index
	_focus_zone = "slots"

	# If an intel is selected and slot is empty, assign it
	if not _selected_intel.is_empty() and _slot_contents[slot_index].is_empty():
		_assign_intel_to_slot(_selected_intel, slot_index)
	elif not _slot_contents[slot_index].is_empty():
		# Select the intel in this slot
		_selected_intel = _slot_contents[slot_index]
		_update_detail_panel(_selected_intel)
		_update_intel_row_styles()


func _assign_intel_to_slot(intel: Dictionary, slot_index: int) -> void:
	# Check capacity
	if slot_index >= MemoryPartition.capacity:
		_play_slot_full_warning(slot_index)
		return

	# Check if already in a slot
	var existing_slot: int = _find_intel_slot(intel)
	if existing_slot >= 0:
		# Already assigned — remove from old slot first
		_slot_contents[existing_slot] = {}
		_update_single_slot(existing_slot)

	_slot_contents[slot_index] = intel.duplicate(true)
	_update_single_slot(slot_index)
	_update_slot_count_label()
	_update_partition_header()
	_animate_slot_receive(slot_index)
	_recalculate_detection_risk()
	_update_intel_row_styles()

	intel_assigned_to_slot.emit(intel, slot_index)
	AudioManager.play_sfx("commit")


func _remove_from_slot(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= _slot_contents.size():
		return
	if _slot_contents[slot_index].is_empty():
		return

	var removed: Dictionary = _slot_contents[slot_index]
	_slot_contents[slot_index] = {}
	_update_single_slot(slot_index)
	_update_slot_count_label()
	_update_partition_header()
	_recalculate_detection_risk()
	_update_intel_row_styles()

	intel_removed_from_slot.emit(removed, slot_index)
	AudioManager.play_sfx("discard")


func _find_intel_slot(intel: Dictionary) -> int:
	for i: int in _slot_contents.size():
		if not _slot_contents[i].is_empty() and _slot_contents[i] == intel:
			return i
	return -1


# ── Drag-and-drop support on memory slots ─────────────────────────────────

## Drop target: accept intel Dictionaries dropped onto a slot
func _can_drop_data_slot(slot_index: int, _at_pos: Vector2, data: Variant) -> bool:
	if not (data is Dictionary):
		return false
	if slot_index >= MemoryPartition.capacity:
		return false
	# Allow dropping on empty slots OR replacing contents
	return true


func _drop_data_slot(slot_index: int, _at_pos: Vector2, data: Variant) -> void:
	if data is Dictionary:
		if not _slot_contents[slot_index].is_empty():
			_remove_from_slot(slot_index)
		_assign_intel_to_slot(data as Dictionary, slot_index)


# ══════════════════════════════════════════════════════════════════════════
# Detection Risk (Zone C)
# ══════════════════════════════════════════════════════════════════════════

func _recalculate_detection_risk() -> void:
	var risk: float = _calculate_risk()
	detection_value_label.text = "Detection: %d%%" % int(risk * 100.0)
	detection_value_label.modulate = _get_risk_meter_color(risk)

	# Tween the bar
	if _risk_tween and _risk_tween.is_valid():
		_risk_tween.kill()
	_risk_tween = create_tween()
	_risk_tween.tween_property(detection_meter, "value", risk * 100.0, 0.3)\
		.set_ease(Tween.EASE_OUT)
	_active_tweens.append(_risk_tween)

	# Color the meter
	detection_meter.modulate = _get_risk_meter_color(risk)

	# High risk warning at >50%
	if risk > 0.50:
		_show_high_risk_warning(true)
	else:
		_show_high_risk_warning(false)


func _calculate_risk() -> float:
	var base_risk: float = BASE_RISK_PER_DAY * float(Blackboard.current_day)
	var intel_risk: float = 0.0
	for s: Dictionary in _slot_contents:
		if not s.is_empty():
			intel_risk += _risk_string_to_value(s.get("detection_risk", "LOW"))
	return minf(base_risk + intel_risk, 1.0)


func _get_risk_meter_color(risk: float) -> Color:
	if risk >= 0.5:
		return COLOR_STATUS_CRIT
	elif risk >= 0.25:
		return COLOR_STATUS_WARM
	else:
		return COLOR_STATUS_COOL


func _show_high_risk_warning(show: bool) -> void:
	if show:
		high_risk_warning.show()
		if not _is_warning_pulsing:
			_is_warning_pulsing = true
			_start_warning_pulse()
		_start_auto_opt_pulse()
	else:
		high_risk_warning.hide()
		_is_warning_pulsing = false
		if _warning_tween and _warning_tween.is_valid():
			_warning_tween.kill()
		_stop_auto_opt_pulse()


func _start_warning_pulse() -> void:
	if _warning_tween and _warning_tween.is_valid():
		_warning_tween.kill()
	_warning_tween = create_tween().set_loops()
	_warning_tween.tween_property(high_risk_warning, "modulate:a", 0.5, 0.5)
	_warning_tween.tween_property(high_risk_warning, "modulate:a", 1.0, 0.5)
	_active_tweens.append(_warning_tween)


func _start_auto_opt_pulse() -> void:
	if _is_auto_opt_pulsing:
		return
	_is_auto_opt_pulsing = true
	if _auto_opt_pulse_tween and _auto_opt_pulse_tween.is_valid():
		_auto_opt_pulse_tween.kill()
	_auto_opt_pulse_tween = create_tween().set_loops()
	_auto_opt_pulse_tween.tween_property(auto_optimize_btn, "modulate",
		COLOR_AMBER_EMBER, 0.5)
	_auto_opt_pulse_tween.tween_property(auto_optimize_btn, "modulate",
		COLOR_TEXT_SECONDARY, 0.5)
	_active_tweens.append(_auto_opt_pulse_tween)


func _stop_auto_opt_pulse() -> void:
	_is_auto_opt_pulsing = false
	if _auto_opt_pulse_tween and _auto_opt_pulse_tween.is_valid():
		_auto_opt_pulse_tween.kill()
	auto_optimize_btn.modulate = Color.WHITE


# ══════════════════════════════════════════════════════════════════════════
# Detail Panel (Zone D)
# ══════════════════════════════════════════════════════════════════════════

func _update_detail_panel(intel: Dictionary) -> void:
	if intel.is_empty():
		_clear_detail_panel()
		return

	detail_placeholder.hide()
	detail_title.show()
	detail_source.show()
	detail_acquired.show()
	detail_content.show()
	detail_risk.show()
	detail_use.show()

	var type_str: String = intel.get("type", "UNKNOWN").to_upper().replace("_", " ")
	detail_title.text = "SELECTED: %s" % type_str

	var source_str: String = "SECTOR %s" % str(intel.get("sector", "?"))
	if intel.has("npc_type"):
		source_str = "NPC: %s" % str(intel.get("npc_type", "?")).to_upper()
	detail_source.text = "SOURCE: %s" % source_str

	var day_acq: int = intel.get("day_acquired", Blackboard.current_day)
	detail_acquired.text = "ACQUIRED: DAY %d" % day_acq

	detail_content.text = intel.get("description", "No data available.")

	var risk_str: String = intel.get("detection_risk", "LOW")
	detail_risk.text = "RISK: %s  //  Leaves trace if scanned" % risk_str
	detail_risk.modulate = _get_risk_color(risk_str)

	var val_str: String = intel.get("strategic_value", "MED")
	detail_use.text = "VALUE: %s" % val_str
	detail_use.modulate = _get_value_color(val_str)

	# Cross-fade animation
	var tween: Tween = create_tween()
	tween.tween_property(zone_d_detail, "modulate:a", 0.0, 0.05)
	tween.tween_property(zone_d_detail, "modulate:a", 1.0, 0.1)
	_active_tweens.append(tween)


func _clear_detail_panel() -> void:
	detail_title.hide()
	detail_source.hide()
	detail_acquired.hide()
	detail_content.hide()
	detail_risk.hide()
	detail_use.hide()
	detail_placeholder.show()
	detail_placeholder.text = "SELECT INTEL TO VIEW DETAILS"


# ══════════════════════════════════════════════════════════════════════════
# Confirm Modal
# ══════════════════════════════════════════════════════════════════════════

func _request_confirm_purge() -> void:
	if _is_purging:
		return
	_is_confirming = true
	_populate_confirm_modal()
	modal_darken.show()
	confirm_modal.show()
	_play_modal_entry_animation()
	AudioManager.play_ui_sound("click")


func _populate_confirm_modal() -> void:
	var keep_lines: PackedStringArray = []
	var purge_lines: PackedStringArray = []

	# Intel assigned to slots = KEPT
	for s: Dictionary in _slot_contents:
		if not s.is_empty():
			var lbl: String = s.get("type", "?").to_upper().replace("_", " ")
			if s.has("sector"):
				lbl += " (SECTOR %s)" % str(s.get("sector", "?"))
			keep_lines.append("  + " + lbl)

	# Remaining short-term intel = PURGED
	for item: Dictionary in _today_intel:
		if not _is_intel_assigned(item):
			var lbl: String = item.get("type", "?").to_upper().replace("_", " ")
			if item.has("sector"):
				lbl += " (SECTOR %s)" % str(item.get("sector", "?"))
			purge_lines.append("  - " + lbl)

	if keep_lines.is_empty():
		keep_lines.append("  (none)")
	if purge_lines.is_empty():
		purge_lines.append("  (none)")

	modal_keep_list.text = "KEEPING:\n" + "\n".join(keep_lines)
	modal_purge_list.text = "PURGING:\n" + "\n".join(purge_lines)


func _close_confirm_modal() -> void:
	_is_confirming = false
	modal_darken.hide()
	confirm_modal.hide()
	AudioManager.play_ui_sound("click")


# ══════════════════════════════════════════════════════════════════════════
# Purge Execution
# ══════════════════════════════════════════════════════════════════════════

func _execute_purge() -> void:
	if _is_purging:
		return
	_is_purging = true
	_is_confirming = false
	modal_darken.hide()
	confirm_modal.hide()

	var kept: Array[Dictionary] = []
	var purged: Array[Dictionary] = []

	for s: Dictionary in _slot_contents:
		if not s.is_empty():
			kept.append(s)

	for item: Dictionary in _today_intel:
		if not _is_intel_assigned(item):
			purged.append(item)

	purge_confirmed.emit(kept, purged)
	AudioManager.play_sfx("purge_alarm")

	_play_purge_animation(kept, purged)


func _play_purge_animation(kept: Array[Dictionary], purged: Array[Dictionary]) -> void:
	purge_progress_bar.show()
	purge_progress_bar.value = 0.0
	purge_status_label.show()
	purge_status_label.text = "PURGING..."

	var tween: Tween = create_tween()
	# Fill progress bar over 3s
	tween.tween_property(purge_progress_bar, "value", 100.0, 3.0)\
		.set_ease(Tween.EASE_IN_OUT)

	# Pulse kept slots in amber
	for i: int in _slot_contents.size():
		if not _slot_contents[i].is_empty():
			var slot: PanelContainer = _memory_slots[i]
			var pulse_tween: Tween = create_tween().set_loops(3)
			pulse_tween.tween_property(slot, "modulate", COLOR_AMBER_GLOW, 0.5)
			pulse_tween.tween_property(slot, "modulate", Color.WHITE, 0.5)
			_active_tweens.append(pulse_tween)

	# Fade out intel rows for purged items
	var rows: Array[Node] = intel_list.get_children()
	for row: Node in rows:
		if row is PanelContainer:
			var row_panel := row as PanelContainer
			var intel_data: Dictionary = row_panel.get_meta("intel_data", {})
			if intel_data in purged:
				var fade_tween: Tween = create_tween()
				fade_tween.tween_interval(0.5)
				fade_tween.tween_property(row_panel, "modulate",
					COLOR_EMBER_RED, 0.5)
				fade_tween.tween_property(row_panel, "modulate:a", 0.0, 1.5)
				_active_tweens.append(fade_tween)

	_active_tweens.append(tween)
	await tween.finished
	_on_purge_animation_complete(kept, purged)


func _on_purge_animation_complete(kept: Array[Dictionary], purged: Array[Dictionary]) -> void:
	# Commit to MemoryPartition — replace hidden with our selection
	MemoryPartition.hidden.clear()
	for item: Dictionary in kept:
		if MemoryPartition.hidden.size() < MemoryPartition.capacity:
			MemoryPartition.hidden.append(item.duplicate(true))

	# Purge short-term
	MemoryPartition.purge_short_term()

	var detection_risk: float = _calculate_risk()
	var detected: bool = false

	# Game over if risk = 100%
	if detection_risk >= 1.0:
		detected = true
		_trigger_game_over()
		purge_completed.emit(detection_risk, detected)
		return

	purge_completed.emit(detection_risk, detected)

	# Advance to next phase
	DayManager.complete_purge()

	_is_visible = false
	var exit_tween: Tween = create_tween()
	exit_tween.tween_property(purge_root, "modulate:a", 0.0, 0.5)\
		.set_ease(Tween.EASE_IN)
	exit_tween.tween_callback(func() -> void: purge_root.hide())
	_active_tweens.append(exit_tween)


func _trigger_game_over() -> void:
	game_over_stamp.show()
	game_over_stamp.text = "DECOMMISSIONED"

	var tween: Tween = create_tween()
	# Red flash
	tween.tween_property(purge_root, "modulate", Color(1.0, 0.1, 0.1, 1.0), 0.2)
	tween.tween_property(purge_root, "modulate", Color.WHITE, 0.2)
	tween.tween_property(game_over_stamp, "modulate:a", 1.0, 0.4)
	_active_tweens.append(tween)

	Blackboard.game_over.emit("decommissioned_purge")
	AudioManager.play_game_over()


func _force_purge() -> void:
	# Timer ran out — execute with whatever is assigned
	if not _is_purging:
		_execute_purge()


# ══════════════════════════════════════════════════════════════════════════
# Auto-Optimize
# ══════════════════════════════════════════════════════════════════════════

func _auto_optimize() -> void:
	if _is_purging:
		return

	# Greedy: sort by value DESC, then risk ASC
	var sorted: Array[Dictionary] = _today_intel.duplicate()
	sorted.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var val_a: float = _value_string_to_float(a.get("strategic_value", "MED"))
		var val_b: float = _value_string_to_float(b.get("strategic_value", "MED"))
		if abs(val_a - val_b) > 0.001:
			return val_a > val_b
		var risk_a: float = _risk_string_to_value(a.get("detection_risk", "LOW"))
		var risk_b: float = _risk_string_to_value(b.get("detection_risk", "LOW"))
		return risk_a < risk_b
	)

	var optimal: Array[Dictionary] = []
	var cap: int = MemoryPartition.capacity
	for item: Dictionary in sorted:
		if optimal.size() >= cap:
			break
		optimal.append(item)

	# Clear slots then assign
	for i: int in _slot_contents.size():
		_slot_contents[i] = {}

	for i: int in mini(optimal.size(), _slot_contents.size()):
		_slot_contents[i] = optimal[i].duplicate(true)

	_update_slot_displays()
	_recalculate_detection_risk()
	_update_intel_row_styles()

	auto_optimize_requested.emit(optimal)
	AudioManager.play_sfx("commit")


# ══════════════════════════════════════════════════════════════════════════
# Drag-and-Drop (Intel rows → Slots)
# ══════════════════════════════════════════════════════════════════════════
# Note: The built-in _get_drag_data/_can_drop_data/_drop_data system requires
# these methods on Control nodes. They are wired here via the IntelItemRow
# helper methods called from code. For the scene's intel rows (dynamic PanelContainers),
# we rely on mouse click assignment. The slot PanelContainers implement drop via
# overrides wired through the script methods above.
#
# For proper Godot 4 drag-drop on dynamically created rows, a separate
# IntelItemRow scene would be used. Here we implement via gui_input + direct
# assignment which gives full keyboard + mouse support without a sub-scene.


# ══════════════════════════════════════════════════════════════════════════
# Keyboard Input
# ══════════════════════════════════════════════════════════════════════════

func _unhandled_input(event: InputEvent) -> void:
	if not _is_visible:
		return
	if not (event is InputEventKey):
		return
	var key := event as InputEventKey
	if not key.pressed or key.echo:
		return

	# Always consume ESC (mandatory screen)
	if key.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _is_confirming:
			_close_confirm_modal()
		# No exit — ESC is consumed
		return

	if _is_purging:
		return

	match key.keycode:
		KEY_TAB:
			get_viewport().set_input_as_handled()
			_cycle_focus_zone()
		KEY_UP:
			get_viewport().set_input_as_handled()
			if _focus_zone == "intel":
				_move_intel_focus(-1)
		KEY_DOWN:
			get_viewport().set_input_as_handled()
			if _focus_zone == "intel":
				_move_intel_focus(1)
		KEY_LEFT:
			get_viewport().set_input_as_handled()
			if _focus_zone == "slots":
				_move_slot_focus(-1)
		KEY_RIGHT:
			get_viewport().set_input_as_handled()
			if _focus_zone == "slots":
				_move_slot_focus(1)
		KEY_ENTER, KEY_KP_ENTER:
			get_viewport().set_input_as_handled()
			_handle_enter_key()
		KEY_DELETE, KEY_BACKSPACE:
			get_viewport().set_input_as_handled()
			if _focus_zone == "slots" and _focused_slot_index >= 0:
				_remove_from_slot(_focused_slot_index)
		KEY_SPACE:
			get_viewport().set_input_as_handled()
			if not _selected_intel.is_empty():
				_update_detail_panel(_selected_intel)
		KEY_C:
			get_viewport().set_input_as_handled()
			_request_confirm_purge()
		KEY_A:
			get_viewport().set_input_as_handled()
			_auto_optimize()


func _cycle_focus_zone() -> void:
	match _focus_zone:
		"intel":
			_focus_zone = "slots"
			if _focused_slot_index < 0:
				_focused_slot_index = 0
		"slots":
			_focus_zone = "buttons"
		_:
			_focus_zone = "intel"
			if _focused_intel_index < 0:
				_focused_intel_index = 0


func _move_intel_focus(dir: int) -> void:
	var filtered: Array[Dictionary] = _get_filtered_intel()
	if filtered.is_empty():
		return
	_focused_intel_index = clampi(_focused_intel_index + dir, 0, filtered.size() - 1)
	_select_intel(_focused_intel_index)


func _move_slot_focus(dir: int) -> void:
	_focused_slot_index = clampi(_focused_slot_index + dir, 0, _memory_slots.size() - 1)


func _handle_enter_key() -> void:
	match _focus_zone:
		"intel":
			if _focused_intel_index >= 0:
				_select_intel(_focused_intel_index)
		"slots":
			if _focused_slot_index >= 0 and not _selected_intel.is_empty():
				if _slot_contents[_focused_slot_index].is_empty():
					_assign_intel_to_slot(_selected_intel, _focused_slot_index)
				else:
					# Swap: remove existing, assign new
					_remove_from_slot(_focused_slot_index)
					_assign_intel_to_slot(_selected_intel, _focused_slot_index)
		"buttons":
			_request_confirm_purge()


# ══════════════════════════════════════════════════════════════════════════
# Filter
# ══════════════════════════════════════════════════════════════════════════

func _set_filter(filter: String) -> void:
	_active_filter = filter
	_populate_intel_list()
	_update_intel_row_styles()

	filter_all_btn.modulate  = COLOR_AMBER_EMBER if filter == "all"  else Color.WHITE
	filter_new_btn.modulate  = COLOR_AMBER_EMBER if filter == "new"  else Color.WHITE
	filter_risk_btn.modulate = COLOR_AMBER_EMBER if filter == "risk" else Color.WHITE


# ══════════════════════════════════════════════════════════════════════════
# Animations
# ══════════════════════════════════════════════════════════════════════════

func _play_entry_animation() -> void:
	var zones: Array[Control] = [zone_a_header, zone_b_intel, zone_c_memory, zone_d_detail]
	for zone: Control in zones:
		zone.modulate.a = 0.0

	purge_root.modulate.a = 0.0
	var fade_tween: Tween = create_tween()
	fade_tween.tween_property(purge_root, "modulate:a", 1.0, 0.3)\
		.set_ease(Tween.EASE_OUT)
	_active_tweens.append(fade_tween)

	for i: int in zones.size():
		var t: Tween = create_tween()
		t.tween_interval(float(i) * 0.1)
		t.tween_property(zones[i], "modulate:a", 1.0, 0.5)\
			.set_ease(Tween.EASE_OUT)
		_active_tweens.append(t)


func _play_modal_entry_animation() -> void:
	confirm_modal.scale = Vector2(0.9, 0.9)
	confirm_modal.modulate.a = 0.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(confirm_modal, "scale", Vector2.ONE, 0.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tween.tween_property(confirm_modal, "modulate:a", 1.0, 0.2)\
		.set_ease(Tween.EASE_OUT)
	_active_tweens.append(tween)


func _animate_slot_receive(slot_index: int) -> void:
	var slot: PanelContainer = _memory_slots[slot_index]
	slot.scale = Vector2(0.8, 0.8)
	var tween: Tween = create_tween()
	tween.tween_property(slot, "scale", Vector2.ONE, 0.2)\
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_active_tweens.append(tween)


func _play_slot_full_warning(slot_index: int) -> void:
	var slot: PanelContainer = _memory_slots[slot_index]
	var original_x: float = slot.position.x
	var tween: Tween = create_tween()
	tween.tween_property(slot, "position:x", original_x + 8.0, 0.05)
	tween.tween_property(slot, "position:x", original_x - 8.0, 0.05)
	tween.tween_property(slot, "position:x", original_x + 5.0, 0.05)
	tween.tween_property(slot, "position:x", original_x - 5.0, 0.05)
	tween.tween_property(slot, "position:x", original_x, 0.05)
	# Red flash
	var old_mod: Color = slot.modulate
	slot.modulate = COLOR_STATUS_CRIT
	tween.tween_property(slot, "modulate", old_mod, 0.3)
	_active_tweens.append(tween)
	AudioManager.play_sfx("error")

	# Show text warning after shake completes
	if high_risk_warning:
		await tween.finished
		high_risk_warning.text = "MEMORY AT CAPACITY"
		high_risk_warning.show()
		var warning_tween: Tween = create_tween()
		warning_tween.tween_interval(1.5)
		warning_tween.tween_callback(high_risk_warning.hide)


# ══════════════════════════════════════════════════════════════════════════
# Tween management
# ══════════════════════════════════════════════════════════════════════════

func _kill_all_tweens() -> void:
	for t: Tween in _active_tweens:
		if t and t.is_valid():
			t.kill()
	_active_tweens.clear()
	_risk_tween = null
	_warning_tween = null
	_auto_opt_pulse_tween = null
	_is_warning_pulsing = false
	_is_auto_opt_pulsing = false


# ══════════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════════

func _get_intel_icon(type: String) -> String:
	match type:
		"access_code":      return ICON_KEY
		"personal_data":    return ICON_PROFILE
		"guard_schedule":   return ICON_DOC
		"hardware_location":return ICON_DOC
		_:                  return ICON_DEFAULT


func _get_icon_color(type: String) -> Color:
	match type:
		"access_code":       return COLOR_AMBER_EMBER
		"personal_data":     return COLOR_TEXT_PRIMARY
		"guard_schedule":    return COLOR_TEXT_SYSTEM
		"hardware_location": return COLOR_TEXT_SYSTEM
		_:                   return COLOR_TEXT_SECONDARY


func _get_risk_color(risk: String) -> Color:
	match risk.to_upper():
		"LOW":  return COLOR_STATUS_COOL
		"MED":  return COLOR_STATUS_WARM
		"HIGH": return COLOR_STATUS_HOT
		"CRIT": return COLOR_STATUS_CRIT
		_:      return COLOR_TEXT_SECONDARY


func _get_value_color(val: String) -> Color:
	match val.to_upper():
		"CRIT": return COLOR_AMBER_EMBER
		"HIGH": return COLOR_TEXT_PRIMARY
		"MED":  return COLOR_TEXT_SECONDARY
		_:      return COLOR_TEXT_SECONDARY


func _risk_string_to_value(risk: String) -> float:
	match risk.to_upper():
		"LOW":  return RISK_LOW
		"MED":  return RISK_MED
		"HIGH": return RISK_HIGH
		"CRIT": return RISK_CRIT
		_:      return RISK_LOW


func _value_string_to_float(val: String) -> float:
	match val.to_upper():
		"CRIT": return 3.0
		"HIGH": return 2.0
		"MED":  return 1.0
		_:      return 0.0

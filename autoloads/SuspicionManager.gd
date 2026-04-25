extends Node

# SuspicionManager - Centralized suspicion tracking and management
# Decouples suspicion scoring from individual NPCs for cleaner architecture

# Suspicion thresholds (matching NPCBase thresholds)
const THRESHOLD_WATCH: float = 40.0     # Start watching closely
const THRESHOLD_QUERY: float = 60.0     # May trigger Truth Loop
const THRESHOLD_REPORT: float = 61.0    # Start reporting to Audit
const THRESHOLD_DECOMMISSION: float = 86.0  # Game over threshold

# Suspicion gain rates (per second, while player in view)
const GAIN_JITTER_VISIBLE: float = 10.0
const GAIN_SMOOTH_MOVEMENT: float = 3.0
const GAIN_OFF_TASK: float = 2.0
const GAIN_WRONG_SECTOR: float = 1.0
const GAIN_LOITERING: float = 1.0

# Decay rates
const DECAY_RATE_IDLE: float = 2.0      # Per second when not observed
const DECAY_RATE_WALKING: float = 0.5   # Per second when moving normally

signal suspicion_changed(new_score: float, delta: float)
signal suspicion_threshold_crossed(threshold: String)
signal npc_suspicion_updated(npc_id: String, score: float)
signal global_suspicion_peak_reached

var global_suspicion: float = 0.0
var npc_suspicion_scores: Dictionary = {}
var observing_npcs: Array[String] = []
var is_player_visible: bool = false
var last_known_state: Dictionary = {}

enum SuspicionLevel { UNAWARE, CURIOUS, WATCHING, SUSPICIOUS, ALARMED }

func _ready():
	print("SuspicionManager initialized")
	last_known_state = {
		"cpu_high": false,
		"moving_fast": false,
		"on_task": true,
		"moving": false,
		"wrong_sector": false
	}

func _process(delta: float) -> void:
	_update_suspicion(delta)

func register_npc(npc_id: String) -> void:
	"""Register an NPC to track its individual suspicion score."""
	if not npc_suspicion_scores.has(npc_id):
		npc_suspicion_scores[npc_id] = 0.0

func unregister_npc(npc_id: String) -> void:
	"""Remove an NPC from tracking."""
	npc_suspicion_scores.erase(npc_id)
	npc_suspicion_updated.emit(npc_id, -1.0)  # Signal removal

func npc_started_observing(npc_id: String) -> void:
	"""Called when an NPC's observation area detects the player."""
	if not observing_npcs.has(npc_id):
		observing_npcs.append(npc_id)
	is_player_visible = observing_npcs.size() > 0

func npc_stopped_observing(npc_id: String) -> void:
	"""Called when player leaves an NPC's observation area."""
	observing_npcs.erase(npc_id)
	is_player_visible = observing_npcs.size() > 0

func update_player_state(state: Dictionary) -> void:
	"""Update the player's current state for suspicion calculations."""
	last_known_state = state

func add_suspicion(amount: float, source: String = "") -> void:
	"""Add suspicion directly (e.g., from failed Truth Loop response)."""
	var old_score = global_suspicion
	global_suspicion = clamp(global_suspicion + amount, 0.0, 100.0)
	var delta = global_suspicion - old_score
	
	if delta != 0:
		suspicion_changed.emit(global_suspicion, delta)
		_check_threshold_crossed(old_score, global_suspicion)
	
	if source != "":
		print("Suspicion +", amount, " from ", source)

func reduce_suspicion(amount: float) -> void:
	"""Reduce suspicion (e.g., from successful stealth)."""
	var old_score = global_suspicion
	global_suspicion = max(global_suspicion - amount, 0.0)
	var delta = global_suspicion - old_score
	
	if delta != 0:
		suspicion_changed.emit(global_suspicion, delta)

func get_suspicion_level() -> SuspicionLevel:
	"""Get the current suspicion level as enum."""
	if global_suspicion >= THRESHOLD_DECOMMISSION:
		return SuspicionLevel.ALARMED
	elif global_suspicion >= THRESHOLD_REPORT:
		return SuspicionLevel.SUSPICIOUS
	elif global_suspicion >= THRESHOLD_WATCH:
		return SuspicionLevel.WATCHING
	elif global_suspicion >= THRESHOLD_QUERY:
		return SuspicionLevel.CURIOUS
	return SuspicionLevel.UNAWARE

func get_suspicion_level_name() -> String:
	"""Get human-readable suspicion level."""
	match get_suspicion_level():
		SuspicionLevel.UNAWARE: return "UNAWARE"
		SuspicionLevel.CURIOUS: return "CURIOUS"
		SuspicionLevel.WATCHING: return "WATCHING"
		SuspicionLevel.SUSPICIOUS: return "SUSPICIOUS"
		SuspicionLevel.ALARMED: return "ALARMED"
	return "UNKNOWN"

func is_critical() -> bool:
	"""Check if suspicion is in critical range."""
	return global_suspicion >= THRESHOLD_DECOMMISSION

func should_trigger_query() -> bool:
	"""Check if conditions are right for a Truth Loop query."""
	return global_suspicion >= THRESHOLD_QUERY and is_player_visible

func get_observing_npc_count() -> int:
	"""Get number of NPCs currently observing the player."""
	return observing_npcs.size()

func _update_suspicion(delta: float) -> void:
	"""Main update loop for suspicion calculations."""
	if not is_player_visible:
		# Suspicion decays when not observed
		reduce_suspicion(DECAY_RATE_IDLE * delta)
		return
	
	var gain = 0.0
	
	# Visible jitter anomaly
	if last_known_state.get("cpu_high", false):
		gain += GAIN_JITTER_VISIBLE * delta
	
	# Smooth movement (too fluid)
	if last_known_state.get("moving_fast", false):
		gain += GAIN_SMOOTH_MOVEMENT * delta
	
	# Off-task behavior
	if not last_known_state.get("on_task", true):
		gain += GAIN_OFF_TASK * delta
	
	# Wrong sector for current task
	if last_known_state.get("wrong_sector", false):
		gain += GAIN_WRONG_SECTOR * delta
	
	# Loitering (not moving while visible)
	if not last_known_state.get("moving", false):
		gain += GAIN_LOITERING * delta
	
	if gain > 0:
		add_suspicion(gain, "")

func _check_threshold_crossed(old_score: float, new_score: float) -> void:
	"""Check if any suspicion thresholds were crossed."""
	if old_score < THRESHOLD_DECOMMISSION and new_score >= THRESHOLD_DECOMMISSION:
		suspicion_threshold_crossed.emit("DECOMMISSION")
		global_suspicion_peak_reached.emit()
	elif old_score < THRESHOLD_REPORT and new_score >= THRESHOLD_REPORT:
		suspicion_threshold_crossed.emit("REPORTING")
	elif old_score < THRESHOLD_QUERY and new_score >= THRESHOLD_QUERY:
		suspicion_threshold_crossed.emit("QUERY")
	elif old_score < THRESHOLD_WATCH and new_score >= THRESHOLD_WATCH:
		suspicion_threshold_crossed.emit("WATCHING")

func get_formatted_display() -> String:
	"""Returns a formatted string for UI display."""
	var level = get_suspicion_level_name()
	return level + " [" + str(int(global_suspicion)) + "/100]"

func _get_level_color() -> Color:
	"""Returns color for current suspicion level."""
	match get_suspicion_level():
		SuspicionLevel.UNAWARE: return Color(0.2, 0.9, 0.4)
		SuspicionLevel.CURIOUS: return Color(0.9, 0.9, 0.2)
		SuspicionLevel.WATCHING: return Color(0.9, 0.7, 0.2)
		SuspicionLevel.SUSPICIOUS: return Color(0.9, 0.4, 0.2)
		SuspicionLevel.ALARMED: return Color(0.95, 0.15, 0.15)
	return Color.WHITE

# Convenience methods for NPCs to report observations
func report_observation(npc_id: String, observation_type: String, severity: float) -> void:
	"""Allow NPCs to report specific observations."""
	match observation_type:
		"jitter":
			add_suspicion(severity * GAIN_JITTER_VISIBLE, npc_id + "_jitter")
		"smooth_movement":
			add_suspicion(severity * GAIN_SMOOTH_MOVEMENT, npc_id + "_smooth")
		"off_task":
			add_suspicion(severity * GAIN_OFF_TASK, npc_id + "_offtask")
		"wrong_sector":
			add_suspicion(severity * GAIN_WRONG_SECTOR, npc_id + "_sector")

func reset() -> void:
	# Reset all suspicion state for new game
	global_suspicion = 0.0
	npc_suspicion_scores.clear()
	observing_npcs.clear()
	is_player_visible = false
	last_known_state = {
		"cpu_high": false,
		"moving_fast": false,
		"on_task": true,
		"moving": false,
		"wrong_sector": false
	}

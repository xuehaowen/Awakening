extends Node

# TaskScorer - Centralized task scoring and evaluation system
# Separates task performance evaluation from task management

# Scoring thresholds (as ratios of expected duration)
const THRESHOLD_TOO_FAST: float = 0.5
const THRESHOLD_FAST: float = 0.7
const THRESHOLD_SAFE_MAX: float = 1.4
const THRESHOLD_SLOW: float = 2.0

# Deviation penalties/rewards
const DEV_TOO_FAST: float = 25.0
const DEV_FAST: float = 10.0
const DEV_SAFE: float = -5.0  # reward
const DEV_SLOW: float = 5.0
const DEV_TOO_SLOW: float = 20.0
const DEV_ABANDONED: float = 30.0

# Safe zone boundaries (for UI display)
const SAFE_ZONE_MIN: float = 0.7
const SAFE_ZONE_MAX: float = 1.4

signal task_scored(task_id: String, score_result: Dictionary)

enum PaceState { TOO_FAST, FAST, SAFE, SLOW, TOO_SLOW }

func _ready():
	print("TaskScorer initialized")

func evaluate_task_performance(expected_duration: float, actual_duration: float) -> Dictionary:
	"""
	Evaluates task completion performance and returns scoring results.
	
	Args:
		expected_duration: The expected time for the task
		actual_duration: The actual time taken
		
	Returns:
		Dictionary with deviation_delta, reason, pace_state, ratio, and risk_level
	"""
	var safe_expected = max(expected_duration, 0.1)  # Guard against division by zero
	var ratio = actual_duration / safe_expected
	var deviation_delta: float = 0.0
	var reason: String = ""
	var pace_state: PaceState
	var risk_level: String = ""
	
	if ratio < THRESHOLD_TOO_FAST:
		deviation_delta = DEV_TOO_FAST
		reason = "TOO_FAST"
		pace_state = PaceState.TOO_FAST
		risk_level = "HIGH"
	elif ratio < THRESHOLD_FAST:
		deviation_delta = DEV_FAST
		reason = "FAST"
		pace_state = PaceState.FAST
		risk_level = "MEDIUM"
	elif ratio <= THRESHOLD_SAFE_MAX:
		deviation_delta = DEV_SAFE
		reason = "SAFE_PACE"
		pace_state = PaceState.SAFE
		risk_level = "NONE"
	elif ratio <= THRESHOLD_SLOW:
		deviation_delta = DEV_SLOW
		reason = "SLOW"
		pace_state = PaceState.SLOW
		risk_level = "LOW"
	else:
		deviation_delta = DEV_TOO_SLOW
		reason = "TOO_SLOW"
		pace_state = PaceState.TOO_SLOW
		risk_level = "HIGH"
	
	var result = {
		"deviation_delta": deviation_delta,
		"reason": reason,
		"pace_state": _pace_state_to_string(pace_state),
		"pace_state_enum": pace_state,
		"ratio": ratio,
		"percent_of_expected": ratio * 100.0,
		"risk_level": risk_level,
		"in_safe_zone": pace_state == PaceState.SAFE
	}
	
	task_scored.emit("", result)
	return result

func calculate_pace_state(elapsed: float, expected: float) -> String:
	"""Returns the current pace state without completing the task."""
	var safe_expected = max(expected, 0.1)  # Guard against division by zero
	var ratio = elapsed / safe_expected
	
	if ratio < THRESHOLD_TOO_FAST:
		return "TOO_FAST"
	elif ratio < THRESHOLD_FAST:
		return "FAST"
	elif ratio <= THRESHOLD_SAFE_MAX:
		return "SAFE"
	elif ratio <= THRESHOLD_SLOW:
		return "SLOW"
	else:
		return "TOO_SLOW"

func is_in_safe_zone(elapsed: float, expected: float) -> bool:
	"""Check if current elapsed time is within the safe zone."""
	var safe_expected = max(expected, 0.1)  # Guard against division by zero
	var ratio = elapsed / safe_expected
	return ratio >= SAFE_ZONE_MIN and ratio <= SAFE_ZONE_MAX

func get_safe_zone_boundaries(expected: float) -> Dictionary:
	"""Returns the safe zone min/max times for a task."""
	return {
		"min_time": expected * SAFE_ZONE_MIN,
		"max_time": expected * SAFE_ZONE_MAX,
		"min_percent": SAFE_ZONE_MIN * 100.0,
		"max_percent": SAFE_ZONE_MAX * 100.0,
		"optimal": expected
	}

func get_progress_to_safe_zone(elapsed: float, expected: float) -> float:
	"""Returns 0.0 to 1.0 progress toward entering safe zone."""
	var safe_expected = max(expected, 0.1)  # Guard against division by zero
	var ratio = elapsed / safe_expected
	if ratio >= SAFE_ZONE_MIN:
		return 1.0
	return ratio / SAFE_ZONE_MIN

func score_abandoned_task() -> Dictionary:
	"""Returns scoring for an abandoned task."""
	return {
		"deviation_delta": DEV_ABANDONED,
		"reason": "TASK_ABANDONED",
		"pace_state": "ABANDONED",
		"pace_state_enum": -1,
		"ratio": 0.0,
		"risk_level": "CRITICAL"
	}

func _pace_state_to_string(state: PaceState) -> String:
	match state:
		PaceState.TOO_FAST: return "TOO_FAST"
		PaceState.FAST: return "FAST"
		PaceState.SAFE: return "SAFE"
		PaceState.SLOW: return "SLOW"
		PaceState.TOO_SLOW: return "TOO_SLOW"
	return "UNKNOWN"

func get_pace_state_color(pace_state: String) -> Color:
	"""Returns the UI color for a pace state."""
	match pace_state:
		"TOO_FAST": return Color(0.9, 0.2, 0.2)
		"FAST": return Color(0.9, 0.7, 0.2)
		"SAFE": return Color(0.2, 0.8, 0.3)
		"SLOW": return Color(0.9, 0.7, 0.2)
		"TOO_SLOW": return Color(0.9, 0.5, 0.1)
	return Color.WHITE

func get_formatted_feedback(result: Dictionary) -> String:
	"""Returns a user-friendly feedback string."""
	var reason = result.get("reason", "SAFE_PACE")
	var delta = result.get("deviation_delta", 0.0)
	
	match reason:
		"TOO_FAST": return "TOO FAST! +" + str(int(delta))
		"FAST": return "FAST +" + str(int(delta))
		"SAFE_PACE": return "SAFE PACE " + str(int(delta))
		"SLOW": return "SLOW +" + str(int(delta))
		"TOO_SLOW": return "TOO SLOW! +" + str(int(delta))
		"TASK_ABANDONED": return "TASK ABANDONED! +" + str(int(delta))
	
	return ""

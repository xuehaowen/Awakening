extends Node

var task_log: Array[Dictionary] = []
var audit_flags: int = 0
var under_review: bool = false
var daily_flags: int = 0

signal audit_report_generated(report: Dictionary)
signal system_flag_added(severity: int, reason: String)

func _ready():
	task_log.clear()
	audit_flags = 0

func log_task_completion(task: Dictionary, actual_duration: float) -> void:
	var entry = {
		"task_id": task["id"],
		"sector": task.get("sector", 0),
		"room": task["assigned_room"],
		"expected": task["expected_duration"],
		"actual": actual_duration,
		"discrepancy": abs(actual_duration - task["expected_duration"]),
		"day": Blackboard.current_day,
		"ratio": actual_duration / task["expected_duration"]
	}
	task_log.append(entry)
	_update_log_integrity()

func log_event(source: String, deviation_added: float) -> void:
	# Log significant deviation events
	if deviation_added > 10.0:
		audit_flags += 1
		daily_flags += 1
		Blackboard.audit_flags = audit_flags
		system_flag_added.emit(1, source)

func _update_log_integrity() -> void:
	var total_discrepancy = 0.0
	var day_entries = task_log.filter(func(e): return e["day"] == Blackboard.current_day)
	
	for entry in day_entries:
		total_discrepancy += entry["discrepancy"] / entry["expected"]
	
	# More tasks = more tolerance for discrepancies
	var tolerance = max(day_entries.size() * 0.5, 1.0)
	var integrity = clamp(100.0 - (total_discrepancy * 20.0 / tolerance), 0, 100)
	
	Blackboard.log_integrity = integrity

func end_of_day_report() -> Dictionary:
	_update_log_integrity()
	
	var consequence = _determine_consequence()
	var report = {
		"day": Blackboard.current_day,
		"flags": daily_flags,
		"total_flags": audit_flags,
		"log_integrity": Blackboard.log_integrity,
		"consequence": consequence,
		"tasks_completed": task_log.filter(func(e): return e["day"] == Blackboard.current_day).size()
	}
	
	audit_report_generated.emit(report)
	_reset_daily()
	
	return report

func _determine_consequence() -> String:
	if daily_flags >= 3 or Blackboard.log_integrity < 50.0:
		return "full_audit"
	elif daily_flags >= 1 or Blackboard.log_integrity < 75.0:
		return "under_review"
	else:
		return "clean"

func add_flag(severity: int, reason: String = "") -> void:
	audit_flags += severity
	daily_flags += severity
	Blackboard.audit_flags = audit_flags
	system_flag_added.emit(severity, reason)

func flag_decommission(npc: Node) -> void:
	Blackboard.game_over.emit("decommission")

func _reset_daily() -> void:
	daily_flags = 0

func get_log_summary() -> String:
	var day_entries = task_log.filter(func(e): return e["day"] == Blackboard.current_day)
	if day_entries.is_empty():
		return "No tasks logged today."
	
	var total_discrepancy = 0.0
	for entry in day_entries:
		total_discrepancy += entry["discrepancy"]
	
	return "Tasks: %d | Total Discrepancy: %.1fs" % [day_entries.size(), total_discrepancy]

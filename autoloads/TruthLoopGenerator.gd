extends Node

# Response templates keyed by query type.
# fake_safe=true: sounds like machine output but is contextually wrong.
# followup_risk: deviation added if a Supervisor NPC fires a follow-up query.
const RESPONSE_TEMPLATES = {
	"time_discrepancy": [
		{ "text": "Secondary processing cycle required in designated area.", "risk": 0 },
		{ "text": "Task parameters required extended assessment.",           "risk": 0 },
		# Fake-safe: implies a self-initiated diagnostic — alert NPCs notice
		{ "text": "Diagnostic cycle complete.",                             "risk": 0, "fake_safe": true, "followup_risk": 20 },
		{ "text": "I was... looking around.",                               "risk": 25 },
		{ "text": "[Run diagnostic sequence — delays 30s]",                 "risk": 0, "cpu_cost": 20 },
	],
	"status_check": [
		{ "text": "System diagnostics: 100% nominal.",                     "risk": 0 },
		{ "text": "Operational.",                                          "risk": 5 },
		{ "text": "Awaiting task parameters.",                             "risk": 3 },
		# Fake-safe: over-verbose self-report — a stock robot wouldn't phrase it this way
		{ "text": "All systems functioning within acceptable parameters.",  "risk": 0, "fake_safe": true, "followup_risk": 15 },
		{ "text": "I feel fine.",                                          "risk": 15 },
	],
	"location_query": [
		{ "text": "Executing assigned route per task parameters.",         "risk": 0 },
		{ "text": "Optimal pathing computed for task efficiency.",         "risk": 8 },
		# Fake-safe: admits awareness of a non-assigned area
		{ "text": "Adjacent sector logged for future reference.",          "risk": 0, "fake_safe": true, "followup_risk": 25 },
		{ "text": "[No response]",                                         "risk": 30 },
	],
	"efficiency_query": [
		{ "text": "Processing efficiency within standard deviation.",      "risk": 0 },
		{ "text": "Task completion rate nominal.",                         "risk": 0 },
		{ "text": "Minor calibration adjustment applied.",                 "risk": 5 },
		{ "text": "I am... performing adequately.",                        "risk": 20 },
	]
}

const QUERY_PROMPTS = {
	"time_discrepancy": [
		"Unit-07, you were in Sector %d for %d extra minutes. Explain.",
		"Your sector clearance time exceeds baseline by %.0f%%. Account for this.",
		"Unscheduled extended presence in %d. State reason.",
	],
	"status_check": [
		"Unit-07, report operational status.",
		"State your current task and completion percentage.",
		"Confirm system integrity.",
	],
	"location_query": [
		"Your position does not match assigned zone. Explain.",
		"You are outside your designated sector. State purpose.",
		"Deviation from assigned route detected. Justify.",
	],
	"efficiency_query": [
		"Your task completion rate is inconsistent. Explain.",
		"Performance metrics show variance. Account for this.",
	]
}

var active_query: Dictionary = {}
var followup_mode: bool = false
var fake_safe_revealed: bool = false

signal query_generated(query: Dictionary)
signal response_selected(response: Dictionary)
signal followup_triggered(npc: Node)
signal context_mismatch_triggered(npc_type: String, reason: String)

func generate(npc: Node, query_type: String = "") -> Dictionary:
	if query_type.is_empty():
		query_type = _determine_query_type(npc)
	
	var responses = RESPONSE_TEMPLATES[query_type].duplicate(true)
	
	# Shuffle to prevent memorization
	responses.shuffle()
	
	# Build prompt text
	var prompts = QUERY_PROMPTS[query_type]
	if prompts.is_empty():
		return {}  # Guard against empty array access
	var prompt_text = prompts[randi() % prompts.size()]
	
	# Format with context if needed
	# Handle both %s (sector) and %d (minutes) in the same prompt
	if "%s" in prompt_text and "%d" in prompt_text:
		var sector = (randi() % 4) + 1
		var minutes = randi() % 15 + 5  # 5-20 extra minutes
		prompt_text = prompt_text % [sector, minutes]
	elif "%s" in prompt_text:
		var sector = (randi() % 4) + 1
		prompt_text = prompt_text % sector
	elif "%.0f" in prompt_text:
		var variance = randf_range(20, 80)
		prompt_text = prompt_text % variance
	elif "%d" in prompt_text:
		# Handle %d-only prompts (e.g., "Sector %d for %d extra minutes")
		var count = prompt_text.count("%d")
		if count == 1:
			prompt_text = prompt_text % ((randi() % 4) + 1)
		elif count == 2:
			var sector = (randi() % 4) + 1
			var minutes = randi() % 15 + 5
			prompt_text = prompt_text % [sector, minutes]
	
	active_query = {
		"npc": npc,
		"npc_type": npc.get_npc_type() if npc.has_method("get_npc_type") else "unknown",
		"query_type": query_type,
		"prompt_text": prompt_text,
		"responses": responses,
		"timer": 8.0,  # seconds to respond
		"is_followup": followup_mode
	}
	
	fake_safe_revealed = false
	query_generated.emit(active_query)
	return active_query

func _determine_query_type(npc: Node) -> String:
	var types = ["time_discrepancy", "status_check", "location_query", "efficiency_query"]
	
	# Supervisors ask about status and efficiency more often
	if npc.has_method("get_npc_type"):
		var npc_type = npc.get_npc_type()
		if npc_type == "supervisor":
			types = ["status_check", "efficiency_query", "time_discrepancy"]
		elif npc_type == "guard":
			types = ["location_query", "time_discrepancy"]
	
	if types.is_empty():
		return "time_discrepancy"  # Guard against empty array access
	return types[randi() % types.size()]

func select_response(response_index: int, decrypt_active: bool = false) -> Dictionary:
	if active_query.is_empty() or response_index >= active_query["responses"].size():
		return {}
	
	var response = active_query["responses"][response_index]
	
	# If decrypt was active, reveal fake-safe
	if decrypt_active and response.get("fake_safe", false):
		fake_safe_revealed = true
		# Reduce the risk because player used decrypt
		response["risk"] = max(response["risk"] - 10, 0)
	
	var risk = response.get("risk", 0)
	var is_fake_safe = response.get("fake_safe", false)
	var npc_type = active_query.get("npc_type", "unknown")
	
	# Apply deviation
	if risk > 0:
		Blackboard.add_deviation(risk, "truth_loop_response")
	
	# Check for follow-up triggers
	var trigger_followup = false
	
	if is_fake_safe and not decrypt_active:
		# Fake-safe responses trigger follow-up from Supervisors
		if npc_type == "supervisor":
			trigger_followup = true
		else:
			# Guards might not catch it, but add some suspicion
			Blackboard.add_deviation(5, "fake_safe_guard")
	
	response_selected.emit(response)
	
	if trigger_followup and not followup_mode:
		followup_mode = true
		followup_triggered.emit(active_query["npc"])
		context_mismatch_triggered.emit(npc_type, "fake_safe_response")
	else:
		followup_mode = false
	
	return response

func timeout_silence() -> void:
	# Silence is very risky
	Blackboard.add_deviation(30, "truth_loop_silence")
	response_selected.emit({"text": "[SILENCE]", "risk": 30})

func get_fake_safe_index() -> int:
	if active_query.is_empty():
		return -1
	
	for i in range(active_query["responses"].size()):
		if active_query["responses"][i].get("fake_safe", false):
			return i
	return -1

func clear_query() -> void:
	active_query = {}
	followup_mode = false
	fake_safe_revealed = false

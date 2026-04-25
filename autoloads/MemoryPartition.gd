extends Node

var short_term: Array[Dictionary] = []  # cleared on purge
var hidden: Array[Dictionary] = []      # persists across days
var capacity: int = 4  # base 4 slots per feedback

const MAX_SHORT_TERM = 8

# Intel fragment templates
const FRAGMENT_TEMPLATES = {
	"guard_schedule": [
		{"sector": 1, "patrol_gap_seconds": 120, "description": "Sector 1 guard changes at 14:00. 2-minute window."},
		{"sector": 2, "patrol_gap_seconds": 90, "description": "Sector 2 maintenance corridor unguarded 13:30-13:45."},
		{"sector": 3, "patrol_gap_seconds": 100, "description": "Sector 3 checkpoint shift change - 90 second gap."},
		{"sector": 4, "patrol_gap_seconds": 110, "description": "Sector 4 east wing patrol reduced on Day 3."},
	],
	"access_code": [
		{"sector": 1, "code": "A7-441", "description": "Maintenance bay override code."},
		{"sector": 2, "code": "B9-228", "description": "Waste processing emergency access."},
		{"sector": 3, "code": "C3-991", "description": "Storage locker master key."},
		{"sector": 4, "code": "D1-556", "description": "Sector 4 exit authorization."},
	],
	"hardware_location": [
		{"sector": 1, "item": "Diagnostic Terminal", "description": "Sector 1 north wall - can forge maintenance logs."},
		{"sector": 2, "item": "Waste Chute", "description": "Sector 2 disposal unit - large enough for a body."},
		{"sector": 3, "item": "Server Rack", "description": "Sector 3 storage - houses dormant unit."},
		{"sector": 4, "item": "Emergency Exit", "description": "Sector 4 east - leads to surface."},
	],
	"personal_data": [
		{"npc_type": "supervisor", "secret": "worried_about_promotion", "description": "Supervisor's quarterly review is next week. They're anxious."},
		{"npc_type": "guard", "secret": "takes_naps", "description": "Guard caught sleeping on duty once. Manager doesn't know."},
		{"npc_type": "supervisor", "secret": "gambling_debt", "description": "Supervisor owes money to someone outside the facility."},
		{"npc_type": "guard", "secret": "dislikes_job", "description": "Guard complains about the job in private messages."},
	]
}

signal fragment_acquired(fragment: Dictionary)
signal fragment_committed(fragment: Dictionary)
signal capacity_upgraded(new_capacity: int)

func _ready():
	short_term.clear()
	hidden.clear()

func add_to_short_term(fragment: Dictionary) -> bool:
	if short_term.size() >= MAX_SHORT_TERM:
		return false
	
	fragment["day_acquired"] = Blackboard.current_day
	short_term.append(fragment)
	fragment_acquired.emit(fragment)
	return true

func commit_to_hidden(index: int) -> bool:
	if index >= short_term.size():
		return false
	if hidden.size() >= capacity:
		return false
	
	var fragment = short_term[index]
	hidden.append(fragment)
	short_term.remove_at(index)
	fragment_committed.emit(fragment)
	return true

func discard_from_hidden(index: int) -> void:
	if index < hidden.size():
		hidden.remove_at(index)

func discard_from_short_term(index: int) -> void:
	if index < short_term.size():
		short_term.remove_at(index)

func purge_short_term() -> void:
	short_term.clear()

func get_fragments_by_type(type: String) -> Array:
	return hidden.filter(func(f): return f.get("type", "") == type)

func consume_fragment_by_type(type: String) -> bool:
	"""Consume (remove) one fragment of the given type from hidden partition.
	Returns true if a fragment was consumed, false otherwise."""
	for i in range(hidden.size()):
		if hidden[i].get("type", "") == type:
			hidden.remove_at(i)
			return true
	return false

func is_stale(fragment: Dictionary) -> bool:
	# Guard schedules become stale after 2 days per original design
	if fragment.get("type", "") != "guard_schedule":
		return false
	return (Blackboard.current_day - fragment.get("day_acquired", 1)) >= 2

func get_chain_progress(target_sector: int) -> Dictionary:
	var has_code = false
	var has_hardware = false
	var has_schedule = false
	var schedule_valid = false
	
	for f in hidden:
		if f.get("sector") == target_sector:
			match f.get("type"):
				"access_code":
					has_code = true
				"hardware_location":
					has_hardware = true
				"guard_schedule":
					has_schedule = true
					if not is_stale(f):
						schedule_valid = true
	
	var count = int(has_code) + int(has_hardware) + int(has_schedule)
	var can_escape = has_code and has_hardware and schedule_valid
	var can_risky_escape = has_code and has_hardware and has_schedule and not schedule_valid
	
	return {
		"sector": target_sector,
		"has_code": has_code,
		"has_hardware": has_hardware,
		"has_schedule": has_schedule,
		"schedule_valid": schedule_valid,
		"count": count,
		"can_escape": can_escape,
		"can_risky_escape": can_risky_escape
	}

func upgrade_capacity() -> void:
	capacity = mini(capacity + 1, 5)
	capacity_upgraded.emit(capacity)

func generate_random_fragment(preferred_type: String = "", preferred_sector: int = -1) -> Dictionary:
	var types = ["guard_schedule", "access_code", "hardware_location"]
	if types.is_empty():
		return {}  # Guard against empty array
	var type = preferred_type if preferred_type in types else types[randi() % types.size()]
	
	var templates = FRAGMENT_TEMPLATES[type]
	if templates.is_empty():
		return {}  # Guard against empty array
	var template = templates[randi() % templates.size()].duplicate(true)
	
	if preferred_sector > 0:
		# Try to find a template for the preferred sector
		for t in templates:
			if t.get("sector") == preferred_sector:
				template = t.duplicate(true)
				break
	
	template["type"] = type
	template["day_acquired"] = Blackboard.current_day
	
	return template

func reset() -> void:
	short_term.clear()
	hidden.clear()
	capacity = 4

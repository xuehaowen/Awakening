extends Node

const TASK_TEMPLATES = [
	{ "id": "clean_sector", "label": "Clean Sector %s", "duration_range": [15, 30], "room_tag": "cleanable" },
	{ "id": "sort_waste",   "label": "Sort Bio-Waste",   "duration_range": [20, 40], "room_tag": "waste" },
	{ "id": "inventory",    "label": "Inventory Check",  "duration_range": [15, 35],  "room_tag": "storage" },
	{ "id": "transport",    "label": "Transport Cargo",  "duration_range": [25, 45], "room_tag": "any" },
]

var active_tasks: Array[Dictionary] = []
var completed_tasks: Array[Dictionary] = []
var current_task_index: int = -1

signal task_assigned(task: Dictionary)
signal task_completed(task: Dictionary, result: Dictionary)
signal all_tasks_completed()

func generate_day_tasks(day: int) -> void:
	active_tasks.clear()
	completed_tasks.clear()
	
	# 3-5 tasks per day based on day number
	var count = clamp(3 + day - 1, 3, 5)
	
	for i in count:
		var template = TASK_TEMPLATES[randi() % TASK_TEMPLATES.size()].duplicate(true)
		var sector = (randi() % 4) + 1  # Sectors 1-4
		
		template["assigned_room"] = "sector_" + str(sector)
		template["sector"] = sector
		template["expected_duration"] = randf_range(template["duration_range"][0], template["duration_range"][1])
		template["safe_min"] = template["expected_duration"] * 0.7  # 70% lower bound
		template["safe_max"] = template["expected_duration"] * 1.4  # 140% upper bound
		template["actual_start_time"] = -1.0
		template["actual_end_time"] = -1.0
		template["elapsed"] = 0.0
		template["completed"] = false
		
		active_tasks.append(template)
	
	# Assign first task
	if active_tasks.size() > 0:
		current_task_index = 0
		active_tasks[0]["actual_start_time"] = Time.get_ticks_msec() / 1000.0
		task_assigned.emit(active_tasks[0])
	
	print("Generated ", count, " tasks for Day ", day)

func get_current_task() -> Dictionary:
	if current_task_index >= 0 and current_task_index < active_tasks.size():
		return active_tasks[current_task_index]
	return {}

func get_task_progress() -> Dictionary:
	var task = get_current_task()
	if task.is_empty():
		return {}
	
	var elapsed = (Time.get_ticks_msec() / 1000.0) - task["actual_start_time"]
	var expected = task["expected_duration"]
	var ratio = elapsed / expected
	
	var pace_state: String
	if ratio < 0.5:
		pace_state = "TOO_FAST"
	elif ratio < 0.7:
		pace_state = "FAST"
	elif ratio <= 1.4:
		pace_state = "SAFE"
	elif ratio <= 2.0:
		pace_state = "SLOW"
	else:
		pace_state = "TOO_SLOW"
	
	return {
		"elapsed": elapsed,
		"expected": expected,
		"safe_min": task["safe_min"],
		"safe_max": task["safe_max"],
		"ratio": ratio,
		"pace_state": pace_state,
		"percent_complete": clamp(ratio * 100, 0, 200)
	}

func complete_current_task() -> Dictionary:
	var task = get_current_task()
	if task.is_empty():
		return {"deviation_delta": 0, "reason": "no_task"}
	
	var elapsed = (Time.get_ticks_msec() / 1000.0) - task["actual_start_time"]
	var expected = task["expected_duration"]
	var ratio = elapsed / expected
	
	var deviation_delta: float = 0.0
	var reason: String = ""
	
	# Goldilocks scoring (from AgentHandoff)
	if ratio < 0.5:
		deviation_delta = 25.0
		reason = "TOO_FAST"
	elif ratio < 0.7:
		deviation_delta = 10.0
		reason = "FAST"
	elif ratio <= 1.4:
		deviation_delta = -5.0  # reward
		reason = "SAFE_PACE"
	elif ratio <= 2.0:
		deviation_delta = 5.0
		reason = "SLOW"
	else:
		deviation_delta = 20.0
		reason = "TOO_SLOW"
	
	task["actual_end_time"] = Time.get_ticks_msec() / 1000.0
	task["actual_duration"] = elapsed
	task["deviation_delta"] = deviation_delta
	task["completed"] = true
	
	completed_tasks.append(task)
	active_tasks.remove_at(current_task_index)
	
	# Log to audit system
	AuditSystem.log_task_completion(task, elapsed)
	
	# Assign next task
	if active_tasks.size() > 0:
		current_task_index = 0
		active_tasks[0]["actual_start_time"] = Time.get_ticks_msec() / 1000.0
		task_assigned.emit(active_tasks[0])
	else:
		current_task_index = -1
		all_tasks_completed.emit()
	
	var result = {"deviation_delta": deviation_delta, "reason": reason, "ratio": ratio}
	task_completed.emit(task, result)
	return result

func skip_to_next_task() -> void:
	# Used when player wants to abandon current task
	var task = get_current_task()
	if not task.is_empty():
		# Abandoning tasks is heavily penalized
		Blackboard.add_deviation(30.0, "task_abandoned")
		active_tasks.remove_at(current_task_index)
		
		if active_tasks.size() > 0:
			current_task_index = 0
			active_tasks[0]["actual_start_time"] = Time.get_ticks_msec() / 1000.0
			task_assigned.emit(active_tasks[0])
		else:
			current_task_index = -1

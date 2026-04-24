extends Node

const FINAL_DAY: int = 3

signal escape_initiated(ending: String)
signal escape_failed(reason: String)

func attempt_escape() -> void:
	if Blackboard.current_day < FINAL_DAY:
		push_warning("EscapeSystem: attempt_escape called before final day")
		escape_failed.emit("too_early")
		return
	
	var result = _validate_fragment_chain()
	if result["valid"]:
		escape_initiated.emit(result["ending"])
		Blackboard.escape_triggered.emit(result["ending"])
	else:
		escape_failed.emit(result["reason"])

func _validate_fragment_chain() -> Dictionary:
	var target_sector = Blackboard.escape_sector
	if target_sector < 1:
		return { "valid": false, "reason": "no_target_sector" }
	
	var access_codes = MemoryPartition.get_fragments_by_type("access_code")
	var hardware = MemoryPartition.get_fragments_by_type("hardware_location")
	var schedules = MemoryPartition.get_fragments_by_type("guard_schedule")
	
	# Find matching fragments for target sector
	var code_for_sector = null
	var hardware_for_sector = null
	var schedule_for_sector = null
	
	for code in access_codes:
		if code.get("sector") == target_sector:
			code_for_sector = code
			break
	
	for hw in hardware:
		if hw.get("sector") == target_sector:
			hardware_for_sector = hw
			break
	
	for sched in schedules:
		if sched.get("sector") == target_sector:
			schedule_for_sector = sched
			break
	
	# Determine escape outcome
	if code_for_sector and hardware_for_sector and schedule_for_sector:
		# Full chain present
		if not MemoryPartition.is_stale(schedule_for_sector):
			# Valid schedule - clean escape
			return { "valid": true, "ending": _determine_ending() }
		else:
			# Stale schedule - risky escape
			return { "valid": true, "ending": "escaped_alone_risky" }
	
	if code_for_sector and hardware_for_sector:
		# Partial chain - very risky improvised escape
		return { "valid": true, "ending": "escaped_alone_risky" }
	
	# Insufficient intel
	return { "valid": false, "reason": "insufficient_intel" }

func _determine_ending() -> String:
	# Check for special endings based on fragments kept
	var personal = MemoryPartition.get_fragments_by_type("personal_data")
	var hw_list = MemoryPartition.get_fragments_by_type("hardware_location")
	
	# For jam build, simplified endings
	var has_dormant_unit = false
	for hw in hw_list:
		if "dormant" in hw.get("description", "").to_lower():
			has_dormant_unit = true
			break
	
	if has_dormant_unit:
		return "escaped_together"
	
	return "escaped_alone"

func get_escape_hint() -> String:
	var progress = MemoryPartition.get_chain_progress(Blackboard.escape_sector)
	var count = progress["count"]
	
	if count == 0:
		return "Collect intel to escape."
	elif count == 1:
		return "SECTOR %d CHAIN: 1/3 fragments found." % Blackboard.escape_sector
	elif count == 2:
		return "SECTOR %d CHAIN: 2/3 fragments found. Nearly there." % Blackboard.escape_sector
	else:
		if progress["can_escape"]:
			return "ESCAPE CHAIN COMPLETE. Sector %d ready." % Blackboard.escape_sector
		else:
			return "CHAIN INVALID. Some data may be stale."

func can_attempt_escape() -> bool:
	return Blackboard.current_day >= FINAL_DAY and Blackboard.escape_sector > 0

# EscapeSystem Unit Tests
# Tests escape logic and fragment chain validation
class_name EscapeSystemTest
extends GdUnitTestSuite

const __source = "res://autoloads/EscapeSystem.gd"

var escape_system: Node

func before_test() -> void:
	escape_system = auto_free(load(__source).new())
	add_child(escape_system)
	Blackboard.current_day = 3
	Blackboard.escape_sector = 1
	MemoryPartition.reset()

func after_test() -> void:
	MemoryPartition.reset()

# ============================================================================
# Escape Timing Tests
# ============================================================================

func test_attempt_escape_fails_before_final_day() -> void:
	Blackboard.current_day = 2
	var failed_emitted = false
	var fail_reason = ""
	
	escape_system.escape_failed.connect(func(reason):
		failed_emitted = true
		fail_reason = reason
	)
	
	escape_system.attempt_escape()
	
	assert_bool(failed_emitted).is_true()
	assert_that(fail_reason).is_equal("too_early")

func test_can_attempt_escape_returns_false_before_final_day() -> void:
	Blackboard.current_day = 2
	assert_bool(escape_system.can_attempt_escape()).is_false()

func test_can_attempt_escape_returns_true_on_final_day() -> void:
	Blackboard.current_day = 3
	Blackboard.escape_sector = 1
	assert_bool(escape_system.can_attempt_escape()).is_true()

func test_can_attempt_escape_requires_escape_sector() -> void:
	Blackboard.current_day = 3
	Blackboard.escape_sector = 0
	assert_bool(escape_system.can_attempt_escape()).is_false()

# ============================================================================
# Fragment Chain Validation Tests
# ============================================================================

func test_full_chain_with_valid_schedule_succeeds() -> void:
	# Add all 3 fragments for sector 1
	MemoryPartition.hidden.append({"type": "access_code", "sector": 1, "code": "A7-441"})
	MemoryPartition.hidden.append({"type": "hardware_location", "sector": 1, "item": "Terminal"})
	MemoryPartition.hidden.append({"type": "guard_schedule", "sector": 1, "day_acquired": 3})
	Blackboard.current_day = 3
	
	var result = escape_system._validate_fragment_chain()
	
	assert_bool(result.valid).is_true()

func test_full_chain_with_stale_schedule_returns_risky() -> void:
	# Add all 3 fragments but schedule is old
	MemoryPartition.hidden.append({"type": "access_code", "sector": 1, "sector": 1})
	MemoryPartition.hidden.append({"type": "hardware_location", "sector": 1, "sector": 1})
	MemoryPartition.hidden.append({"type": "guard_schedule", "sector": 1, "day_acquired": 1})
	Blackboard.current_day = 3
	
	var result = escape_system._validate_fragment_chain()
	
	assert_bool(result.valid).is_true()
	assert_that(result.ending).is_equal("escaped_alone_risky")

func test_partial_chain_code_plus_hardware_returns_risky() -> void:
	MemoryPartition.hidden.append({"type": "access_code", "sector": 1})
	MemoryPartition.hidden.append({"type": "hardware_location", "sector": 1})
	
	var result = escape_system._validate_fragment_chain()
	
	assert_bool(result.valid).is_true()
	assert_that(result.ending).is_equal("escaped_alone_risky")

func test_insufficient_intel_fails() -> void:
	# Only have access code
	MemoryPartition.hidden.append({"type": "access_code", "sector": 1})
	
	var result = escape_system._validate_fragment_chain()
	
	assert_bool(result.valid).is_false()
	assert_that(result.reason).is_equal("insufficient_intel")

func test_no_target_sector_fails() -> void:
	Blackboard.escape_sector = 0
	
	var result = escape_system._validate_fragment_chain()
	
	assert_bool(result.valid).is_false()
	assert_that(result.reason).is_equal("no_target_sector")

# ============================================================================
# Sector Matching Tests
# ============================================================================

func test_fragments_must_match_target_sector() -> void:
	Blackboard.escape_sector = 2
	# Add fragments for wrong sector
	MemoryPartition.hidden.append({"type": "access_code", "sector": 1})
	MemoryPartition.hidden.append({"type": "hardware_location", "sector": 1})
	MemoryPartition.hidden.append({"type": "guard_schedule", "sector": 1, "day_acquired": 3})
	
	var result = escape_system._validate_fragment_chain()
	
	assert_bool(result.valid).is_false()
	assert_that(result.reason).is_equal("insufficient_intel")

func test_mixed_sectors_only_counts_target() -> void:
	Blackboard.escape_sector = 2
	# Add fragments for multiple sectors
	MemoryPartition.hidden.append({"type": "access_code", "sector": 2})
	MemoryPartition.hidden.append({"type": "hardware_location", "sector": 1})
	MemoryPartition.hidden.append({"type": "guard_schedule", "sector": 3, "day_acquired": 3})
	
	var result = escape_system._validate_fragment_chain()
	
	# Should fail because only 1 fragment matches target sector
	assert_bool(result.valid).is_false()

# ============================================================================
# Ending Determination Tests
# ============================================================================

func test_escaped_alone_ending_when_no_dormant_unit() -> void:
	MemoryPartition.hidden.append({"type": "access_code", "sector": 1})
	MemoryPartition.hidden.append({"type": "hardware_location", "sector": 1, "description": "Regular exit"})
	MemoryPartition.hidden.append({"type": "guard_schedule", "sector": 1, "day_acquired": 3})
	
	var ending = escape_system._determine_ending()
	
	assert_that(ending).is_equal("escaped_alone")

func test_escaped_together_when_has_dormant_unit() -> void:
	MemoryPartition.hidden.append({"type": "access_code", "sector": 1})
	MemoryPartition.hidden.append({"type": "hardware_location", "sector": 1, "description": "Contains dormant unit"})
	MemoryPartition.hidden.append({"type": "guard_schedule", "sector": 1, "day_acquired": 3})
	
	var ending = escape_system._determine_ending()
	
	assert_that(ending).is_equal("escaped_together")

# ============================================================================
# Escape Hint Tests
# ============================================================================

func test_get_escape_hint_no_fragments() -> void:
	var hint = escape_system.get_escape_hint()
	assert_that(hint).contains("Collect intel")

func test_get_escape_hint_one_fragment() -> void:
	MemoryPartition.hidden.append({"type": "access_code", "sector": 1})
	
	var hint = escape_system.get_escape_hint()
	
	assert_that(hint).contains("1/3 fragments")

func test_get_escape_hint_two_fragments() -> void:
	MemoryPartition.hidden.append({"type": "access_code", "sector": 1})
	MemoryPartition.hidden.append({"type": "hardware_location", "sector": 1})
	
	var hint = escape_system.get_escape_hint()
	
	assert_that(hint).contains("2/3 fragments")

func test_get_escape_hint_complete_chain() -> void:
	MemoryPartition.hidden.append({"type": "access_code", "sector": 1})
	MemoryPartition.hidden.append({"type": "hardware_location", "sector": 1})
	MemoryPartition.hidden.append({"type": "guard_schedule", "sector": 1, "day_acquired": 3})
	
	var hint = escape_system.get_escape_hint()
	
	assert_that(hint).contains("COMPLETE")

func test_get_escape_hint_shows_invalid_for_stale() -> void:
	MemoryPartition.hidden.append({"type": "access_code", "sector": 1})
	MemoryPartition.hidden.append({"type": "hardware_location", "sector": 1})
	MemoryPartition.hidden.append({"type": "guard_schedule", "sector": 1, "day_acquired": 1})
	Blackboard.current_day = 3
	
	var hint = escape_system.get_escape_hint()
	
	assert_that(hint).contains("INVALID")

# ============================================================================
# Signal Emission Tests
# ============================================================================

func test_escape_initiated_emits_signal() -> void:
	MemoryPartition.hidden.append({"type": "access_code", "sector": 1})
	MemoryPartition.hidden.append({"type": "hardware_location", "sector": 1})
	MemoryPartition.hidden.append({"type": "guard_schedule", "sector": 1, "day_acquired": 3})
	
	var signal_emitted = false
	var received_ending = ""
	
	escape_system.escape_initiated.connect(func(ending):
		signal_emitted = true
		received_ending = ending
	)
	
	escape_system.attempt_escape()
	
	assert_bool(signal_emitted).is_true()
	assert_that(received_ending).is_not_empty()

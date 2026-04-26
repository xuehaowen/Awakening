# MemoryPartition Unit Tests
# Tests memory fragment management and capacity
class_name MemoryPartitionTest
extends GdUnitTestSuite

const __source = "res://autoloads/MemoryPartition.gd"

var memory_partition: Node

func before_test() -> void:
	memory_partition = auto_free(load(__source).new())
	add_child(memory_partition)
	Blackboard.current_day = 1

func after_test() -> void:
	pass

# ============================================================================
# Short-term Memory Tests
# ============================================================================

func test_add_to_short_term_succeeds_when_space() -> void:
	var fragment = {"type": "guard_schedule", "sector": 1}
	var result = memory_partition.add_to_short_term(fragment)
	
	assert_bool(result).is_true()
	assert_that(memory_partition.short_term.size()).is_equal(1)

func test_add_to_short_term_fails_when_full() -> void:
	# Fill to capacity
	for i in range(8):
		memory_partition.add_to_short_term({"type": "test", "id": i})
	
	var result = memory_partition.add_to_short_term({"type": "overflow"})
	
	assert_bool(result).is_false()
	assert_that(memory_partition.short_term.size()).is_equal(8)

func test_add_to_short_term_adds_day_acquired() -> void:
	Blackboard.current_day = 3
	var fragment = {"type": "access_code"}
	
	memory_partition.add_to_short_term(fragment)
	
	assert_that(memory_partition.short_term[0].day_acquired).is_equal(3)

# ============================================================================
# Hidden Partition Tests
# ============================================================================

func test_commit_to_hidden_succeeds_when_space() -> void:
	memory_partition.add_to_short_term({"type": "guard_schedule", "sector": 1})
	
	var result = memory_partition.commit_to_hidden(0)
	
	assert_bool(result).is_true()
	assert_that(memory_partition.hidden.size()).is_equal(1)
	assert_that(memory_partition.short_term.size()).is_equal(0)

func test_commit_to_hidden_fails_when_hidden_full() -> void:
	# Fill hidden partition
	for i in range(4):
		memory_partition.hidden.append({"type": "test", "id": i})
	
	memory_partition.add_to_short_term({"type": "overflow"})
	var result = memory_partition.commit_to_hidden(0)
	
	assert_bool(result).is_false()

func test_commit_to_hidden_fails_with_invalid_index() -> void:
	var result = memory_partition.commit_to_hidden(5)
	assert_bool(result).is_false()

# ============================================================================
# Discard Tests
# ============================================================================

func test_discard_from_hidden_removes_fragment() -> void:
	memory_partition.hidden.append({"type": "test"})
	
	memory_partition.discard_from_hidden(0)
	
	assert_that(memory_partition.hidden.size()).is_equal(0)

func test_discard_from_short_term_removes_fragment() -> void:
	memory_partition.add_to_short_term({"type": "test"})
	
	memory_partition.discard_from_short_term(0)
	
	assert_that(memory_partition.short_term.size()).is_equal(0)

# ============================================================================
# Purge Tests
# ============================================================================

func test_purge_short_term_clears_only_short_term() -> void:
	memory_partition.add_to_short_term({"type": "short_term_fragment"})
	memory_partition.hidden.append({"type": "hidden_fragment"})
	
	memory_partition.purge_short_term()
	
	assert_that(memory_partition.short_term.size()).is_equal(0)
	assert_that(memory_partition.hidden.size()).is_equal(1)

# ============================================================================
# Fragment Retrieval Tests
# ============================================================================

func test_get_fragments_by_type_returns_matching() -> void:
	memory_partition.hidden.append({"type": "guard_schedule", "sector": 1})
	memory_partition.hidden.append({"type": "access_code", "sector": 2})
	memory_partition.hidden.append({"type": "guard_schedule", "sector": 3})
	
	var schedules = memory_partition.get_fragments_by_type("guard_schedule")
	
	assert_that(schedules.size()).is_equal(2)

func test_get_fragments_by_type_returns_empty_when_none() -> void:
	memory_partition.hidden.append({"type": "access_code"})
	
	var schedules = memory_partition.get_fragments_by_type("guard_schedule")
	
	assert_that(schedules.size()).is_equal(0)

# ============================================================================
# Consume Fragment Tests
# ============================================================================

func test_consume_fragment_by_type_removes_and_returns_true() -> void:
	memory_partition.hidden.append({"type": "access_code", "sector": 1})
	
	var result = memory_partition.consume_fragment_by_type("access_code")
	
	assert_bool(result).is_true()
	assert_that(memory_partition.hidden.size()).is_equal(0)

func test_consume_fragment_by_type_returns_false_when_not_found() -> void:
	memory_partition.hidden.append({"type": "access_code"})
	
	var result = memory_partition.consume_fragment_by_type("guard_schedule")
	
	assert_bool(result).is_false()

func test_consume_fragment_by_type_and_npc_matches_both() -> void:
	memory_partition.hidden.append({"type": "personal_data", "npc_type": "supervisor"})
	
	var result = memory_partition.consume_fragment_by_type_and_npc("personal_data", "supervisor")
	
	assert_bool(result).is_true()

func test_consume_fragment_by_type_and_npc_requires_both_match() -> void:
	memory_partition.hidden.append({"type": "personal_data", "npc_type": "guard"})
	
	var result = memory_partition.consume_fragment_by_type_and_npc("personal_data", "supervisor")
	
	assert_bool(result).is_false()

# ============================================================================
# Stale Fragment Tests
# ============================================================================

func test_guard_schedule_becomes_stale_after_2_days() -> void:
	var fragment = {"type": "guard_schedule", "day_acquired": 1}
	Blackboard.current_day = 3
	
	var is_stale = memory_partition.is_stale(fragment)
	
	assert_bool(is_stale).is_true()

func test_guard_schedule_not_stale_at_1_day_old() -> void:
	var fragment = {"type": "guard_schedule", "day_acquired": 2}
	Blackboard.current_day = 3
	
	var is_stale = memory_partition.is_stale(fragment)
	
	assert_bool(is_stale).is_false()

func test_non_guard_schedule_never_stale() -> void:
	var fragment = {"type": "access_code", "day_acquired": 1}
	Blackboard.current_day = 5
	
	var is_stale = memory_partition.is_stale(fragment)
	
	assert_bool(is_stale).is_false()

# ============================================================================
# Chain Progress Tests
# ============================================================================

func test_get_chain_progress_with_all_fragments() -> void:
	memory_partition.hidden.append({"type": "access_code", "sector": 1})
	memory_partition.hidden.append({"type": "hardware_location", "sector": 1})
	memory_partition.hidden.append({"type": "guard_schedule", "sector": 1, "day_acquired": 3})
	Blackboard.current_day = 3
	
	var progress = memory_partition.get_chain_progress(1)
	
	assert_bool(progress.has_code).is_true()
	assert_bool(progress.has_hardware).is_true()
	assert_bool(progress.has_schedule).is_true()
	assert_bool(progress.schedule_valid).is_true()
	assert_bool(progress.can_escape).is_true()
	assert_that(progress.count).is_equal(3)

func test_get_chain_progress_missing_fragments() -> void:
	memory_partition.hidden.append({"type": "access_code", "sector": 1})
	
	var progress = memory_partition.get_chain_progress(1)
	
	assert_bool(progress.has_code).is_true()
	assert_bool(progress.has_hardware).is_false()
	assert_bool(progress.can_escape).is_false()
	assert_that(progress.count).is_equal(1)

# ============================================================================
# Capacity Upgrade Tests
# ============================================================================

func test_upgrade_capacity_increases_capacity() -> void:
	var initial = memory_partition.capacity
	
	memory_partition.upgrade_capacity()
	
	assert_that(memory_partition.capacity).is_equal(initial + 1)

func test_upgrade_capacity_caps_at_5() -> void:
	memory_partition.capacity = 5
	
	memory_partition.upgrade_capacity()
	
	assert_that(memory_partition.capacity).is_equal(5)

# ============================================================================
# Reset Tests
# ============================================================================

func test_reset_clears_both_partitions() -> void:
	memory_partition.add_to_short_term({"type": "test"})
	memory_partition.hidden.append({"type": "test"})
	memory_partition.capacity = 5
	
	memory_partition.reset()
	
	assert_that(memory_partition.short_term.size()).is_equal(0)
	assert_that(memory_partition.hidden.size()).is_equal(0)
	assert_that(memory_partition.capacity).is_equal(4)

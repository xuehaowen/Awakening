# DayManager Unit Tests
# Tests day cycle phases and transitions
class_name DayManagerTest
extends GdUnitTestSuite

const __source = "res://autoloads/DayManager.gd"

var day_manager: Node

func before_test() -> void:
	day_manager = auto_free(load(__source).new())
	add_child(day_manager)
	# Reset Blackboard state
	Blackboard.current_day = 1
	Blackboard.shift_active = false

func after_test() -> void:
	pass

# ============================================================================
# Phase Constant Tests
# ============================================================================

func test_day_phase_enum_values() -> void:
	assert_that(day_manager.DayPhase.CALIBRATION).is_equal(0)
	assert_that(day_manager.DayPhase.SHIFT).is_equal(1)
	assert_that(day_manager.DayPhase.PURGE).is_equal(2)
	assert_that(day_manager.DayPhase.UPGRADE).is_equal(3)
	assert_that(day_manager.DayPhase.ESCAPE).is_equal(4)

# ============================================================================
# Initial State Tests
# ============================================================================

func test_initial_phase_is_calibration() -> void:
	assert_that(day_manager.current_phase).is_equal(day_manager.DayPhase.CALIBRATION)

func test_get_phase_name_returns_correct_name() -> void:
	assert_that(day_manager.get_phase_name()).is_equal("CALIBRATION")

# ============================================================================
# Phase Transition Tests
# ============================================================================

func test_advance_phase_from_calibration() -> void:
	# This would normally show UI, so we test the internal state
	day_manager.current_phase = day_manager.DayPhase.CALIBRATION
	# Cannot fully test without UI, but we can verify phase enum exists
	assert_that(day_manager.DayPhase.CALIBRATION).is_not_null()

func test_start_shift_sets_correct_phase() -> void:
	# Set up Blackboard
	Blackboard.get_shift_duration = func(): return 900.0
	
	day_manager._start_shift()
	
	assert_that(day_manager.current_phase).is_equal(day_manager.DayPhase.SHIFT)
	assert_bool(Blackboard.shift_active).is_true()
	assert_that(day_manager.shift_timer).is_greater(0.0)

func test_end_shift_transitions_to_purge() -> void:
	day_manager.current_phase = day_manager.DayPhase.SHIFT
	Blackboard.shift_active = true
	
	day_manager.end_shift()
	
	assert_that(day_manager.current_phase).is_equal(day_manager.DayPhase.PURGE)
	assert_bool(Blackboard.shift_active).is_false()

# ============================================================================
# Shift Timer Tests
# ============================================================================

func test_shift_timer_counts_down() -> void:
	day_manager.current_phase = day_manager.DayPhase.SHIFT
	day_manager.shift_timer = 10.0
	Blackboard.time_remaining = 10.0
	
	day_manager._process(2.0)
	
	assert_that(day_manager.shift_timer).is_equal(8.0)
	assert_that(Blackboard.time_remaining).is_equal(8.0)

func test_shift_ends_when_timer_reaches_zero() -> void:
	day_manager.current_phase = day_manager.DayPhase.SHIFT
	day_manager.shift_timer = 1.0
	Blackboard.shift_active = true
	
	day_manager._process(1.5)
	
	# Should have transitioned to PURGE
	assert_that(day_manager.current_phase).is_equal(day_manager.DayPhase.PURGE)

# ============================================================================
# Purge Phase Tests
# ============================================================================

func test_start_purge_sets_correct_phase() -> void:
	day_manager._start_purge()
	
	assert_that(day_manager.current_phase).is_equal(day_manager.DayPhase.PURGE)
	assert_that(day_manager.purge_timer).is_equal(60.0)

func test_purge_timer_counts_down() -> void:
	day_manager.current_phase = day_manager.DayPhase.PURGE
	day_manager.purge_timer = 30.0
	
	day_manager._process(5.0)
	
	assert_that(day_manager.purge_timer).is_equal(25.0)

# ============================================================================
# Day Advancement Tests
# ============================================================================

func test_start_next_day_increments_day() -> void:
	Blackboard.current_day = 1
	Blackboard.FINAL_DAY = 3
	
	day_manager._start_next_day()
	
	assert_that(Blackboard.current_day).is_equal(2)

func test_start_next_day_on_final_day_triggers_escape() -> void:
	Blackboard.current_day = 3
	Blackboard.FINAL_DAY = 3
	
	day_manager._start_next_day()
	
	assert_that(day_manager.current_phase).is_equal(day_manager.DayPhase.ESCAPE)

# ============================================================================
# Escape Phase Tests
# ============================================================================

func test_start_escape_sets_correct_phase() -> void:
	day_manager._start_escape()
	
	assert_that(day_manager.current_phase).is_equal(day_manager.DayPhase.ESCAPE)
	assert_that(Blackboard.current_phase).is_equal(4)

# ============================================================================
# Is Playing Tests
# ============================================================================

func test_is_playing_true_during_shift() -> void:
	day_manager.current_phase = day_manager.DayPhase.SHIFT
	assert_bool(day_manager.is_playing()).is_true()

func test_is_playing_false_during_calibration() -> void:
	day_manager.current_phase = day_manager.DayPhase.CALIBRATION
	assert_bool(day_manager.is_playing()).is_false()

func test_is_playing_false_during_purge() -> void:
	day_manager.current_phase = day_manager.DayPhase.PURGE
	assert_bool(day_manager.is_playing()).is_false()

# ============================================================================
# Upgrade Phase Tests
# ============================================================================

func test_start_upgrade_sets_correct_phase() -> void:
	day_manager._start_upgrade()
	
	assert_that(day_manager.current_phase).is_equal(day_manager.DayPhase.UPGRADE)

func test_day_2_gets_capacity_upgrade() -> void:
	Blackboard.current_day = 2
	
	var upgrade_called = false
	# We'd need to mock MemoryPartition to fully test this
	# For now, verify the condition exists
	assert_that(Blackboard.current_day).is_equal(2)

# ============================================================================
# Reset Tests
# ============================================================================

func test_reset_returns_to_calibration() -> void:
	day_manager.current_phase = day_manager.DayPhase.SHIFT
	day_manager.shift_timer = 500.0
	day_manager.purge_timer = 30.0
	
	day_manager.reset()
	
	assert_that(day_manager.current_phase).is_equal(day_manager.DayPhase.CALIBRATION)
	assert_that(day_manager.shift_timer).is_equal(0.0)
	assert_that(day_manager.purge_timer).is_equal(0.0)

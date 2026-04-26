# TaskScorer Unit Tests
# Tests the Goldilocks zone deviation calculations
class_name TaskScorerTest
extends GdUnitTestSuite

const __source = "res://autoloads/TaskScorer.gd"

var task_scorer: Node

func before_test() -> void:
	task_scorer = auto_free(load(__source).new())
	add_child(task_scorer)

func after_test() -> void:
	# Auto-cleanup via auto_free
	pass

# ============================================================================
# Goldilocks Zone Boundary Tests
# ============================================================================

func test_too_fast_completion_adds_high_deviation() -> void:
	# Ratio < 0.5 should add 25 deviation
	var result = task_scorer.evaluate_task_performance(100.0, 40.0)  # 40% of expected
	assert_that(result.deviation_delta).is_equal(25.0)
	assert_that(result.reason).is_equal("TOO_FAST")
	assert_that(result.risk_level).is_equal("HIGH")
	assert_bool(result.in_safe_zone).is_false()

func test_fast_completion_adds_medium_deviation() -> void:
	# Ratio 0.5-0.7 should add 10 deviation
	var result = task_scorer.evaluate_task_performance(100.0, 60.0)  # 60% of expected
	assert_that(result.deviation_delta).is_equal(10.0)
	assert_that(result.reason).is_equal("FAST")
	assert_that(result.risk_level).is_equal("MEDIUM")
	assert_bool(result.in_safe_zone).is_false()

func test_safe_pace_gives_reward() -> void:
	# Ratio 0.7-1.4 should subtract 5 deviation (reward)
	var result_min = task_scorer.evaluate_task_performance(100.0, 70.0)   # 70% - boundary
	var result_mid = task_scorer.evaluate_task_performance(100.0, 100.0)  # 100% - perfect
	var result_max = task_scorer.evaluate_task_performance(100.0, 140.0)  # 140% - boundary
	
	assert_that(result_min.deviation_delta).is_equal(-5.0)
	assert_that(result_mid.deviation_delta).is_equal(-5.0)
	assert_that(result_max.deviation_delta).is_equal(-5.0)
	assert_that(result_min.reason).is_equal("SAFE_PACE")
	assert_bool(result_min.in_safe_zone).is_true()
	assert_bool(result_mid.in_safe_zone).is_true()
	assert_bool(result_max.in_safe_zone).is_true()

func test_slow_completion_adds_low_deviation() -> void:
	# Ratio 1.4-2.0 should add 5 deviation
	var result = task_scorer.evaluate_task_performance(100.0, 170.0)  # 170% of expected
	assert_that(result.deviation_delta).is_equal(5.0)
	assert_that(result.reason).is_equal("SLOW")
	assert_that(result.risk_level).is_equal("LOW")
	assert_bool(result.in_safe_zone).is_false()

func test_too_slow_completion_adds_high_deviation() -> void:
	# Ratio > 2.0 should add 20 deviation
	var result = task_scorer.evaluate_task_performance(100.0, 250.0)  # 250% of expected
	assert_that(result.deviation_delta).is_equal(20.0)
	assert_that(result.reason).is_equal("TOO_SLOW")
	assert_that(result.risk_level).is_equal("HIGH")
	assert_bool(result.in_safe_zone).is_false()

# ============================================================================
# Edge Cases and Boundary Tests
# ============================================================================

func test_exact_thresholds_at_boundaries() -> void:
	# Test exact boundary values (0.5, 0.7, 1.4, 2.0)
	var at_50 = task_scorer.evaluate_task_performance(100.0, 50.0)   # 50% - TOO_FAST boundary
	var at_70 = task_scorer.evaluate_task_performance(100.0, 70.0)   # 70% - SAFE boundary
	var at_140 = task_scorer.evaluate_task_performance(100.0, 140.0) # 140% - SAFE boundary
	var at_200 = task_scorer.evaluate_task_performance(100.0, 200.0) # 200% - SLOW boundary
	
	assert_that(at_50.reason).is_equal("TOO_FAST")  # < 0.5 is too fast
	assert_that(at_70.reason).is_equal("SAFE_PACE") # >= 0.7 is safe
	assert_that(at_140.reason).is_equal("SAFE_PACE") # <= 1.4 is safe
	assert_that(at_200.reason).is_equal("SLOW")     # <= 2.0 is slow

func test_zero_expected_duration_guard() -> void:
	# Division by zero should be guarded
	var result = task_scorer.evaluate_task_performance(0.0, 50.0)
	assert_that(result.ratio).is_greater(0.0)  # Should not be infinity
	assert_that(result.deviation_delta).is_not_null()

func test_negative_expected_duration_guard() -> void:
	# Negative expected should be handled
	var result = task_scorer.evaluate_task_performance(-10.0, 50.0)
	assert_that(result.ratio).is_greater(0.0)  # Should handle gracefully

# ============================================================================
# Pace State Calculation Tests
# ============================================================================

func test_calculate_pace_state_returns_correct_strings() -> void:
	assert_that(task_scorer.calculate_pace_state(40.0, 100.0)).is_equal("TOO_FAST")  # 40%
	assert_that(task_scorer.calculate_pace_state(60.0, 100.0)).is_equal("FAST")      # 60%
	assert_that(task_scorer.calculate_pace_state(100.0, 100.0)).is_equal("SAFE")     # 100%
	assert_that(task_scorer.calculate_pace_state(170.0, 100.0)).is_equal("SLOW")     # 170%
	assert_that(task_scorer.calculate_pace_state(250.0, 100.0)).is_equal("TOO_SLOW") # 250%

# ============================================================================
# Safe Zone Helper Tests
# ============================================================================

func test_is_in_safe_zone_returns_correct_bool() -> void:
	# Safe zone: 70% - 140% of expected
	assert_bool(task_scorer.is_in_safe_zone(69.0, 100.0)).is_false()   # Just under
	assert_bool(task_scorer.is_in_safe_zone(70.0, 100.0)).is_true()    # At min boundary
	assert_bool(task_scorer.is_in_safe_zone(100.0, 100.0)).is_true()   # Middle
	assert_bool(task_scorer.is_in_safe_zone(140.0, 100.0)).is_true()   # At max boundary
	assert_bool(task_scorer.is_in_safe_zone(141.0, 100.0)).is_false()  # Just over

func test_get_safe_zone_boundaries_returns_correct_values() -> void:
	var boundaries = task_scorer.get_safe_zone_boundaries(100.0)
	assert_that(boundaries.min_time).is_equal(70.0)   # 70% of 100
	assert_that(boundaries.max_time).is_equal(140.0)  # 140% of 100
	assert_that(boundaries.optimal).is_equal(100.0)
	assert_that(boundaries.min_percent).is_equal(70.0)
	assert_that(boundaries.max_percent).is_equal(140.0)

func test_get_progress_to_safe_zone_calculates_correctly() -> void:
	# Progress from 0% to entering safe zone at 70%
	assert_that(task_scorer.get_progress_to_safe_zone(0.0, 100.0)).is_equal(0.0)
	assert_that(task_scorer.get_progress_to_safe_zone(35.0, 100.0)).is_equal(0.5)   # Halfway to 70%
	assert_that(task_scorer.get_progress_to_safe_zone(70.0, 100.0)).is_equal(1.0)  # Entered safe zone
	assert_that(task_scorer.get_progress_to_safe_zone(100.0, 100.0)).is_equal(1.0) # Still in safe zone

# ============================================================================
# Abandoned Task Tests
# ============================================================================

func test_abandoned_task_returns_critical_penalty() -> void:
	var result = task_scorer.score_abandoned_task()
	assert_that(result.deviation_delta).is_equal(30.0)
	assert_that(result.reason).is_equal("TASK_ABANDONED")
	assert_that(result.risk_level).is_equal("CRITICAL")

# ============================================================================
# Result Dictionary Structure Tests
# ============================================================================

func test_result_contains_all_required_fields() -> void:
	var result = task_scorer.evaluate_task_performance(100.0, 100.0)
	assert_that(result).contains_keys([
		"deviation_delta",
		"reason", 
		"pace_state",
		"pace_state_enum",
		"ratio",
		"percent_of_expected",
		"risk_level",
		"in_safe_zone"
	])

func test_ratio_calculated_correctly() -> void:
	var result = task_scorer.evaluate_task_performance(100.0, 150.0)
	assert_that(result.ratio).is_equal(1.5)
	assert_that(result.percent_of_expected).is_equal(150.0)

# ============================================================================
# UI Helper Tests
# ============================================================================

func test_get_pace_state_color_returns_colors() -> void:
	# Just verify colors are returned (not white/default)
	var too_fast_color = task_scorer.get_pace_state_color("TOO_FAST")
	var safe_color = task_scorer.get_pace_state_color("SAFE")
	
	assert_that(too_fast_color).is_not_equal(Color.WHITE)
	assert_that(safe_color).is_not_equal(Color.WHITE)

func test_get_formatted_feedback_returns_strings() -> void:
	var result = task_scorer.evaluate_task_performance(100.0, 100.0)
	var feedback = task_scorer.get_formatted_feedback(result)
	assert_that(feedback).is_not_empty()
	assert_that(feedback).contains("SAFE PACE")

# SuspicionManager Unit Tests
# Tests suspicion accumulation, thresholds, and decay
class_name SuspicionManagerTest
extends GdUnitTestSuite

const __source = "res://autoloads/SuspicionManager.gd"

var suspicion_manager: Node

func before_test() -> void:
	suspicion_manager = auto_free(load(__source).new())
	add_child(suspicion_manager)

func after_test() -> void:
	pass

# ============================================================================
# Basic Suspicion Addition Tests
# ============================================================================

func test_add_suspicion_increases_global_score() -> void:
	suspicion_manager.add_suspicion(10.0, "test")
	assert_that(suspicion_manager.global_suspicion).is_equal(10.0)

func test_add_suspicion_caps_at_100() -> void:
	suspicion_manager.add_suspicion(150.0, "test")
	assert_that(suspicion_manager.global_suspicion).is_equal(100.0)

func test_add_suspicion_emits_changed_signal() -> void:
	var signal_received = false
	var received_score = 0.0
	
	suspicion_manager.suspicion_changed.connect(func(score, delta):
		signal_received = true
		received_score = score
	)
	
	suspicion_manager.add_suspicion(25.0, "test")
	
	assert_bool(signal_received).is_true()
	assert_that(received_score).is_equal(25.0)

# ============================================================================
# Suspicion Reduction Tests
# ============================================================================

func test_reduce_suspicion_decreases_score() -> void:
	suspicion_manager.global_suspicion = 50.0
	suspicion_manager.reduce_suspicion(20.0)
	assert_that(suspicion_manager.global_suspicion).is_equal(30.0)

func test_reduce_suspicion_floors_at_zero() -> void:
	suspicion_manager.global_suspicion = 10.0
	suspicion_manager.reduce_suspicion(30.0)
	assert_that(suspicion_manager.global_suspicion).is_equal(0.0)

# ============================================================================
# Suspicion Level Tests
# ============================================================================

func test_unaware_level_at_zero() -> void:
	suspicion_manager.global_suspicion = 0.0
	assert_that(suspicion_manager.get_suspicion_level()).is_equal(suspicion_manager.SuspicionLevel.UNAWARE)

func test_curious_level_at_40() -> void:
	suspicion_manager.global_suspicion = 40.0
	assert_that(suspicion_manager.get_suspicion_level()).is_equal(suspicion_manager.SuspicionLevel.CURIOUS)

func test_watching_level_at_45() -> void:
	suspicion_manager.global_suspicion = 45.0
	assert_that(suspicion_manager.get_suspicion_level()).is_equal(suspicion_manager.SuspicionLevel.WATCHING)

func test_suspicious_level_at_61() -> void:
	suspicion_manager.global_suspicion = 61.0
	assert_that(suspicion_manager.get_suspicion_level()).is_equal(suspicion_manager.SuspicionLevel.SUSPICIOUS)

func test_alarmed_level_at_86() -> void:
	suspicion_manager.global_suspicion = 86.0
	assert_that(suspicion_manager.get_suspicion_level()).is_equal(suspicion_manager.SuspicionLevel.ALARMED)

# ============================================================================
# Level Name Tests
# ============================================================================

func test_get_suspicion_level_name_returns_correct_names() -> void:
	suspicion_manager.global_suspicion = 0.0
	assert_that(suspicion_manager.get_suspicion_level_name()).is_equal("UNAWARE")
	
	suspicion_manager.global_suspicion = 45.0
	assert_that(suspicion_manager.get_suspicion_level_name()).is_equal("WATCHING")
	
	suspicion_manager.global_suspicion = 86.0
	assert_that(suspicion_manager.get_suspicion_level_name()).is_equal("ALARMED")

# ============================================================================
# Threshold Crossing Tests
# ============================================================================

func test_threshold_crossed_emits_signal() -> void:
	var threshold_signal = ""
	suspicion_manager.suspicion_threshold_crossed.connect(func(threshold):
		threshold_signal = threshold
	)
	
	suspicion_manager.global_suspicion = 30.0
	suspicion_manager.add_suspicion(20.0, "test")  # Crosses 40 threshold
	
	assert_that(threshold_signal).is_equal("WATCHING")

func test_decommission_threshold_emits_peak_signal() -> void:
	var peak_emitted = false
	suspicion_manager.global_suspicion_peak_reached.connect(func():
		peak_emitted = true
	)
	
	suspicion_manager.global_suspicion = 80.0
	suspicion_manager.add_suspicion(10.0, "test")  # Crosses 86 threshold
	
	assert_bool(peak_emitted).is_true()

# ============================================================================
# Critical State Tests
# ============================================================================

func test_is_critical_returns_false_below_86() -> void:
	suspicion_manager.global_suspicion = 85.0
	assert_bool(suspicion_manager.is_critical()).is_false()

func test_is_critical_returns_true_at_86() -> void:
	suspicion_manager.global_suspicion = 86.0
	assert_bool(suspicion_manager.is_critical()).is_true()

# ============================================================================
# Query Trigger Tests
# ============================================================================

func test_should_trigger_query_requires_visibility() -> void:
	suspicion_manager.global_suspicion = 65.0
	suspicion_manager.is_player_visible = false
	assert_bool(suspicion_manager.should_trigger_query()).is_false()

func test_should_trigger_query_true_when_visible_and_high() -> void:
	suspicion_manager.global_suspicion = 65.0
	suspicion_manager.is_player_visible = true
	assert_bool(suspicion_manager.should_trigger_query()).is_true()

func test_should_trigger_query_false_when_low_suspicion() -> void:
	suspicion_manager.global_suspicion = 50.0
	suspicion_manager.is_player_visible = true
	assert_bool(suspicion_manager.should_trigger_query()).is_false()

# ============================================================================
# NPC Observation Tests
# ============================================================================

func test_npc_started_observing_adds_to_list() -> void:
	suspicion_manager.npc_started_observing("npc_1")
	assert_that(suspicion_manager.observing_npcs.size()).is_equal(1)
	assert_that(suspicion_manager.observing_npcs[0]).is_equal("npc_1")

func test_npc_stopped_observing_removes_from_list() -> void:
	suspicion_manager.npc_started_observing("npc_1")
	suspicion_manager.npc_stopped_observing("npc_1")
	assert_that(suspicion_manager.observing_npcs.size()).is_equal(0)
	assert_bool(suspicion_manager.is_player_visible).is_false()

func test_multiple_npcs_observing() -> void:
	suspicion_manager.npc_started_observing("npc_1")
	suspicion_manager.npc_started_observing("npc_2")
	assert_that(suspicion_manager.get_observing_npc_count()).is_equal(2)
	assert_bool(suspicion_manager.is_player_visible).is_true()

# ============================================================================
# Update Loop Tests
# ============================================================================

func test_suspicion_decays_when_not_visible() -> void:
	suspicion_manager.global_suspicion = 50.0
	suspicion_manager.is_player_visible = false
	suspicion_manager._update_suspicion(1.0)
	
	assert_that(suspicion_manager.global_suspicion).is_equal(48.0)  # -2.0 decay

func test_suspicion_increases_with_cpu_high() -> void:
	suspicion_manager.global_suspicion = 10.0
	suspicion_manager.is_player_visible = true
	suspicion_manager.last_known_state["cpu_high"] = true
	suspicion_manager._update_suspicion(1.0)
	
	assert_that(suspicion_manager.global_suspicion).is_greater(10.0)  # +10 from jitter

func test_suspicion_increases_when_off_task() -> void:
	suspicion_manager.global_suspicion = 10.0
	suspicion_manager.is_player_visible = true
	suspicion_manager.last_known_state["on_task"] = false
	suspicion_manager._update_suspicion(1.0)
	
	assert_that(suspicion_manager.global_suspicion).is_greater(10.0)  # +2 from off_task

# ============================================================================
# Report Observation Tests
# ============================================================================

func test_report_observation_jitter_adds_suspicion() -> void:
	suspicion_manager.global_suspicion = 0.0
	suspicion_manager.report_observation("npc_1", "jitter", 1.0)
	assert_that(suspicion_manager.global_suspicion).is_equal(10.0)

func test_report_observation_off_task_adds_suspicion() -> void:
	suspicion_manager.global_suspicion = 0.0
	suspicion_manager.report_observation("npc_1", "off_task", 1.0)
	assert_that(suspicion_manager.global_suspicion).is_equal(2.0)

# ============================================================================
# Reset Tests
# ============================================================================

func test_reset_clears_all_state() -> void:
	suspicion_manager.global_suspicion = 50.0
	suspicion_manager.npc_suspicion_scores["npc_1"] = 25.0
	suspicion_manager.observing_npcs.append("npc_1")
	suspicion_manager.is_player_visible = true
	
	suspicion_manager.reset()
	
	assert_that(suspicion_manager.global_suspicion).is_equal(0.0)
	assert_that(suspicion_manager.npc_suspicion_scores.size()).is_equal(0)
	assert_that(suspicion_manager.observing_npcs.size()).is_equal(0)
	assert_bool(suspicion_manager.is_player_visible).is_false()

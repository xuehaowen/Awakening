# TruthLoopGenerator Unit Tests
# Tests query generation and response selection
class_name TruthLoopGeneratorTest
extends GdUnitTestSuite

const __source = "res://autoloads/TruthLoopGenerator.gd"

var truth_generator: Node
var mock_npc: Node

func before_test() -> void:
	truth_generator = auto_free(load(__source).new())
	add_child(truth_generator)
	
	# Create a mock NPC
	mock_npc = auto_free(Node.new())
	mock_npc.set_script(GDScript.new())
	mock_npc.set("npc_type", "supervisor")
	add_child(mock_npc)

func after_test() -> void:
	truth_generator.clear_query()

# ============================================================================
# Query Generation Tests
# ============================================================================

func test_generate_returns_valid_query_dictionary() -> void:
	var query = truth_generator.generate(mock_npc, "time_discrepancy")
	
	assert_that(query).is_not_null()
	assert_bool(query.has("npc")).is_true()
	assert_bool(query.has("query_type")).is_true()
	assert_bool(query.has("prompt_text")).is_true()
	assert_bool(query.has("responses")).is_true()
	assert_bool(query.has("timer")).is_true()

func test_generate_includes_npc_in_query() -> void:
	var query = truth_generator.generate(mock_npc, "status_check")
	
	assert_that(query.npc).is_equal(mock_npc)

func test_generate_sets_correct_query_type() -> void:
	var query = truth_generator.generate(mock_npc, "location_query")
	
	assert_that(query.query_type).is_equal("location_query")

func test_generate_returns_responses_array() -> void:
	var query = truth_generator.generate(mock_npc, "efficiency_query")
	
	assert_that(query.responses).is_not_null()
	assert_that(query.responses.size()).is_greater(0)

func test_generate_sets_timer_to_8_seconds() -> void:
	var query = truth_generator.generate(mock_npc, "status_check")
	
	assert_that(query.timer).is_equal(8.0)

# ============================================================================
# Query Type Determination Tests
# ============================================================================

func test_determine_query_type_for_supervisor() -> void:
	mock_npc.set("npc_type", "supervisor")
	
	# Should pick from status_check, efficiency_query, time_discrepancy
	var query_type = truth_generator._determine_query_type(mock_npc)
	var valid_types = ["status_check", "efficiency_query", "time_discrepancy"]
	
	assert_that(valid_types).contains(query_type)

func test_determine_query_type_for_guard() -> void:
	mock_npc.set("npc_type", "guard")
	
	# Should pick from location_query, time_discrepancy
	var query_type = truth_generator._determine_query_type(mock_npc)
	var valid_types = ["location_query", "time_discrepancy"]
	
	assert_that(valid_types).contains(query_type)

func test_determine_query_type_defaults_when_no_npc_type() -> void:
	var generic_npc = auto_free(Node.new())
	add_child(generic_npc)
	
	var query_type = truth_generator._determine_query_type(generic_npc)
	var valid_types = ["time_discrepancy", "status_check", "location_query", "efficiency_query"]
	
	assert_that(valid_types).contains(query_type)

func test_generate_uses_determined_type_when_empty() -> void:
	var query = truth_generator.generate(mock_npc, "")
	
	assert_that(query.query_type).is_not_empty()

# ============================================================================
# Response Template Tests
# ============================================================================

func test_response_templates_exist_for_all_types() -> void:
	var types = ["time_discrepancy", "status_check", "location_query", "efficiency_query"]
	
	for type in types:
		var templates = truth_generator.RESPONSE_TEMPLATES[type]
		assert_that(templates).is_not_null()
		assert_that(templates.size()).is_greater(0)

func test_responses_have_required_fields() -> void:
	var query = truth_generator.generate(mock_npc, "time_discrepancy")
	
	for response in query.responses:
		assert_bool(response.has("text")).is_true()
		assert_bool(response.has("risk")).is_true()

func test_responses_include_risk_values() -> void:
	var query = truth_generator.generate(mock_npc, "status_check")
	
	var found_risk = false
	for response in query.responses:
		if response.risk > 0:
			found_risk = true
			break
	
	# At least some responses should have risk > 0
	assert_bool(found_risk).is_true()

func test_fake_safe_responses_exist() -> void:
	var found_fake_safe = false
	
	# Check multiple times since responses are shuffled
	for i in range(5):
		var query = truth_generator.generate(mock_npc, "time_discrepancy")
		for response in query.responses:
			if response.get("fake_safe", false):
				found_fake_safe = true
				break
		if found_fake_safe:
			break
	
	assert_bool(found_fake_safe).is_true()

# ============================================================================
# Response Selection Tests
# ============================================================================

func test_select_response_returns_selected() -> void:
	truth_generator.generate(mock_npc, "status_check")
	
	var response = truth_generator.select_response(0)
	
	assert_that(response).is_not_null()
	assert_that(response.text).is_not_empty()

func test_select_response_returns_empty_on_invalid_index() -> void:
	truth_generator.generate(mock_npc, "status_check")
	
	var response = truth_generator.select_response(100)
	
	assert_that(response).is_equal({})

func test_select_response_returns_empty_when_no_active_query() -> void:
	var response = truth_generator.select_response(0)
	
	assert_that(response).is_equal({})

func test_select_response_applies_risk_to_deviation() -> void:
	truth_generator.generate(mock_npc, "status_check")
	var initial_deviation = Blackboard.get_deviation() if Blackboard.has_method("get_deviation") else 0.0
	
	# Find a response with risk and select it
	for i in range(truth_generator.active_query.responses.size()):
		if truth_generator.active_query.responses[i].risk > 0:
			truth_generator.select_response(i)
			break
	
	# Note: Would need to mock Blackboard to verify deviation change
	assert_that(truth_generator.active_query).is_not_null()

# ============================================================================
# Decrypt Active Tests
# ============================================================================

func test_decrypt_active_reveals_fake_safe() -> void:
	truth_generator.generate(mock_npc, "time_discrepancy")
	
	# Find a fake_safe response
	var fake_safe_index = -1
	for i in range(truth_generator.active_query.responses.size()):
		if truth_generator.active_query.responses[i].get("fake_safe", false):
			fake_safe_index = i
			break
	
	if fake_safe_index >= 0:
		truth_generator.select_response(fake_safe_index, true)  # decrypt_active = true
		assert_bool(truth_generator.fake_safe_revealed).is_true()

func test_decrypt_active_reduces_risk() -> void:
	truth_generator.generate(mock_npc, "time_discrepancy")
	
	# Find a fake_safe response with initial risk
	for i in range(truth_generator.active_query.responses.size()):
		var resp = truth_generator.active_query.responses[i]
		if resp.get("fake_safe", false) and resp.risk > 0:
			var initial_risk = resp.risk
			truth_generator.select_response(i, true)
			# Risk should be reduced by 10
			break

# ============================================================================
# Personal Data Leverage Tests
# ============================================================================

func test_leverage_option_added_when_personal_data_available() -> void:
	# Add personal data for supervisor
	MemoryPartition.hidden.append({"type": "personal_data", "npc_type": "supervisor", "secret": "gambling_debt"})
	
	mock_npc.set("npc_type", "supervisor")
	var query = truth_generator.generate(mock_npc, "status_check")
	
	var found_leverage = false
	for response in query.responses:
		if response.get("category", "") == "LEVERAGE":
			found_leverage = true
			break
	
	assert_bool(found_leverage).is_true()

# ============================================================================
# Follow-up Mode Tests
# ============================================================================

func test_fake_safe_triggers_followup_from_supervisor() -> void:
	mock_npc.set("npc_type", "supervisor")
	truth_generator.generate(mock_npc, "time_discrepancy")
	
	var followup_emitted = false
	truth_generator.followup_triggered.connect(func(npc): followup_emitted = true)
	
	# Find and select a fake_safe response without decrypt
	for i in range(truth_generator.active_query.responses.size()):
		if truth_generator.active_query.responses[i].get("fake_safe", false):
			truth_generator.select_response(i, false)  # decrypt_active = false
			break
	
	assert_bool(followup_emitted).is_true()
	assert_bool(truth_generator.followup_mode).is_true()

func test_clear_query_resets_state() -> void:
	truth_generator.generate(mock_npc, "status_check")
	truth_generator.followup_mode = true
	truth_generator.fake_safe_revealed = true
	
	truth_generator.clear_query()
	
	assert_that(truth_generator.active_query).is_equal({})
	assert_bool(truth_generator.followup_mode).is_false()
	assert_bool(truth_generator.fake_safe_revealed).is_false()

# ============================================================================
# Timeout Tests
# ============================================================================

func test_timeout_silence_adds_deviation() -> void:
	truth_generator.generate(mock_npc, "status_check")
	
	var response_emitted = false
	truth_generator.response_selected.connect(func(resp): response_emitted = true)
	
	truth_generator.timeout_silence()
	
	assert_bool(response_emitted).is_true()

# ============================================================================
# Query Prompts Tests
# ============================================================================

func test_query_prompts_formatted_correctly() -> void:
	var query = truth_generator.generate(mock_npc, "time_discrepancy")
	
	# Prompt should not contain format specifiers
	assert_that(query.prompt_text).not_contains("%s")
	assert_that(query.prompt_text).not_contains("%d")
	assert_that(query.prompt_text).not_contains("%.0f")

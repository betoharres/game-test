extends "res://tests/test_case.gd"


func test_lean_actions_use_q_and_e_keys() -> void:
	var left_events := InputMap.action_get_events("lean_left")
	var right_events := InputMap.action_get_events("lean_right")

	assert_equal(left_events.size(), 1)
	assert_equal(right_events.size(), 1)
	assert_equal((left_events[0] as InputEventKey).physical_keycode, KEY_Q)
	assert_equal((right_events[0] as InputEventKey).physical_keycode, KEY_E)

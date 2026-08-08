extends "res://tests/test_case.gd"

const TestCase := preload("res://tests/test_case.gd")


func test_basic_assertions_pass() -> void:
	assert_true(true)
	assert_false(false)
	assert_equal(2 + 2, 4)
	assert_not_equal("player", "enemy")
	assert_null(null)
	assert_not_null(self)


func test_failed_assertion_is_recorded() -> void:
	var test_case := TestCase.new()
	test_case.assert_true(false, "Expected failure")
	assert_equal(test_case.get_failures(), ["Expected failure"])

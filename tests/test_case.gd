extends RefCounted

var _failures: Array[String] = []


func before_each() -> void:
	pass


func after_each() -> void:
	pass


func assert_true(condition: bool, message: String = "") -> void:
	if not condition:
		_record_failure(message if not message.is_empty() else "Expected value to be true.")


func assert_false(condition: bool, message: String = "") -> void:
	if condition:
		_record_failure(message if not message.is_empty() else "Expected value to be false.")


func assert_equal(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual != expected:
		_record_failure(
			message if not message.is_empty()
			else "Expected <%s>, but got <%s>." % [str(expected), str(actual)]
		)


func assert_not_equal(actual: Variant, expected: Variant, message: String = "") -> void:
	if actual == expected:
		_record_failure(
			message if not message.is_empty()
			else "Expected values to differ, but both were <%s>." % str(actual)
		)


func assert_null(value: Variant, message: String = "") -> void:
	if value != null:
		_record_failure(
			message if not message.is_empty()
			else "Expected <null>, but got <%s>." % str(value)
		)


func assert_not_null(value: Variant, message: String = "") -> void:
	if value == null:
		_record_failure(message if not message.is_empty() else "Expected a non-null value.")


func get_failures() -> Array[String]:
	return _failures


func reset_assertions() -> void:
	_failures.clear()


func _record_failure(message: String) -> void:
	_failures.append(message)

extends SceneTree

const TEST_DIRECTORY := "res://tests"
const TEST_FILE_SUFFIX := "_test.gd"

var _tests_run := 0
var _tests_failed := 0


func _init() -> void:
	call_deferred("_run_tests")


func _run_tests() -> void:
	var test_files := _find_test_files()
	if test_files.is_empty():
		printerr("No test files matching *%s were found in %s." % [TEST_FILE_SUFFIX, TEST_DIRECTORY])
		quit(1)
		return

	print("Running %d test file(s)..." % test_files.size())
	for test_file in test_files:
		_run_test_file(test_file)

	print("\n%d test(s), %d failure(s)" % [_tests_run, _tests_failed])
	quit(0 if _tests_failed == 0 else 1)


func _find_test_files() -> Array[String]:
	var test_files: Array[String] = []
	var directory := DirAccess.open(TEST_DIRECTORY)
	if directory == null:
		return test_files

	directory.list_dir_begin()
	var file_name := directory.get_next()
	while not file_name.is_empty():
		if not directory.current_is_dir() and file_name.ends_with(TEST_FILE_SUFFIX):
			test_files.append(TEST_DIRECTORY.path_join(file_name))
		file_name = directory.get_next()
	directory.list_dir_end()
	test_files.sort()
	return test_files


func _run_test_file(test_file: String) -> void:
	var test_script := load(test_file) as GDScript
	if test_script == null:
		_record_runner_failure(test_file, "Could not load test script.")
		return

	var test_case := test_script.new() as RefCounted
	if not _is_valid_test_case(test_case):
		_record_runner_failure(
			test_file,
			"Test scripts must extend res://tests/test_case.gd."
		)
		return

	var test_methods: Array[StringName] = []
	for method: Dictionary in test_case.get_method_list():
		var method_name: StringName = method["name"]
		if String(method_name).begins_with("test_") and method["args"].is_empty():
			test_methods.append(method_name)
	test_methods.sort()

	if test_methods.is_empty():
		_record_runner_failure(test_file, "No zero-argument test_ methods were found.")
		return

	for test_method in test_methods:
		_run_test_method(test_file, test_case, test_method)


func _is_valid_test_case(test_case: Variant) -> bool:
	return (
		test_case is RefCounted
		and test_case.has_method("before_each")
		and test_case.has_method("after_each")
		and test_case.has_method("get_failures")
		and test_case.has_method("reset_assertions")
	)


func _run_test_method(test_file: String, test_case: RefCounted, test_method: StringName) -> void:
	_tests_run += 1
	test_case.reset_assertions()
	test_case.before_each()
	test_case.call(test_method)
	test_case.after_each()

	var failures: Array[String] = test_case.get_failures()
	var test_name := "%s::%s" % [test_file, test_method]
	if failures.is_empty():
		print("PASS %s" % test_name)
		return

	_tests_failed += 1
	printerr("FAIL %s" % test_name)
	for failure in failures:
		printerr("  %s" % failure)


func _record_runner_failure(test_file: String, message: String) -> void:
	_tests_run += 1
	_tests_failed += 1
	printerr("FAIL %s" % test_file)
	printerr("  %s" % message)

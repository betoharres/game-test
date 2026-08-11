extends "res://tests/test_case.gd"

const Controller := preload("res://scripts/player/first_person_controller.gd")

var _controller: FirstPersonController


func before_each() -> void:
	_controller = Controller.new()
	_controller.sprint_duration = 5.0
	_controller.stamina_regeneration_delay = 2.0
	_controller.stamina_regeneration_duration = 5.0
	_controller.stamina = _controller.sprint_duration


func after_each() -> void:
	_controller.free()


func test_sprinting_exhausts_stamina_after_five_seconds() -> void:
	_controller._update_stamina(5.0, true)

	assert_equal(_controller.stamina, 0.0)


func test_stamina_waits_two_seconds_before_regenerating() -> void:
	_controller._update_stamina(1.0, true)
	_controller._update_stamina(2.0, false)

	assert_equal(_controller.stamina, 4.0)

	_controller._update_stamina(0.5, false)

	assert_equal(_controller.stamina, 4.5)


func test_stamina_does_not_regenerate_while_sprinting() -> void:
	_controller.stamina = 2.0
	_controller._update_stamina(1.0, true)

	assert_equal(_controller.stamina, 1.0)

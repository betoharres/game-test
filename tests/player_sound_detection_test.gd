extends "res://tests/test_case.gd"

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _controller: FirstPersonController


func before_each() -> void:
	_controller = PLAYER_SCENE.instantiate() as FirstPersonController
	(Engine.get_main_loop() as SceneTree).root.add_child(_controller)


func after_each() -> void:
	_controller.free()


func test_player_is_a_detectable_sound_emitter() -> void:
	assert_true(_controller.is_in_group("detectable_sound_emitters"))


func test_player_is_an_enemy_vision_target() -> void:
	assert_true(_controller.is_in_group("players"))


func test_stationary_and_airborne_movement_are_silent() -> void:
	assert_equal(_controller._get_movement_sound_radius(false, true, false), 0.0)
	assert_equal(_controller._get_movement_sound_radius(true, false, false), 0.0)


func test_movement_uses_crouch_walk_and_sprint_radii() -> void:
	_controller.is_crouching = true
	assert_equal(
		_controller._get_movement_sound_radius(true, true, false),
		_controller.crouch_sound_radius
	)

	_controller.is_crouching = false
	assert_equal(
		_controller._get_movement_sound_radius(true, true, false),
		_controller.walk_sound_radius
	)
	assert_equal(
		_controller._get_movement_sound_radius(true, true, true),
		_controller.sprint_sound_radius
	)


func test_sound_radius_change_reports_radius_and_maximum() -> void:
	var emitted_values: Array[float] = []
	_controller.sound_radius_changed.connect(
		func(current_radius: float, maximum_radius: float) -> void:
			emitted_values.append(current_radius)
			emitted_values.append(maximum_radius)
	)

	_controller.current_sound_radius = _controller.walk_sound_radius

	assert_equal(emitted_values.size(), 2)
	assert_equal(emitted_values[0], _controller.walk_sound_radius)
	assert_equal(emitted_values[1], _controller.get_max_sound_radius())

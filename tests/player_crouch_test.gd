extends "res://tests/test_case.gd"

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _controller: FirstPersonController


func before_each() -> void:
	_controller = PLAYER_SCENE.instantiate() as FirstPersonController
	(Engine.get_main_loop() as SceneTree).root.add_child(_controller)


func after_each() -> void:
	Input.action_release("crouch")
	_controller.free()


func test_crouch_action_uses_control_key() -> void:
	var crouch_events := InputMap.action_get_events("crouch")

	assert_equal(crouch_events.size(), 1)
	assert_equal((crouch_events[0] as InputEventKey).physical_keycode, KEY_CTRL)


func test_player_crouches_only_while_action_is_held() -> void:
	Input.action_press("crouch")
	_controller._update_crouch_state(Input.is_action_pressed("crouch"))

	assert_true(_controller.is_crouching)
	assert_true(
		is_equal_approx(
			(_controller.collision_shape.shape as CapsuleShape3D).height,
			_controller.crouch_height
		)
	)

	Input.action_release("crouch")
	_controller._update_crouch_state(Input.is_action_pressed("crouch"))

	assert_false(_controller.is_crouching)


func test_crouching_reduces_footstep_volume() -> void:
	_controller.footstep_volume_variation_db = 0.0
	_controller.is_crouching = true
	_controller._play_footstep()

	assert_equal(
		_controller.footstep_players[0].volume_db,
		_controller.footstep_volume_db - _controller.crouch_footstep_attenuation_db
	)

	_controller.is_crouching = false
	_controller._play_footstep()

	assert_equal(
		_controller.footstep_players[1].volume_db,
		_controller.footstep_volume_db
	)

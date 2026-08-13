extends "res://tests/test_case.gd"

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")

var _world_environment: WorldEnvironment
var _controller: FirstPersonController


func before_each() -> void:
	_world_environment = WorldEnvironment.new()
	_world_environment.environment = Environment.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_world_environment)


func after_each() -> void:
	if _controller != null:
		_controller.free()
	_world_environment.free()


func test_local_player_configures_fog_on_its_camera() -> void:
	_controller = PLAYER_SCENE.instantiate() as FirstPersonController
	(Engine.get_main_loop() as SceneTree).root.add_child(_controller)

	var local_environment := _controller.camera.environment
	assert_not_null(local_environment)
	assert_true(local_environment.fog_enabled)
	assert_equal(local_environment.fog_mode, Environment.FOG_MODE_DEPTH)
	assert_equal(local_environment.fog_light_color, Color(0.008, 0.01, 0.014, 1.0))
	assert_equal(local_environment.fog_density, 1.0)
	assert_equal(local_environment.fog_depth_begin, 12.0)
	assert_equal(local_environment.fog_depth_end, 22.0)
	assert_false(_world_environment.environment.fog_enabled)


func test_remote_player_does_not_configure_fog() -> void:
	_controller = PLAYER_SCENE.instantiate() as FirstPersonController
	_controller.set_multiplayer_authority(2)
	(Engine.get_main_loop() as SceneTree).root.add_child(_controller)

	assert_null(_controller.camera.environment)
	assert_false(_world_environment.environment.fog_enabled)

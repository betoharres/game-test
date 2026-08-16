extends "res://tests/test_case.gd"

const ENEMY_SCENE := preload("res://scenes/enemies/placeholder_enemy.tscn")

class SoundTarget:
	extends Node3D
	var current_sound_radius: float = 0.0

var _enemy: PlaceholderEnemy
var _target: SoundTarget


func before_each() -> void:
	_enemy = ENEMY_SCENE.instantiate() as PlaceholderEnemy
	(Engine.get_main_loop() as SceneTree).root.add_child(_enemy)
	_target = SoundTarget.new()
	(Engine.get_main_loop() as SceneTree).root.add_child(_target)
	_target.add_to_group("players")
	_target.add_to_group("detectable_sound_emitters")


func after_each() -> void:
	_target.free()
	_enemy.free()


func test_vision_is_relaxed_outside_the_cone_or_behind_a_wall() -> void:
	assert_equal(
		_enemy._get_visual_detection_state(Vector3(10.0, 0.0, -1.0), true),
		PlaceholderEnemy.State.RELAXED
	)
	assert_equal(
		_enemy._get_visual_detection_state(Vector3(0.0, 0.0, -10.0), false),
		PlaceholderEnemy.State.RELAXED
	)


func test_vision_is_suspicious_in_far_third_and_attacking_when_nearer() -> void:
	assert_equal(
		_enemy._get_visual_detection_state(Vector3(0.0, 0.0, -10.0), true),
		PlaceholderEnemy.State.SUSPICIOUS
	)
	assert_equal(
		_enemy._get_visual_detection_state(Vector3(0.0, 0.0, -6.0), true),
		PlaceholderEnemy.State.ATTACKING
	)


func test_hearing_uses_emitter_radius_and_five_meter_attack_distance() -> void:
	assert_equal(
		_enemy._get_hearing_detection_state(7.0, 9.0),
		PlaceholderEnemy.State.SUSPICIOUS
	)
	assert_equal(
		_enemy._get_hearing_detection_state(4.0, 5.0),
		PlaceholderEnemy.State.ATTACKING
	)
	assert_equal(
		_enemy._get_hearing_detection_state(6.0, 5.0),
		PlaceholderEnemy.State.RELAXED
	)


func test_physics_update_changes_state_and_cube_color_in_real_time() -> void:
	_target.position = Vector3(0.0, 0.0, 7.0)
	_target.current_sound_radius = 9.0
	_enemy._physics_process(0.0)

	assert_equal(_enemy.current_state, PlaceholderEnemy.State.SUSPICIOUS)
	assert_equal(
		(_enemy.body.material_override as StandardMaterial3D).albedo_color,
		_enemy.suspicious_color
	)

	_target.position = Vector3(0.0, 0.0, 4.0)
	_enemy._physics_process(0.0)

	assert_equal(_enemy.current_state, PlaceholderEnemy.State.ATTACKING)
	assert_equal(
		(_enemy.body.material_override as StandardMaterial3D).albedo_color,
		_enemy.attacking_color
	)

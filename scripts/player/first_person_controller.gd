class_name FirstPersonController
extends CharacterBody3D

const FOOTSTEP_STREAMS: Array[AudioStream] = [
	preload("res://sounds/footsteps/data_pion-st1-footstep-sfx-323053.mp3"),
	preload("res://sounds/footsteps/data_pion-st2-footstep-sfx-323055.mp3"),
	preload("res://sounds/footsteps/data_pion-st3-footstep-sfx-323056.mp3"),
]

@export_group("Movement")
@export var walk_speed: float = 5.0
@export var sprint_speed: float = 8.0
@export var ground_acceleration: float = 24.0
@export var air_acceleration: float = 8.0
@export var jump_velocity: float = 7.0

@export_group("Footsteps")
@export_range(0.1, 1.0, 0.01) var walk_step_interval: float = 0.44
@export_range(0.1, 1.0, 0.01) var sprint_step_interval: float = 0.34
@export_range(-40.0, 0.0, 0.5) var footstep_volume_db: float = -12.0
@export_range(0.0, 6.0, 0.1) var footstep_volume_variation_db: float = 1.5
@export_range(0.0, 0.25, 0.01) var footstep_pitch_variation: float = 0.05

@export_group("Camera")
@export_range(0.01, 1.0, 0.01) var mouse_sensitivity: float = 0.1
@export_range(-89.0, 0.0, 1.0) var minimum_look_angle: float = -89.0
@export_range(0.0, 89.0, 1.0) var maximum_look_angle: float = 89.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var interaction_ray: RayCast3D = $Head/Camera3D/InteractionRay
@onready var body_mesh: MeshInstance3D = $BodyMesh
@onready var footstep_players: Array[AudioStreamPlayer] = [
	$FootstepPlayerA,
	$FootstepPlayerB,
]

var _gravity: float = float(ProjectSettings.get_setting("physics/3d/default_gravity"))
var _pitch: float = 0.0
var _footstep_timer: float = 0.0
var _next_footstep_player: int = 0
var _footstep_rng := RandomNumberGenerator.new()


func _ready() -> void:
	var is_local_player := is_multiplayer_authority()
	set_physics_process(is_local_player)
	set_process_unhandled_input(is_local_player)
	camera.current = is_local_player
	interaction_ray.enabled = is_local_player
	body_mesh.visible = not is_local_player
	if is_local_player:
		_footstep_rng.randomize()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not is_multiplayer_authority():
		return

	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate_camera(event.relative)


func _physics_process(delta: float) -> void:
	if not is_multiplayer_authority():
		return

	var input_direction := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var local_direction := Vector3(input_direction.x, 0.0, input_direction.y)
	var movement_direction := (transform.basis * local_direction).normalized()
	var is_sprinting := Input.is_action_pressed("sprint")
	var target_speed := sprint_speed if is_sprinting else walk_speed
	var acceleration := ground_acceleration if is_on_floor() else air_acceleration

	velocity.x = move_toward(velocity.x, movement_direction.x * target_speed, acceleration * delta)
	velocity.z = move_toward(velocity.z, movement_direction.z * target_speed, acceleration * delta)

	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = jump_velocity
	else:
		velocity.y -= _gravity * delta

	move_and_slide()
	_update_footsteps(delta, not input_direction.is_zero_approx(), is_sprinting)


func _update_footsteps(delta: float, has_movement_input: bool, is_sprinting: bool) -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	if not is_multiplayer_authority() or not is_on_floor() or not has_movement_input or horizontal_speed < 0.1:
		_footstep_timer = 0.0
		return

	_footstep_timer -= delta
	if _footstep_timer > 0.0:
		return

	_play_footstep()
	_footstep_timer = sprint_step_interval if is_sprinting else walk_step_interval


func _play_footstep() -> void:
	var footstep_player := footstep_players[_next_footstep_player]
	_next_footstep_player = (_next_footstep_player + 1) % footstep_players.size()
	footstep_player.stream = FOOTSTEP_STREAMS[_footstep_rng.randi_range(0, FOOTSTEP_STREAMS.size() - 1)]
	footstep_player.volume_db = footstep_volume_db + _footstep_rng.randf_range(
		-footstep_volume_variation_db,
		footstep_volume_variation_db
	)
	footstep_player.pitch_scale = _footstep_rng.randf_range(
		1.0 - footstep_pitch_variation,
		1.0 + footstep_pitch_variation
	)
	footstep_player.play()


func _rotate_camera(mouse_delta: Vector2) -> void:
	rotate_y(deg_to_rad(-mouse_delta.x * mouse_sensitivity))
	_pitch = clampf(
		_pitch - mouse_delta.y * mouse_sensitivity,
		minimum_look_angle,
		maximum_look_angle
	)
	head.rotation.x = deg_to_rad(_pitch)
